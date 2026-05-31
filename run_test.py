#!/usr/bin/env python3
"""
TestableUIKit Test Runner - Two Phase Verification
Phase A: Network path verification (ping)
Phase B: Logic verification (tap)

【実行前のチェック】
1. iOS Simulator が起動していることを確認
2. DemoApp が Simulator 上で実行中であることを確認
3. Xcode のコンソールに "[SERVER] Started on http://localhost:8888" が表示されていることを確認
"""

import json
import sys
import subprocess
import time
import os


def send_http_request(method: str, path: str, data: dict = None) -> dict:
    """Generic HTTP request via curl"""
    url = f"http://localhost:8888{path}"

    curl_cmd = ["curl", "-s", "-X", method, url]

    if method == "POST" and data:
        curl_cmd.extend([
            "-H", "Content-Type: application/json",
            "-d", json.dumps(data)
        ])

    try:
        result = subprocess.run(curl_cmd, capture_output=True, text=True, timeout=5)
        if result.returncode != 0:
            print(f"❌ curl failed: {result.stderr}")
            return None

        if result.stdout:
            return json.loads(result.stdout)
        return {}
    except Exception as e:
        print(f"❌ HTTP request failed: {e}")
        return None


def check_prerequisites():
    """実行前の環境チェック"""
    print("=" * 70)
    print("Preflight Checks")
    print("=" * 70)

    checks = [
        ("Xcode available", lambda: os.path.exists("/Applications/Xcode.app")),
        ("curl available", lambda: subprocess.run(["which", "curl"], capture_output=True).returncode == 0),
        ("Python 3.6+", lambda: sys.version_info >= (3, 6)),
    ]

    all_passed = True
    for check_name, check_fn in checks:
        try:
            result = check_fn()
            status = "✅" if result else "❌"
            print(f"{status} {check_name}")
            if not result:
                all_passed = False
        except Exception as e:
            print(f"❌ {check_name}: {e}")
            all_passed = False

    if not all_passed:
        print("\n⚠️  Some prerequisites are missing!")
        print("Make sure:")
        print("  1. Xcode is installed at /Applications/Xcode.app")
        print("  2. curl is available in terminal")
        print("  3. Python 3.6+ is installed")
        return False

    print("\n✅ All prerequisites passed\n")
    return True


def main():
    print("=" * 70)
    print("TestableUIKit Test Runner - Phase A & B")
    print("=" * 70)

    # Preflight checks
    if not check_prerequisites():
        sys.exit(1)

    print("\n⚠️  IMPORTANT BEFORE RUNNING:")
    print("1. Make sure iOS Simulator is running with DemoApp")
    print("2. Check Xcode console shows: '[SERVER] Started on http://localhost:8888'")
    print("3. Press ENTER to continue or Ctrl+C to abort")
    input()

    # ──────────────────────────────────────────────────────────────
    # Phase A: Network path verification
    # ──────────────────────────────────────────────────────────────
    print("\n[PHASE A] Network Path Verification")
    print("-" * 70)
    print("Verifying that Simulator → localhost:8888 is reachable...")

    ping_response = send_http_request("GET", "/ping")

    if ping_response is None or ping_response.get("status") != "ok":
        print("❌ [FAIL] Server not reachable!")
        print("\nMake sure:")
        print("  1. iOS Simulator is running")
        print("  2. App is running and has started TestableServer")
        print("  3. No firewall blocks localhost:8888")
        sys.exit(1)

    print("✅ [PASS] Server is reachable")
    print(f"   Response: {json.dumps(ping_response)}")

    # ──────────────────────────────────────────────────────────────
    # Phase B: Logic verification - State change verification
    # ──────────────────────────────────────────────────────────────
    print("\n[PHASE B] Logic Verification - State Change (getState → tap → getState)")
    print("-" * 70)

    # Step B-1: Get initial state
    print("\nStep B-1: Querying initial state...")
    getstate_payload = {
        "testID": "scene.auth.loginButton",
        "commandName": "getState",
        "parameters": {}
    }

    initial_state = send_http_request("POST", "/perform", getstate_payload)

    if initial_state is None:
        print("❌ [FAIL] Failed to query initial state!")
        sys.exit(1)

    print("✅ Initial state retrieved:")
    print(f"   {json.dumps(initial_state, indent=3)}")

    # Verify initial state structure
    if "isEnabled" not in initial_state or "title" not in initial_state:
        print("❌ [FAIL] Initial state missing required fields")
        sys.exit(1)

    initial_isEnabled = initial_state.get("isEnabled")
    initial_title = initial_state.get("title")

    print(f"   isEnabled: {initial_isEnabled}")
    print(f"   title: '{initial_title}'")

    # Step B-2: Execute tap command
    print("\nStep B-2: Sending 'tap' command...")
    tap_payload = {
        "testID": "scene.auth.loginButton",
        "commandName": "tap",
        "parameters": {}
    }

    tap_response = send_http_request("POST", "/perform", tap_payload)

    if tap_response is None:
        print("❌ [FAIL] Tap command failed!")
        sys.exit(1)

    print("✅ Tap command executed")
    print(f"   Response: {json.dumps(tap_response, indent=3)}")

    # Step B-3: Query state after tap
    print("\nStep B-3: Querying state after tap...")
    final_state = send_http_request("POST", "/perform", getstate_payload)

    if final_state is None:
        print("❌ [FAIL] Failed to query final state!")
        sys.exit(1)

    print("✅ Final state retrieved:")
    print(f"   {json.dumps(final_state, indent=3)}")

    final_isEnabled = final_state.get("isEnabled")
    final_title = final_state.get("title")

    print(f"   isEnabled: {final_isEnabled}")
    print(f"   title: '{final_title}'")

    # Step B-4: Verify state change
    print("\n" + "-" * 70)
    print("State Change Analysis:")
    print("-" * 70)
    print(f"isEnabled:  {initial_isEnabled} → {final_isEnabled}")
    print(f"title:      '{initial_title}' → '{final_title}'")

    state_changed = (initial_isEnabled != final_isEnabled)
    if state_changed:
        print("\n✅ [PASS] State changed as expected!")
        if initial_isEnabled is True and final_isEnabled is False:
            print("         (isEnabled: true → false, as expected for tap)")
    else:
        print("\n❌ [FAIL] State did not change after tap!")
        print("         Expected: isEnabled to change from true to false")
        sys.exit(1)

    # ──────────────────────────────────────────────────────────────
    # Summary
    # ──────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("Test Summary")
    print("=" * 70)
    print("Phase A (Network): ✅ PASS")
    print("Phase B (Logic):   ✅ PASS")
    print("=" * 70)
    print("All tests completed successfully!")


if __name__ == "__main__":
    main()
