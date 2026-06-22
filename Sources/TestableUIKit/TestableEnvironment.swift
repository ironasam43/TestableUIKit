import SwiftUI

// MARK: - TestableRegistry EnvironmentKey
//
// `TestableRegistry` は actor であり `ObservableObject` 要件を持つ
// `EnvironmentObject` には適合不可（@MainActor class 要求）。
// そのため SwiftUI 標準の `EnvironmentKey` カスタムキー方式を採用する。
// `.environment(\.testableRegistry, registry)` で注入し、
// `@Environment(\.testableRegistry)` で取得する。
//
// defaultValue リスク: `.environment()` 注入を忘れた View では
// 登録先が空の独立 registry になりサーバ registry と別物になる（サイレント失敗）。
// 正しく注入すれば問題なし（design.md C② に注記済み）。

@available(iOS 15.0, macOS 13.0, *)
private struct TestableRegistryKey: EnvironmentKey {
  static let defaultValue = TestableRegistry()
}

@available(iOS 15.0, macOS 13.0, *)
public extension EnvironmentValues {
  var testableRegistry: TestableRegistry {
    get { self[TestableRegistryKey.self] }
    set { self[TestableRegistryKey.self] = newValue }
  }
}
