// © GHOZT

import ArcKit
import BaseKit
import CoreLocation
import UIKit

/// Provides access to and manages device location data. Certain operations may
/// run in the background (if specified to do so) even when the app is
/// terminated (i.e. to periodically fetch location updates given that device
/// location access permissions allow).
///
/// - SeeAlso:
///   https://developer.apple.com/library/content/documentation/Performance/Conceptual/EnergyGuide-iOS/LocationBestPractices.html#//apple_ref/doc/uid/TP40015243-CH24-SW1
public class LocationService: NSObject, Observable {

  public typealias Observer = LocationServiceObserver

  /// Specifies if debug mode is enabled (generating debug logs).
  public var debugMode: Bool { false }

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
    let status = CLLocationManager.authorizationStatus()

    switch status {
    case .authorizedAlways:
      return .authorized
    case .authorizedWhenInUse:
      return .restricted
    case .notDetermined:
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
  @UserDefault("hasAlreadyRequestedForAlwaysAuthorization", default: false)
  public private(set) var hasAlreadyRequestedForAlwaysAuthorization: Bool

  /// Internal `CLLocationManager` instance.
  private var manager: CLLocationManager?

  /// The current location update frequency.
  public private(set) var updateFrequency: UpdateFrequency = .never

  /// Timer for tracking location request timeouts.
  private var timeoutTimer: Timer?

  /// Placemark instance used for determining the phone number region code of
  /// the device's current location.
  public private(set) var currentPlacemark: CLPlacemark?

  public override init() {
    super.init()

    self.manager = CLLocationManager()
    self.manager?.allowsBackgroundLocationUpdates = true
    self.manager?.pausesLocationUpdatesAutomatically = true
    self.manager?.activityType = .fitness
    self.manager?.delegate = self
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
        if !hasAlreadyRequestedForAlwaysAuthorization {
          manager?.requestAlwaysAuthorization()
          hasAlreadyRequestedForAlwaysAuthorization = true
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
      case .notDetermined, .restricted: manager?.requestAlwaysAuthorization()
      case .denied: failureHandler(.denied)
      case .authorized: break
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
      timeoutTimer?.invalidate()
      timeoutTimer = nil
      manager?.stopMonitoringSignificantLocationChanges()
      manager?.stopUpdatingLocation()
      self.updateFrequency = .never
      return
    }

    // Ignore if frequency did not change unless the new frequency is
    // `background`, which requires special attention.
    guard newUpdateFrequency != updateFrequency || newUpdateFrequency == .background else { return }

    manager?.stopUpdatingHeading()
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

    timeoutTimer?.invalidate()

    // Start anticipating for a timeout if the frequency is not `background`.
    if newUpdateFrequency != .background {
      timeoutTimer = Timer.scheduledTimer(timeInterval: locationUpdateTimeoutInterval, target: self, selector: #selector(locationUpdateDidTimeout), userInfo: nil, repeats: false)
    }

    updateFrequency = newUpdateFrequency

    log(.debug, isEnabled: debugMode) { "Setting location update frequency... OK: \(newUpdateFrequency)" }
  }

  /// Handler invoked when the most recent location update attempt has timed out.
  @objc private func locationUpdateDidTimeout() {
    timeoutTimer?.invalidate()
    timeoutTimer = nil

    notifyObservers {
      $0.locationService(self, locationUpdateDidTimeoutAfter: locationUpdateTimeoutInterval)
    }

    switch updateFrequency {
    // If the update frequency is set to `once` and a timeout occurred, simply
    // stop updating location.
    case .once:
      changeUpdateFrequency(.never)
    // If the update frequency is continuous and a timeout occurred, prepare to
    // capture the next update timeout.
    case .loosely,
         .always:
      timeoutTimer = Timer.scheduledTimer(timeInterval: locationUpdateTimeoutInterval, target: self, selector: #selector(locationUpdateDidTimeout), userInfo: nil, repeats: false)
    // Otherwise do nothing.
    default: break
    }
  }
}

extension LocationService: CLLocationManagerDelegate {

  public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let newLocation = locations.last else { return }

    let isInBackground = UIApplication.shared.applicationState == .background

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

    log(.debug, isEnabled: debugMode) { "Processing location update... OK: \(newLocation.coordinate)" }

    notifyObservers {
      if isInBackground {
        guard $0 is BackgroundService else { return }
        $0.locationService(self, locationDidChange: newLocation, inBackground: true)
      }
      else {
        $0.locationService(self, locationDidChange: newLocation, inBackground: false)
      }
    }
  }

  public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    log(.debug, isEnabled: debugMode) { "Processing heading update... OK: \(newHeading)" }

    let isInBackground = UIApplication.shared.applicationState == .background

    notifyObservers {
      if isInBackground {
        guard $0 is BackgroundService else { return }
        $0.locationService(self, headingDidChange: newHeading, inBackground: true)
      }
      else {
        $0.locationService(self, headingDidChange: newHeading, inBackground: false)
      }
    }
  }

  public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .notDetermined:
      hasAlreadyRequestedForAlwaysAuthorization = false
    default: break
    }

    notifyObservers {
      $0.locationService(self, authorizationStatusDidChange: authorizationStatus)
    }
  }

  public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    log(.error, isEnabled: debugMode) { "Processing location update... ERR: \(error.localizedDescription)" }

    notifyObservers {
      $0.locationService(self, locationUpdateDidFailWithError: error)
    }
  }
}
