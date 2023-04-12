// swift-tools-version:5.5

import PackageDescription

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

enum Environment: String {
  case local
  case development
  case production

  static func get() -> Environment {
    if let envPointer = getenv("SWIFT_ENV"), let environment = Environment(rawValue: String(cString: envPointer)) {
      return environment
    }
    else if let envPointer = getenv("CI"), String(cString: envPointer) == "true" {
      return .production
    }
    else {
      return .local
    }
  }
}

var dependencies: [Package.Dependency] = [

]

switch Environment.get() {
case .local:
  dependencies.append(.package(path: "../BaseKit"))
case .development:
  dependencies.append(.package(name: "BaseKit", url: "https://github.com/ghoztsys/swift-basekit", .branch("master")))
case .production:
  dependencies.append(.package(name: "BaseKit", url: "https://github.com/ghoztsys/swift-basekit", from: "0.30.0"))
}

let package = Package(
  name: "GeoKit",
  platforms: [.iOS(.v15)],
  products: [
    .library(
      name: "GeoKit",
      targets: ["GeoKit"]),
  ],
  dependencies: dependencies,
  targets: [
    .target(
      name: "GeoKit",
      dependencies: ["BaseKit"]),
    .testTarget(
      name: "GeoKitTests",
      dependencies: ["GeoKit"]),
  ]
)
