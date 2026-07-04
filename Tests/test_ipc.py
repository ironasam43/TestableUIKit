"""
TestableUIKit IPC integration tests (pytest).

Tests:
  - GET /ping
  - POST /perform: getState / tap (enabled / disabled no-op) / setProperty (isEnabled / title)

Prerequisite: DemoApp must be running on iOS Simulator with
              TestableServer listening on localhost:8888.
The autouse fixture in conftest.py resets LoginButton to initial state before each test.
"""

import requests


# ========== Helpers ==========

EXPECTED_KEYS = {"isEnabled", "title", "isHidden", "alpha", "backgroundColor"}


def assert_described_state(state: dict):
    """Verify that describedState satisfies the 5-key fixed schema."""
    assert set(state.keys()) == EXPECTED_KEYS, (
        f"Expected keys {EXPECTED_KEYS}, got {set(state.keys())}"
    )


# ========== Phase A: Network Connectivity ==========

class TestPing:
    def test_ping_returns_ok(self, base_url):
        """GET /ping returns {"status": "ok"}."""
        resp = requests.get(f"{base_url}/ping", timeout=10)
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}


# ========== Phase B: Logic Verification ==========

class TestGetState:
    def test_initial_state_has_five_keys(self, perform):
        """getState returns describedState with 5 fixed keys."""
        state = perform("getState")
        assert_described_state(state)

    def test_initial_state_values(self, perform):
        """Initial values from getState match expected values."""
        state = perform("getState")
        assert state["isEnabled"] is True
        assert state["title"] == "Log In"
        assert state["isHidden"] is False
        assert state["alpha"] == 1.0
        assert state["backgroundColor"] == "systemBlue"


class TestTap:
    def test_tap_enabled_changes_state(self, perform):
        """Tapping when enabled changes isEnabled=false, title="Logged In"."""
        state = perform("tap")
        assert_described_state(state)
        assert state["isEnabled"] is False
        assert state["title"] == "Logged In"

    def test_tap_enabled_unchanged_other_keys(self, perform):
        """isHidden / alpha / backgroundColor remain unchanged after tap."""
        state = perform("tap")
        assert state["isHidden"] is False
        assert state["alpha"] == 1.0
        assert state["backgroundColor"] == "systemBlue"

    def test_tap_disabled_is_noop(self, perform):
        """Tapping when disabled is a no-op (state does not change)."""
        # Disable first
        perform("setProperty", {"key": "isEnabled", "value": False})

        # Tap (should be no-op)
        state = perform("tap")
        assert_described_state(state)
        assert state["isEnabled"] is False
        assert state["title"] == "Log In"  # same as before tap


class TestSetProperty:
    def test_set_property_is_enabled_false(self, perform):
        """setProperty can set isEnabled to false."""
        state = perform("setProperty", {"key": "isEnabled", "value": False})
        assert_described_state(state)
        assert state["isEnabled"] is False

    def test_set_property_is_enabled_true(self, perform):
        """setProperty can restore isEnabled to true."""
        perform("setProperty", {"key": "isEnabled", "value": False})
        state = perform("setProperty", {"key": "isEnabled", "value": True})
        assert_described_state(state)
        assert state["isEnabled"] is True

    def test_set_property_title(self, perform):
        """setProperty can change title."""
        state = perform("setProperty", {"key": "title", "value": "Testing"})
        assert_described_state(state)
        assert state["title"] == "Testing"

    def test_set_property_title_persists(self, perform):
        """Title changed by setProperty is preserved in getState."""
        perform("setProperty", {"key": "title", "value": "Persisted"})
        state = perform("getState")
        assert state["title"] == "Persisted"
