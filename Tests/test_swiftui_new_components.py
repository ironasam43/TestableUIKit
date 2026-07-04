"""
IPC integration tests for new components (TextInput / OnOffSwitch / RangeSlider) (pytest).

Tests:
  - POST /perform: getState / component-specific commands
  testIDs:
    - "scene.demo.textInput"
    - "scene.demo.onOffSwitch"
    - "scene.demo.rangeSlider"

Prerequisite: DemoApp must be running on iOS Simulator with
              TestableServer listening on localhost:8888.
"""

import pytest
import requests

TEXT_INPUT_TEST_ID = "scene.demo.textInput"
ON_OFF_SWITCH_TEST_ID = "scene.demo.onOffSwitch"
RANGE_SLIDER_TEST_ID = "scene.demo.rangeSlider"


# ========== Helpers ==========

def assert_text_input_state(state: dict):
    """Verify that TextInput describedState contains the expected keys."""
    expected_keys = {"text", "placeholder", "isEnabled"}
    assert set(state.keys()) == expected_keys, (
        f"TextInput: Expected keys {expected_keys}, got {set(state.keys())}"
    )


def assert_on_off_switch_state(state: dict):
    """Verify that OnOffSwitch describedState contains the expected keys."""
    expected_keys = {"isOn", "label", "isEnabled"}
    assert set(state.keys()) == expected_keys, (
        f"OnOffSwitch: Expected keys {expected_keys}, got {set(state.keys())}"
    )


def assert_range_slider_state(state: dict):
    """Verify that RangeSlider describedState contains the expected keys."""
    expected_keys = {"value", "minValue", "maxValue", "step"}
    assert set(state.keys()) == expected_keys, (
        f"RangeSlider: Expected keys {expected_keys}, got {set(state.keys())}"
    )


# ========== Fixtures ==========

@pytest.fixture
def text_input_perform(base_url):
    """POST /perform helper for the TextInput component."""
    def _perform(command_name, parameters=None):
        payload = {
            "testID": TEXT_INPUT_TEST_ID,
            "commandName": command_name,
            "parameters": parameters,
        }
        resp = requests.post(f"{base_url}/perform", json=payload, timeout=10)
        if not resp.ok:
            print(
                f"\n[HTTP ERROR] {resp.status_code} on text_input_perform('{command_name}'): {resp.text}",
                flush=True,
            )
        resp.raise_for_status()
        return resp.json()

    return _perform


@pytest.fixture
def on_off_switch_perform(base_url):
    """POST /perform helper for the OnOffSwitch component."""
    def _perform(command_name, parameters=None):
        payload = {
            "testID": ON_OFF_SWITCH_TEST_ID,
            "commandName": command_name,
            "parameters": parameters,
        }
        resp = requests.post(f"{base_url}/perform", json=payload, timeout=10)
        if not resp.ok:
            print(
                f"\n[HTTP ERROR] {resp.status_code} on on_off_switch_perform('{command_name}'): {resp.text}",
                flush=True,
            )
        resp.raise_for_status()
        return resp.json()

    return _perform


@pytest.fixture
def range_slider_perform(base_url):
    """POST /perform helper for the RangeSlider component."""
    def _perform(command_name, parameters=None):
        payload = {
            "testID": RANGE_SLIDER_TEST_ID,
            "commandName": command_name,
            "parameters": parameters,
        }
        resp = requests.post(f"{base_url}/perform", json=payload, timeout=10)
        if not resp.ok:
            print(
                f"\n[HTTP ERROR] {resp.status_code} on range_slider_perform('{command_name}'): {resp.text}",
                flush=True,
            )
        resp.raise_for_status()
        return resp.json()

    return _perform


# ========== TextInput Tests ==========

class TestTextInput:
    """IPC tests for the TextInput component."""

    def test_text_input_get_state(self, text_input_perform):
        """getState for testID="scene.demo.textInput" responds correctly."""
        state = text_input_perform("getState")
        assert_text_input_state(state)
        # Verify initial value types
        assert isinstance(state.get("text"), str)
        assert isinstance(state.get("placeholder"), str)
        assert isinstance(state.get("isEnabled"), bool)

    def test_text_input_clear(self, text_input_perform):
        """TextInput.clear command can be executed."""
        # Get initial state
        initial_state = text_input_perform("getState")
        assert_text_input_state(initial_state)

        # Execute clear
        cleared_state = text_input_perform("clear")
        assert_text_input_state(cleared_state)
        # Verify: text is empty
        assert cleared_state.get("text") == "", (
            f"Expected text to be cleared, got: {cleared_state.get('text')}"
        )


# ========== OnOffSwitch Tests ==========

class TestOnOffSwitch:
    """IPC tests for the OnOffSwitch component."""

    def test_on_off_switch_get_state(self, on_off_switch_perform):
        """getState for testID="scene.demo.onOffSwitch" responds correctly."""
        state = on_off_switch_perform("getState")
        assert_on_off_switch_state(state)
        # Verify initial value types
        assert isinstance(state.get("isOn"), bool)
        assert isinstance(state.get("label"), str)
        assert isinstance(state.get("isEnabled"), bool)

    def test_on_off_switch_toggle(self, on_off_switch_perform):
        """OnOffSwitch.toggle command can be executed."""
        # Get initial state
        initial_state = on_off_switch_perform("getState")
        assert_on_off_switch_state(initial_state)
        initial_value = initial_state.get("isOn")

        # Execute toggle
        toggled_state = on_off_switch_perform("toggle")
        assert_on_off_switch_state(toggled_state)
        # Verify: isOn is flipped
        assert toggled_state.get("isOn") != initial_value, (
            f"Expected isOn to toggle, got same value: {toggled_state.get('isOn')}"
        )


# ========== RangeSlider Tests ==========

class TestRangeSlider:
    """IPC tests for the RangeSlider component."""

    def test_range_slider_get_state(self, range_slider_perform):
        """getState for testID="scene.demo.rangeSlider" responds correctly."""
        state = range_slider_perform("getState")
        assert_range_slider_state(state)
        # Verify initial value types
        assert isinstance(state.get("value"), (int, float))
        assert isinstance(state.get("minValue"), (int, float))
        assert isinstance(state.get("maxValue"), (int, float))

    def test_range_slider_reset(self, range_slider_perform):
        """RangeSlider.reset command can be executed."""
        # Get initial state
        initial_state = range_slider_perform("getState")
        assert_range_slider_state(initial_state)
        initial_value = initial_state.get("value")

        # Execute reset
        reset_state = range_slider_perform("reset")
        assert_range_slider_state(reset_state)
        # Verify: value is reset to midpoint ((maxValue - minValue)/2 + minValue)
        expected_reset_value = (reset_state.get("maxValue") - reset_state.get("minValue")) / 2 + reset_state.get("minValue")
        assert reset_state.get("value") == expected_reset_value, (
            f"Expected value to reset to midpoint {expected_reset_value}, got: {reset_state.get('value')}"
        )
