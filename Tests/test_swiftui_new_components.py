"""
新規コンポーネント（TextInput / OnOffSwitch / RangeSlider）の IPC 統合テスト (pytest)

テスト対象:
  - POST /perform: getState / 各コマンド
  testID:
    - "scene.demo.textInput"
    - "scene.demo.onOffSwitch"
    - "scene.demo.rangeSlider"

前提: DemoApp が iOS Simulator 上で起動済みで、
      localhost:8888 で TestableServer がリッスンしている。
"""

import pytest
import requests

TEXT_INPUT_TEST_ID = "scene.demo.textInput"
ON_OFF_SWITCH_TEST_ID = "scene.demo.onOffSwitch"
RANGE_SLIDER_TEST_ID = "scene.demo.rangeSlider"


# ========== ヘルパー ==========

def assert_text_input_state(state: dict):
    """TextInput の describedState が期待するキーを満たすことを検証する"""
    expected_keys = {"text", "placeholder", "isEnabled"}
    assert set(state.keys()) == expected_keys, (
        f"TextInput: Expected keys {expected_keys}, got {set(state.keys())}"
    )


def assert_on_off_switch_state(state: dict):
    """OnOffSwitch の describedState が期待するキーを満たすことを検証する"""
    expected_keys = {"isOn", "label", "isEnabled"}
    assert set(state.keys()) == expected_keys, (
        f"OnOffSwitch: Expected keys {expected_keys}, got {set(state.keys())}"
    )


def assert_range_slider_state(state: dict):
    """RangeSlider の describedState が期待するキーを満たすことを検証する"""
    expected_keys = {"value", "minValue", "maxValue"}
    assert set(state.keys()) == expected_keys, (
        f"RangeSlider: Expected keys {expected_keys}, got {set(state.keys())}"
    )


# ========== Fixtures ==========

@pytest.fixture
def text_input_perform(base_url):
    """TextInput コンポーネント向け POST /perform ヘルパー"""
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
    """OnOffSwitch コンポーネント向け POST /perform ヘルパー"""
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
    """RangeSlider コンポーネント向け POST /perform ヘルパー"""
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


# ========== TextInput テスト ==========

class TestTextInput:
    """TextInput コンポーネントの IPC テスト"""

    def test_text_input_get_state(self, text_input_perform):
        """testID="scene.demo.textInput" の getState が応答する"""
        state = text_input_perform("getState")
        assert_text_input_state(state)
        # 初期値確認
        assert isinstance(state.get("text"), str)
        assert isinstance(state.get("placeholder"), str)
        assert isinstance(state.get("isEnabled"), bool)

    def test_text_input_clear(self, text_input_perform):
        """TextInput.clear コマンドが実行できる"""
        # 初期状態を取得
        initial_state = text_input_perform("getState")
        assert_text_input_state(initial_state)

        # clear を実行
        cleared_state = text_input_perform("clear")
        assert_text_input_state(cleared_state)
        # 確認: text が空になっている
        assert cleared_state.get("text") == "", (
            f"Expected text to be cleared, got: {cleared_state.get('text')}"
        )


# ========== OnOffSwitch テスト ==========

class TestOnOffSwitch:
    """OnOffSwitch コンポーネントの IPC テスト"""

    def test_on_off_switch_get_state(self, on_off_switch_perform):
        """testID="scene.demo.onOffSwitch" の getState が応答する"""
        state = on_off_switch_perform("getState")
        assert_on_off_switch_state(state)
        # 初期値確認
        assert isinstance(state.get("isOn"), bool)
        assert isinstance(state.get("label"), str)
        assert isinstance(state.get("isEnabled"), bool)

    def test_on_off_switch_toggle(self, on_off_switch_perform):
        """OnOffSwitch.toggle コマンドが実行できる"""
        # 初期状態を取得
        initial_state = on_off_switch_perform("getState")
        assert_on_off_switch_state(initial_state)
        initial_value = initial_state.get("isOn")

        # toggle を実行
        toggled_state = on_off_switch_perform("toggle")
        assert_on_off_switch_state(toggled_state)
        # 確認: isOn が反転している
        assert toggled_state.get("isOn") != initial_value, (
            f"Expected isOn to toggle, got same value: {toggled_state.get('isOn')}"
        )


# ========== RangeSlider テスト ==========

class TestRangeSlider:
    """RangeSlider コンポーネントの IPC テスト"""

    def test_range_slider_get_state(self, range_slider_perform):
        """testID="scene.demo.rangeSlider" の getState が応答する"""
        state = range_slider_perform("getState")
        assert_range_slider_state(state)
        # 初期値確認
        assert isinstance(state.get("value"), (int, float))
        assert isinstance(state.get("minValue"), (int, float))
        assert isinstance(state.get("maxValue"), (int, float))

    def test_range_slider_reset(self, range_slider_perform):
        """RangeSlider.reset コマンドが実行できる"""
        # 初期状態を取得
        initial_state = range_slider_perform("getState")
        assert_range_slider_state(initial_state)
        initial_value = initial_state.get("value")

        # reset を実行
        reset_state = range_slider_perform("reset")
        assert_range_slider_state(reset_state)
        # 確認: value がデフォルト値に戻っている（通常は minValue）
        assert reset_state.get("value") == reset_state.get("minValue"), (
            f"Expected value to reset to minValue, got: {reset_state.get('value')}"
        )
