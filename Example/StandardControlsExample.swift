// StandardControlsExample.swift
//
// Minimal sample for the Tier 2 API (instant instrumentation of standard SwiftUI controls).
// Toggle / TextField / Stepper / Slider / Button — just write them the same way as normal SwiftUI
// and they are automatically instrumented (no bridge class or Core value type needed).
//
// Note: This file is not part of the Swift Package build (Example/ is outside Sources/).
//       Copy it into your own project. See docs/getting-started.md for instructions.

import SwiftUI
import TestableUIKit

struct StandardControlsView: View {
  @State private var isOn = false
  @State private var name = ""
  @State private var quantity = 0
  @State private var volume = 0.5
  @State private var tapMessage = "Not tapped"

  var body: some View {
    VStack(spacing: 16) {
      // Toggle: commands = toggle / setProperty (describe: isOn)
      TestableToggle("Notifications", isOn: $isOn, id: "controls.toggle")

      // TextField: commands = setProperty (describe: text)
      TestableTextField("Name", text: $name, id: "controls.textField")

      // Stepper: commands = increment / decrement / setProperty (describe: value)
      TestableStepper("Quantity: \(quantity)", value: $quantity, id: "controls.stepper")

      // Slider: commands = setProperty (describe: value)
      TestableSlider(value: $volume, in: 0...1, id: "controls.slider")

      // Button: commands = tap (describe: tapCount)
      TestableButton("Submit", id: "controls.button") {
        tapMessage = "Tapped"
      }

      Text(tapMessage)
    }
    .padding()
  }
}

// MARK: - App wiring (create one Registry, inject it into both the server and the View tree)

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
