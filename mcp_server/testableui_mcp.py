#!/usr/bin/env python3
"""
TestableUIKit MCP Server — UI テスト用 MCP ラッパー

TestableUIKit の HTTP IPC（localhost:8888）を MCP tool で薄くラップし、
Claude が実行中の iOS UI を直接駆動・describedState を構造化検査できる。

公開する MCP tool（4本）:
  ui_ping        — GET /ping  死活確認
  ui_getState    — POST /perform getState  状態取得
  ui_perform     — POST /perform  コマンド実行（tap/setProperty/setEnabled など）
  ui_screenshot  — simctl io booted screenshot  スクリーンショット取得

使い方:
  python3 mcp_server/testableui_mcp.py

前提:
  DemoApp が iOS Simulator 上で起動済み（localhost:8888 でリッスン中）
  .venv に mcp・requests インストール済み（mcp_server/requirements.txt 参照）
"""

import base64
import os
import subprocess
import sys
import tempfile
from typing import Optional

# 同梱ヘルパーをインポート（外部依存なし）
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ipc_helpers import (
    build_base_url,
    build_perform_payload,
    build_simctl_screenshot_command,
    passthrough_state,
)

import requests
from mcp.server.fastmcp import FastMCP

# ================================================================
# MCP サーバーインスタンス
# ================================================================

mcp = FastMCP("TestableUIKit")
_IPC_BASE = build_base_url()


# ================================================================
# MCP ツール定義（HTTP を薄く中継・状態レス）
# ================================================================


@mcp.tool()
def ui_ping() -> dict:
    """TestableUIKit サーバーの死活確認（GET /ping）。

    DemoApp が Simulator 上で起動中かどうかを確認する。
    正常応答: {"status": "ok"}

    Returns:
        IPC サーバーからのレスポンス dict
    """
    resp = requests.get(f"{_IPC_BASE}/ping", timeout=5)
    resp.raise_for_status()
    return resp.json()


@mcp.tool()
def ui_getState(testID: str) -> dict:
    """指定コンポーネントの現在の describedState を取得する（POST /perform getState）。

    describedState のキー構成はコンポーネント実装に依存する（不透明 dict）。
    例: loginButton → {isEnabled, title, isHidden, alpha, backgroundColor}
        counter    → {count, isEnabled}
        rangeSlider→ {value, minValue, maxValue, step}

    Args:
        testID: コンポーネントの testID（例: "scene.auth.loginButton"）

    Returns:
        describedState の不透明 dict
    """
    payload = build_perform_payload(testID, "getState")
    resp = requests.post(f"{_IPC_BASE}/perform", json=payload, timeout=10)
    resp.raise_for_status()
    return passthrough_state(resp.json())


@mcp.tool()
def ui_perform(testID: str, command: str, params: Optional[dict] = None) -> dict:
    """コンポーネントにコマンドを送信する（POST /perform）。

    コマンド例:
      "tap"           — ボタンタップ（params 不要）
      "setProperty"   — {"key": "isEnabled", "value": false}
      "setEnabled"    — {"value": true}
      "increment"     — Counter をインクリメント

    Args:
        testID: コンポーネントの testID
        command: コマンド名
        params: コマンドパラメータ dict（コマンドにより異なる。省略可）

    Returns:
        実行後の describedState（不透明 dict）
    """
    payload = build_perform_payload(testID, command, params)
    resp = requests.post(f"{_IPC_BASE}/perform", json=payload, timeout=10)
    resp.raise_for_status()
    return passthrough_state(resp.json())


@mcp.tool()
def ui_screenshot() -> dict:
    """起動中の iOS Simulator のスクリーンショットを取得する（simctl io booted screenshot）。

    UI の崩れ・表示状態の一次判定に使用する。

    Returns:
        {"image_base64": "<PNG の base64 文字列>", "format": "png"}
    """
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        output_path = f.name

    try:
        cmd = build_simctl_screenshot_command(output_path)
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if result.returncode != 0:
            raise RuntimeError(f"simctl screenshot failed: {result.stderr}")

        with open(output_path, "rb") as f:
            image_data = base64.b64encode(f.read()).decode("utf-8")
    finally:
        if os.path.exists(output_path):
            os.unlink(output_path)

    return {"image_base64": image_data, "format": "png"}


# ================================================================
# エントリーポイント（stdio transport）
# ================================================================

if __name__ == "__main__":
    mcp.run()
