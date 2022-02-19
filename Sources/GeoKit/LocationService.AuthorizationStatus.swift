// © GHOZT

import Foundation

extension LocationService {

  /// User-granted authorization status of accessing the device's location.
  public enum AuthorizationStatus: Comparable {

    // Permission is explicitly denied.
    case denied

    // User has not been prompted for granting permission yet, or user previously selected "Allow
    // Once" and this is a subsequent app session.
    case notDetermined

    // Permission is only granted when the app is in use, or when the user selected "Allow Once" in
    // this app session.
    case restricted

    // Permission is granted even for background access ("Always Allow").
    case authorized
  }
}
