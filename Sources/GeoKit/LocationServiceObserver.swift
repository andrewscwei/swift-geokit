// © GHOZT

import Foundation
import CoreLocation

/// An object conforming to this protocol becomes an observer of `LocationService`.
public protocol LocationServiceObserver {

  /// Method invoked when the device location is changed. This can occur while the application is
  /// running in the background.
  ///
  /// - Parameters:
  ///   - service: The `LocationService` instance that invoked this method.
  ///   - newLocation: The new location.
  ///   - inBackground: Indicates if the location change occurred while the application is running
  ///                   in the background.
  func locationService(_ service: LocationService, locationDidChange newLocation: CLLocation, inBackground: Bool)

  /// Method invoked when the device heading is change. This can occur while the application is
  /// running in the background.
  ///
  /// - Parameters:
  ///   - service: The `LocationService` isntance that invoked this method.
  ///   - newHeading: The new heading.
  ///   - inBackground: Indicates if the heading change occurred while the application is running in
  ///                   the background.
  func locationService(_ service: LocationService, headingDidChange newHeading: CLHeading, inBackground: Bool)

  /// Method invoked when an attempt to fetch the current device location times out.
  ///
  /// - Parameters:
  ///   - service: The `LocationService` instance that invoked this method.
  ///   - timeout: The timeout interval (in seconds).
  func locationService(_ service: LocationService, locationUpdateDidTimeoutAfter timeout: TimeInterval)

  /// Method invoked when an attempt to fetch the current device location fails.
  ///
  /// - Parameters:
  ///   - service: The `LocationService` instance that invoked this method.
  ///   - error: The `Error` that occurred.
  func locationService(_ service: LocationService, locationUpdateDidFailWithError error: Error)

  /// Method invoked when the location access authorization status changes.
  ///
  /// - Parameters:
  ///   - service: The `LocationService` instance that invoked this method.
  ///   - authorizationStatus: The new authorization status.
  func locationService(_ service: LocationService, authorizationStatusDidChange authorizationStatus: LocationService.AuthorizationStatus)
}

extension LocationServiceObserver {

  public func locationService(_ service: LocationService, locationDidChange newLocation: CLLocation, inBackground: Bool) {}

  public func locationService(_ service: LocationService, headingDidChange newHeading: CLHeading, inBackground: Bool) {}

  public func locationService(_ service: LocationService, locationUpdateDidTimeoutAfter timeout: TimeInterval) {}

  public func locationService(_ service: LocationService, locationUpdateDidFailWithError error: Error) {}

  public func locationService(_ service: LocationService, authorizationStatusDidChange authorizationStatus: LocationService.AuthorizationStatus) {}
}
