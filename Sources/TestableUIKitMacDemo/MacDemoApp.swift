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
  // Registry インスタンスをアプリ起点で1つ生成し、サーバと View ツリーへ注入する
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
      // 同一 registry を View ツリー全体へ注入（各コンポーネントの .testable() が利用）
      .environment(\.testableRegistry, registry)
      .task {
        do {
          // AppKit key window を PNG キャプチャする closure（AppKit 依存を app 側に閉じる）
          // iOS DemoApp の UIGraphicsImageRenderer に対応する macOS 実装
          let screenshotProvider: TestableServer.ScreenshotProvider = { @MainActor in
            guard let window = NSApp.keyWindow ?? NSApp.windows.first,
                  let contentView = window.contentView else {
              throw NSError(
                domain: "TestableUIKit.Screenshot", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "key window が取得できません"]
              )
            }
            let bounds = contentView.bounds
            guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
              throw NSError(
                domain: "TestableUIKit.Screenshot", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "BitmapImageRep 生成に失敗しました"]
              )
            }
            contentView.cacheDisplay(in: bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else {
              throw NSError(
                domain: "TestableUIKit.Screenshot", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "PNG 変換に失敗しました"]
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

        // サーバ状態インジケータ
        HStack {
          Circle()
            .fill(serverRunning ? Color.green : Color.red)
            .frame(width: 12, height: 12)
          Text(serverRunning ? "Server: Running ✓" : "Server: Starting...")
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)

        // LoginButton コンポーネント
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

        // Counter コンポーネント（.testable で自動登録）
        MacCounterView(counter: counter)
          .testable(counter)

        Divider()
          .padding()

        // TextInput コンポーネント（.testable で自動登録）
        VStack(spacing: 8) {
          Text("TextInput")
            .font(.headline)
          MacTextInputView(textInput: textInput)
        }
        .testable(textInput)

        // OnOffSwitch コンポーネント（.testable で自動登録）
        VStack(spacing: 8) {
          Text("OnOffSwitch")
            .font(.headline)
          MacOnOffSwitchView(onOffSwitch: onOffSwitch)
        }
        .testable(onOffSwitch)

        // RangeSlider コンポーネント（.testable で自動登録）
        VStack(spacing: 8) {
          Text("RangeSlider")
            .font(.headline)
          MacRangeSliderView(rangeSlider: rangeSlider)
        }
        .testable(rangeSlider)

        Text("e2e 検証:\ncurl http://localhost:8888/ping")
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
