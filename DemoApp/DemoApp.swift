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
  @State private var server: TestableServer?
  @State private var serverRunning = false

  var body: some View {
    ContentView(loginButton: loginButton, counter: counter, serverRunning: $serverRunning)
      .task {
        do {
          let s = try TestableServer(port: 8888)
          await TestableRegistry.shared.register(loginButton)
          await TestableRegistry.shared.register(counter)
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

      // Counter コンポーネント
      CounterView(counter: counter)

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
    serverRunning: .constant(true)
  )
}
