// © GHOZT

import CoreLocation

extension CLLocationCoordinate2D {

  /// Array representation of this `CLLocationCoordinate2D` in the format of
  /// `[longitude, latitude]`.
  public var arrayValue: [CLLocationDegrees] {
    return [self.longitude, self.latitude]
  }

  /// Initializes a `CLLocationCoordinate2D` using an array representation of a
  /// 2D coordinate in the format of [longitude, latitude]`.
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

extension CLLocationCoordinate2D: Equatable {

  public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.arrayValue == rhs.arrayValue
  }
}

extension CLLocationCoordinate2D: Codable {

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let arrayValue = try container.decode([CLLocationDegrees].self)

    self = .init(latitude: arrayValue[1], longitude: arrayValue[0])
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    try container.encode(arrayValue)
  }
}
