#if os(macOS)
import SwiftUI
import AppKit
import TestableUIKit

// MARK: - Entry Point

@main
struct MacDemoApp: App {
  @StateObject private var loginButton = MacLoginButton()
  @StateObject private var counter = MacCounter()
  @StateObject private var textInput = MacTextInput()
  @StateObject private var onOffSwitch = MacOnOffSwitch()
  @StateObject private var rangeSlider = MacRangeSlider()
  // Create one Registry instance at the app entry point and inject it into the server and View tree.
  @State private var registry = TestableRegistry()
  @State private var server: TestableServer?
  @State private var serverRunning = false

  var body: some Scene {
    WindowGroup {
      MacContentView(
        loginButton: loginButton,
        counter: counter,
        textInput: textInput,
        onOffSwitch: onOffSwitch,
        rangeSlider: rangeSlider,
        serverRunning: $serverRunning
      )
      // Inject the same registry into the entire View tree (used by each component's .testable()).
      .environment(\.testableRegistry, registry)
      .task {
        do {
          // Closure that captures a PNG screenshot of the AppKit key window (AppKit dependency
          // is confined to the app side). Corresponds to UIGraphicsImageRenderer on iOS.
          let screenshotProvider: TestableServer.ScreenshotProvider = { @MainActor in
            guard let window = NSApp.keyWindow ?? NSApp.windows.first,
                  let contentView = window.contentView else {
              throw NSError(
                domain: "TestableUIKit.Screenshot", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not obtain key window"]
              )
            }
            let bounds = contentView.bounds
            guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
              throw NSError(
                domain: "TestableUIKit.Screenshot", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create BitmapImageRep"]
              )
            }
            contentView.cacheDisplay(in: bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else {
              throw NSError(
                domain: "TestableUIKit.Screenshot", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert to PNG"]
              )
            }
            return data
          }

          let s = try TestableServer(
            port: 8888,
            host: "127.0.0.1",
            registry: registry,
            screenshotProvider: screenshotProvider
          )
          s.start()
          server = s
          serverRunning = true
        } catch {
          print("❌ Server failed: \(error)")
          serverRunning = false
        }
      }
    }
    .windowStyle(.titleBar)
    .windowResizability(.contentSize)
  }
}

// MARK: - Content View

struct MacContentView: View {
  @ObservedObject var loginButton: MacLoginButton
  @ObservedObject var counter: MacCounter
  @ObservedObject var textInput: MacTextInput
  @ObservedObject var onOffSwitch: MacOnOffSwitch
  @ObservedObject var rangeSlider: MacRangeSlider
  @Binding var serverRunning: Bool

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Text("TestableUIKit macOS Demo")
          .font(.title)
          .fontWeight(.bold)

        // Server status indicator
        HStack {
          Circle()
            .fill(serverRunning ? Color.green : Color.red)
            .frame(width: 12, height: 12)
          Text(serverRunning ? "Server: Running ✓" : "Server: Starting...")
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)

        // LoginButton component
        VStack(spacing: 12) {
          Button(action: {
            Task { @MainActor in
              let _ = try? await loginButton.perform(commandName: "tap", parameters: .null)
            }
          }) {
            Text(loginButton.title)
              .frame(maxWidth: .infinity)
              .padding()
              .background(loginButton.isEnabled ? Color.blue : Color.gray)
              .foregroundColor(.white)
              .cornerRadius(8)
          }
          .disabled(!loginButton.isEnabled)
          .buttonStyle(.plain)

          Text("Status: \(loginButton.isEnabled ? "enabled" : "disabled")")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .testable(loginButton)

        // Counter component (auto-registered via .testable)
        MacCounterView(counter: counter)
          .testable(counter)

        Divider()
          .padding()

        // TextInput component (auto-registered via .testable)
        VStack(spacing: 8) {
          Text("TextInput")
            .font(.headline)
          MacTextInputView(textInput: textInput)
        }
        .testable(textInput)

        // OnOffSwitch component (auto-registered via .testable)
        VStack(spacing: 8) {
          Text("OnOffSwitch")
            .font(.headline)
          MacOnOffSwitchView(onOffSwitch: onOffSwitch)
        }
        .testable(onOffSwitch)

        // RangeSlider component (auto-registered via .testable)
        VStack(spacing: 8) {
          Text("RangeSlider")
            .font(.headline)
          MacRangeSliderView(rangeSlider: rangeSlider)
        }
        .testable(rangeSlider)

        Text("e2e verification:\ncurl http://localhost:8888/ping")
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding()

        Spacer()
      }
      .padding()
    }
    .frame(minWidth: 420, minHeight: 650)
  }
}

#endif // os(macOS)
