// © Sybl

import Foundation

extension LocationService {

  /// Indicates how frequent the device location updates.
  public enum UpdateFrequency: Comparable {

    /// The `LocationService` instance becomes inactive immediately and terminates any existing
    /// location update attempts.
    case never

    /// The `LocationService` instance becomes inactive as soon as it has updated the current
    /// location exactly once since this frequency is applied.
    case once

    /// The `LocationService` instance continuously updates the current location in the background
    /// upon significant location changes only.
    case background

    /// The `LocationService` instance continuously updates the current location for as long as it
    /// is active but at a lower precision.
    case loosely

    /// The `LocationService` instance continuously updates the current location for as long as it
    /// is active at the highest precision.
    case always
  }
}
