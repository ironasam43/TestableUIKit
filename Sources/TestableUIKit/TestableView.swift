import SwiftUI

// MARK: - TestableRegistrationModifier

/// SwiftUI View に `.testable(_:)` 修飾を付与するだけで AnyTestable を
/// TestableRegistry へ登録できる ViewModifier。
/// View の表示開始（`.task`）で自動登録されるため、手動 `register` 呼び出しが不要になる。
/// 登録先は `@Environment(\.testableRegistry)` で取得した注入 Registry を使う。
/// 祖先 View で `.environment(\.testableRegistry, registry)` を設定しない場合は
/// defaultValue（空の独立 Registry）へ登録されるため、TestableServer と共有できない点に注意。
@available(iOS 15.0, macOS 13.0, *)
public struct TestableRegistrationModifier: ViewModifier {
  private let testable: AnyTestable
  @Environment(\.testableRegistry) private var registry

  public init(_ testable: AnyTestable) {
    self.testable = testable
  }

  public func body(content: Content) -> some View {
    content
      .task {
        await registry.register(testable)
      }
  }
}

// MARK: - View extension

@available(iOS 15.0, macOS 13.0, *)
public extension View {
  /// AnyTestable を TestableRegistry へ自動登録する ViewModifier を適用する。
  /// `@testable import` との命名衝突を避けるため、属性構文ではなくメソッド構文を採用。
  func testable(_ testable: AnyTestable) -> some View {
    modifier(TestableRegistrationModifier(testable))
  }
}
