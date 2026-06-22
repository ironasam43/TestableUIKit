"""
Counter コンポーネントの IPC 統合テスト (pytest)

テスト対象:
  - POST /perform: getState / increment / decrement / reset / setProperty
  testID: "scene.demo.counter"

前提: DemoApp が iOS Simulator 上で起動済みで、
      localhost:8888 で TestableServer がリッスンしている。
このファイルの autouse fixture により、各テスト前に Counter を初期状態にリセットする。
"""

import pytest
import requests

COUNTER_TEST_ID = "scene.demo.counter"
EXPECTED_KEYS = {"count", "isEnabled"}


# ========== ヘルパー ==========

def assert_counter_state(state: dict):
    """describedState が 2キー固定スキーマを満たすことを検証する"""
    assert set(state.keys()) == EXPECTED_KEYS, (
        f"Expected keys {EXPECTED_KEYS}, got {set(state.keys())}"
    )


# ========== Fixtures ==========

@pytest.fixture
def counter_perform(base_url):
    """
    Counter コンポーネント向け POST /perform ヘルパー関数を返す fixture。

    使い方:
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
    各テストの前に Counter を初期状態にリセットする（autouse）。

    初期状態: count: 0, isEnabled: true
    """
    counter_perform("reset")
    counter_perform("setProperty", {"key": "isEnabled", "value": True})
    yield


# ========== getState ==========

class TestCounterGetState:
    def test_initial_state_keys(self, counter_perform):
        """getState は count / isEnabled の2キーを返す"""
        state = counter_perform("getState")
        assert_counter_state(state)

    def test_initial_count_is_zero(self, counter_perform):
        """初期値 count=0"""
        state = counter_perform("getState")
        assert state["count"] == 0

    def test_initial_is_enabled_true(self, counter_perform):
        """初期値 isEnabled=true"""
        state = counter_perform("getState")
        assert state["isEnabled"] is True


# ========== increment ==========

class TestCounterIncrement:
    def test_increment_increases_count_by_one(self, counter_perform):
        """increment で count が 1 増加する"""
        state = counter_perform("increment")
        assert_counter_state(state)
        assert state["count"] == 1

    def test_increment_twice(self, counter_perform):
        """2回 increment すると count=2"""
        counter_perform("increment")
        state = counter_perform("increment")
        assert state["count"] == 2

    def test_increment_state_transition(self, counter_perform):
        """getState → increment → getState の状態遷移を検証"""
        before = counter_perform("getState")
        assert before["count"] == 0
        counter_perform("increment")
        after = counter_perform("getState")
        assert after["count"] == 1

    def test_increment_disabled_is_noop(self, counter_perform):
        """isEnabled=false のとき increment は no-op"""
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        state = counter_perform("increment")
        assert_counter_state(state)
        assert state["count"] == 0


# ========== decrement ==========

class TestCounterDecrement:
    def test_decrement_decreases_count_by_one(self, counter_perform):
        """decrement で count が 1 減少する"""
        counter_perform("increment")   # count = 1
        state = counter_perform("decrement")  # count = 0
        assert_counter_state(state)
        assert state["count"] == 0

    def test_decrement_below_zero(self, counter_perform):
        """count は負の値になれる（下限なし）"""
        state = counter_perform("decrement")
        assert state["count"] == -1

    def test_decrement_state_transition(self, counter_perform):
        """increment × 2 → decrement の状態遷移を検証"""
        counter_perform("increment")
        counter_perform("increment")   # count = 2
        state = counter_perform("decrement")  # count = 1
        assert state["count"] == 1

    def test_decrement_disabled_is_noop(self, counter_perform):
        """isEnabled=false のとき decrement は no-op"""
        counter_perform("increment")   # count = 1
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        state = counter_perform("decrement")
        assert state["count"] == 1  # no-op


# ========== reset ==========

class TestCounterReset:
    def test_reset_sets_count_to_zero(self, counter_perform):
        """reset で count が 0 に戻る"""
        counter_perform("increment")
        counter_perform("increment")
        state = counter_perform("reset")
        assert_counter_state(state)
        assert state["count"] == 0

    def test_reset_from_negative(self, counter_perform):
        """負の値から reset しても count=0"""
        counter_perform("decrement")
        state = counter_perform("reset")
        assert state["count"] == 0

    def test_reset_persists_via_getstate(self, counter_perform):
        """reset 後に getState しても count=0 を維持"""
        counter_perform("increment")
        counter_perform("reset")
        state = counter_perform("getState")
        assert state["count"] == 0


# ========== setProperty ==========

class TestCounterSetProperty:
    def test_set_property_count(self, counter_perform):
        """setProperty で count を直接設定できる"""
        state = counter_perform("setProperty", {"key": "count", "value": 42})
        assert_counter_state(state)
        assert state["count"] == 42

    def test_set_property_is_enabled_false(self, counter_perform):
        """setProperty で isEnabled を false に設定できる"""
        state = counter_perform("setProperty", {"key": "isEnabled", "value": False})
        assert_counter_state(state)
        assert state["isEnabled"] is False

    def test_set_property_is_enabled_restore(self, counter_perform):
        """isEnabled=false → true への復帰"""
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        state = counter_perform("setProperty", {"key": "isEnabled", "value": True})
        assert state["isEnabled"] is True

    def test_set_property_count_persists(self, counter_perform):
        """setProperty で設定した count が getState でも維持される"""
        counter_perform("setProperty", {"key": "count", "value": 99})
        state = counter_perform("getState")
        assert state["count"] == 99


# ========== 状態遷移シナリオ ==========

class TestCounterStateTransitions:
    def test_enable_disable_enable_sequence(self, counter_perform):
        """enable → disable → enable のトグルシナリオ"""
        # isEnabled=true（初期）
        assert counter_perform("getState")["isEnabled"] is True
        # disable
        counter_perform("setProperty", {"key": "isEnabled", "value": False})
        assert counter_perform("getState")["isEnabled"] is False
        # re-enable
        counter_perform("setProperty", {"key": "isEnabled", "value": True})
        assert counter_perform("getState")["isEnabled"] is True

    def test_increment_reset_increment_scenario(self, counter_perform):
        """increment × 3 → reset → increment のシナリオ"""
        counter_perform("increment")
        counter_perform("increment")
        counter_perform("increment")
        assert counter_perform("getState")["count"] == 3
        counter_perform("reset")
        assert counter_perform("getState")["count"] == 0
        state = counter_perform("increment")
        assert state["count"] == 1

    def test_mixed_increment_decrement(self, counter_perform):
        """increment × 5 → decrement × 2 の正味 count=3"""
        for _ in range(5):
            counter_perform("increment")
        for _ in range(2):
            counter_perform("decrement")
        state = counter_perform("getState")
        assert state["count"] == 3
