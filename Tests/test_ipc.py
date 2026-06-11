"""
TestableUIKit IPC integration tests (pytest).

テスト対象:
  - GET /ping
  - POST /perform: getState / tap（有効・無効 no-op）/ setProperty（isEnabled / title）

前提: DemoApp が iOS Simulator 上で起動済みで、
      localhost:8888 で TestableServer がリッスンしている。
conftest.py の autouse fixture により、各テスト前に LoginButton を初期状態にリセットする。
"""

import requests


# ========== ヘルパー ==========

EXPECTED_KEYS = {"isEnabled", "title", "isHidden", "alpha", "backgroundColor"}


def assert_described_state(state: dict):
    """describedState が 5キー固定スキーマを満たすことを検証する"""
    assert set(state.keys()) == EXPECTED_KEYS, (
        f"Expected keys {EXPECTED_KEYS}, got {set(state.keys())}"
    )


# ========== Phase A: Network Connectivity ==========

class TestPing:
    def test_ping_returns_ok(self, base_url):
        """GET /ping は {"status": "ok"} を返す"""
        resp = requests.get(f"{base_url}/ping", timeout=10)
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}


# ========== Phase B: Logic Verification ==========

class TestGetState:
    def test_initial_state_has_five_keys(self, perform):
        """getState は 5キー固定の describedState を返す"""
        state = perform("getState")
        assert_described_state(state)

    def test_initial_state_values(self, perform):
        """getState の初期値が期待値と一致する"""
        state = perform("getState")
        assert state["isEnabled"] is True
        assert state["title"] == "Log In"
        assert state["isHidden"] is False
        assert state["alpha"] == 1.0
        assert state["backgroundColor"] == "systemBlue"


class TestTap:
    def test_tap_enabled_changes_state(self, perform):
        """有効状態で tap すると isEnabled=false, title="Logged In" に変化する"""
        state = perform("tap")
        assert_described_state(state)
        assert state["isEnabled"] is False
        assert state["title"] == "Logged In"

    def test_tap_enabled_unchanged_other_keys(self, perform):
        """tap 後も isHidden / alpha / backgroundColor は変化しない"""
        state = perform("tap")
        assert state["isHidden"] is False
        assert state["alpha"] == 1.0
        assert state["backgroundColor"] == "systemBlue"

    def test_tap_disabled_is_noop(self, perform):
        """無効状態で tap しても状態は変化しない（no-op）"""
        # 無効にする
        perform("setProperty", {"key": "isEnabled", "value": False})

        # tap を実行（no-op のはず）
        state = perform("tap")
        assert_described_state(state)
        assert state["isEnabled"] is False
        assert state["title"] == "Log In"  # tap 前と同じ


class TestSetProperty:
    def test_set_property_is_enabled_false(self, perform):
        """setProperty で isEnabled を false に設定できる"""
        state = perform("setProperty", {"key": "isEnabled", "value": False})
        assert_described_state(state)
        assert state["isEnabled"] is False

    def test_set_property_is_enabled_true(self, perform):
        """setProperty で isEnabled を true に復帰できる"""
        perform("setProperty", {"key": "isEnabled", "value": False})
        state = perform("setProperty", {"key": "isEnabled", "value": True})
        assert_described_state(state)
        assert state["isEnabled"] is True

    def test_set_property_title(self, perform):
        """setProperty で title を変更できる"""
        state = perform("setProperty", {"key": "title", "value": "Testing"})
        assert_described_state(state)
        assert state["title"] == "Testing"

    def test_set_property_title_persists(self, perform):
        """setProperty で変更した title が getState でも維持される"""
        perform("setProperty", {"key": "title", "value": "Persisted"})
        state = perform("getState")
        assert state["title"] == "Persisted"
