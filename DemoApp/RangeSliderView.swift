import SwiftUI
import TestableUIKit

// MARK: - RangeSlider（AnyTestable 準拠 SwiftUI コンポーネント）

@MainActor
final class RangeSlider: ObservableObject, AnyTestable {
  let testID: String = "scene.demo.rangeSlider"

  @Published var value: Double = 50.0
  @Published var minValue: Double = 0.0
  @Published var maxValue: Double = 100.0
  @Published var step: Double = 1.0
  @Published var isEnabled: Bool = true

  private var _state: RangeSliderState {
    get {
      var s = RangeSliderState()
      s.value = value
      s.minValue = minValue
      s.maxValue = maxValue
      s.step = step
      return s
    }
    set {
      value = newValue.value
      minValue = newValue.minValue
      maxValue = newValue.maxValue
      step = newValue.step
    }
  }

  var describedState: [String: JSONValue] {
    makeRangeSliderDescribedState(_state)
  }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState":
      return describedState
    case "reset":
      var state = _state
      applyRangeSliderReset(to: &state)
      _state = state
      return describedState
    case "setProperty":
      var state = _state
      try applyRangeSliderSetProperty(to: &state, parameters: parameters)
      _state = state
      return describedState
    default:
      throw TestError.unknownCommand(commandName)
    }
  }
}

// MARK: - RangeSliderView

struct RangeSliderView: View {
  @ObservedObject var rangeSlider: RangeSlider

  var body: some View {
    VStack(spacing: 15) {
      Text("Value: \(String(format: "%.1f", rangeSlider.value))")
        .font(.headline)

      Slider(
        value: $rangeSlider.value,
        in: rangeSlider.minValue...rangeSlider.maxValue,
        step: rangeSlider.step
      )
      .disabled(!rangeSlider.isEnabled)

      Button("Reset") {
        Task { @MainActor in
          _ = try? await rangeSlider.perform(commandName: "reset", parameters: .null)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(rangeSlider.isEnabled ? Color.blue : Color.gray)
      .foregroundColor(.white)
      .cornerRadius(8)
      .disabled(!rangeSlider.isEnabled)
    }
    .padding()
  }
}

#Preview {
  RangeSliderView(rangeSlider: RangeSlider())
}
