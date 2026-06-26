// MyToggleExample.swift
//
// 自作 SwiftUI コンポーネント（トグル）を TestableUIKit で計装する最小サンプル（Tier 1）。
//
// ※ このファイルは Swift Package のビルド対象外（Example/ は Sources/ の外）です。
//    自分のプロジェクトへコピペして使ってください。実行手順は docs/getting-started.md 参照。
//
// ＝＝＝ Tier 1（state 宣言型 高レベル API）＝＝＝
// 旧版で必要だった「② AnyTestable ブリッジ class（@Published ↔ Core ＋ 手書き perform switch）」が
// 不要になりました。state 値型と TestableComponent の宣言（properties / commands）だけで計装できます。

import SwiftUI
import TestableUIKit

// MARK: - ① Core（純粋ロジック・XCTest で直接検証できる値型）

struct MyToggleState {
  var isOn: Bool = false
}

// MARK: - ② ブリッジは不要に
//
// 旧版の `@MainActor final class MyToggle: ObservableObject, AnyTestable { ... perform switch ... }`
// は丸ごと削除できます。代わりに TestableComponent<MyToggleState> を 1 つ宣言するだけです。

// MARK: - View

struct MyToggleView: View {
  // TestableComponent を直接 StateObject として保持する
  @StateObject private var toggle = TestableComponent<MyToggleState>(
    id: "example.my.toggle",
    state: MyToggleState(),
    // describe 省略 → properties から自動導出（isOn を describe）
    properties: [
      "isOn": .bool(\.isOn)
    ],
    commands: [
      // toggle コマンド: ON/OFF 反転
      "toggle": { state, _ in state.isOn.toggle() }
    ]
  )

  var body: some View {
    Toggle("My Toggle", isOn: Binding(
      get: { toggle.state.isOn },
      set: { _ in Task { _ = try? await toggle.perform(commandName: "toggle", parameters: .null) } }
    ))
    .padding()
    .testable(toggle)   // ★ View 表示時に registry へ自動登録
  }
}

// MARK: - ③ アプリ配線（Registry を 1 つ生成し、サーバと View ツリーの両方へ同じものを注入）

@main
struct MyExampleApp: App {
  @State private var registry = TestableRegistry()   // ★ アプリ起点で 1 つだけ生成
  @State private var server: TestableServer?

  var body: some Scene {
    WindowGroup {
      MyToggleView()
        .environment(\.testableRegistry, registry)    // ★ View ツリーへ同じ registry を注入
        .task {
          do {
            let s = try TestableServer(port: 8888, registry: registry)  // ★ サーバへ同じ registry
            s.onStateChange = { state in
              if case .failed(let e) = state { print("起動失敗（ポート競合の可能性）: \(e)") }
            }
            s.start()
            server = s
          } catch {
            print("❌ Server failed: \(error)")
          }
        }
    }
  }
}
