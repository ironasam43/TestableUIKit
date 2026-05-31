// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "TestableUIKit",
  platforms: [
    .iOS(.v15),
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "TestableUIKit",
      targets: ["TestableUIKit"]
    ),
    .executable(
      name: "TestableUIKitDemo",
      targets: ["TestableUIKitDemo"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "TestableUIKit",
      dependencies: [],
      path: "Sources/TestableUIKit"
    ),
    .executableTarget(
      name: "TestableUIKitDemo",
      dependencies: ["TestableUIKit"],
      path: "Sources/TestableUIKitDemo"
    ),
    .testTarget(
      name: "TestableUIKitTests",
      dependencies: ["TestableUIKit"],
      path: "Tests/TestableUIKitTests"
    )
  ]
)
