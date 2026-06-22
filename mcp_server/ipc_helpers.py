"""
TestableUIKit MCP Server — 純粋ヘルパー関数

HTTP IPC の payload 構築・レスポンス passthrough・simctl コマンド組み立て。
外部依存なし。Simulator/DemoApp 不要で単体テスト可能。
"""

import os

DEFAULT_IPC_HOST = "localhost"
DEFAULT_IPC_PORT = 8888

# 環境変数名定数（Design D: LAN 越し IPC 接続先の上書き用）
ENV_IPC_HOST = "TESTABLE_IPC_HOST"
ENV_IPC_PORT = "TESTABLE_IPC_PORT"


def resolve_ipc_host_port(env: dict = None) -> tuple:
    """環境変数から IPC 接続先の host・port を解決する。

    環境変数が未設定の場合は既定値（localhost:8888）を返す。
    引数 env に dict を渡すと os.environ の代わりに使用する（テスト用）。

    Args:
        env: 参照する環境変数 dict（省略時は os.environ）

    Returns:
        (host: str, port: int) のタプル

    環境変数:
        TESTABLE_IPC_HOST: 接続先ホスト（既定: "localhost"）
        TESTABLE_IPC_PORT: 接続先ポート番号文字列（既定: 8888）
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
    """IPC サーバーのベース URL を組み立てる。"""
    return f"http://{host}:{port}"


def build_perform_payload(test_id: str, command_name: str, parameters=None) -> dict:
    """POST /perform の request body を構築する。

    Args:
        test_id: コンポーネントの testID（例: "scene.auth.loginButton"）
        command_name: コマンド名（"getState" / "tap" / "setProperty" など）
        parameters: コマンドパラメータ dict（省略可）

    Returns:
        {"testID": ..., "commandName": ..., "parameters": ...}
    """
    return {
        "testID": test_id,
        "commandName": command_name,
        "parameters": parameters,
    }


def passthrough_state(response_data: dict) -> dict:
    """describedState を不透明 dict として passthrough する。

    キー固定を前提にしない（STEP2 前方互換）。
    schema 変化に強い薄いラッパーとして中身を加工しない。
    """
    return response_data


def build_simctl_screenshot_command(output_path: str) -> list:
    """simctl io booted screenshot コマンドを組み立てる。

    Args:
        output_path: スクリーンショットの保存先ファイルパス

    Returns:
        subprocess.run に渡せるコマンドリスト
    """
    return ["xcrun", "simctl", "io", "booted", "screenshot", output_path]


def build_screenshot_url(host: str = DEFAULT_IPC_HOST, port: int = DEFAULT_IPC_PORT) -> str:
    """GET /screenshot エンドポイントの URL を組み立てる。

    Args:
        host: 接続先ホスト（既定: "localhost"）
        port: 接続先ポート（既定: 8888）

    Returns:
        "http://<host>:<port>/screenshot" 形式の URL 文字列
    """
    return f"{build_base_url(host=host, port=port)}/screenshot"


def is_loopback_host(host: str) -> bool:
    """host がループバックアドレスかどうかを判定する（純粋関数）。

    simctl フォールバック判定に使用する。
    loopback かつ /screenshot 不達の場合のみ simctl へフォールバックする。

    Args:
        host: IPC 接続先ホスト文字列

    Returns:
        True  = loopback（"localhost" / "127.0.0.1" / "::1"）
        False = LAN IP など非 loopback（実機接続など）
    """
    return host in ("localhost", "127.0.0.1", "::1")
