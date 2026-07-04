"""
L1 tests: Pure helper functions for TestableUIKit MCP Server.

No Simulator / DemoApp / HTTP connection required. No mcp package needed.
Exhaustively tests all functions in mcp_server/ipc_helpers.py.
"""

import os
import sys

# Add mcp_server/ to import path (only pure helper functions are targeted, no external deps)
# Tests/unit/ is two levels up from the project root's mcp_server/
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
        """Returns localhost:8888 with default values."""
        assert build_base_url() == "http://localhost:8888"

    def test_default_host_constant(self):
        """DEFAULT_IPC_HOST is "localhost"."""
        assert DEFAULT_IPC_HOST == "localhost"

    def test_default_port_constant(self):
        """DEFAULT_IPC_PORT is 8888."""
        assert DEFAULT_IPC_PORT == 8888

    def test_custom_port(self):
        """A custom port can be specified."""
        assert build_base_url(port=9000) == "http://localhost:9000"

    def test_custom_host(self):
        """A custom host can be specified."""
        assert build_base_url(host="192.168.1.1") == "http://192.168.1.1:8888"

    def test_custom_host_and_port(self):
        """Both host and port can be specified."""
        assert build_base_url(host="10.0.0.1", port=9999) == "http://10.0.0.1:9999"

    def test_no_trailing_slash(self):
        """No trailing slash."""
        url = build_base_url()
        assert not url.endswith("/")

    def test_returns_string(self):
        """Returns a str."""
        assert isinstance(build_base_url(), str)


# ================================================================
# build_perform_payload
# ================================================================


class TestBuildPerformPayload:
    def test_minimal_getstate(self):
        """Can build a getState (no parameters) payload."""
        payload = build_perform_payload("scene.auth.loginButton", "getState")
        assert payload["testID"] == "scene.auth.loginButton"
        assert payload["commandName"] == "getState"
        assert payload["parameters"] is None

    def test_tap_command(self):
        """Can build a tap command payload."""
        payload = build_perform_payload("counter", "tap")
        assert payload["testID"] == "counter"
        assert payload["commandName"] == "tap"
        assert payload["parameters"] is None

    def test_set_property_with_params(self):
        """Can build a setProperty + params dict payload."""
        params = {"key": "isEnabled", "value": False}
        payload = build_perform_payload("loginButton", "setProperty", params)
        assert payload["testID"] == "loginButton"
        assert payload["commandName"] == "setProperty"
        assert payload["parameters"] == params

    def test_set_enabled_with_params(self):
        """Can build a setEnabled + params dict payload."""
        params = {"value": True}
        payload = build_perform_payload("switch1", "setEnabled", params)
        assert payload["parameters"] == params

    def test_payload_keys_are_exactly_three(self):
        """Payload contains exactly testID / commandName / parameters."""
        payload = build_perform_payload("foo", "bar")
        assert set(payload.keys()) == {"testID", "commandName", "parameters"}

    def test_payload_returns_dict(self):
        """Returns a dict."""
        payload = build_perform_payload("x", "y")
        assert isinstance(payload, dict)

    def test_explicit_none_parameters(self):
        """Explicitly passing parameters=None yields the same result."""
        a = build_perform_payload("id1", "cmd1")
        b = build_perform_payload("id1", "cmd1", None)
        assert a == b

    def test_parameters_is_passed_through(self):
        """parameters is stored as-is without modification."""
        params = {"nested": {"key": "value"}, "list": [1, 2, 3]}
        payload = build_perform_payload("id", "cmd", params)
        assert payload["parameters"] is params


# ================================================================
# passthrough_state
# ================================================================


class TestPassthroughState:
    def test_login_button_state(self):
        """Returns LoginButton describedState (5 keys) unchanged."""
        state = {
            "isEnabled": True,
            "title": "Log In",
            "isHidden": False,
            "alpha": 1.0,
            "backgroundColor": "systemBlue",
        }
        assert passthrough_state(state) == state

    def test_counter_state(self):
        """Returns Counter describedState unchanged."""
        state = {"count": 5, "isEnabled": True}
        assert passthrough_state(state) == state

    def test_range_slider_state(self):
        """Returns RangeSlider describedState (4 keys) unchanged."""
        state = {"value": 50.0, "minValue": 0.0, "maxValue": 100.0, "step": 1.0}
        assert passthrough_state(state) == state

    def test_empty_dict(self):
        """An empty dict is returned as-is."""
        assert passthrough_state({}) == {}

    def test_same_object_identity(self):
        """Returns the same object (no copy)."""
        state = {"key": "value"}
        assert passthrough_state(state) is state

    def test_arbitrary_keys(self):
        """Future unknown keys are also returned unchanged (forward compatible)."""
        state = {"future_key1": [1, 2], "future_key2": {"nested": True}}
        assert passthrough_state(state) == state


# ================================================================
# build_simctl_screenshot_command
# ================================================================


class TestBuildSimctlScreenshotCommand:
    def test_exact_command(self):
        """Returns the expected simctl command list."""
        cmd = build_simctl_screenshot_command("/tmp/screenshot.png")
        assert cmd == ["xcrun", "simctl", "io", "booted", "screenshot", "/tmp/screenshot.png"]

    def test_custom_path(self):
        """Custom path is placed at the end of the command."""
        cmd = build_simctl_screenshot_command("/custom/path/image.png")
        assert cmd[-1] == "/custom/path/image.png"

    def test_returns_list(self):
        """Returns a list."""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert isinstance(cmd, list)

    def test_xcrun_is_first(self):
        """xcrun is the first element."""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert cmd[0] == "xcrun"

    def test_simctl_is_second(self):
        """simctl is the second element."""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert cmd[1] == "simctl"

    def test_screenshot_in_command(self):
        """'screenshot' keyword is present in the command."""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert "screenshot" in cmd

    def test_booted_in_command(self):
        """'booted' is present in the command."""
        cmd = build_simctl_screenshot_command("/tmp/test.png")
        assert "booted" in cmd


# ================================================================
# resolve_ipc_host_port (Design D: LAN IPC env-var resolution)
# ================================================================


class TestResolveIpcHostPort:
    def test_defaults_when_no_env(self):
        """Returns default values (localhost, 8888) when no env vars are set."""
        host, port = resolve_ipc_host_port(env={})
        assert host == "localhost"
        assert port == 8888

    def test_env_host_overrides(self):
        """TESTABLE_IPC_HOST overrides the target host."""
        host, port = resolve_ipc_host_port(env={ENV_IPC_HOST: "192.168.1.100"})
        assert host == "192.168.1.100"
        assert port == 8888

    def test_env_port_overrides(self):
        """TESTABLE_IPC_PORT overrides the target port."""
        host, port = resolve_ipc_host_port(env={ENV_IPC_PORT: "9000"})
        assert host == "localhost"
        assert port == 9000

    def test_env_host_and_port_both_override(self):
        """Both host and port can be overridden together."""
        host, port = resolve_ipc_host_port(
            env={ENV_IPC_HOST: "10.0.0.1", ENV_IPC_PORT: "9999"}
        )
        assert host == "10.0.0.1"
        assert port == 9999

    def test_invalid_port_falls_back_to_default(self):
        """An invalid port string falls back to the default port 8888."""
        host, port = resolve_ipc_host_port(env={ENV_IPC_PORT: "not_a_number"})
        assert port == DEFAULT_IPC_PORT

    def test_returns_tuple(self):
        """Returns a (host, port) tuple."""
        result = resolve_ipc_host_port(env={})
        assert isinstance(result, tuple)
        assert len(result) == 2

    def test_host_is_str(self):
        """host is returned as str."""
        host, _ = resolve_ipc_host_port(env={})
        assert isinstance(host, str)

    def test_port_is_int(self):
        """port is returned as int."""
        _, port = resolve_ipc_host_port(env={})
        assert isinstance(port, int)

    def test_env_constant_host_name(self):
        """ENV_IPC_HOST constant has the correct string value."""
        assert ENV_IPC_HOST == "TESTABLE_IPC_HOST"

    def test_env_constant_port_name(self):
        """ENV_IPC_PORT constant has the correct string value."""
        assert ENV_IPC_PORT == "TESTABLE_IPC_PORT"

    def test_default_host_matches_constant(self):
        """Default host matches DEFAULT_IPC_HOST."""
        host, _ = resolve_ipc_host_port(env={})
        assert host == DEFAULT_IPC_HOST

    def test_default_port_matches_constant(self):
        """Default port matches DEFAULT_IPC_PORT."""
        _, port = resolve_ipc_host_port(env={})
        assert port == DEFAULT_IPC_PORT

    def test_build_base_url_with_resolved_values(self):
        """resolve_ipc_host_port result can be passed to build_base_url to assemble a URL."""
        env = {ENV_IPC_HOST: "192.168.1.50", ENV_IPC_PORT: "9001"}
        host, port = resolve_ipc_host_port(env=env)
        url = build_base_url(host=host, port=port)
        assert url == "http://192.168.1.50:9001"


# ================================================================
# build_screenshot_url (Step 4 addition)
# ================================================================


class TestBuildScreenshotUrl:
    def test_default_url(self):
        """Returns localhost:8888/screenshot with default values."""
        assert build_screenshot_url() == "http://localhost:8888/screenshot"

    def test_custom_host(self):
        """A custom host can be specified."""
        assert build_screenshot_url(host="192.168.0.181") == "http://192.168.0.181:8888/screenshot"

    def test_custom_port(self):
        """A custom port can be specified."""
        assert build_screenshot_url(port=9000) == "http://localhost:9000/screenshot"

    def test_custom_host_and_port(self):
        """Both host and port can be specified."""
        assert build_screenshot_url(host="10.0.0.1", port=9999) == "http://10.0.0.1:9999/screenshot"

    def test_ends_with_screenshot(self):
        """URL ends with /screenshot path."""
        url = build_screenshot_url()
        assert url.endswith("/screenshot")

    def test_returns_string(self):
        """Returns a str."""
        assert isinstance(build_screenshot_url(), str)

    def test_no_trailing_slash(self):
        """No trailing slash after /screenshot."""
        url = build_screenshot_url()
        assert not url.endswith("/screenshot/")

    def test_consistent_with_base_url(self):
        """Matches build_base_url result with /screenshot appended."""
        host = "192.168.1.1"
        port = 9001
        expected = f"{build_base_url(host=host, port=port)}/screenshot"
        assert build_screenshot_url(host=host, port=port) == expected


# ================================================================
# is_loopback_host (Step 4 addition)
# ================================================================


class TestIsLoopbackHost:
    def test_localhost_is_loopback(self):
        """"localhost" is loopback."""
        assert is_loopback_host("localhost") is True

    def test_127_0_0_1_is_loopback(self):
        """"127.0.0.1" is loopback."""
        assert is_loopback_host("127.0.0.1") is True

    def test_ipv6_loopback(self):
        """"::1" is loopback."""
        assert is_loopback_host("::1") is True

    def test_lan_ip_is_not_loopback(self):
        """LAN IP (192.168.x.x) is not loopback."""
        assert is_loopback_host("192.168.0.181") is False

    def test_lan_ip_10_is_not_loopback(self):
        """LAN IP (10.x.x.x) is not loopback."""
        assert is_loopback_host("10.0.0.1") is False

    def test_empty_string_is_not_loopback(self):
        """Empty string is not loopback."""
        assert is_loopback_host("") is False

    def test_arbitrary_host_is_not_loopback(self):
        """Arbitrary hostname is not loopback."""
        assert is_loopback_host("example.com") is False

    def test_returns_bool(self):
        """Returns a bool."""
        result = is_loopback_host("localhost")
        assert isinstance(result, bool)

    def test_loopback_fallback_logic(self):
        """Only loopback is a valid simctl fallback target (fallback logic check)."""
        # Real device IP → no fallback
        assert is_loopback_host("192.168.0.181") is False
        # Simulator (loopback) → fallback possible
        assert is_loopback_host("localhost") is True
        assert is_loopback_host("127.0.0.1") is True
