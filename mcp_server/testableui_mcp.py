#!/usr/bin/env python3
"""
TestableUIKit MCP Server — MCP wrapper for UI testing.

Thinly wraps TestableUIKit's HTTP IPC (localhost:8888) as MCP tools,
enabling Claude to directly drive a running iOS UI and inspect describedState.

Exposed MCP tools (4):
  ui_ping        — GET /ping  liveness check
  ui_getState    — POST /perform getState  retrieve state
  ui_perform     — POST /perform  execute command (tap/setProperty/setEnabled, etc.)
  ui_screenshot  — simctl io booted screenshot  capture screenshot

Usage:
  python3 mcp_server/testableui_mcp.py

Prerequisites:
  DemoApp running on iOS Simulator (listening on localhost:8888)
  mcp and requests installed in .venv (see mcp_server/requirements.txt)
"""

import base64
import os
import subprocess
import sys
import tempfile
from typing import Optional

# Import bundled helpers (no external dependencies)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ipc_helpers import (
    build_base_url,
    build_perform_payload,
    build_screenshot_url,
    build_simctl_screenshot_command,
    is_loopback_host,
    passthrough_state,
    resolve_ipc_host_port,
)

import requests
from mcp.server.fastmcp import FastMCP

# ================================================================
# MCP server instance
# ================================================================

mcp = FastMCP("TestableUIKit")

# Override connection target via TESTABLE_IPC_HOST / TESTABLE_IPC_PORT (default: localhost:8888)
_ipc_host, _ipc_port = resolve_ipc_host_port()
_IPC_BASE = build_base_url(host=_ipc_host, port=_ipc_port)


# ================================================================
# MCP tool definitions (thin HTTP relay, stateless)
# ================================================================


@mcp.tool()
def ui_ping() -> dict:
    """Liveness check for the TestableUIKit server (GET /ping).

    Confirms whether DemoApp is running on the Simulator.
    Expected response: {"status": "ok"}

    Returns:
        Response dict from the IPC server
    """
    resp = requests.get(f"{_IPC_BASE}/ping", timeout=5)
    resp.raise_for_status()
    return resp.json()


@mcp.tool()
def ui_getState(testID: str) -> dict:
    """Retrieve the current describedState of the specified component (POST /perform getState).

    The describedState key structure depends on the component implementation (opaque dict).
    Examples:
      loginButton → {isEnabled, title, isHidden, alpha, backgroundColor}
      counter     → {count, isEnabled}
      rangeSlider → {value, minValue, maxValue, step}

    Args:
        testID: Component testID (e.g. "scene.auth.loginButton")

    Returns:
        Opaque dict of describedState
    """
    payload = build_perform_payload(testID, "getState")
    resp = requests.post(f"{_IPC_BASE}/perform", json=payload, timeout=10)
    resp.raise_for_status()
    return passthrough_state(resp.json())


@mcp.tool()
def ui_perform(testID: str, command: str, params: Optional[dict] = None) -> dict:
    """Send a command to a component (POST /perform).

    Command examples:
      "tap"           — button tap (no params needed)
      "setProperty"   — {"key": "isEnabled", "value": false}
      "setEnabled"    — {"value": true}
      "increment"     — increment the Counter

    Args:
        testID: Component testID
        command: Command name
        params: Command parameters dict (varies by command; optional)

    Returns:
        describedState after execution (opaque dict)
    """
    payload = build_perform_payload(testID, command, params)
    resp = requests.post(f"{_IPC_BASE}/perform", json=payload, timeout=10)
    resp.raise_for_status()
    return passthrough_state(resp.json())


@mcp.tool()
def ui_screenshot() -> dict:
    """Capture a screenshot of the running DemoApp (iOS device or Simulator).

    Capture order (by priority):
    1. GET /screenshot (in-app capture via TestableServer) — works on both device and Simulator
    2. simctl io booted screenshot (Simulator-only fallback)
       Used only when the target is loopback and /screenshot endpoint is unreachable.

    Returns:
        {"image_base64": "<PNG base64 string>", "format": "png"}
    """
    screenshot_url = build_screenshot_url(host=_ipc_host, port=_ipc_port)
    try:
        resp = requests.get(screenshot_url, timeout=10)
        if resp.status_code == 200:
            return resp.json()
        # HTTP errors (503: provider not configured / 500: capture failure, etc.) raise as exception
        raise RuntimeError(
            f"GET /screenshot returned HTTP {resp.status_code}: {resp.text}"
        )
    except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
        # Connection failed → attempt simctl fallback only for loopback
        if not is_loopback_host(_ipc_host):
            raise RuntimeError(
                f"Connection to GET /screenshot failed (host={_ipc_host}): {e}\n"
                "When connecting to a real device, ensure DemoApp is running and "
                "the GET /screenshot endpoint is enabled."
            ) from e
        # loopback (Simulator) only: try simctl fallback
        return _simctl_screenshot_fallback()


def _simctl_screenshot_fallback() -> dict:
    """Simulator-only fallback: simctl io booted screenshot.

    Called when /screenshot endpoint is unreachable and the target is loopback.
    """
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        output_path = f.name
    try:
        cmd = build_simctl_screenshot_command(output_path)
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if result.returncode != 0:
            raise RuntimeError(f"simctl screenshot failed: {result.stderr}")
        with open(output_path, "rb") as f:
            image_data = base64.b64encode(f.read()).decode("utf-8")
    finally:
        if os.path.exists(output_path):
            os.unlink(output_path)
    return {"image_base64": image_data, "format": "png"}


# ================================================================
# Entry point (stdio transport)
# ================================================================

if __name__ == "__main__":
    mcp.run()
