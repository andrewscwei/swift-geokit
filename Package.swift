// swift-tools-version:5.3

import PackageDescription

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

enum Environment: String {
  static let `default`: Environment = .local

  case local
  case development
  case production

  static func get() -> Environment {
    if let envPointer = getenv("CI"), String(cString: envPointer) == "true" {
      return .production
    }
    else if let envPointer = getenv("SWIFT_ENV") {
      let env = String(cString: envPointer)
      return Environment(rawValue: env) ?? .default
    }
    else {
      return .default
    }
  }
}

let package = Package(
  name: "GeoKit",
  platforms: [.iOS(.v11)],
  products: [
    .library(
      name: "GeoKit",
      targets: ["GeoKit"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "GeoKit",
      dependencies: []),
    .testTarget(
      name: "GeoKitTests",
      dependencies: ["GeoKit"]),
  ]
)
