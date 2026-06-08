#!/usr/bin/env bash
# HTML を headless Chrome で PNG にレンダリングする（同期・2x既定）。
# 使い方: render.sh <html> <out.png> [WxH] [scale]
#   例:   render.sh fig.html fig.png 1000,700 2
# ウィンドウサイズはパネルが収まる十分な大きさにすること（はみ出すと切れる）。
set -uo pipefail

HTML="${1:?usage: render.sh <html> <out.png> [WxH] [scale]}"
OUT="${2:?output png required}"
WIN="${3:-1100,800}"
SCALE="${4:-2}"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Chrome not found at: $CHROME" >&2; exit 1; }
[ -f "$HTML" ]   || { echo "HTML not found: $HTML" >&2; exit 1; }

# 既存の出力を削除する。残っていると、Chrome が上書きする前に「出力サイズが
# 安定した」と誤検知して古い画像のまま返ってしまうため（再生成のたびに必須）。
rm -f "$OUT"

# 絶対パス -> file:// URL（空白・日本語を正しくエンコード）
ABS="$(cd "$(dirname "$HTML")" && pwd)/$(basename "$HTML")"
URL="$(python3 - "$ABS" <<'PY'
import sys, pathlib
print(pathlib.Path(sys.argv[1]).as_uri())
PY
)"

# プロファイルはリポジトリ外の一時ディレクトリに作り、終了時に必ず削除する
# （出力先に作ると git に残るため）
PROFILE="$(mktemp -d "${TMPDIR:-/tmp}/chrome-prof-XXXXXX")"

# Chrome は --screenshot 完了後もプロセスが終了しないことがある（この環境では
# headless=new/old とも再現）。放置すると profile が書き戻されてゴミ・ゾンビ化
# するため、出力生成を検知したらプロセスグループごと SIGKILL で即終了させる。
# SIGTERM だと graceful shutdown 中に profile を書き戻し rm が失敗するので -9。
CHROME_PID=""
CHROME_PGID=""
cleanup() {
  # プロセスグループごと SIGKILL する。ただし取得した PGID が自分自身（このスクリプト）
  # のグループと一致する場合は、誤って親まで巻き込むので絶対に kill しない。
  if [ -n "$CHROME_PGID" ] && \
     [ "$CHROME_PGID" != "$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')" ]; then
    kill -9 -- -"$CHROME_PGID" 2>/dev/null
  fi
  # PGID を引けなかった場合の取りこぼし対策に、リーダー PID 単体も止める
  [ -n "$CHROME_PID" ] && kill -9 "$CHROME_PID" 2>/dev/null
  # 全プロセス消滅を待ってから削除（書き戻しによる rm 失敗を防ぐ）
  sleep 0.3
  rm -rf "$PROFILE"
}
trap cleanup EXIT

# job control を有効にして起動すると、ジョブが独立したプロセスグループの
# リーダーになる（kill -- -PGID で子プロセスごと一括終了するため）。
set -m
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor="$SCALE" --window-size="$WIN" \
  --user-data-dir="$PROFILE" --screenshot="$OUT" "$URL" >/dev/null 2>&1 &
CHROME_PID=$!
set +m
# $! はジョブの PID。リーダーなら PID==PGID だが、明示的に実 PGID を ps から引く。
CHROME_PGID="$(ps -o pgid= -p "$CHROME_PID" 2>/dev/null | tr -d ' ')"

# 出力ファイルのサイズが安定する（=撮影完了）までポーリングで待つ（最大15秒）。
# 生成直後に kill すると書き込み途中で壊れるため、連続して同サイズを確認する。
prev=-1; stable=0
for _ in $(seq 1 150); do
  if [ -s "$OUT" ]; then
    cur=$(wc -c < "$OUT")
    if [ "$cur" = "$prev" ]; then
      stable=$((stable + 1))
      [ "$stable" -ge 3 ] && break
    else
      stable=0
    fi
    prev=$cur
  fi
  sleep 0.1
done

if [ -s "$OUT" ]; then
  echo "rendered: $OUT  (window $WIN @${SCALE}x)"
else
  echo "render failed: $OUT" >&2
  exit 1
fi
