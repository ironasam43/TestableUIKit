# Scenario Authoring Guide

Reference documentation for writing declarative UI scenarios (`ui_runScenario`) in JSON.

## What is a Scenario?

A UI test scenario **declaratively describes** a sequence of steps and verifies the UI state after each step using `expect` (expected values). Scenario execution is automated via the MCP `ui_runScenario` tool, which returns the pass/fail result for each step as structured data.

```json
{
  "name": "counter-flow",
  "steps": [
    {
      "action": "getState",
      "testID": "scene.demo.counter",
      "expect": { "count": 0 }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 1 }
    }
  ]
}
```

## Top-Level Schema

| Key | Type | Required | Description |
|---|---|---|---|
| `$schema` | string | No | JSON Schema reference (e.g. `scenario.schema.json`) |
| `name` | string | **Yes** | Scenario name (e.g. `counter-flow`, `login-flow`) |
| `steps` | array | **Yes** | Array of steps to execute, run in order from the first |

## Step Schema

Each step is an object with the following keys:

| Key | Type | Required | Description |
|---|---|---|---|
| `action` | string | **Yes** | Command to execute (enum) |
| `testID` | string | **Yes** | testID of the target component |
| `parameters` | object | No | Command parameters. Format varies by command. |
| `expect` | object | No | Keys and expected values to assert after execution. Multiple keys can be asserted simultaneously. |

## Action (Command) Catalog

### Universal Commands (available on all components)

#### `getState`
Retrieves the current `describedState` of the component. No side effects.

```json
{
  "action": "getState",
  "testID": "scene.demo.counter",
  "expect": { "count": 0, "isEnabled": true }
}
```

**parameters**: none

---

#### `setProperty`
Modifies a component property.

```json
{
  "action": "setProperty",
  "testID": "scene.demo.counter",
  "parameters": { "key": "isEnabled", "value": false },
  "expect": { "isEnabled": false }
}
```

**parameters** format (required):
```json
{
  "key": "property name (string)",
  "value": "any value (number / boolean / string, etc.)"
}
```

---

### Component-Specific Commands

#### `tap`
Taps a tappable component such as a button.

```json
{
  "action": "tap",
  "testID": "scene.auth.loginButton",
  "expect": { "title": "Logged In" }
}
```

**parameters**: none

---

#### `increment` / `decrement`
Increments or decrements a numeric counter (e.g. Counter).

```json
{
  "action": "increment",
  "testID": "scene.demo.counter",
  "expect": { "count": 1 }
}
```

**parameters**: none

---

#### `reset`
Resets the component (e.g. Counter) to its initial state.

```json
{
  "action": "reset",
  "testID": "scene.demo.counter",
  "expect": { "count": 0 }
}
```

**parameters**: none

---

#### `toggle`
Toggles the On/Off switch state.

```json
{
  "action": "toggle",
  "testID": "scene.demo.switch",
  "expect": { "isOn": true }
}
```

**parameters**: none

---

#### `clear`
Clears a text input field.

```json
{
  "action": "clear",
  "testID": "scene.form.nameInput",
  "expect": { "text": "" }
}
```

**parameters**: none

---

#### `setEnabled`
Directly sets a component's enabled/disabled state. To avoid redundancy with `setProperty { key: "isEnabled", value: bool }`, prefer using `setProperty` when possible.

```json
{
  "action": "setEnabled",
  "testID": "scene.auth.loginButton",
  "parameters": false,
  "expect": { "isEnabled": false }
}
```

**parameters**: boolean (true / false)

---

## expect (Assertion) Key Catalog

### Fixed (Universal) Keys

These 5 keys are available on virtually all components:

| Key | Type | Description |
|---|---|---|
| `isEnabled` | boolean | Whether the component is enabled |
| `title` | string | Display text such as a button label |
| `isHidden` | boolean | Whether the component is hidden |
| `alpha` | number | Opacity (0.0–1.0) |
| `backgroundColor` | string | Background color (color name or hex code) |

```json
{
  "expect": {
    "isEnabled": true,
    "title": "Submit",
    "isHidden": false,
    "alpha": 1,
    "backgroundColor": "systemBlue"
  }
}
```

### Component-Specific Keys

Each component has a custom described state; you can assert any key in addition to the fixed keys:

| Component | Key example | Type | Description |
|---|---|---|---|
| Counter | `count` | number | Current count value |
| OnOffSwitch | `isOn` | boolean | On/off state |
| TextInput | `text` | string | Input text |
| Slider | `value` | number | Slider value |
| Label | `label` | string | Label text |

```json
{
  "expect": {
    "count": 5,      // Counter-specific
    "isEnabled": true // universal
  }
}
```

Multiple keys are evaluated with AND logic: all specified keys must match for the step to pass.

---

## Complete Examples

### counter-flow.json (Counter UI test)

```json
{
  "$schema": "scenario.schema.json",
  "name": "counter-flow",
  "steps": [
    {
      "action": "getState",
      "testID": "scene.demo.counter",
      "expect": { "count": 0, "isEnabled": true }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 1, "isEnabled": true }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 2 }
    },
    {
      "action": "setProperty",
      "testID": "scene.demo.counter",
      "parameters": { "key": "isEnabled", "value": false },
      "expect": { "isEnabled": false }
    },
    {
      "action": "increment",
      "testID": "scene.demo.counter",
      "expect": { "count": 2, "isEnabled": false }
    }
  ]
}
```

This scenario verifies:
1. Counter initial state is count=0 and enabled
2. increment increases count to 1
3. Another increment increases count to 2
4. setProperty changes isEnabled to false
5. Sending increment to a disabled component does not change the count (count remains 2)

---

### login-flow.json (Button state transition test)

```json
{
  "$schema": "scenario.schema.json",
  "name": "login-flow",
  "steps": [
    {
      "action": "getState",
      "testID": "scene.auth.loginButton",
      "expect": {
        "isEnabled": true,
        "title": "Log In",
        "isHidden": false,
        "alpha": 1,
        "backgroundColor": "systemBlue"
      }
    },
    {
      "action": "tap",
      "testID": "scene.auth.loginButton",
      "expect": { "isEnabled": false, "title": "Logged In" }
    },
    {
      "action": "setProperty",
      "testID": "scene.auth.loginButton",
      "parameters": { "key": "isEnabled", "value": true },
      "expect": { "isEnabled": true, "title": "Logged In" }
    }
  ]
}
```

This scenario verifies:
1. Login button initial state (enabled, title "Log In", visible, fully opaque, blue background)
2. tap disables the button and changes the title to "Logged In"
3. setProperty re-enables the button

---

## Authoring Tips & Pitfalls

### 1. Verify commands issued to disabled components

After a component is disabled (`isEnabled: false`), commands are still sent but state changes may not occur. Verify this explicitly with `expect`:

```json
{
  "action": "setProperty",
  "testID": "scene.demo.counter",
  "parameters": { "key": "isEnabled", "value": false },
  "expect": { "isEnabled": false }
},
{
  "action": "increment",
  "testID": "scene.demo.counter",
  "expect": { "count": 0 }  // confirm count does not increase
}
```

### 2. `expect` is optional

Skip unnecessary assertions:

```json
{
  "action": "getState",
  "testID": "scene.demo.counter"
  // no expect = just retrieve state without asserting
}
```

### 3. `parameters` format varies by command

- `setProperty`: must use `{ "key": string, "value": any }` format
- `setEnabled`: pass the boolean directly (`parameters: false`)
- Other commands: typically omitted

### 4. Exact `testID` match required

The `testID` must **exactly match** the value set in the component. Typos and partial matches will not work.

### 5. Color string format

`backgroundColor` accepts the following formats:
- Color name: `"systemBlue"`, `"systemRed"`, `"white"`, `"black"`, etc.
- Hex: `"#FF0000"` (upper or lower case)
- RGB: depends on component implementation (color names recommended)

---

## JSON Schema Validation

All scenarios can be validated against `Example/scenarios/scenario.schema.json`. Use your IDE or a JSON validator to check validity before committing.

---

## Related Documentation

- **IPC protocol details**: `docs/ipc-protocol.md` §4 "/perform command reference"
- **Design spec**: `docs/design.md` §E2 "Declarative Scenario implementation"
- **Sample scenarios**: `Example/scenarios/` (counter-flow.json, login-flow.json)
