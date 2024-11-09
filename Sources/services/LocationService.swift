import CoreLocation

/// Provides access to and manages device location data. Certain operations may
/// run in the background (if specified to do so) even when the app is
/// terminated (i.e. to periodically fetch location updates given that device
/// location access permissions allow).
///
/// - SeeAlso:
///   https://developer.apple.com/library/content/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html#//apple_ref/doc/uid/TP40015243-CH24-SW1
public class LocationService: NSObject {

  /// The most recently retrieved device location.
  public var currentLocation: CLLocation? { manager?.location }

  /// The most recently retrieved device heading.
  public var currentHeading: CLHeading? { manager?.heading }

  /// Current region code (i.e. useful for phone numbers) if applicable.
  public var currentRegionCode: String? {
    if let regionCode = currentPlacemark?.isoCountryCode {
      return regionCode
    }
    else if let regionCode = Locale.current.regionCode {
      return regionCode
    }

    return nil
  }

  /// The minimum distance (in meters) a device must travel before an imprecise
  /// location update event is generated (i.e. when the update frequency is set
  /// to `loosely`).
  public var impreciseDistanceFilter: CLLocationDistance = 50.0

  /// The minimum distance (in meters) a device must travel before a precise
  /// location update event is generated (i.e. when the update frequency is set
  /// to `always`).
  public var preciseDistanceFilter: CLLocationDistance = 20.0

  /// Specifies how long it takes (in seconds) before a location update attempt
  /// times out.
  public var locationUpdateTimeoutInterval: TimeInterval = 1.0

  /// Gets the current device location access authorization status.
  public var authorizationStatus: AuthorizationStatus {
    let status = manager?.authorizationStatus

    switch status {
    case .authorizedAlways:
      return .authorized
    case .authorizedWhenInUse:
      return .restricted
    case .notDetermined, .none:
      return .notDetermined
    case .restricted,
         .denied:
      return .denied
    @unknown default:
      return .notDetermined
    }
  }

  /// Indicates if user has already requested for "Always" authorization
  /// (meaning that it subsequent requests will be ignored).
  public private(set) var hasAlreadyRequestedForBackgroundAuthorization: Bool {
    get {
      UserDefaults.standard.bool(forKey: "hasAlreadyRequestedForBackgroundAuthorization")
    }

    set {
      UserDefaults.standard.set(newValue, forKey: "hasAlreadyRequestedForBackgroundAuthorization")
    }
  }

  /// The current location update frequency.
  public private(set) var updateFrequency: UpdateFrequency = .never

  /// Placemark instance used for determining the phone number region code of
  /// the device's current location.
  public private(set) var currentPlacemark: CLPlacemark?

  private var manager: CLLocationManager?
  private var observers: [WeakReference<LocationServiceObserver>] = []
  private var timeoutTimer: Timer?

  public override init() {
    super.init()

    self.manager = CLLocationManager()
    self.manager?.allowsBackgroundLocationUpdates = true
    self.manager?.pausesLocationUpdatesAutomatically = true
    self.manager?.activityType = .fitness
    self.manager?.delegate = self

    _log.debug { "Starting location service... OK" }
  }

  /// Requests for permission to access the device location. The authorization
  /// level to request for is automatically determined depending on the current
  /// authorization status.
  ///
  /// - Parameters:
  ///   - failureHandler: Handler invoked when authorization cannot be requested
  ///                     by the location manager.
  public func requestAuthorization(failure failureHandler: @escaping (AuthorizationStatus) -> Void = { _ in }) {
    // Starting from iOS 13, location access becomes a bit more strict.
    if #available(iOS 13.0, *) {
      switch authorizationStatus {
      case .notDetermined:
        // When the status is not determined, request for a less invasive
        // location access permission, i.e. user can decide to at most allow
        // location access while using the app.
        manager?.requestWhenInUseAuthorization()
      case .denied:
        // When the status is explicitly denied by the user, the only way to
        // change it is via settings. Redirect the user.
        failureHandler(.denied)
      case .restricted:
        // When the status is restricted, meaning the user has only allowed for
        // location access while the app is in use, only then can we ask for a
        // higher permission level, i.e. granting location access even when the
        // app is in the background. Note that if this status is a result of the
        // user allowing location access just once, the following method does
        // nothing.
        if !hasAlreadyRequestedForBackgroundAuthorization {
          manager?.requestAlwaysAuthorization()
          hasAlreadyRequestedForBackgroundAuthorization = true
        }
        else {
          failureHandler(.restricted)
        }
      case .authorized:
        // Nothing to do here.
        break
      }
    }
    else {
      switch authorizationStatus {
      case .notDetermined, .restricted:
        manager?.requestAlwaysAuthorization()
      case .denied:
        failureHandler(.denied)
      case .authorized:
        break
      }
    }
  }

  /// Changes the current location update frequency.
  ///
  /// - Parameters:
  ///   - newUpdateFrequency: New update frequency.
  public func changeUpdateFrequency(_ newUpdateFrequency: UpdateFrequency) {
    let authorizationStatus = self.authorizationStatus

    // Deactivate `LocationService` if authorization status is not allowed or if
    // update frequency is set to `never`.
    guard authorizationStatus == .authorized || authorizationStatus == .restricted, newUpdateFrequency != .never else {
      manager?.stopMonitoringSignificantLocationChanges()
      manager?.stopUpdatingLocation()

      updateFrequency = .never

      _log.error { "Changing update frequency... ERR: Insufficient permissions, resetting to \(UpdateFrequency.never)" }

      return
    }

    // Ignore if frequency did not change unless the new frequency is
    // `background`, which requires special attention.
    guard newUpdateFrequency != updateFrequency || newUpdateFrequency == .background else { return }

    stopLocationUpdateTimer()

#if os(iOS) || os(watchOS)
    manager?.stopUpdatingHeading()
#endif
    manager?.stopUpdatingLocation()
    manager?.stopMonitoringSignificantLocationChanges()

    switch newUpdateFrequency {
    case .once:
      manager?.desiredAccuracy = kCLLocationAccuracyBest
      manager?.distanceFilter = kCLDistanceFilterNone
      manager?.startUpdatingLocation()
      manager?.startUpdatingHeading()
    case .background:
      if CLLocationManager.significantLocationChangeMonitoringAvailable() {
        manager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager?.distanceFilter = kCLDistanceFilterNone
        manager?.startMonitoringSignificantLocationChanges()
      }
    case .loosely:
      manager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
      manager?.distanceFilter = impreciseDistanceFilter
      manager?.startUpdatingLocation()
      manager?.startUpdatingHeading()
    case .always:
      manager?.desiredAccuracy = kCLLocationAccuracyBest
      manager?.distanceFilter = preciseDistanceFilter
      manager?.startUpdatingLocation()
      manager?.startUpdatingHeading()
    default:
      break
    }

    // Start anticipating for a timeout if the frequency is not `background`.
    if newUpdateFrequency != .background {
      startLocationUpdateTimer()
    }

    updateFrequency = newUpdateFrequency

    _log.debug { "Changing update frequency... OK: \(updateFrequency)" }
  }

  /// Registers an observer.
  ///
  /// - Parameters:
  ///   - observer: The observer to add.
  public func addObserver(_ observer: LocationServiceObserver) {
    observers = observers.filter { $0.get() as AnyObject !== observer as AnyObject } + [WeakReference(observer)]
  }

  /// Unregisters an existing observer.
  ///
  /// - Parameters:
  ///   - observer: The observer to remove.
  public func removeObserver(_ observer: LocationServiceObserver) {
    observers = observers.filter { $0.get() as AnyObject !== observer as AnyObject }
  }


  private func notifyObservers(iteratee: (LocationServiceObserver) -> Void) {
    for o in observers {
      guard let observer = o.get() else { continue }
      iteratee(observer)
    }
  }

  private func startLocationUpdateTimer() {
    stopLocationUpdateTimer()
    timeoutTimer = Timer.scheduledTimer(timeInterval: locationUpdateTimeoutInterval, target: self, selector: #selector(locationUpdateDidTimeout), userInfo: nil, repeats: false)
  }

  private func stopLocationUpdateTimer() {
    timeoutTimer?.invalidate()
    timeoutTimer = nil
  }

  @objc
  private func locationUpdateDidTimeout() {
    _log.error { "Updating location... ERR: Timed out after \(locationUpdateTimeoutInterval)s" }

    stopLocationUpdateTimer()

    notifyObservers {
      $0.locationService(self, locationUpdateDidTimeoutAfter: locationUpdateTimeoutInterval)
    }

    switch updateFrequency {
    // If the update frequency is set to `once` and a timeout occurred, simply
    // stop updating location.
    case .once:
      changeUpdateFrequency(.never)
    // Otherwise do nothing.
    default:
      break
    }
  }
}

extension LocationService: CLLocationManagerDelegate {
  public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let newLocation = locations.last else { return }

    _log.debug { "Updating location... OK: \(newLocation)" }

    stopLocationUpdateTimer()

    switch updateFrequency {
    case .once:
      changeUpdateFrequency(.never)
    default:
      break
    }

    CLGeocoder().reverseGeocodeLocation(newLocation) { placemarks, error in
      guard error == nil, let placemark = placemarks?.first else { return }
      self.currentPlacemark = placemark
    }

    notifyObservers {
      $0.locationService(self, locationDidChange: newLocation)
    }
  }

  public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    _log.debug { "Updating heading... OK: \(newHeading)" }

    notifyObservers {
      $0.locationService(self, headingDidChange: newHeading)
    }
  }

  public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    _log.debug { "Changing authorization status... OK: \(status)" }

    switch status {
    case .notDetermined:
      hasAlreadyRequestedForBackgroundAuthorization = false
    default:
      break
    }

    notifyObservers {
      $0.locationService(self, authorizationStatusDidChange: authorizationStatus)
    }
  }

  public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    _log.error { "Updating location... ERR: \(error)" }

    notifyObservers {
      $0.locationService(self, locationUpdateDidFailWithError: error)
    }
  }
}
