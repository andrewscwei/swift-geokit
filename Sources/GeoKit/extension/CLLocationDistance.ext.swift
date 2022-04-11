// © GHOZT

import CoreLocation
import MapKit

extension CLLocationDistance {

  /// String representation of this distance.
  public var stringValue: String {
    let formatter = MKDistanceFormatter()
    formatter.unitStyle = .abbreviated
    return formatter.string(fromDistance: self)
  }

  /// Radians representation of this distance (with respect to Earth).
  public var radiansValue: Double {
    let earthRadiusInMeters = 6378.0 * 1000.0
    return self / earthRadiusInMeters
  }

  /// Degrees representation of this distance (with respect to Earth).
  public var degreesValue: CLLocationDegrees {
    return radiansValue * 180 / .pi
  }
}
