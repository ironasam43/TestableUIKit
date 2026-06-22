"""
pytest fixtures for TestableUIKit IPC integration tests.

前提: DemoApp が iOS Simulator 上で起動済みで、
      TestableServer がリッスンしている。

接続先の上書き（Design D: LAN 越し IPC）:
  TESTABLE_IPC_HOST 環境変数で接続先ホストを変更可（既定: localhost）
  TESTABLE_IPC_PORT 環境変数で接続先ポートを変更可（既定: 8888）
"""

import os
import sys

import pytest
import requests

# mcp_server/ を import パスに追加（resolve_ipc_host_port 使用）
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "mcp_server"))
from ipc_helpers import resolve_ipc_host_port

# ========== 定数 ==========

_ipc_host, _ipc_port = resolve_ipc_host_port()
BASE_URL = f"http://{_ipc_host}:{_ipc_port}"
TEST_ID = "scene.auth.loginButton"

# LoginButton の初期状態（5キー固定）
INITIAL_STATE = {
    "isEnabled": True,
    "title": "Log In",
    "isHidden": False,
    "alpha": 1.0,
    "backgroundColor": "systemBlue",
}


# ========== Fixtures ==========

@pytest.fixture(scope="session")
def base_url():
    """IPC サーバーのベース URL（セッション全体で共有）"""
    return BASE_URL


@pytest.fixture(scope="session")
def test_id():
    """テスト対象コンポーネントの testID（セッション全体で共有）"""
    return TEST_ID


@pytest.fixture
def perform(base_url, test_id):
    """
    POST /perform のヘルパー関数を返す fixture。

    使い方:
        state = perform("tap")
        state = perform("setProperty", {"key": "isEnabled", "value": True})
    """
    def _perform(command_name, parameters=None):
        payload = {
            "testID": test_id,
            "commandName": command_name,
            "parameters": parameters,
        }
        resp = requests.post(f"{base_url}/perform", json=payload, timeout=10)
        if not resp.ok:
            print(
                f"\n[HTTP ERROR] {resp.status_code} on perform('{command_name}'): {resp.text}",
                flush=True,
            )
        resp.raise_for_status()
        return resp.json()

    return _perform


@pytest.fixture(autouse=True)
def reset_state(perform):
    """
    各テストの前に LoginButton を初期状態にリセットする（autouse）。

    初期状態:
      isEnabled: true, title: "Log In", isHidden: false,
      alpha: 1.0, backgroundColor: "systemBlue"
    """
    # isEnabled と title を初期値に戻す（tap で変化する2キーのみリセット）
    perform("setProperty", {"key": "isEnabled", "value": True})
    perform("setProperty", {"key": "title", "value": "Log In"})
    yield
