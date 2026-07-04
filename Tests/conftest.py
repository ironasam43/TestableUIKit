"""
pytest fixtures for TestableUIKit IPC integration tests.

Prerequisite: DemoApp must be running on iOS Simulator with
              TestableServer listening.

Override connection target (Design D: LAN IPC):
  TESTABLE_IPC_HOST env var to change target host (default: localhost)
  TESTABLE_IPC_PORT env var to change target port (default: 8888)
"""

import os
import sys

import pytest
import requests

# Add mcp_server/ to import path (for resolve_ipc_host_port)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp_server"))
from ipc_helpers import resolve_ipc_host_port

# ========== Constants ==========

_ipc_host, _ipc_port = resolve_ipc_host_port()
BASE_URL = f"http://{_ipc_host}:{_ipc_port}"
TEST_ID = "scene.auth.loginButton"

# LoginButton initial state (5 fixed keys)
INITIAL_STATE = {
    "isEnabled": True,
    "title": "Log In",
    "isHidden": False,
    "alpha": 1.0,
    "backgroundColor": "systemBlue",
}


# ========== Fixtures ==========

@pytest.fixture(scope="session")
def base_url():
    """Base URL of the IPC server (shared for the entire session)."""
    return BASE_URL


@pytest.fixture(scope="session")
def test_id():
    """testID of the component under test (shared for the entire session)."""
    return TEST_ID


@pytest.fixture
def perform(base_url, test_id):
    """
    Returns a helper fixture function for POST /perform.

    Usage:
        state = perform("tap")
        state = perform("setProperty", {"key": "isEnabled", "value": True})
    """
    def _perform(command_name, parameters=None):
        payload = {
            "testID": test_id,
            "commandName": command_name,
            "parameters": parameters,
        }
        resp = requests.post(f"{base_url}/perform", json=payload, timeout=10)
        if not resp.ok:
            print(
                f"\n[HTTP ERROR] {resp.status_code} on perform('{command_name}'): {resp.text}",
                flush=True,
            )
        resp.raise_for_status()
        return resp.json()

    return _perform


@pytest.fixture(autouse=True)
def reset_state(perform):
    """
    Resets LoginButton to initial state before each test (autouse).

    Initial state:
      isEnabled: true, title: "Log In", isHidden: false,
      alpha: 1.0, backgroundColor: "systemBlue"
    """
    # Reset only the two keys that change on tap (isEnabled and title)
    perform("setProperty", {"key": "isEnabled", "value": True})
    perform("setProperty", {"key": "title", "value": "Log In"})
    yield
