# Getting Started — Instrument Your Component in 5 Minutes

TestableUIKit is a framework that lets SwiftUI components **self-report their state and commands**,
making them controllable and verifiable from the outside (test runners, AI agents) over
HTTP IPC (`localhost:8888`).

This guide shows you how to instrument your custom SwiftUI component in 3 steps.
It takes about 5 minutes.

> Prerequisite: familiarity with Swift Package Manager. For detailed Xcode setup see [`SETUP.md`](../SETUP.md).

---

## 3 Instrumentation Tiers (which one to use)

There are three levels of abstraction for instrumentation. **Start from the top** and drop down only if the higher tier doesn't fit.

| Tier | API | Best for | What you need |
|---|---|---|---|
| **Tier 2** | `TestableToggle` / `TestableTextField` / `TestableStepper` / `TestableSlider` / `TestableButton` | Standard SwiftUI controls | Just swap in the Testable* view (no state type or bridge needed) |
| **Tier 1** | `TestableComponent<State>` | Custom components (with a state value type) | state value type + `properties` / `commands` declarations (no handwritten `perform` switch) |
| **Tier 0** | Handwritten `AnyTestable` conformance | Special instrumentation (lock control, cross-process, etc.) | Self-implement `testID` / `describedState` / `perform` |

- **Tier 2**: The fastest option for standard controls. Just write `TestableToggle("Notifications", isOn: $isOn, id: "x")` and it is instrumented automatically (see "Tier 2" below).
- **Tier 1**: For components with a custom state type, declare `TestableComponent<State>`. When `describe` is omitted it falls back to `properties`, and if those are absent it uses Mirror to auto-describe value-type properties (Bool/Int/Double/String) (see "Tier 1" below).
- **Tier 0**: The "Under the Hood (3 Building Blocks)" section below describes the Tier 0 approach. Use it only when you need maximum flexibility.

---

## Tier 2: Instantly Instrument Standard Controls

Standard SwiftUI controls can be instrumented by simply replacing them with the corresponding `Testable*` view.

```swift
import TestableUIKit

struct SettingsView: View {
  @State private var isOn = false
  @State private var name = ""
  @State private var qty = 0

  var body: some View {
    VStack {
      TestableToggle("Notifications", isOn: $isOn, id: "settings.toggle")
      TestableTextField("Name", text: $name, id: "settings.name")
      TestableStepper("Qty: \(qty)", value: $qty, id: "settings.qty")
      TestableButton("Save", id: "settings.save") { /* action */ }
    }
    .environment(\.testableRegistry, registry)  // ★ registry injection is the same as Tier 0/1
  }
}
```

Commands accepted by each control:

| View | Commands | describe keys |
|---|---|---|
| `TestableToggle` | `toggle` / `setProperty` | `isOn` |
| `TestableTextField` | `setProperty` | `text` |
| `TestableStepper` | `increment` / `decrement` / `setProperty` | `value` |
| `TestableSlider` | `setProperty` | `value` |
| `TestableButton` | `tap` | `tapCount` |

> Registry injection (`.environment(\.testableRegistry, registry)` + passing the same registry to the server) is common to all tiers (see Step 3 below). See a working example at [`Example/StandardControlsExample.swift`](../Example/StandardControlsExample.swift).

---

## Tier 1: Instrument Custom Components with `TestableComponent`

For components that have a custom state value type, you can instrument them by declaring
`TestableComponent<State>` — no need to write a handwritten `AnyTestable` bridge class.

```swift
import TestableUIKit

struct MyToggleState { var isOn = false }

struct MyToggleView: View {
  @StateObject private var toggle = TestableComponent<MyToggleState>(
    id: "example.my.toggle",
    state: MyToggleState(),
    properties: ["isOn": .bool(\.isOn)],            // auto-generates describe + setProperty
    commands: ["toggle": { s, _ in s.isOn.toggle() }]
  )

  var body: some View {
    Toggle("My Toggle", isOn: Binding(
      get: { toggle.state.isOn },
      set: { _ in Task { _ = try? await toggle.perform(commandName: "toggle", parameters: .null) } }
    ))
    .testable(toggle)
  }
}
```

- `properties`: Dictionary of `TestableProperty<State>`. Use `.bool/.int/.double/.string(\.keyPath)` to auto-generate get/set from a KeyPath (type mismatch throws).
- `commands`: Command name → `(inout State, JSONValue) throws -> Void`.
- `describe`: When omitted, derived from `properties` → Mirror fallback (only own value types; SwiftUI private types and composite types are skipped) if no properties are provided.
- `getState` / `setProperty` are handled automatically.

> See a working example at [`Example/MyToggleExample.swift`](../Example/MyToggleExample.swift). The handwritten `AnyTestable` bridge class (with a `perform` switch) that was required in previous versions is no longer needed.

---

## Under the Hood (3 Building Blocks)

> This section covers the **Tier 0 (`AnyTestable` handwritten)** approach. Use it only for special instrumentation that Tier 1/2 cannot handle.

Instrumentation requires the following three pieces.

1. **`*Core.swift` (pure logic)** — State struct + command handler functions. Written as testable value types.
2. **`AnyTestable`-conforming class** — A thin bridge that implements `testID` / `describedState` / `perform(...)` and delegates to Core.
3. **Registry injection + `.testable(_:)`** — Create a single `TestableRegistry` at the app entry point and inject it into both the server and the View tree. Attach `.testable(component)` to the View for automatic registration.

---

## Step 1: Add the Dependency

Add to `Package.swift` (or Xcode's Package Dependencies):

```swift
.package(url: "https://github.com/ironasam43/TestableUIKit", from: "0.1.0")
```

Add `"TestableUIKit"` to the target's dependencies.

---

## Step 2: Conform Your Component to `AnyTestable`

As an example, we'll instrument a "counter." First, separate the pure logic (Core).

```swift
import TestableUIKit

// --- Core (pure value type — easy to test) ---
struct CounterState { var count = 0; var isEnabled = true }

func makeDescribedState(_ s: CounterState) -> [String: JSONValue] {
  ["count": .int(s.count), "isEnabled": .bool(s.isEnabled)]
}
func applyIncrement(to s: inout CounterState) { if s.isEnabled { s.count += 1 } }
```

Next, write the `AnyTestable`-conforming bridge class.
It bridges `@Published` properties and the Core struct, and delegates commands to Core via `perform`.

```swift
@MainActor
final class Counter: ObservableObject, AnyTestable {
  let testID = "scene.demo.counter"   // unique ID — specify this in IPC to target the component
  @Published var count = 0
  @Published var isEnabled = true

  private var _state: CounterState {
    get { var s = CounterState(); s.count = count; s.isEnabled = isEnabled; return s }
    set { count = newValue.count; isEnabled = newValue.isEnabled }
  }

  var describedState: [String: JSONValue] { makeDescribedState(_state) }

  func perform(commandName: String, parameters: JSONValue) async throws -> [String: JSONValue] {
    switch commandName {
    case "getState": return describedState
    case "increment": var s = _state; applyIncrement(to: &s); _state = s; return describedState
    default: throw TestError.unknownCommand(commandName)
    }
  }
}
```

> **Key point**: By moving logic to Core (pure functions), you can verify Core functions directly
> in XCTest without going through `perform` (test pyramid L1). Keep the bridge thin.

---

## Step 3: Inject the Registry and add `.testable(_:)` to your View

Create **exactly one** `TestableRegistry` at the app entry point and **inject that same instance into both the server and the View tree**.
This is the most error-prone step in instrumentation (see "Common Pitfalls" below).

```swift
@main
struct MyApp: App {
  @StateObject private var counter = Counter()
  @State private var registry = TestableRegistry()   // ★ create exactly one instance at app entry point
  @State private var server: TestableServer?

  var body: some Scene {
    WindowGroup {
      CounterView(counter: counter)
        .testable(counter)                            // ★ auto-registers when the View appears
        .environment(\.testableRegistry, registry)    // ★ inject the same registry into the View tree
        .task {
          let s = try? TestableServer(port: 8888, registry: registry)  // ★ pass the same registry to the server
          s?.start()
          server = s
        }
    }
  }
}
```

That's it. When you launch the app, `✅ TestableServer listening on http://127.0.0.1:8888` will
appear in the console.

---

## Verify It Works

You can confirm connectivity, state retrieval, and command execution from a separate terminal.

```bash
# Connectivity check
curl http://localhost:8888/ping
# => {"status":"ok"}

# Get state (getState)
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"scene.demo.counter","commandName":"getState","parameters":null}'
# => {"count":0,"isEnabled":true}

# Run increment
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"scene.demo.counter","commandName":"increment","parameters":null}'
# => {"count":1,"isEnabled":true}
```

For the full IPC protocol specification, see [`docs/ipc-protocol.md`](ipc-protocol.md).

---

## Common Pitfalls

### ① Registry not shared (most common — silent failure)

If you forget the `.environment(\.testableRegistry, registry)` injection, `.testable(_:)` registers
the component in an empty default registry separate from the server's registry.
No error is raised; the server returns `component not found` (404).

**Fix**: Always pass the same `registry` instance created at the app entry point to
**both the server (`TestableServer(registry:)`) and the View tree (`.environment`)**.

### ② Duplicate `testID`

If you assign the same `testID` to multiple components, the last one registered wins.
Use unique names that reflect the scene and role (e.g., `scene.demo.counter`).

### ③ Port 8888 conflict

If another process is already using port 8888, `TestableServer` startup will fail with `.failed`.
You can detect this via `server.onStateChange` (see [`docs/troubleshooting.md`](troubleshooting.md)).

---

## What to Read Next

- Minimal working example: [`Example/`](../Example/README.md)
- IPC protocol specification: [`docs/ipc-protocol.md`](ipc-protocol.md)
- Troubleshooting: [`docs/troubleshooting.md`](troubleshooting.md)
- Design rationale: [`docs/design.md`](design.md)
