// === iOS App プロジェクト用テンプレート：DemoApp.swift ===
//
// 【使用方法】
// 1. Xcode で新規 iOS App プロジェクト "TestableUIKitDemo" を作成
// 2. このファイルの以下の行（コメント外）をすべてコピー
// 3. Xcode で File > New > File... > Swift File を選択
// 4. ファイル名を "DemoApp.swift" として保存
// 5. 内容を貼り付け
//
// 【このコメントブロックは削除不要】
// 【以下の import から最後の #Preview まで全てコピペしてください】

import SwiftUI
import TestableUIKit

/// 最小デモアプリケーション
@main
struct DemoApp: App {
  @State private var serverError: String?
  @State private var isServerRunning = false

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onAppear {
          startServer()
        }
    }
  }

  /// Testable サーバーを起動
  private func startServer() {
    Task {
      do {
        let server = TestableServer()
        try await server.start()
        await MainActor.run {
          isServerRunning = true
        }
      } catch {
        await MainActor.run {
          serverError = "Server error: \(error)"
          print("[APP] Server failed: \(error)")
        }
      }
    }
  }
}

/// メインビュー
struct ContentView: View {
  @State private var loginButton: LoginButton?

  var body: some View {
    VStack(spacing: 20) {
      Text("Testable UIKit Demo")
        .font(.title)
        .padding()

      // LoginButton を表示
      LoginButtonView(buttonRef: $loginButton)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .padding()

      Text("Server running on http://localhost:8888")
        .font(.caption)
        .foregroundColor(.gray)
        .padding()

      Spacer()

      HStack(spacing: 10) {
        VStack(alignment: .leading) {
          Text("Test with:")
            .font(.caption)
            .bold()
          Text("python3 run_test.py")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.blue)
        }
        Spacer()
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(8)
      .padding()
    }
  }
}

/// LoginButton を SwiftUI で表示するためのラッパー
struct LoginButtonView: UIViewRepresentable {
  @Binding var buttonRef: LoginButton?

  func makeUIView(context: Context) -> LoginButton {
    let button = LoginButton(type: .system)
    button.setTitle("Log In", for: .normal)
    button.backgroundColor = .systemBlue
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 8

    // Registry に登録
    Task { @MainActor in
      TestableRegistry.shared.register(button)
      buttonRef = button
    }

    return button
  }

  func updateUIView(_ uiView: LoginButton, context: Context) {
    // 更新不要
  }
}

#Preview {
  ContentView()
}
