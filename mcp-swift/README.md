# TestableUIKit MCP Server (Swift)

A standalone Swift executable that exposes
[TestableUIKit](https://github.com/ironasam43/TestableUIKit)'s HTTP IPC as
**MCP (Model Context Protocol) tools**, enabling Claude and other AI agents to
drive a running iOS/macOS app and inspect UI state in a structured way.

---

## Overview

```
AI Agent (Claude)
      │  MCP stdio
      ▼
TestableUIKitMCP  ─── HTTP localhost:8888 ───►  DemoApp (running on Simulator/device)
  (this package)                                  TestableUIKit framework
```

The MCP server acts as a **stateless HTTP relay**: it receives MCP tool calls
over stdio, forwards them to the TestableUIKit HTTP server embedded in the
running app, and returns the responses. No Swift types are imported from the
main library.

---

## Prerequisites

- macOS 13+
- Swift 6.0+ (`swift --version`)
- **DemoApp must be running** on a Simulator or physical device and listening on
  port 8888 before invoking any tool

---

## Build

```sh
cd mcp-swift
swift build -c release
```

The executable is output to:

```
mcp-swift/.build/release/TestableUIKitMCP
```

---

## Usage

### stdio transport (recommended for MCP clients)

Configure your MCP client (e.g. Claude Desktop) to launch the server:

```json
{
  "mcpServers": {
    "testableUIKit": {
      "command": "/path/to/mcp-swift/.build/release/TestableUIKitMCP"
    }
  }
}
```

The server communicates over **stdio** using the MCP protocol.

### Direct test via stdio

```sh
.build/release/TestableUIKitMCP
# Then send MCP JSON-RPC messages over stdin
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TESTABLE_IPC_HOST` | `127.0.0.1` | IP address or hostname of the device running DemoApp |
| `TESTABLE_IPC_PORT` | `8888` | Port the TestableUIKit HTTP server listens on |

**Physical device (LAN Wi-Fi) example:**

```sh
TESTABLE_IPC_HOST=192.168.1.42 TESTABLE_IPC_PORT=8888 \
  .build/release/TestableUIKitMCP
```

---

## MCP Tools

Five tools are registered. All tools return text responses (JSON strings) unless
noted otherwise.

### `ui_ping`

Liveness check — confirms DemoApp is running and the TestableUIKit server is
reachable.

- **HTTP**: `GET /ping`
- **Parameters**: none
- **Returns**: `{"status":"ok"}` on success

---

### `ui_getState`

Retrieves the current `describedState` of a registered component.

- **HTTP**: `POST /perform` with action `getState`
- **Parameters**:
  - `testID` *(string, required)* — dot-separated component identifier (e.g. `scene.counter`)
- **Returns**: JSON object containing the component's described state

---

### `ui_perform`

Sends an arbitrary command to a component.

- **HTTP**: `POST /perform`
- **Parameters**:
  - `testID` *(string, required)* — component identifier
  - `command` *(string, required)* — command name (see table below)
  - `params` *(object, optional)* — command-specific parameters
- **Returns**: updated `describedState` JSON object

**Built-in commands:**

| Command | Description | `params` |
|---------|-------------|----------|
| `tap` | Simulates a tap/press | — |
| `increment` | Increments a stepper | — |
| `decrement` | Decrements a stepper | — |
| `reset` | Resets to default state | — |
| `toggle` | Toggles a boolean switch | — |
| `clear` | Clears a text field | — |
| `setEnabled` | Enables or disables a component | `{"value": true}` |
| `setProperty` | Sets a named property | `{"key": "isHidden", "value": true}` |
| `getState` | Returns current state (same as `ui_getState`) | — |

---

### `ui_screenshot`

Captures a screenshot of the running app.

- **Primary path**: `GET /screenshot` from the app's embedded screenshot provider
- **Fallback** (Simulator / loopback only): `xcrun simctl io booted screenshot`
- **Parameters**: none
- **Returns**: PNG image data (MCP image content type)

---

### `ui_runScenario`

Executes a declarative JSON scenario — a sequence of steps, each with an
action, a target `testID`, optional parameters, and optional `expect`
assertions. All steps run in order; failures are recorded but do not abort
execution.

- **Parameters**:
  - `scenario` *(object, required)*:
    - `name` *(string)* — human-readable scenario name
    - `steps` *(array)* — list of step objects:
      - `action` *(string, required)* — one of the commands listed above
      - `testID` *(string, required)* — target component
      - `parameters` *(object, optional)* — command parameters
      - `expect` *(object, optional)* — key/value assertions against `describedState`
- **Returns**: `ScenarioResult` JSON with per-step pass/fail details

**Example scenario:**

```json
{
  "name": "Counter increment test",
  "steps": [
    { "action": "getState",   "testID": "scene.counter", "expect": { "count": 0 } },
    { "action": "increment",  "testID": "scene.counter" },
    { "action": "getState",   "testID": "scene.counter", "expect": { "count": 1 } }
  ]
}
```

---

## Package Structure

```
mcp-swift/
  Package.swift
  Sources/
    TestableUIKitMCPCore/      # Pure helpers (no MCP SDK dependency; XCTestable)
      IPCHelpers.swift
      Scenario.swift
    TestableUIKitMCP/          # Executable entry point
      main.swift
  Tests/
    TestableUIKitMCPCoreTests/ # Unit tests for core helpers
```

The MCP SDK dependency (`swift-sdk`) is scoped to the `TestableUIKitMCP`
executable target only, keeping `TestableUIKitMCPCore` independently testable
without the SDK.

---

## Running Tests

```sh
cd mcp-swift
swift test
```

---

## License

MIT — see [LICENSE](../LICENSE) in the repository root.
