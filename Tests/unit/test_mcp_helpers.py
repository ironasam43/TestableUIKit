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
    ENV_IPC_HOST,
    ENV_IPC_PORT,
    build_base_url,
    build_perform_payload,
    build_screenshot_url,
    build_simctl_screenshot_command,
    is_loopback_host,
    passthrough_state,
    resolve_ipc_host_port,
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


# ================================================================
# resolve_ipc_host_port (Design D: LAN 越し IPC 環境変数解決)
# ================================================================


class TestResolveIpcHostPort:
    def test_defaults_when_no_env(self):
        """環境変数なしで既定値 (localhost, 8888) が返る"""
        host, port = resolve_ipc_host_port(env={})
        assert host == "localhost"
        assert port == 8888

    def test_env_host_overrides(self):
        """TESTABLE_IPC_HOST で接続先ホストを上書きできる"""
        host, port = resolve_ipc_host_port(env={ENV_IPC_HOST: "192.168.1.100"})
        assert host == "192.168.1.100"
        assert port == 8888

    def test_env_port_overrides(self):
        """TESTABLE_IPC_PORT で接続先ポートを上書きできる"""
        host, port = resolve_ipc_host_port(env={ENV_IPC_PORT: "9000"})
        assert host == "localhost"
        assert port == 9000

    def test_env_host_and_port_both_override(self):
        """ホストとポートを両方上書きできる"""
        host, port = resolve_ipc_host_port(
            env={ENV_IPC_HOST: "10.0.0.1", ENV_IPC_PORT: "9999"}
        )
        assert host == "10.0.0.1"
        assert port == 9999

    def test_invalid_port_falls_back_to_default(self):
        """不正なポート文字列は既定ポート 8888 にフォールバックする"""
        host, port = resolve_ipc_host_port(env={ENV_IPC_PORT: "not_a_number"})
        assert port == DEFAULT_IPC_PORT

    def test_returns_tuple(self):
        """(host, port) のタプルを返す"""
        result = resolve_ipc_host_port(env={})
        assert isinstance(result, tuple)
        assert len(result) == 2

    def test_host_is_str(self):
        """host は str を返す"""
        host, _ = resolve_ipc_host_port(env={})
        assert isinstance(host, str)

    def test_port_is_int(self):
        """port は int を返す"""
        _, port = resolve_ipc_host_port(env={})
        assert isinstance(port, int)

    def test_env_constant_host_name(self):
        """ENV_IPC_HOST 定数が正しい文字列"""
        assert ENV_IPC_HOST == "TESTABLE_IPC_HOST"

    def test_env_constant_port_name(self):
        """ENV_IPC_PORT 定数が正しい文字列"""
        assert ENV_IPC_PORT == "TESTABLE_IPC_PORT"

    def test_default_host_matches_constant(self):
        """デフォルト host が DEFAULT_IPC_HOST と一致する"""
        host, _ = resolve_ipc_host_port(env={})
        assert host == DEFAULT_IPC_HOST

    def test_default_port_matches_constant(self):
        """デフォルト port が DEFAULT_IPC_PORT と一致する"""
        _, port = resolve_ipc_host_port(env={})
        assert port == DEFAULT_IPC_PORT

    def test_build_base_url_with_resolved_values(self):
        """resolve_ipc_host_port の結果を build_base_url に渡して URL が組み立てられる"""
        env = {ENV_IPC_HOST: "192.168.1.50", ENV_IPC_PORT: "9001"}
        host, port = resolve_ipc_host_port(env=env)
        url = build_base_url(host=host, port=port)
        assert url == "http://192.168.1.50:9001"


# ================================================================
# build_screenshot_url (Step 4 追加)
# ================================================================


class TestBuildScreenshotUrl:
    def test_default_url(self):
        """デフォルト値で localhost:8888/screenshot が返る"""
        assert build_screenshot_url() == "http://localhost:8888/screenshot"

    def test_custom_host(self):
        """カスタムホストを指定できる"""
        assert build_screenshot_url(host="192.168.0.181") == "http://192.168.0.181:8888/screenshot"

    def test_custom_port(self):
        """カスタムポートを指定できる"""
        assert build_screenshot_url(port=9000) == "http://localhost:9000/screenshot"

    def test_custom_host_and_port(self):
        """ホストとポートを両方指定できる"""
        assert build_screenshot_url(host="10.0.0.1", port=9999) == "http://10.0.0.1:9999/screenshot"

    def test_ends_with_screenshot(self):
        """/screenshot パスで終わる"""
        url = build_screenshot_url()
        assert url.endswith("/screenshot")

    def test_returns_string(self):
        """str を返す"""
        assert isinstance(build_screenshot_url(), str)

    def test_no_trailing_slash(self):
        """/screenshot の後にスラッシュがない"""
        url = build_screenshot_url()
        assert not url.endswith("/screenshot/")

    def test_consistent_with_base_url(self):
        """build_base_url の結果に /screenshot を足したものと一致する"""
        host = "192.168.1.1"
        port = 9001
        expected = f"{build_base_url(host=host, port=port)}/screenshot"
        assert build_screenshot_url(host=host, port=port) == expected


# ================================================================
# is_loopback_host (Step 4 追加)
# ================================================================


class TestIsLoopbackHost:
    def test_localhost_is_loopback(self):
        """"localhost" はループバック"""
        assert is_loopback_host("localhost") is True

    def test_127_0_0_1_is_loopback(self):
        """"127.0.0.1" はループバック"""
        assert is_loopback_host("127.0.0.1") is True

    def test_ipv6_loopback(self):
        """"::1" はループバック"""
        assert is_loopback_host("::1") is True

    def test_lan_ip_is_not_loopback(self):
        """LAN IP（192.168.x.x）はループバックでない"""
        assert is_loopback_host("192.168.0.181") is False

    def test_lan_ip_10_is_not_loopback(self):
        """LAN IP（10.x.x.x）はループバックでない"""
        assert is_loopback_host("10.0.0.1") is False

    def test_empty_string_is_not_loopback(self):
        """空文字列はループバックでない"""
        assert is_loopback_host("") is False

    def test_arbitrary_host_is_not_loopback(self):
        """任意のホスト名はループバックでない"""
        assert is_loopback_host("example.com") is False

    def test_returns_bool(self):
        """bool を返す"""
        result = is_loopback_host("localhost")
        assert isinstance(result, bool)

    def test_loopback_fallback_logic(self):
        """loopback のみ simctl フォールバック対象になる（フォールバック判定ロジック検証）"""
        # 実機 IP → フォールバック不可
        assert is_loopback_host("192.168.0.181") is False
        # Simulator（loopback）→ フォールバック可
        assert is_loopback_host("localhost") is True
        assert is_loopback_host("127.0.0.1") is True
