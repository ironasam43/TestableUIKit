import SwiftUI
import TestableUIKit

// MARK: - Counter（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class Counter: ObservableObject, AnyTestable {
  let testID: String = "scene.demo.counter"

  // @Published プロパティ（SwiftUI バインディング用）
  @Published var count: Int = 0
  @Published var isEnabled: Bool = true

  // CounterState へのブリッジ（@Published ↔ struct の相互変換）
  private var _state: CounterState {
    get {
      var s = CounterState()
      s.count = count
      s.isEnabled = isEnabled
      return s
    }
    set {
      count = newValue.count
      isEnabled = newValue.isEnabled
    }
  }

  var describedState: [String: JSONValue] {
    makeCounterDescribedState(_state)
  }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "increment":
      var state = _state
      applyIncrement(to: &state)
      _state = state
      return describedState
    case "decrement":
      var state = _state
      applyDecrement(to: &state)
      _state = state
      return describedState
    case "reset":
      var state = _state
      applyCounterReset(to: &state)
      _state = state
      return describedState
    case "setProperty":
      var state = _state
      try applyCounterSetProperty(to: &state, parameters: parameters)
      _state = state
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

// MARK: - CounterView

struct CounterView: View {
  @ObservedObject var counter: Counter

  var body: some View {
    VStack(spacing: 10) {
      Text("Counter: \(counter.count)")
        .font(.headline)

      HStack(spacing: 20) {
        Button("-") {
          Task { @MainActor in
            _ = try? await counter.perform(commandName: "decrement", parameters: .null)
          }
        }
        .frame(width: 44, height: 44)
        .background(counter.isEnabled ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(!counter.isEnabled)

        Button("+") {
          Task { @MainActor in
            _ = try? await counter.perform(commandName: "increment", parameters: .null)
          }
        }
        .frame(width: 44, height: 44)
        .background(counter.isEnabled ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(!counter.isEnabled)
      }

      Text("testID: \(counter.testID)")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(8)
  }
}

#Preview {
  CounterView(counter: Counter())
}
