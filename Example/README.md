# Example — Minimal Sample for Testing Your Own Component

This directory contains a minimal example of instrumenting a custom SwiftUI component with TestableUIKit.
All three building blocks needed for instrumentation (Core / `AnyTestable` bridge / app wiring) fit in a single file, `MyToggleExample.swift`.
Copy and use it as a starting point for your own project.

> This directory is **not part of the Swift Package build** (it lives outside `Sources/`).
> It serves as documentation and a copy-paste reference. For instructions on actually running the example, see
> [`docs/getting-started.md`](../docs/getting-started.md).

## Files

- `MyToggleExample.swift` — A self-contained example of instrumenting a toggle (ON/OFF switch).

## The 3 Instrumentation Building Blocks (recap)

1. **Core (pure logic)**: State struct + command-handling functions. A pure value type you can test directly with XCTest.
2. **`AnyTestable` bridge**: `testID` / `describedState` / `perform(...)` implemented as a thin class that delegates to Core.
3. **Wiring**: Create one `TestableRegistry` at app entry point and inject the **same instance** into both `TestableServer` and
   `.environment(\.testableRegistry,)`. Add `.testable(_:)` to the View.

## Verification (Control this toggle via IPC)

```bash
# Get state
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"example.my.toggle","commandName":"getState","parameters":null}'
# => {"isOn":false}

# Execute toggle
curl -X POST http://localhost:8888/perform \
  -H 'Content-Type: application/json' \
  -d '{"testID":"example.my.toggle","commandName":"toggle","parameters":null}'
# => {"isOn":true}
```

If you run into trouble, see [`docs/troubleshooting.md`](../docs/troubleshooting.md).
