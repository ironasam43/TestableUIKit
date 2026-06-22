"""
Tests/unit/ 専用 conftest.py

純粋ヘルパーの L1 テスト用。HTTP 接続・DemoApp 起動不要。
Tests/conftest.py の autouse reset_state fixture（HTTP を呼ぶ）を
no-op で上書きして IPC 接続エラーを防ぐ。
"""

import pytest


@pytest.fixture(autouse=True)
def reset_state():
    """No-op override: 純粋ユニットテストは HTTP 接続を必要としない。"""
    yield
