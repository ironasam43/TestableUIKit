# TestableUIKit IPC Protocol Specification

## Overview

TestableUIKit uses a REST API over HTTP for communication between the iOS app and the host PC.  
The `TestableServer` inside the app listens on localhost:8888, and test automation tools send HTTP requests to it.

---

## Endpoints

### 1. GET /ping

**Purpose**: Verify server connectivity  
**Request**: none

**Response**:
```json
{
  "status": "ok"
}
```

---

### 2. POST /perform

**Purpose**: Execute a command on a UI component and retrieve its state  
**Request**:

```json
{
  "testID": "string",        // Unique identifier for the UI component
  "commandName": "string",   // Name of the command to execute
  "parameters": {}           // Command-specific parameters (dict or null)
}
```

**Response** (success):

> **All commands**: On success, always returns the following **5-key fixed describedState**.

```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**Response** (error):
```json
{
  "error": "string"
}
```

---

### 3. GET /screenshot

**Purpose**: Capture an in-app screenshot (works on both Simulator and physical device)  
**Request**: none

**Implementation**: Calls the `screenshotProvider` closure injected into `TestableServer`,
renders the key window as PNG, and returns it base64-encoded.
Returns 503 if `screenshotProvider` is not injected (always injected in DemoApp DEBUG builds).

**Response** (success):
```json
{
  "image_base64": "<base64-encoded PNG string>",
  "format": "png"
}
```

**Response** (error / provider not configured):
```json
{
  "error": "screenshotProvider not configured"
}
```

**HTTP status codes**:
- `200` — PNG data retrieved successfully
- `500` — Exception occurred during capture
- `503` — `screenshotProvider` not injected

**Design notes**:
- UIKit dependencies (e.g. `UIGraphicsImageRenderer`) are not imported into the library; the app (DemoApp) injects them via a closure.
- MCP `ui_screenshot` uses this endpoint as the primary route, falling back to `simctl io booted screenshot` (Simulator only) only when the loopback connection fails.

---

### 4. MCP `ui_runScenario` (Declarative scenario execution)

**Purpose**: Execute multiple UI operations with expected-value assertions in a single MCP call, declaratively.

**Implementation location**: `mcp-swift/` (MCP layer only — **no new HTTP endpoints are added**).  
Each step is internally translated to `POST /perform` calls in order; the IPC protocol itself is unchanged.

**Scenario format**:
```json
{
  "name": "counter-flow",
  "steps": [
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "parameters": null,
      "expect": { "count": 1, "isEnabled": true }
    }
  ]
}
```

- `action` is passed directly as `commandName` to `POST /perform` (getState / tap / setProperty / setEnabled / component-specific commands).
- `parameters` is optional (defaults to `null`).
- `expect` is optional. When specified, each key is matched against the resulting `describedState`; mismatched or missing keys are recorded as failures (numbers allow a small tolerance; all other types require exact match).
- Steps execute in order. If a step fails (HTTP error or `{"error":...}` response), the scenario continues to the next step rather than aborting.

**Return value**: Structured JSON containing the pass/fail result and assert details for each step, plus an overall summary (`passCount`/`failCount`). See `docs/design.md` §E2 for details.

---

## testID Naming Convention

Use hierarchical names that reflect the app's View structure.

**Format**: `{scene}.{component}[.{subcomponent}]`

**Examples**:
- `"scene.auth.loginButton"` — Login button on the auth screen
- `"scene.dashboard.userCard.editButton"` — Dashboard > UserCard > Edit button
- `"scene.settings.toggleSwitch"` — Toggle switch on the settings screen

### Setting up the testID

Each UI component conforms to the `AnyTestable` protocol and defines a `testID` field:

```swift
final class LoginButton: ObservableObject, AnyTestable {
  let testID: String = "scene.auth.loginButton"
  // ...
}
```

---

## Standard Commands

### getState

**Purpose**: Snapshot the component's current state (no side effects)  
**Parameters**: none

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**Example implementation**:
```swift
case "getState":
  return describedState
```

---

### tap

**Purpose**: Execute a tap action on a button or similar component  
**Parameters**: none

**Semantics (S2 finalized)**:
- If `isEnabled == false`, the command is a **no-op** (mirrors real-user behavior)
- When enabled: set `isEnabled = false` (prevent double-submit) and `title = "Logged In"` (simulates a login transition)

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**Example implementation** (LoginButton):
```swift
case "tap":
  var state = _state
  applyTap(to: &state)   // guard isEnabled; isEnabled=false; title="Logged In"
  _state = state
  return describedState
```

**tap response example** (when enabled):
```json
{
  "isEnabled": false,
  "title": "Logged In",
  "isHidden": false,
  "alpha": 1.0,
  "backgroundColor": "systemBlue"
}
```

**tap response example** (when disabled / no-op):
```json
{
  "isEnabled": false,
  "title": "Log In",
  "isHidden": false,
  "alpha": 1.0,
  "backgroundColor": "systemBlue"
}
```

---

### setProperty

**Purpose**: Set a property value  
**Parameters**: `{"key": "string", "value": <value>}`

**Supported keys (LoginButton)**:

| key | Type | Description |
|---|---|---|
| `isEnabled` | bool | enable/disable |
| `title` | string | Button label |
| `isHidden` | bool | show/hide |
| `alpha` | double | Opacity (0.0–1.0) |
| `backgroundColor` | string | Background color name (e.g. "systemBlue") |

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**Example implementation**:
```swift
case "setProperty":
  var state = _state
  try applySetProperty(to: &state, parameters: parameters)
  _state = state
  return describedState
```

---

### setEnabled

**Purpose**: Directly set isEnabled (bool parameter)  
**Parameters**: `true` or `false` (JSONValue.bool)

**Response schema**:
```json
{
  "isEnabled": <bool>,
  "title": <string>,
  "isHidden": <bool>,
  "alpha": <number>,
  "backgroundColor": <string>
}
```

**Example implementation**:
```swift
case "setEnabled":
  var state = _state
  try applySetEnabled(to: &state, parameters: parameters)
  _state = state
  return describedState
```

---

## Component-Specific Commands

These commands perform component-specific operations. Each component (Counter, OnOffSwitch, etc.) provides its own implementation.

### increment

**Purpose**: Increment a numeric counter (e.g. Counter)  
**Parameters**: none  
**Precondition**: Only operates when `isEnabled == true`; no-op when disabled

**Response schema**:
```json
{
  "count": <number>,
  // Other describedState keys provided by the component
  "isEnabled": <bool>,
  ...
}
```

**Example implementation** (Counter):
```swift
case "increment":
  var state = _state
  if state.isEnabled { state.count += 1 }
  _state = state
  return describedState
```

---

### decrement

**Purpose**: Decrement a numeric counter (e.g. Counter)  
**Parameters**: none  
**Precondition**: Only operates when `isEnabled == true`; no-op when disabled

**Response schema**:
```json
{
  "count": <number>,
  // Other describedState keys provided by the component
  "isEnabled": <bool>,
  ...
}
```

**Example implementation** (Counter):
```swift
case "decrement":
  var state = _state
  if state.isEnabled { state.count -= 1 }
  _state = state
  return describedState
```

---

### reset

**Purpose**: Reset the component (e.g. Counter) to its initial state  
**Parameters**: none

**Response schema**:
```json
{
  "count": 0,  // or initial value
  "isEnabled": <bool>,
  ...
}
```

**Example implementation** (Counter):
```swift
case "reset":
  var state = _state
  state.count = 0
  _state = state
  return describedState
```

---

### toggle

**Purpose**: Toggle an On/Off switch state (e.g. OnOffSwitch)  
**Parameters**: none

**Response schema**:
```json
{
  "isOn": <bool>,
  "isEnabled": <bool>,
  ...
}
```

**Example implementation** (OnOffSwitch):
```swift
case "toggle":
  var state = _state
  state.isOn.toggle()
  _state = state
  return describedState
```

---

### clear

**Purpose**: Clear a text input field (e.g. TextInput)  
**Parameters**: none

**Response schema**:
```json
{
  "text": "",
  "isEnabled": <bool>,
  ...
}
```

**Example implementation** (TextInput):
```swift
case "clear":
  var state = _state
  state.text = ""
  _state = state
  return describedState
```

---

## Wire Format (JSON Coding)

All values are unified under the `JSONValue` enum:

```swift
public enum JSONValue: Codable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])
}
```

**Request example (tap command)**:
```python
{
  "testID": "scene.auth.loginButton",
  "commandName": "tap",
  "parameters": null
}
```

**Request example (setProperty command)**:
```python
{
  "testID": "scene.auth.loginButton",
  "commandName": "setProperty",
  "parameters": {
    "key": "isEnabled",
    "value": true
  }
}
```

---

## describedState Format

Each `AnyTestable` implementation returns `describedState` in the following structure:

```swift
var describedState: [String: JSONValue] {
  makeLoginButtonDescribedState(_state)
}
```

The `describedState` for LoginButton (shared between CLI and SwiftUI) has **5 fixed keys**:

```json
{
  "isEnabled": true,
  "title": "Log In",
  "isHidden": false,
  "alpha": 1.0,
  "backgroundColor": "systemBlue"
}
```

---

## Error Handling

When an error occurs in `TestableServer`:

```swift
throw TestError.unknownCommand(commandName)
throw TestError.componentNotFound(testID)
throw TestError.invalidParameters
```

The requester receives HTTP 200 OK with:

```json
{
  "error": "Unknown command: 'foo'"
}
```

---

## Test Phases

TestableUIKit verification is performed in three phases:

### Phase A: Network Connectivity
**Purpose**: Verify communication from Simulator to Host (localhost:8888)  
**Execution**: `GET /ping`  
**Expected**: `{"status": "ok"}`

### Phase B: Logic Verification (UI State Change)
**Purpose**: Demonstrate UI component state changes  
**Steps**:
1. `/perform` with `getState` command — retrieve initial state (`isEnabled: true, title: "Log In"`)
2. `/perform` with `tap` command — execute the login transition
3. `/perform` with `getState` command — retrieve final state and verify the change

**Expected**: The following state transition is confirmed:
- `isEnabled: true → false`
- `title: "Log In" → "Logged In"`

**Significance of Phase B**: Exercises the full path — IPC tap → `@Published` change (`title` change proves re-render) → SwiftUI re-render — in a single pass.

### Phase B-5: Bidirectional Recovery
**Purpose**: Demonstrate bidirectional UI state control and recoverability  
**Steps**:
1. Execute `tap` via `/perform` and confirm `isEnabled: false` state
2. Execute `setEnabled(true)` via `/perform` — restore state to initial value
3. Execute `getState` via `/perform` — confirm the recovered state (`isEnabled → true`)

**Expected**: State recovery `isEnabled: false → true` is confirmed  
**Significance**: Ensures test reproducibility and state resetability

---

## Implementation Checklist

- [x] testID naming convention established
- [x] GET /ping endpoint working
- [x] POST /perform with getState command
- [x] POST /perform with tap command
- [x] describedState mechanism
- [x] Phase A (Network) verification
- [x] Phase B (State Change) verification
- [x] Phase B-5 (Bidirectional Recovery) verification
- [x] setProperty command (getState/tap/setProperty/setEnabled unified interface, 5-key describedState)
- [x] tap semantics finalized (S2: guard isEnabled / isEnabled=false / title="Logged In", 5-key fixed maintained)
- [x] All-commands common Response schema documented (5-key fixed describedState)
- [x] Integration with CI/CD via pytest (STEP 1)
