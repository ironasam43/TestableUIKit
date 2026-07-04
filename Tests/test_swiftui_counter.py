"""
IPC integration tests for the Counter component (pytest).

Tests:
  - POST /perform: getState / increment / decrement / reset / setProperty
  testID: "scene.demo.counter"

Prerequisite: DemoApp must be running on iOS Simulator with
              TestableServer listening on localhost:8888.
The autouse fixture in this file resets Counter to initial state before each test.
"""

import pytest
import requests

COUNTER_TEST_ID = "scene.demo.counter"
EXPECTED_KEYS = {"count", "isEnabled"}


# ========== Helpers ==========

def assert_counter_state(state: dict):
    """Verify that describedState satisfies the 2-key fixed schema."""
    assert set(state.keys()) == EXPECTED_KEYS, (
        f"Expected keys {EXPECTED_KEYS}, got {set(state.keys())}"
    )


# ========== Fixtures ==========

@pytest.fixture
def counter_perform(base_url):
    """
    Returns a POST /perform helper fixture for the Counter component.

    Usage:
        state = counter_perform("increment")
        state = counter_perform("setProperty", {"key": "count", "value": 5})
    """
    def _perform(command_name, parameters=None):
        payload = {
            "testID": COUNTER_TEST_ID,
            "commandName": command_name,
            "parameters": parameters,
        }
        resp = requests.post(f"{base_url}/perform", json=payload, timeout=10)
        if not resp.ok:
            print(
                f"\n[HTTP ERROR] {resp.status_code} on counter_perform('{command_name}'): {resp.text}",
                flush=True,
            )
        resp.raise_for_status()
        return resp.json()

    return _perform


@pytest.fixture(autouse=True)
def reset_counter(counter_perform):
    """
    Resets Counter to initial state before each test (autouse).

    Initial state: count: 0, isEnabled: true
    """
    counter_perform("reset")
    counter_perform("setProperty", {"key": "isEnabled", "value": True})
    yield


# ========== getState ==========

class TestCounterGetState:
    def test_initial_state_keys(self, counter_perform):
        """getState returns count and isEnabled as 2 keys."""
        state = counter_perform("getState")
        assert_counter_state(state)

    def test_initial_count_is_zero(self, counter_perform):
        """Initial value: count=0."""
        state = counter_perform("getState")
        assert state["count"] == 0

    def test_initial_is_enabled_true(self, counter_perform):
        """Initial value: isEnabled=true."""
        state = counter_perform("getState")
        assert state["isEnabled"] is True


# ========== increment ==========

class TestCounterIncrement:
    def test_increment_increases_count_by_one(self, counter_perform):
        """increment increases count by 1."""
        state = counter_perform("increment")
        assert_counter_state(state)
        assert state["count"] == 1

    def test_increment_twice(self, counter_perform):
        """Two increments yield count=2."""
        counter_perform("increment")
        state = counter_perform("increment")
        assert state["count"] == 2

    def test_increment_state_transition(self, counter_perform):
        """Verify state transition: getState → increment → getState."""
        before = counter_perform("getState")
        assert before["count"] == 0
        counter_perform("increment")
        after = counter_perform("getState")
        assert after["count"] == 1

    def test_increment_disabled_is_noop(self, counter_perform):
        """increment is a no-op when isEnabled=false."""
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        state = counter_perform("increment")
        assert_counter_state(state)
        assert state["count"] == 0


# ========== decrement ==========

class TestCounterDecrement:
    def test_decrement_decreases_count_by_one(self, counter_perform):
        """decrement decreases count by 1."""
        counter_perform("increment")   # count = 1
        state = counter_perform("decrement")  # count = 0
        assert_counter_state(state)
        assert state["count"] == 0

    def test_decrement_below_zero(self, counter_perform):
        """count can go negative (no lower bound)."""
        state = counter_perform("decrement")
        assert state["count"] == -1

    def test_decrement_state_transition(self, counter_perform):
        """Verify state transition: increment×2 → decrement."""
        counter_perform("increment")
        counter_perform("increment")   # count = 2
        state = counter_perform("decrement")  # count = 1
        assert state["count"] == 1

    def test_decrement_disabled_is_noop(self, counter_perform):
        """decrement is a no-op when isEnabled=false."""
        counter_perform("increment")   # count = 1
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        state = counter_perform("decrement")
        assert state["count"] == 1  # no-op


# ========== reset ==========

class TestCounterReset:
    def test_reset_sets_count_to_zero(self, counter_perform):
        """reset returns count to 0."""
        counter_perform("increment")
        counter_perform("increment")
        state = counter_perform("reset")
        assert_counter_state(state)
        assert state["count"] == 0

    def test_reset_from_negative(self, counter_perform):
        """reset from a negative value still yields count=0."""
        counter_perform("decrement")
        state = counter_perform("reset")
        assert state["count"] == 0

    def test_reset_persists_via_getstate(self, counter_perform):
        """count=0 is preserved in getState after reset."""
        counter_perform("increment")
        counter_perform("reset")
        state = counter_perform("getState")
        assert state["count"] == 0


# ========== setProperty ==========

class TestCounterSetProperty:
    def test_set_property_count(self, counter_perform):
        """setProperty can set count directly."""
        state = counter_perform("setProperty", {"key": "count", "value": 42})
        assert_counter_state(state)
        assert state["count"] == 42

    def test_set_property_is_enabled_false(self, counter_perform):
        """setProperty can set isEnabled to false."""
        state = counter_perform("setProperty", {"key": "isEnabled", "value": False})
        assert_counter_state(state)
        assert state["isEnabled"] is False

    def test_set_property_is_enabled_restore(self, counter_perform):
        """Restore from isEnabled=false to true."""
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        state = counter_perform("setProperty", {"key": "isEnabled", "value": True})
        assert state["isEnabled"] is True

    def test_set_property_count_persists(self, counter_perform):
        """count set via setProperty is preserved in getState."""
        counter_perform("setProperty", {"key": "count", "value": 99})
        state = counter_perform("getState")
        assert state["count"] == 99


# ========== State Transition Scenarios ==========

class TestCounterStateTransitions:
    def test_enable_disable_enable_sequence(self, counter_perform):
        """Toggle scenario: enable → disable → enable."""
        # isEnabled=true (initial)
        assert counter_perform("getState")["isEnabled"] is True
        # disable
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        assert counter_perform("getState")["isEnabled"] is False
        # re-enable
        counter_perform("setProperty", {"key": "isEnabled", "value": True})
        assert counter_perform("getState")["isEnabled"] is True

    def test_increment_reset_increment_scenario(self, counter_perform):
        """Scenario: increment×3 → reset → increment."""
        counter_perform("increment")
        counter_perform("increment")
        counter_perform("increment")
        assert counter_perform("getState")["count"] == 3
        counter_perform("reset")
        assert counter_perform("getState")["count"] == 0
        state = counter_perform("increment")
        assert state["count"] == 1

    def test_mixed_increment_decrement(self, counter_perform):
        """Net count=3 after increment×5 → decrement×2."""
        for _ in range(5):
            counter_perform("increment")
        for _ in range(2):
            counter_perform("decrement")
        state = counter_perform("getState")
        assert state["count"] == 3
