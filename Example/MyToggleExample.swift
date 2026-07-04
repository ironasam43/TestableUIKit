// MyToggleExample.swift
//
// Minimal sample for instrumenting a custom SwiftUI component (toggle) with TestableUIKit (Tier 1).
//
// Note: This file is not part of the Swift Package build (Example/ is outside Sources/).
//       Copy it into your own project. See docs/getting-started.md for instructions.
//
// === Tier 1 (state-declarative high-level API) ===
// The old "② AnyTestable bridge class (@Published ↔ Core + hand-written perform switch)" is
// no longer needed. Instrumentation requires only a state value type and a
// TestableComponent declaration (properties / commands).

import SwiftUI
import TestableUIKit

// MARK: - ① Core (pure logic / value type directly testable with XCTest)

struct MyToggleState {
  var isOn: Bool = false
}

// MARK: - ② Bridge is no longer needed
//
// The old `@MainActor final class MyToggle: ObservableObject, AnyTestable { ... perform switch ... }`
// can be deleted entirely. Replace it with a single TestableComponent<MyToggleState> declaration.

// MARK: - View

struct MyToggleView: View {
  // Hold TestableComponent directly as a StateObject
  @StateObject private var toggle = TestableComponent<MyToggleState>(
    id: "example.my.toggle",
    state: MyToggleState(),
    // Omitting describe → auto-derived from properties (describes isOn)
    properties: [
      "isOn": .bool(\.isOn)
    ],
    commands: [
      // toggle command: flip ON/OFF
      "toggle": { state, _ in state.isOn.toggle() }
    ]
  )

  var body: some View {
    Toggle("My Toggle", isOn: Binding(
      get: { toggle.state.isOn },
      set: { _ in Task { _ = try? await toggle.perform(commandName: "toggle", parameters: .null) } }
    ))
    .padding()
    .testable(toggle)   // ★ auto-registers with registry when the View appears
  }
}

// MARK: - ③ App wiring (create one Registry, inject it into both the server and the View tree)

@main
struct MyExampleApp: App {
  @State private var registry = TestableRegistry()   // ★ create exactly one at the app entry point
  @State private var server: TestableServer?

  var body: some Scene {
    WindowGroup {
      MyToggleView()
        .environment(\.testableRegistry, registry)    // ★ inject the same registry into the View tree
        .task {
          do {
            let s = try TestableServer(port: 8888, registry: registry)  // ★ inject the same registry into the server
            s.onStateChange = { state in
              if case .failed(let e) = state { print("Startup failed (possible port conflict): \(e)") }
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
