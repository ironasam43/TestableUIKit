//
//  IPCHelpersTests.swift
//  TestableUIKitMCPCoreTests
//
//  L1 テスト: MCP サーバ（Swift 版）の純粋ヘルパー関数。
//  Simulator / DemoApp / HTTP / swift-sdk 不要。
//  移植元 Tests/unit/test_mcp_helpers.py（Python）と 1:1 で対応する。
//

import XCTest

@testable import TestableUIKitMCPCore

final class BuildBaseURLTests: XCTestCase {
  func test_default_url() {
    XCTAssertEqual(IPCHelpers.buildBaseURL(), "http://localhost:8888")
  }
  func test_default_host_constant() {
    XCTAssertEqual(IPCHelpers.defaultIPCHost, "localhost")
  }
  func test_default_port_constant() {
    XCTAssertEqual(IPCHelpers.defaultIPCPort, 8888)
  }
  func test_custom_port() {
    XCTAssertEqual(IPCHelpers.buildBaseURL(port: 9000), "http://localhost:9000")
  }
  func test_custom_host() {
    XCTAssertEqual(IPCHelpers.buildBaseURL(host: "192.168.1.1"), "http://192.168.1.1:8888")
  }
  func test_custom_host_and_port() {
    XCTAssertEqual(IPCHelpers.buildBaseURL(host: "10.0.0.1", port: 9999), "http://10.0.0.1:9999")
  }
  func test_no_trailing_slash() {
    XCTAssertFalse(IPCHelpers.buildBaseURL().hasSuffix("/"))
  }
}

final class BuildPerformPayloadTests: XCTestCase {
  func test_minimal_getstate() {
    let p = IPCHelpers.buildPerformPayload(testID: "scene.auth.loginButton", commandName: "getState")
    XCTAssertEqual(
      p,
      #"{"testID":"scene.auth.loginButton","commandName":"getState","parameters":null}"#
    )
  }
  func test_tap_command() {
    let p = IPCHelpers.buildPerformPayload(testID: "counter", commandName: "tap")
    XCTAssertEqual(p, #"{"testID":"counter","commandName":"tap","parameters":null}"#)
  }
  func test_set_property_with_params() {
    let p = IPCHelpers.buildPerformPayload(
      testID: "loginButton", commandName: "setProperty",
      parametersJSON: #"{"key":"isEnabled","value":false}"#
    )
    XCTAssertEqual(
      p,
      #"{"testID":"loginButton","commandName":"setProperty","parameters":{"key":"isEnabled","value":false}}"#
    )
  }
  func test_explicit_nil_parameters_matches_default() {
    let a = IPCHelpers.buildPerformPayload(testID: "id1", commandName: "cmd1")
    let b = IPCHelpers.buildPerformPayload(testID: "id1", commandName: "cmd1", parametersJSON: nil)
    XCTAssertEqual(a, b)
  }
  func test_key_order_fixed() {
    // キー順は testID → commandName → parameters で決定的
    let p = IPCHelpers.buildPerformPayload(testID: "foo", commandName: "bar")
    let idxTestID = p.range(of: "testID")!.lowerBound
    let idxCommand = p.range(of: "commandName")!.lowerBound
    let idxParams = p.range(of: "parameters")!.lowerBound
    XCTAssertTrue(idxTestID < idxCommand)
    XCTAssertTrue(idxCommand < idxParams)
  }
  func test_special_chars_escaped() {
    // testID にダブルクオートが含まれてもエスケープされ JSON が壊れない
    let p = IPCHelpers.buildPerformPayload(testID: #"a"b"#, commandName: "tap")
    XCTAssertEqual(p, #"{"testID":"a\"b","commandName":"tap","parameters":null}"#)
  }
}

final class BuildSimctlScreenshotCommandTests: XCTestCase {
  func test_exact_command() {
    XCTAssertEqual(
      IPCHelpers.buildSimctlScreenshotCommand(outputPath: "/tmp/screenshot.png"),
      ["xcrun", "simctl", "io", "booted", "screenshot", "/tmp/screenshot.png"]
    )
  }
  func test_custom_path() {
    let cmd = IPCHelpers.buildSimctlScreenshotCommand(outputPath: "/custom/path/image.png")
    XCTAssertEqual(cmd.last, "/custom/path/image.png")
  }
  func test_xcrun_is_first() {
    XCTAssertEqual(IPCHelpers.buildSimctlScreenshotCommand(outputPath: "/tmp/test.png").first, "xcrun")
  }
  func test_simctl_is_second() {
    XCTAssertEqual(IPCHelpers.buildSimctlScreenshotCommand(outputPath: "/tmp/test.png")[1], "simctl")
  }
  func test_screenshot_in_command() {
    XCTAssertTrue(IPCHelpers.buildSimctlScreenshotCommand(outputPath: "/tmp/test.png").contains("screenshot"))
  }
  func test_booted_in_command() {
    XCTAssertTrue(IPCHelpers.buildSimctlScreenshotCommand(outputPath: "/tmp/test.png").contains("booted"))
  }
}

final class ResolveIPCHostPortTests: XCTestCase {
  func test_defaults_when_no_env() {
    let (host, port) = IPCHelpers.resolveIPCHostPort(env: [:])
    XCTAssertEqual(host, "localhost")
    XCTAssertEqual(port, 8888)
  }
  func test_env_host_overrides() {
    let (host, port) = IPCHelpers.resolveIPCHostPort(env: [IPCHelpers.envIPCHost: "192.168.1.100"])
    XCTAssertEqual(host, "192.168.1.100")
    XCTAssertEqual(port, 8888)
  }
  func test_env_port_overrides() {
    let (host, port) = IPCHelpers.resolveIPCHostPort(env: [IPCHelpers.envIPCPort: "9000"])
    XCTAssertEqual(host, "localhost")
    XCTAssertEqual(port, 9000)
  }
  func test_env_host_and_port_both_override() {
    let (host, port) = IPCHelpers.resolveIPCHostPort(
      env: [IPCHelpers.envIPCHost: "10.0.0.1", IPCHelpers.envIPCPort: "9999"]
    )
    XCTAssertEqual(host, "10.0.0.1")
    XCTAssertEqual(port, 9999)
  }
  func test_invalid_port_falls_back_to_default() {
    let (_, port) = IPCHelpers.resolveIPCHostPort(env: [IPCHelpers.envIPCPort: "not_a_number"])
    XCTAssertEqual(port, IPCHelpers.defaultIPCPort)
  }
  func test_env_constant_host_name() {
    XCTAssertEqual(IPCHelpers.envIPCHost, "TESTABLE_IPC_HOST")
  }
  func test_env_constant_port_name() {
    XCTAssertEqual(IPCHelpers.envIPCPort, "TESTABLE_IPC_PORT")
  }
  func test_build_base_url_with_resolved_values() {
    let (host, port) = IPCHelpers.resolveIPCHostPort(
      env: [IPCHelpers.envIPCHost: "192.168.1.50", IPCHelpers.envIPCPort: "9001"]
    )
    XCTAssertEqual(IPCHelpers.buildBaseURL(host: host, port: port), "http://192.168.1.50:9001")
  }
}

final class BuildScreenshotURLTests: XCTestCase {
  func test_default_url() {
    XCTAssertEqual(IPCHelpers.buildScreenshotURL(), "http://localhost:8888/screenshot")
  }
  func test_custom_host() {
    XCTAssertEqual(
      IPCHelpers.buildScreenshotURL(host: "192.168.0.181"),
      "http://192.168.0.181:8888/screenshot"
    )
  }
  func test_custom_port() {
    XCTAssertEqual(IPCHelpers.buildScreenshotURL(port: 9000), "http://localhost:9000/screenshot")
  }
  func test_custom_host_and_port() {
    XCTAssertEqual(
      IPCHelpers.buildScreenshotURL(host: "10.0.0.1", port: 9999),
      "http://10.0.0.1:9999/screenshot"
    )
  }
  func test_ends_with_screenshot() {
    XCTAssertTrue(IPCHelpers.buildScreenshotURL().hasSuffix("/screenshot"))
  }
  func test_consistent_with_base_url() {
    let host = "192.168.1.1"
    let port = 9001
    let expected = "\(IPCHelpers.buildBaseURL(host: host, port: port))/screenshot"
    XCTAssertEqual(IPCHelpers.buildScreenshotURL(host: host, port: port), expected)
  }
}

final class IsLoopbackHostTests: XCTestCase {
  func test_localhost_is_loopback() {
    XCTAssertTrue(IPCHelpers.isLoopbackHost("localhost"))
  }
  func test_127_0_0_1_is_loopback() {
    XCTAssertTrue(IPCHelpers.isLoopbackHost("127.0.0.1"))
  }
  func test_ipv6_loopback() {
    XCTAssertTrue(IPCHelpers.isLoopbackHost("::1"))
  }
  func test_lan_ip_is_not_loopback() {
    XCTAssertFalse(IPCHelpers.isLoopbackHost("192.168.0.181"))
  }
  func test_lan_ip_10_is_not_loopback() {
    XCTAssertFalse(IPCHelpers.isLoopbackHost("10.0.0.1"))
  }
  func test_empty_string_is_not_loopback() {
    XCTAssertFalse(IPCHelpers.isLoopbackHost(""))
  }
  func test_arbitrary_host_is_not_loopback() {
    XCTAssertFalse(IPCHelpers.isLoopbackHost("example.com"))
  }
  func test_loopback_fallback_logic() {
    XCTAssertFalse(IPCHelpers.isLoopbackHost("192.168.0.181"))
    XCTAssertTrue(IPCHelpers.isLoopbackHost("localhost"))
    XCTAssertTrue(IPCHelpers.isLoopbackHost("127.0.0.1"))
  }
}
