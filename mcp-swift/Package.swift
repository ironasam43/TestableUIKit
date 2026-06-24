// swift-tools-version: 6.0
import PackageDescription

// TestableUIKit MCP サーバ（Swift 版）独立 sub-package。
//
// 【依存封じ込めの設計意図】
// MCP swift-sdk は tools-version 6.1 / iOS16・macOS13 を要求するため、
// メインの TestableUIKit パッケージ（tools 5.9 / iOS15）に同梱すると
// library consumer まで iOS16・Swift6・swift-system 等の transitive 依存へ
// 巻き込んでしまう。これを避けるため MCP サーバは **完全に独立した
// sub-package** として分離し、メイン Package.swift には一切手を入れない。
// MCP サーバは TestableUIKit の Swift 型を import せず HTTP IPC のみで
// 通信するため、ソース共有は不要でこの分離が成立する。
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
    // 純粋ヘルパー（外部依存ゼロ・swift-sdk 非依存）。XCTest 対象。
    .target(
      name: "TestableUIKitMCPCore",
      dependencies: [],
      path: "Sources/TestableUIKitMCPCore"
    ),
    // MCP サーバ本体。swift-sdk 依存はこの executable のみに付与する。
    .executableTarget(
      name: "TestableUIKitMCP",
      dependencies: [
        "TestableUIKitMCPCore",
        .product(name: "MCP", package: "swift-sdk")
      ],
      path: "Sources/TestableUIKitMCP"
    ),
    // 純関数の機械検証（swift-sdk 非依存）。
    .testTarget(
      name: "TestableUIKitMCPCoreTests",
      dependencies: ["TestableUIKitMCPCore"],
      path: "Tests/TestableUIKitMCPCoreTests"
    )
  ]
)
