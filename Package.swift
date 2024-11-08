// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "GeoKit",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
  ],
  products: [
    .library(
      name: "GeoKit",
      targets: [
        "GeoKit",
      ]),
  ],
  targets: [
    .target(
      name: "GeoKit",
      path: "Sources"
    ),
    .testTarget(
      name: "GeoKitTests",
      dependencies: [
        "GeoKit",
      ],
      path: "Tests"
    ),
  ]
)
