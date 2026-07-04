// swift-tools-version: 6.0
import PackageDescription

// TestableUIKit MCP server (Swift) — independent sub-package.
//
// [Design intent: dependency containment]
// The MCP swift-sdk requires tools-version 6.1 / iOS16 / macOS13, so bundling it
// with the main TestableUIKit package (tools 5.9 / iOS15) would pull transitive
// dependencies (iOS16, Swift 6, swift-system, etc.) onto all library consumers.
// To avoid this, the MCP server is split out as a completely independent sub-package
// and the main Package.swift is left untouched.
// The MCP server communicates with TestableUIKit via HTTP IPC only (no Swift type
// imports), so source sharing is unnecessary and this separation is valid.
let package = Package(
  name: "TestableUIKitMCP",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "TestableUIKitMCP",
      targets: ["TestableUIKitMCP"]
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/modelcontextprotocol/swift-sdk.git",
      from: "0.12.1"
    )
  ],
  targets: [
    // Pure helpers (no external dependencies, no swift-sdk). XCTest target.
    .target(
      name: "TestableUIKitMCPCore",
      dependencies: [],
      path: "Sources/TestableUIKitMCPCore"
    ),
    // MCP server executable. swift-sdk dependency is scoped to this target only.
    .executableTarget(
      name: "TestableUIKitMCP",
      dependencies: [
        "TestableUIKitMCPCore",
        .product(name: "MCP", package: "swift-sdk")
      ],
      path: "Sources/TestableUIKitMCP"
    ),
    // Unit tests for pure functions (no swift-sdk dependency).
    .testTarget(
      name: "TestableUIKitMCPCoreTests",
      dependencies: ["TestableUIKitMCPCore"],
      path: "Tests/TestableUIKitMCPCoreTests"
    )
  ]
)
