#!/usr/bin/env bash
#
# fetch_transcript.sh — YouTube動画のメタ情報と字幕(トランスクリプト)を取得する
#
# 使い方:
#   fetch_transcript.sh <YouTube URL> [work_dir]
#
# 動作:
#   1. yt-dlp(uvx経由)で動画メタ情報を取得
#   2. 字幕を「日本語優先 → 原語フォールバック」でダウンロード(手動字幕/自動字幕の両方)
#   3. VTTを重複除去してプレーンなトランスクリプトに整形
#   4. メタ情報マニフェスト(KEY=VALUE形式)をstdoutへ出力。整形済みトランスクリプトのパスも含む
#
# 前提: uv/uvx が利用可能であること(yt-dlpはuvxが都度取得)。ネットワーク接続が必要。

set -uo pipefail

URL="${1:-}"
WORKDIR="${2:-.tmp/yt-transcript}"

if [[ -z "$URL" ]]; then
  echo "ERROR=missing_url" >&2
  echo "STATUS=ERROR"
  echo "ERROR_MESSAGE=YouTube URLが指定されていません"
  exit 1
fi

mkdir -p "$WORKDIR"

# yt-dlpはバージョンを固定する(供給網ハードニング)。
# 未固定(uvx yt-dlp)だとPyPIの最新へ浮動し、悪性リリースをレビュー猶予なく実行しうるため。
# 更新時はこの値を意図的に引き上げ、リリースノートを確認すること:
#   uvx yt-dlp@latest --version  で最新を確認 → 動作確認のうえ YTDLP_VERSION を更新
# 環境変数 YTDLP_VERSION で一時的な上書きも可能。
YTDLP_VERSION="${YTDLP_VERSION:-2026.06.09}"
YTDLP=(uvx "yt-dlp@${YTDLP_VERSION}")

# --- 1. メタ情報取得 ---
# 各フィールドを1行ずつ出力させる(区切り文字がタイトルに含まれる問題を回避)
META=$("${YTDLP[@]}" --skip-download --no-warnings \
  --print "%(id)s" \
  --print "%(title)s" \
  --print "%(uploader)s" \
  --print "%(duration>%H:%M:%S)s" \
  --print "%(upload_date)s" \
  --print "%(webpage_url)s" \
  "$URL" 2>/dev/null)

if [[ -z "$META" ]]; then
  echo "STATUS=ERROR"
  echo "ERROR_MESSAGE=メタ情報の取得に失敗しました(URL不正/非公開/ネットワーク不可の可能性)"
  exit 1
fi

ID=$(printf '%s\n' "$META" | sed -n '1p')
TITLE=$(printf '%s\n' "$META" | sed -n '2p')
UPLOADER=$(printf '%s\n' "$META" | sed -n '3p')
DURATION=$(printf '%s\n' "$META" | sed -n '4p')
UPLOAD_DATE=$(printf '%s\n' "$META" | sed -n '5p')
WEBURL=$(printf '%s\n' "$META" | sed -n '6p')

# --- 2. 字幕ダウンロード(言語優先順: 日本語 → 原語) ---
download_subs() {
  local langs="$1"
  "${YTDLP[@]}" --skip-download --no-warnings \
    --write-subs --write-auto-subs \
    --sub-langs "$langs" --sub-format vtt \
    --retries 3 --sleep-subtitles 1 \
    -o "$WORKDIR/%(id)s.%(ext)s" "$URL" >/dev/null 2>&1
}

# まず日本語(手動/自動/翻訳)を試す
download_subs "ja,ja-orig,ja.*"

# 日本語が取れたか確認
SUB_FILE=""
SUB_LANG=""
for cand in "$WORKDIR/$ID".ja.vtt "$WORKDIR/$ID".ja-orig.vtt "$WORKDIR/$ID".ja-*.vtt; do
  if [[ -f "$cand" ]]; then SUB_FILE="$cand"; SUB_LANG="ja"; break; fi
done

# 日本語が無ければ原語(英語含む)を試す
if [[ -z "$SUB_FILE" ]]; then
  download_subs "en,en-orig,en.*"
  for cand in "$WORKDIR/$ID".en.vtt "$WORKDIR/$ID".en-orig.vtt "$WORKDIR/$ID".en-*.vtt; do
    if [[ -f "$cand" ]]; then SUB_FILE="$cand"; SUB_LANG="en"; break; fi
  done
fi

# それでも無ければ取得済みの任意のvttを使う
if [[ -z "$SUB_FILE" ]]; then
  CAND=$(ls "$WORKDIR/$ID".*.vtt 2>/dev/null | head -1)
  if [[ -n "$CAND" ]]; then
    SUB_FILE="$CAND"
    SUB_LANG=$(basename "$CAND" | sed -E "s/^.*\.([a-zA-Z-]+)\.vtt$/\1/")
  fi
fi

if [[ -z "$SUB_FILE" ]]; then
  echo "STATUS=NO_SUBTITLES"
  echo "ID=$ID"
  echo "TITLE=$TITLE"
  echo "UPLOADER=$UPLOADER"
  echo "DURATION=$DURATION"
  echo "UPLOAD_DATE=$UPLOAD_DATE"
  echo "URL=$WEBURL"
  echo "ERROR_MESSAGE=この動画には利用可能な字幕(手動/自動)がありませんでした"
  exit 2
fi

# --- 3. VTTを整形(重複除去) ---
TRANSCRIPT_FILE="$WORKDIR/$ID.transcript.txt"
python3 - "$SUB_FILE" "$TRANSCRIPT_FILE" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8", errors="replace").read().splitlines()
out = []
for ln in lines:
    if "-->" in ln or ln.strip() == "" or ln.startswith(("WEBVTT", "Kind:", "Language:")):
        continue
    ln = re.sub(r"<[^>]+>", "", ln).strip()   # インラインのタイムスタンプ/cタグ除去
    if not ln:
        continue
    if out and out[-1] == ln:                  # 連続重複除去(ローリングキャプション対策)
        continue
    out.append(ln)
# さらに連続重複を畳む
clean = []
for ln in out:
    if clean and clean[-1] == ln:
        continue
    clean.append(ln)
text = " ".join(clean)
text = re.sub(r"\s+", " ", text)
# HTMLエンティティと話者交代マーカーの整形
text = text.replace("&gt;&gt;", "\n\n› ").replace("&gt;", ">").replace("&amp;", "&").replace("&#39;", "'").replace("&quot;", '"')
text = text.replace(">> ", "\n\n› ").replace(">>", "\n\n› ")
text = re.sub(r"\n{3,}", "\n\n", text).strip()
open(dst, "w", encoding="utf-8").write(text)
PY
WORDS=$(python3 - "$TRANSCRIPT_FILE" <<'PY'
import sys
print(len(open(sys.argv[1], encoding="utf-8").read().split()))
PY
)

# --- 4. マニフェスト出力 ---
echo "STATUS=OK"
echo "ID=$ID"
echo "TITLE=$TITLE"
echo "UPLOADER=$UPLOADER"
echo "DURATION=$DURATION"
echo "UPLOAD_DATE=$UPLOAD_DATE"
echo "URL=$WEBURL"
echo "SUB_LANG=$SUB_LANG"
echo "WORDS=$WORDS"
echo "TRANSCRIPT_FILE=$(cd "$(dirname "$TRANSCRIPT_FILE")" && pwd)/$(basename "$TRANSCRIPT_FILE")"
