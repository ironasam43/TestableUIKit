# Troubleshooting

This guide covers common issues and solutions when using TestableUIKit.
For setup instructions, see [`SETUP.md`](../SETUP.md); for instrumentation steps, see [`docs/getting-started.md`](getting-started.md).

---

## Server Startup & Connectivity

### `✅ TestableServer listening on ...` not shown

The server is not running.

1. Confirm that the app (DemoApp or your own app) is launched in the Simulator or on a physical device.
2. Verify that `.task { server.start() }` is being called and that `TestableServer` initialization is not silently swallowed by `try?`.
3. Check the logs in Xcode's Console tab.

### `Connection refused` / `Server not reachable`

The server is not listening on the expected host and port.

1. Confirm that `✅ TestableServer listening on http://<host>:8888` appears in the Xcode console.
2. For Simulator: access via `localhost:8888`. For a physical device: expose with `host: "0.0.0.0"` under `#if DEBUG` and specify the device IP (see "Physical Device (LAN)" below).
3. Restart the Simulator (`Xcode > Device > Erase All Content and Settings...`).
4. Check the firewall (`System Settings > Network > Firewall`) to ensure port 8888 is not blocked.

### Port 8888 conflict (multiple instances or another process)

If a process is already holding port 8888, `TestableServer.start()` will not reach the ready state and will instead enter `.failed` (`POSIXErrorCode 48: Address already in use`).

**Detection**: You can detect this programmatically via `onStateChange` (previously only detectable via print output).

```swift
let server = try TestableServer(port: 8888, registry: registry)
server.onStateChange = { state in
  switch state {
  case .ready:        print("listening")
  case .failed(let e): print("Startup failed (possible port conflict): \(e)")  // handle fallback here
  case .cancelled:    print("stopped")
  default: break
  }
}
server.start()
```

**Resolution**:

1. Identify and kill the conflicting process.
   ```bash
   lsof -i :8888
   kill <PID>
   ```
2. Start on a different port (`TestableServer(port: 8889, registry:)`). Update `TESTABLE_IPC_PORT` on the client side accordingly.
3. Check that a previously launched app or server is not still running (multiple instances). Calling `server.stop()` for a graceful shutdown releases the port and delivers `.cancelled` to `onStateChange`.

### `Connection refused` but ping succeeds (`component not found` / 404)

If `POST /perform` returns 404 (`component not found`), the most common cause is a **missing Registry injection**.
If you forget to inject `.environment(\.testableRegistry, registry)`, `.testable(_:)` registers with an empty default-value registry that is separate from the server's registry. Make sure the same `registry` instance created at the app entry point is passed to **both the server and the View tree** (see Gotcha #1 in [`getting-started.md`](getting-started.md)).

---

## Test Runner (Python)

### `No module named 'requests'`

```bash
pip3 install requests
```

### `curl: command not found`

macOS ships with curl by default. Check your PATH.

```bash
which curl   # => /usr/bin/curl if OK
```

### Python test gives `Connection refused`

1. Run the project in Xcode and confirm the app is launched in the Simulator or on a physical device.
2. Wait until `✅ TestableServer listening ...` appears in the console.
3. Run `python3 run_test.py`.

---

## Physical Device (LAN)

### `Connection refused` (physical device)

The device IP is wrong or DemoApp is not running.

1. Confirm that DemoApp is running on the physical device.
2. Double-check the device IP (Settings > Wi-Fi > Info).
3. Confirm that `✅ TestableServer listening on http://0.0.0.0:8888` appears in the Xcode console.
4. Set the target to the device IP: `TESTABLE_IPC_HOST=192.168.x.x python3 ...`.

### `Timeout` (physical device)

The device and Mac cannot communicate.

1. **Wi-Fi**: Confirm both are connected to the same network.
2. **Firewall**: Confirm that port 8888 is not blocked by the Mac's firewall.
3. **Network isolation**: Check whether the network (e.g. corporate Wi-Fi) restricts device-to-device communication.

### `RuntimeError: simctl not available on a non-loopback host`

This log appears when a physical device connection succeeds but the simctl fallback is triggered for screenshots.

- This error can be safely ignored. `GET /screenshot` (route A — in-app capture) has already successfully retrieved the PNG from the device.
- The `simctl` fallback is only available on the Simulator (loopback).
- See [`SETUP.md`](../SETUP.md) step 7-5 for route details.

---

## Component Behavior

### `isEnabled` is `false` and commands are no-ops

Most cores treat increment/decrement commands as no-ops when `isEnabled == false`.
Use `setProperty` to restore `isEnabled` to `true`, or ensure the component is enabled at initialization.

```swift
// Re-enable via IPC
// {"commandName":"setProperty","parameters":{"key":"isEnabled","value":true}}
```
