#!/usr/bin/env bash
# e2e_macdemo.sh — TestableUIKitMacDemo e2e 再現スクリプト
# 実行前提: `swift build` 済み・8888番ポート空き
# Usage: bash e2e_macdemo.sh
set -euo pipefail

LOG_DIR="/tmp/tuk_e2e_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"
echo "LOG_DIR: $LOG_DIR"

# ─── 0. 事前クリア ────────────────────────────────────
lsof -ti :8888 | xargs kill -9 2>/dev/null || true

# ─── 1. swift build ──────────────────────────────────
echo "[1] swift build"
swift build 2>&1 | tee "${LOG_DIR}/build.log"
echo "BUILD_OK"

# ─── 2. swift test ───────────────────────────────────
echo "[2] swift test"
swift test 2>&1 | tee "${LOG_DIR}/test.log"
grep "Executed.*tests" "${LOG_DIR}/test.log" | tail -1
echo "TEST_OK"

# ─── 3. MacDemo 起動 ──────────────────────────────────
echo "[3] swift run TestableUIKitMacDemo (background)"
swift run TestableUIKitMacDemo > "${LOG_DIR}/macdemo.log" 2>&1 &
MACDEMO_PID=$!
echo "PID=$MACDEMO_PID"

# ─── 4. /ping ポーリング ──────────────────────────────
echo "[4] polling /ping"
for i in $(seq 1 30); do
  sleep 1
  RESP=$(curl -s --max-time 2 http://127.0.0.1:8888/ping 2>/dev/null || echo "")
  if echo "$RESP" | grep -q '"ok"'; then
    echo "PING_OK at $i sec: $RESP"
    break
  fi
  [ "$i" -eq 30 ] && { echo "PING_TIMEOUT"; kill $MACDEMO_PID 2>/dev/null; exit 1; }
done

# ─── 5. getState（登録完了ゲート）───────────────────────
echo "[5] getState scene.demo.counter (registration gate)"
for i in $(seq 1 20); do
  sleep 1
  HTTP_CODE=$(curl -s -o /tmp/_gs.json -w "%{http_code}" \
    -X POST http://127.0.0.1:8888/perform \
    -H "Content-Type: application/json" \
    -d '{"testID":"scene.demo.counter","commandName":"getState","parameters":{}}' 2>/dev/null)
  BODY=$(cat /tmp/_gs.json)
  if [ "$HTTP_CODE" = "200" ]; then
    echo "GETSTATE_200: $BODY"
    cp /tmp/_gs.json "${LOG_DIR}/getstate_initial.json"
    break
  fi
  [ "$i" -eq 20 ] && { echo "GETSTATE_TIMEOUT"; kill $MACDEMO_PID 2>/dev/null; exit 1; }
done

COUNT_INIT=$(python3 -c "import json; d=json.load(open('${LOG_DIR}/getstate_initial.json')); print(d['count'])")
[ "$COUNT_INIT" = "0" ] || { echo "FAIL: initial count=$COUNT_INIT (expected 0)"; exit 1; }
echo "count_initial=$COUNT_INIT OK"

# ─── 6. perform increment ────────────────────────────
echo "[6] perform increment"
P_CODE=$(curl -s -o /tmp/_perf.json -w "%{http_code}" \
  -X POST http://127.0.0.1:8888/perform \
  -H "Content-Type: application/json" \
  -d '{"testID":"scene.demo.counter","commandName":"increment","parameters":{}}')
cp /tmp/_perf.json "${LOG_DIR}/perform_increment.json"
echo "perform HTTP=$P_CODE body=$(cat /tmp/_perf.json)"
[ "$P_CODE" = "200" ] || { echo "FAIL: perform HTTP=$P_CODE"; exit 1; }

sleep 0.5
GS_CODE=$(curl -s -o /tmp/_gs2.json -w "%{http_code}" \
  -X POST http://127.0.0.1:8888/perform \
  -H "Content-Type: application/json" \
  -d '{"testID":"scene.demo.counter","commandName":"getState","parameters":{}}')
cp /tmp/_gs2.json "${LOG_DIR}/getstate_after_increment.json"
COUNT_AFTER=$(python3 -c "import json; d=json.load(open('${LOG_DIR}/getstate_after_increment.json')); print(d['count'])")
[ "$COUNT_AFTER" = "1" ] || { echo "FAIL: count after increment=$COUNT_AFTER (expected 1)"; exit 1; }
echo "count_after_increment=$COUNT_AFTER OK (0→1)"

# ─── 7. screenshot ────────────────────────────────────
echo "[7] ui_screenshot"
SS_CODE=$(curl -s -o /tmp/_ss.json -w "%{http_code}" http://127.0.0.1:8888/screenshot)
echo "screenshot HTTP=$SS_CODE"
[ "$SS_CODE" = "200" ] || { echo "FAIL: screenshot HTTP=$SS_CODE"; exit 1; }

python3 - <<PYEOF
import json, base64
with open('/tmp/_ss.json') as f:
    d = json.load(f)
png_data = base64.b64decode(d['image_base64'])
out = '${LOG_DIR}/screenshot.png'
with open(out, 'wb') as f:
    f.write(png_data)
byte_len = len(png_data)
sig = png_data[:8]
expected = bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
assert sig == expected, f"PNG signature mismatch: {sig.hex()}"
assert byte_len > 1024, f"PNG too small: {byte_len} bytes"
print(f"PNG OK: {byte_len} bytes, sig={sig.hex()}")
PYEOF

sips -g pixelWidth -g pixelHeight "${LOG_DIR}/screenshot.png"
echo "screenshot saved: ${LOG_DIR}/screenshot.png"

# ─── 8. クリーンアップ ────────────────────────────────
echo "[8] cleanup"
kill $MACDEMO_PID 2>/dev/null || true
wait $MACDEMO_PID 2>/dev/null || true
lsof -ti :8888 | xargs kill -9 2>/dev/null || true
echo "Port 8888 released"

echo ""
echo "=== ALL e2e PASS ==="
echo "Logs: $LOG_DIR"
