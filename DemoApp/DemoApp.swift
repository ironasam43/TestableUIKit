import SwiftUI
import TestableUIKit

@main
struct TestableUIApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
    }
  }
}

struct RootView: View {
  @StateObject private var loginButton = LoginButton()
  @StateObject private var counter = Counter()
  @StateObject private var textInput = TextInput()
  @StateObject private var onOffSwitch = OnOffSwitch()
  @StateObject private var rangeSlider = RangeSlider()
  // Registry インスタンスをアプリ起点で1つ生成し、サーバと View ツリーへ注入する
  @State private var registry = TestableRegistry()
  @State private var server: TestableServer?
  @State private var serverRunning = false

  var body: some View {
    ContentView(loginButton: loginButton, counter: counter, textInput: textInput, onOffSwitch: onOffSwitch, rangeSlider: rangeSlider, serverRunning: $serverRunning)
      // 同一 registry を View ツリー全体へ注入（CounterView の .testable() が利用）
      .environment(\.testableRegistry, registry)
      .task {
        do {
          // Server にも同じ registry を注入してシングルトンを廃止
          let s = try TestableServer(port: 8888, registry: registry)
          // loginButton と counter は各ビューに付与した .testable() で自動登録
          s.start()
          server = s
          serverRunning = true
        } catch {
          print("❌ Server failed: \(error)")
          serverRunning = false
        }
      }
  }
}

struct ContentView: View {
  @ObservedObject var loginButton: LoginButton
  @ObservedObject var counter: Counter
  @ObservedObject var textInput: TextInput
  @ObservedObject var onOffSwitch: OnOffSwitch
  @ObservedObject var rangeSlider: RangeSlider
  @Binding var serverRunning: Bool

  var body: some View {
    VStack(spacing: 20) {
      Text("TestableUIKit Vertical Slice")
        .font(.title)
        .fontWeight(.bold)

      HStack {
        Circle()
          .fill(serverRunning ? Color.green : Color.red)
          .frame(width: 12, height: 12)
        Text(serverRunning ? "Server: Running ✓" : "Server: Starting...")
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(8)

      // LoginButton コンポーネント
      VStack(spacing: 12) {
        Button(action: {
          Task { @MainActor in
            let _ = try await loginButton.perform(commandName: "tap", parameters: .null)
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

        Text("Status: \(loginButton.isEnabled ? "enabled" : "disabled")")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .testable(loginButton)

      // Counter コンポーネント（.testable で自動登録）
      CounterView(counter: counter)
        .testable(counter)

      Divider()
        .padding()

      // TextInput コンポーネント（.testable で自動登録）
      VStack(spacing: 8) {
        Text("TextInput")
          .font(.headline)
        TextInputView(textInput: textInput)
      }
      .testable(textInput)

      // OnOffSwitch コンポーネント（.testable で自動登録）
      VStack(spacing: 8) {
        Text("OnOffSwitch")
          .font(.headline)
        OnOffSwitchView(onOffSwitch: onOffSwitch)
      }
      .testable(onOffSwitch)

      // RangeSlider コンポーネント（.testable で自動登録）
      VStack(spacing: 8) {
        Text("RangeSlider")
          .font(.headline)
        RangeSliderView(rangeSlider: rangeSlider)
      }
      .testable(rangeSlider)

      Text("Run in Terminal:\npython3 run_test.py")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding()

      Spacer()
    }
    .padding()
  }
}

#Preview {
  ContentView(
    loginButton: LoginButton(),
    counter: Counter(),
    textInput: TextInput(),
    onOffSwitch: OnOffSwitch(),
    rangeSlider: RangeSlider(),
    serverRunning: .constant(true)
  )
}
