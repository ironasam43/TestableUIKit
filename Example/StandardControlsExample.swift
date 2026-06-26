// StandardControlsExample.swift
//
// Tier 2（標準 SwiftUI コントロールの即計装 API）の最小サンプル。
// Toggle / TextField / Stepper / Slider / Button の 5 種を、通常の SwiftUI と同じ感覚で
// 書くだけで自動計装できます（ブリッジ class も Core 値型も不要）。
//
// ※ このファイルは Swift Package のビルド対象外（Example/ は Sources/ の外）です。
//    自分のプロジェクトへコピペして使ってください。実行手順は docs/getting-started.md 参照。

import SwiftUI
import TestableUIKit

struct StandardControlsView: View {
  @State private var isOn = false
  @State private var name = ""
  @State private var quantity = 0
  @State private var volume = 0.5
  @State private var tapMessage = "未タップ"

  var body: some View {
    VStack(spacing: 16) {
      // Toggle: コマンド = toggle / setProperty（describe: isOn）
      TestableToggle("通知", isOn: $isOn, id: "controls.toggle")

      // TextField: コマンド = setProperty（describe: text）
      TestableTextField("名前", text: $name, id: "controls.textField")

      // Stepper: コマンド = increment / decrement / setProperty（describe: value）
      TestableStepper("数量: \(quantity)", value: $quantity, id: "controls.stepper")

      // Slider: コマンド = setProperty（describe: value）
      TestableSlider(value: $volume, in: 0...1, id: "controls.slider")

      // Button: コマンド = tap（describe: tapCount）
      TestableButton("送信", id: "controls.button") {
        tapMessage = "タップされました"
      }

      Text(tapMessage)
    }
    .padding()
  }
}

// MARK: - アプリ配線（Registry を 1 つ生成し、サーバと View ツリーの両方へ注入）

@main
struct StandardControlsApp: App {
  @State private var registry = TestableRegistry()
  @State private var server: TestableServer?

  var body: some Scene {
    WindowGroup {
      StandardControlsView()
        .environment(\.testableRegistry, registry)
        .task {
          do {
            let s = try TestableServer(port: 8888, registry: registry)
            s.start()
            server = s
          } catch {
            print("❌ Server failed: \(error)")
          }
        }
    }
  }
}
