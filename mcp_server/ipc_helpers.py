"""
TestableUIKit MCP Server — 純粋ヘルパー関数

HTTP IPC の payload 構築・レスポンス passthrough・simctl コマンド組み立て。
外部依存なし。Simulator/DemoApp 不要で単体テスト可能。
"""

DEFAULT_IPC_HOST = "localhost"
DEFAULT_IPC_PORT = 8888


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
