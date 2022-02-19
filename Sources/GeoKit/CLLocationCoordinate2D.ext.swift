// © GHOZT

import CoreLocation

extension CLLocationCoordinate2D {

  /// Array representation of this `CLLocationCoordinate2D` in the format of `[longitude,
  /// latitude]`.
  public var arrayValue: [CLLocationDegrees] {
    return [self.longitude, self.latitude]
  }

  /// Initializes a `CLLocationCoordinate2D` using an array representation of a 2D coordinate in the
  /// format of [longitude, latitude]`.
  ///
  /// - Parameters:
  ///   - arrayValue: Array representation of a 2D coordinate.
  public init?(arrayValue: [CLLocationDegrees]) {
    guard arrayValue.count == 2 else { return nil }

    let longitude = arrayValue[0]
    let latitude = arrayValue[1]

    self.init(latitude: latitude, longitude: longitude)
  }
}
