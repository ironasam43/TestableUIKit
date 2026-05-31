// === iOS App プロジェクト用テンプレート：LoginButton.swift ===
//
// 【使用方法】
// 1. Xcode で File > New > File... > Swift File を選択
// 2. ファイル名を "LoginButton.swift" として保存
// 3. 以下の内容をすべてコピー＆ペースト
//
// 【このコメントブロックは削除不要】
// 【以下の import から最後の } まで全てコピペしてください】

import UIKit
import TestableUIKit

/// テスト対象コンポーネント：ログインボタン
public class LoginButton: UIButton, AnyTestable {
  public let testID: String = "auth.loginButton"

  public var describedState: [String: JSONValue] {
    return [
      "isEnabled": .bool(isEnabled),
      "title": .string(title(for: .normal) ?? "Log In"),
    ]
  }

  public func perform(
    commandName: String,
    parameters: JSONValue
  ) async throws -> [String: JSONValue] {
    switch commandName {
    case "tap":
      // ボタンが有効な場合のみ tap をシミュレート
      if isEnabled {
        sendActions(for: .touchUpInside)
      }
      return describedState

    case "setEnabled":
      // parameters が object で "enabled" キーを持つ場合のみ処理
      if case .object(let params) = parameters,
         let enabled = params["enabled"]?.asBool {
        isEnabled = enabled
      }
      return describedState

    default:
      throw TestableError.unknownCommand(commandName)
    }
  }
}
