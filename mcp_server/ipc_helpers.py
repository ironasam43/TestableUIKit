"""
TestableUIKit MCP Server — Pure helper functions.

HTTP IPC payload construction, response passthrough, and simctl command assembly.
No external dependencies. Testable standalone without Simulator/DemoApp.
"""

import os

DEFAULT_IPC_HOST = "localhost"
DEFAULT_IPC_PORT = 8888

# Env var name constants (Design D: override IPC target for LAN connections)
ENV_IPC_HOST = "TESTABLE_IPC_HOST"
ENV_IPC_PORT = "TESTABLE_IPC_PORT"


def resolve_ipc_host_port(env: dict = None) -> tuple:
    """Resolve the IPC host and port from environment variables.

    Returns the default values (localhost:8888) when no env vars are set.
    Pass a dict as `env` to use it instead of os.environ (for testing).

    Args:
        env: Environment variable dict to use (defaults to os.environ)

    Returns:
        (host: str, port: int) tuple

    Environment variables:
        TESTABLE_IPC_HOST: Target host (default: "localhost")
        TESTABLE_IPC_PORT: Target port as string (default: 8888)
    """
    if env is None:
        env = os.environ
    host = env.get(ENV_IPC_HOST, DEFAULT_IPC_HOST)
    port_str = env.get(ENV_IPC_PORT, str(DEFAULT_IPC_PORT))
    try:
        port = int(port_str)
    except ValueError:
        port = DEFAULT_IPC_PORT
    return host, port


def build_base_url(host: str = DEFAULT_IPC_HOST, port: int = DEFAULT_IPC_PORT) -> str:
    """Build the base URL for the IPC server."""
    return f"http://{host}:{port}"


def build_perform_payload(test_id: str, command_name: str, parameters=None) -> dict:
    """Build the POST /perform request body.

    Args:
        test_id: Component testID (e.g. "scene.auth.loginButton")
        command_name: Command name ("getState" / "tap" / "setProperty", etc.)
        parameters: Command parameters dict (optional)

    Returns:
        {"testID": ..., "commandName": ..., "parameters": ...}
    """
    return {
        "testID": test_id,
        "commandName": command_name,
        "parameters": parameters,
    }


def passthrough_state(response_data: dict) -> dict:
    """Pass through describedState as an opaque dict.

    Does not assume a fixed set of keys (STEP2 forward compatible).
    A thin wrapper that does not modify contents for schema-change resilience.
    """
    return response_data


def build_simctl_screenshot_command(output_path: str) -> list:
    """Assemble the simctl io booted screenshot command.

    Args:
        output_path: Destination file path for the screenshot

    Returns:
        Command list ready to pass to subprocess.run
    """
    return ["xcrun", "simctl", "io", "booted", "screenshot", output_path]


def build_screenshot_url(host: str = DEFAULT_IPC_HOST, port: int = DEFAULT_IPC_PORT) -> str:
    """Build the URL for the GET /screenshot endpoint.

    Args:
        host: Target host (default: "localhost")
        port: Target port (default: 8888)

    Returns:
        URL string in "http://<host>:<port>/screenshot" format
    """
    return f"{build_base_url(host=host, port=port)}/screenshot"


def is_loopback_host(host: str) -> bool:
    """Determine whether the host is a loopback address (pure function).

    Used for the simctl fallback decision:
    Falls back to simctl only when the target is loopback and /screenshot is unreachable.

    Args:
        host: IPC target host string

    Returns:
        True  = loopback ("localhost" / "127.0.0.1" / "::1")
        False = non-loopback such as LAN IP (real device connection, etc.)
    """
    return host in ("localhost", "127.0.0.1", "::1")
