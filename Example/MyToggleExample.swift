// MyToggleExample.swift
//
// 自作 SwiftUI コンポーネント（トグル）を TestableUIKit で計装する最小サンプル。
// 計装に必要な 3 部品を 1 ファイルにまとめています。
//
// ※ このファイルは Swift Package のビルド対象外（Example/ は Sources/ の外）です。
//    自分のプロジェクトへコピペして使ってください。実行手順は docs/getting-started.md 参照。

import SwiftUI
import TestableUIKit

// MARK: - ① Core（純粋ロジック・XCTest で直接検証できる値型）

struct MyToggleState {
  var isOn: Bool = false
}

/// describedState を生成する純粋関数
func makeMyToggleDescribedState(_ s: MyToggleState) -> [String: JSONValue] {
  ["isOn": .bool(s.isOn)]
}

/// toggle コマンド処理（ON/OFF 反転）
func applyMyToggle(to s: inout MyToggleState) {
  s.isOn.toggle()
}

/// setProperty コマンド処理（key="isOn" の bool を設定）
func applyMyToggleSetProperty(to s: inout MyToggleState, parameters: JSONValue) throws {
  guard case .object(let dict) = parameters,
        case .string(let key) = dict["key"],
        let value = dict["value"] else {
    throw TestError.invalidParameters
  }
  switch key {
  case "isOn":
    guard case .bool(let b) = value else { throw TestError.invalidParameters }
    s.isOn = b
  default:
    throw TestError.unknownCommand("setProperty.\(key)")
  }
}

// MARK: - ② AnyTestable ブリッジ（@Published ↔ Core struct・perform を Core へ委譲）

@MainActor
final class MyToggle: ObservableObject, AnyTestable {
  let testID = "example.my.toggle"   // 一意な ID。IPC でこの ID を指定して操作する
  @Published var isOn: Bool = false

  private var _state: MyToggleState {
    get { var s = MyToggleState(); s.isOn = isOn; return s }
    set { isOn = newValue.isOn }
  }

  var describedState: [String: JSONValue] { makeMyToggleDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "toggle":
      var s = _state; applyMyToggle(to: &s); _state = s
      return describedState
    case "setProperty":
      var s = _state; try applyMyToggleSetProperty(to: &s, parameters: parameters); _state = s
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

// MARK: - View

struct MyToggleView: View {
  @ObservedObject var toggle: MyToggle

  var body: some View {
    Toggle("My Toggle", isOn: Binding(
      get: { toggle.isOn },
      set: { _ in Task { _ = try? await toggle.perform(commandName: "toggle", parameters: .null) } }
    ))
    .padding()
  }
}

// MARK: - ③ アプリ配線（Registry を 1 つ生成し、サーバと View ツリーの両方へ同じものを注入）

@main
struct MyExampleApp: App {
  @StateObject private var toggle = MyToggle()
  @State private var registry = TestableRegistry()   // ★ アプリ起点で 1 つだけ生成
  @State private var server: TestableServer?

  var body: some Scene {
    WindowGroup {
      MyToggleView(toggle: toggle)
        .testable(toggle)                             // ★ View 表示時に registry へ自動登録
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
