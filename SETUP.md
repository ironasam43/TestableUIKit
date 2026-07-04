# TestableUIKit Demo App — Setup Guide

Step-by-step instructions for running TestableUIKit on the iOS Simulator.

## Prerequisites

- Xcode 14.0 or later
- iOS 14 or later Simulator
- Python 3.8 or later (for the test runner)

## Step 1: Create an iOS App Project

### 1-1. Launch Xcode and create a new project

```
Xcode > File > New > Project...
```

### 1-2. Choose a project template

- **Platform**: iOS
- **Template**: App

### 1-3. Configure the project

| Item | Value |
|---|---|
| Product Name | `TestableUIKitDemo` |
| Team | (select your Team) |
| Organization Identifier | `com.example` |
| Interface | SwiftUI |
| Language | Swift |

### 1-4. Choose a save location

```
/Users/koba-p/Documents/Dev/projects/TestableUIKit/
```

✅ The project has been created. Xcode will open.

---

## Step 2: Add the TestableUIKit Library as a Dependency

### 2-1. Add a Package dependency

```
Project (TestableUIKitDemo) > Package Dependencies > +
```

### 2-2. Specify the local path

```
Add Local...
```

Select the directory:
```
/Users/koba-p/Documents/Dev/projects/TestableUIKit
```

### 2-3. Confirm the version

- Branch: `main` (or latest)
- Add the dependency

✅ TestableUIKit has been added to Linked Frameworks.

---

## Step 3: Add Files

### 3-1. Add DemoApp.swift

1. In Xcode, select `File > New > File...`
2. Choose the `Swift File` template
3. Filename: `DemoApp.swift`
4. Save to: project root
5. Paste the following code:

```swift
// === START ===
// Copy and paste the entire contents of DemoApp-iOS-template.swift
// === END ===
```

Reference file:
```
../DemoApp-iOS-template.swift
```

### 3-2. Add LoginButton.swift

Similarly, create `LoginButton.swift`:

```swift
// === START ===
// Copy and paste the entire contents of LoginButton-iOS-template.swift
// === END ===
```

Reference file:
```
../LoginButton-iOS-template.swift
```

✅ Both files have been added to the Xcode project.

---

## Step 4: Verify Build Settings

### 4-1. Check Build Settings

```
Project (TestableUIKitDemo) > Build Settings
```

| Key | Value |
|---|---|
| iOS Deployment Target | 14.0 or later |
| Architectures | arm64 (Simulator: x86_64) |

### 4-2. Configure Signing & Capabilities (if needed)

```
Project > Signing & Capabilities > Set Team
```

✅ Build settings are complete.

---

## Step 5: Run in Simulator

### 5-1. Select a Simulator device

```
Xcode > Product > Destination > [your preferred iPhone] > Simulator
```

Examples:
- `iPhone 15 Pro (17.0)`
- `iPhone 14 (16.0)`

### 5-2. Launch the Simulator

```
Xcode > Product > Run
or Command + R
```

**On first launch:**
- The Simulator will start (wait 1–2 minutes)
- DemoApp will appear in the Simulator

✅ DemoApp launches in the Simulator and the "Testable UIKit Demo" screen is displayed.

---

## Step 6: Run Tests

### 6-1. Confirm the app is running in the Simulator

The screen should display:
- `Testable UIKit Demo` (title)
- `Log In` button (blue)
- `Server running on http://localhost:8888`

### 6-2. Confirm server startup in console

The following should appear in Xcode's Debug Console:

```
[SERVER] Started on http://localhost:8888
```

### 6-3. Run the Python test runner

Open a separate terminal and run from the project directory:

```bash
cd /Users/koba-p/Documents/Dev/projects/TestableUIKit
python3 run_test.py
```

### 6-4. Check test results

#### Phase A (Network Path Verification)

```
[PHASE A] Network Path Verification
...
✅ [PASS] Server is reachable
   Response: {"status": "ok"}
```

#### Phase B (Logic Verification)

```
[PHASE B] Logic Verification - Tap LoginButton
...
✅ [PASS] Tap command successful
   Response: {
     "isEnabled": true,
     "title": "Log In"
   }
```

✅ You are done when **All tests passed!** is displayed.

---

## Step 7: Running on a Physical Device (LAN)

Instructions for running tests on a physical iPhone or iPad instead of the Simulator.

### Prerequisites

- DemoApp installed on the device via a DEBUG build
- The device and Mac are connected to the same Wi-Fi network
- Confirm in the Xcode console that DemoApp is running

### 7-1. How LAN exposure works

In a DEBUG build, DemoApp binds the HTTP server to `0.0.0.0:8888` (exposed on the local network).

```swift
// From DemoApp.swift
#if DEBUG
    let server = try TestableServer(port: 8888, host: "0.0.0.0")  // LAN exposed
#else
    let server = try TestableServer(port: 8888)  // Release: localhost only
#endif
```

### 7-2. Confirm server startup log

After launching DemoApp on the device, confirm the following appears in Xcode's Debug Console:

```
✅ TestableServer listening on http://0.0.0.0:8888
```

If this log appears, LAN access is available.

### 7-3. Find the device IP address

Look up the IP address from the device (iPhone / iPad) Settings:

```
Settings > Wi-Fi > Connected Network > Info > IP Address
```

Example: `192.168.0.181`

**Note**: The device IP may change due to DHCP. It is recommended to verify it each time you run tests.

### 7-4. Configure Mac-to-Device access

In the Mac terminal, run the test runner with the `TESTABLE_IPC_HOST` environment variable set to the device IP:

```bash
cd /Users/koba-p/Documents/Dev/projects/TestableUIKit
TESTABLE_IPC_HOST=192.168.0.181 python3 run_test.py
```

**Configuration**:
- `TESTABLE_IPC_HOST`: Device IP address (default: `localhost`)
- `TESTABLE_IPC_PORT`: Port number (default: `8888`). Can usually be omitted.

**Command examples**:
```bash
# Without port (default 8888)
TESTABLE_IPC_HOST=192.168.0.181 python3 run_test.py

# With explicit port
TESTABLE_IPC_HOST=192.168.0.181 TESTABLE_IPC_PORT=8888 python3 run_test.py
```

### 7-5. Screenshot capture routes

During test execution, UI screenshot capture works as follows:

| Environment | Route | Description |
|---|---|---|
| Physical device | `GET /screenshot` | Captured in-app via `UIGraphicsImageRenderer`. Does not depend on the Simulator. |
| Simulator | Try `GET /screenshot` → fall back to simctl | If `GET /screenshot` is available it is preferred; `simctl` is used only when it is not. |

**Implementation details**:
- `mcp_server/testableui_mcp.py`'s `ui_screenshot()` first requests `GET /screenshot`
- On a physical device, this endpoint returns the capture directly
- The `simctl` fallback is triggered only when a connection error occurs in the Simulator

### 7-6. Physical device troubleshooting

#### Error: `Connection refused`

The device IP is incorrect or DemoApp is not running:

1. **Confirm DemoApp is running on the device**
2. **Re-check the device IP address** (Settings > Wi-Fi > Info)
3. **Confirm `✅ TestableServer listening on http://0.0.0.0:8888` appears in the Xcode console**

#### Error: `Timeout`

The device and Mac cannot communicate:

1. **Wi-Fi check**: Confirm both are connected to the same network
2. **Firewall check**: Confirm port 8888 is not blocked in Mac firewall settings
   ```
   System Preferences > Security & Privacy > Firewall Options
   ```
3. **Network isolation**: Confirm that device-to-device communication is not restricted (e.g., corporate Wi-Fi)

#### Error: `RuntimeError: simctl not available on a non-loopback host`

The connection to the device succeeded, but this error appears during the screenshot fallback:

- This error can be ignored. The capture has already been obtained via `GET /screenshot` from the device.
- The `simctl` fallback is only active for the Simulator.

---

## Troubleshooting

### Error: `No module named 'requests'`

```bash
pip3 install requests
```

### Error: `curl: command not found`

macOS includes curl by default. Alternative way to test:

```bash
# Use Python requests instead of curl
# Manually modify run_test.py to use requests
```

### Error: `Server not reachable`

If the Simulator cannot reach localhost:8888:

1. **Restart the Simulator**:
   ```
   Xcode > Device > Erase All Content and Settings...
   ```

2. **Check the firewall**:
   ```
   System Preferences > Security & Privacy > Firewall
   ```

3. **Restart Xcode**

### Error: `isEnabled is false`

The button is in a disabled state. Check the LoginButton initialization in DemoApp.swift:

```swift
button.isEnabled = true  // add this
```

---

## Next Steps

The vertical slice has been validated. The following are next-phase items:

- Add Contract definitions (validators)
- Screenshot + diff analysis
- AI test generation integration

---

**If you have any questions or issues, please open a GitHub Issue.**
