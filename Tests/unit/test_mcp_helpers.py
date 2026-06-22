"""
L1 テスト: TestableUIKit MCP Server の純粋ヘルパー関数

Simulator / DemoApp / HTTP 接続不要。mcp パッケージも不要。
mcp_server/ipc_helpers.py の全関数を網羅的に検証する。
"""

import os
import sys

# mcp_server/ を import パスに追加（外部依存なしのヘルパーのみ対象）
# Tests/unit/ からプロジェクトルートの mcp_server/ へは2段上に上る
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "mcp_server"))

from ipc_helpers import (
    DEFAULT_IPC_HOST,
    DEFAULT_IPC_PORT,
    build_base_url,
    build_perform_payload,
    build_simctl_screenshot_command,
    passthrough_state,
)


# ================================================================
# build_base_url
# ================================================================


class TestBuildBaseUrl:
    def test_default_url(self):
        """デフォルト値で localhost:8888 が返る"""
        assert build_base_url() == "http://localhost:8888"

    def test_default_host_constant(self):
        """DEFAULT_IPC_HOST が "localhost" である"""
        assert DEFAULT_IPC_HOST == "localhost"

    def test_default_port_constant(self):
        """DEFAULT_IPC_PORT が 8888 である"""
        assert DEFAULT_IPC_PORT == 8888

    def test_custom_port(self):
        """カスタムポートを指定できる"""
        assert build_base_url(port=9000) == "http://localhost:9000"

    def test_custom_host(self):
        """カスタムホストを指定できる"""
        assert build_base_url(host="192.168.1.1") == "http://192.168.1.1:8888"

    def test_custom_host_and_port(self):
        """ホストとポートを両方指定できる"""
        assert build_base_url(host="10.0.0.1", port=9999) == "http://10.0.0.1:9999"

    def test_no_trailing_slash(self):
        """末尾にスラッシュが付かない"""
        url = build_base_url()
        assert not url.endswith("/")

    def test_returns_string(self):
        """str を返す"""
        assert isinstance(build_base_url(), str)


# ================================================================
# build_perform_payload
# ================================================================


class TestBuildPerformPayload:
    def test_minimal_getstate(self):
        """getState（parameters なし）の payload を構築できる"""
        payload = build_perform_payload("scene.auth.loginButton", "getState")
        assert payload["testID"] == "scene.auth.loginButton"
        assert payload["commandName"] == "getState"
        assert payload["parameters"] is None

    def test_tap_command(self):
        """tap コマンドの payload を構築できる"""
        payload = build_perform_payload("counter", "tap")
        assert payload["testID"] == "counter"
        assert payload["commandName"] == "tap"
        assert payload["parameters"] is None

    def test_set_property_with_params(self):
        """setProperty + params dict の payload を構築できる"""
        params = {"key": "isEnabled", "value": False}
        payload = build_perform_payload("loginButton", "setProperty", params)
        assert payload["testID"] == "loginButton"
        assert payload["commandName"] == "setProperty"
        assert payload["parameters"] == params

    def test_set_enabled_with_params(self):
        """setEnabled + params dict の payload を構築できる"""
        params = {"value": True}
        payload = build_perform_payload("switch1", "setEnabled", params)
        assert payload["parameters"] == params

    def test_payload_keys_are_exactly_three(self):
        """payload のキーは testID / commandName / parameters の3つのみ"""
        payload = build_perform_payload("foo", "bar")
        assert set(payload.keys()) == {"testID", "commandName", "parameters"}

    def test_payload_returns_dict(self):
        """dict を返す"""
        payload = build_perform_payload("x", "y")
        assert isinstance(payload, dict)

    def test_explicit_none_parameters(self):
        """parameters=None を明示指定しても同じ結果"""
        a = build_perform_payload("id1", "cmd1")
        b = build_perform_payload("id1", "cmd1", None)
        assert a == b

    def test_parameters_is_passed_through(self):
        """parameters は加工せずそのまま格納される"""
        params = {"nested": {"key": "value"}, "list": [1, 2, 3]}
        payload = build_perform_payload("id", "cmd", params)
        assert payload["parameters"] is params


# ================================================================
# passthrough_state
# ================================================================


class TestPassthroughState:
    def test_login_button_state(self):
        """LoginButton の describedState（5キー）を加工せず返す"""
        state = {
            "isEnabled": True,
            "title": "Log In",
            "isHidden": False,
            "alpha": 1.0,
            "backgroundColor": "systemBlue",
        }
        assert passthrough_state(state) == state

    def test_counter_state(self):
        """Counter の describedState を加工せず返す"""
        state = {"count": 5, "isEnabled": True}
        assert passthrough_state(state) == state

    def test_range_slider_state(self):
        """RangeSlider の describedState（4キー）を加工せず返す"""
        state = {"value": 50.0, "minValue": 0.0, "maxValue": 100.0, "step": 1.0}
        assert passthrough_state(state) == state

    def test_empty_dict(self):
        """空 dict はそのまま返る"""
        assert passthrough_state({}) == {}

    def test_same_object_identity(self):
        """同一オブジェクトを返す（コピーしない）"""
        state = {"key": "value"}
        assert passthrough_state(state) is state

    def test_arbitrary_keys(self):
        """将来追加される不明なキーも加工せず返す（前方互換）"""
        state = {"future_key1": [1, 2], "future_key2": {"nested": True}}
        assert passthrough_state(state) == state


# ================================================================
# build_simctl_screenshot_command
# ================================================================


class TestBuildSimctlScreenshotCommand:
    def test_exact_command(self):
        """期待通りの simctl コマンドリストが返る"""
        cmd = build_simctl_screenshot_command("/tmp/screenshot.png")
        assert cmd == ["xcrun", "simctl", "io", "booted", "screenshot", "/tmp/screenshot.png"]

    def test_custom_path(self):
        """カスタムパスがコマンド末尾に入る"""
        cmd = build_simctl_screenshot_command("/custom/path/image.png")
        assert cmd[-1] == "/custom/path/image.png"

    def test_returns_list(self):
        """list を返す"""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert isinstance(cmd, list)

    def test_xcrun_is_first(self):
        """xcrun がコマンドの先頭"""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert cmd[0] == "xcrun"

    def test_simctl_is_second(self):
        """simctl が2番目"""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert cmd[1] == "simctl"

    def test_screenshot_in_command(self):
        """'screenshot' キーワードがコマンドに含まれる"""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert "screenshot" in cmd

    def test_booted_in_command(self):
        """'booted' がコマンドに含まれる"""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert "booted" in cmd
