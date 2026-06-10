#!/usr/bin/env bash
#
# fetch_transcript.sh — YouTube動画のメタ情報と字幕(トランスクリプト)を取得する
#
# 使い方:
#   fetch_transcript.sh <YouTube URL> [work_dir]
#
# 動作:
#   1. yt-dlp(uvx経由)で動画メタ情報を取得
#   2. 字幕を「日本語 → 英語 → 動画の原語 → 任意の手動字幕」の順でダウンロード(手動/自動の両方)
#   3. VTTを重複除去してプレーンなトランスクリプトに整形
#   4. メタ情報マニフェスト(KEY=VALUE形式)をstdoutへ出力。整形済みトランスクリプトのパスも含む
#
# 前提: uv/uvx と python3 が利用可能であること(yt-dlpはuvxが都度取得)。ネットワーク接続が必要。

set -uo pipefail
shopt -s nullglob   # マッチしないグロブはリテラルでなく空に展開する

URL="${1:-}"
WORKDIR="${2:-.tmp/yt-transcript}"

# エラーマニフェストを出力して終了する(出力は常にstdoutへ統一)
die() {
  echo "STATUS=ERROR"
  echo "ERROR_MESSAGE=$1"
  exit "${2:-1}"
}

if [[ -z "$URL" ]]; then
  die "YouTube URLが指定されていません"
fi

mkdir -p "$WORKDIR" || die "作業ディレクトリの作成に失敗しました: $WORKDIR"

# yt-dlpはバージョンを固定する(供給網ハードニング)。
# 未固定(uvx yt-dlp)だとPyPIの最新へ浮動し、悪性リリースをレビュー猶予なく実行しうるため。
# 更新時はこの値を意図的に引き上げ、リリースノートを確認すること:
#   uvx yt-dlp@latest --version  で最新を確認 → 動作確認のうえ YTDLP_VERSION を更新
# 環境変数 YTDLP_VERSION で一時的な上書きも可能。
YTDLP_VERSION="${YTDLP_VERSION:-2026.06.09}"
YTDLP=(uvx "yt-dlp@${YTDLP_VERSION}")

# --- 1. メタ情報取得 ---
# 各フィールドを1行ずつ出力させる(区切り文字がタイトルに含まれる問題を回避)
mapfile -t FIELDS < <("${YTDLP[@]}" --skip-download --no-warnings \
  --print "%(id)s" \
  --print "%(title)s" \
  --print "%(uploader)s" \
  --print "%(duration>%H:%M:%S)s" \
  --print "%(upload_date)s" \
  --print "%(webpage_url)s" \
  --print "%(language)s" \
  "$URL" 2>/dev/null)

# 7フィールド揃わない / ID・TITLEが空なら取得失敗とみなす
if (( ${#FIELDS[@]} < 7 )) || [[ -z "${FIELDS[0]}" || -z "${FIELDS[1]}" ]]; then
  die "メタ情報の取得に失敗しました(URL不正/非公開/ネットワーク不可の可能性)"
fi

ID="${FIELDS[0]}"
TITLE="${FIELDS[1]}"
UPLOADER="${FIELDS[2]}"
DURATION="${FIELDS[3]}"
UPLOAD_DATE="${FIELDS[4]}"
WEBURL="${FIELDS[5]}"
LANGUAGE="${FIELDS[6]}"   # 動画の原語(例: en, es)。"NA"や空のことがある

# 共通メタフィールドを出力する(OK/NO_SUBTITLESの両分岐で再利用)
print_meta() {
  echo "ID=$ID"
  echo "TITLE=$TITLE"
  echo "UPLOADER=$UPLOADER"
  echo "DURATION=$DURATION"
  echo "UPLOAD_DATE=$UPLOAD_DATE"
  echo "URL=$WEBURL"
}

# --- 2. 字幕ダウンロード ---
# 指定言語(手動/自動/翻訳)の字幕を取得する
download_subs() {
  local langs="$1"
  "${YTDLP[@]}" --skip-download --no-warnings \
    --write-subs --write-auto-subs \
    --sub-langs "$langs" --sub-format vtt \
    --retries 3 --sleep-subtitles 1 \
    -o "$WORKDIR/%(id)s.%(ext)s" "$URL" >/dev/null 2>&1
}

# 指定プレフィックスの言語でDL済みvttを探し、見つかれば SUB_FILE/SUB_LANG を設定
find_sub() {
  local pfx="$1" f
  for f in "$WORKDIR/$ID.$pfx".vtt "$WORKDIR/$ID.$pfx"-*.vtt; do
    [[ -f "$f" ]] || continue
    SUB_FILE="$f"; SUB_LANG="$pfx"; return 0
  done
  return 1
}

SUB_FILE=""
SUB_LANG=""

# 試行する言語の優先順位: 日本語 → 英語 → 動画の原語
LANG_TRY=("ja" "en")
if [[ -n "$LANGUAGE" && "$LANGUAGE" != "NA" && "$LANGUAGE" != "ja" && "$LANGUAGE" != "en" ]]; then
  LANG_TRY+=("$LANGUAGE")
fi

for lang in "${LANG_TRY[@]}"; do
  download_subs "$lang,$lang-orig,$lang.*"
  if find_sub "$lang"; then break; fi
done

# 最終フォールバック: 利用可能な任意の手動字幕(言語不問)を取得して使う
if [[ -z "$SUB_FILE" ]]; then
  "${YTDLP[@]}" --skip-download --no-warnings \
    --write-subs --sub-langs "all" --sub-format vtt \
    --retries 3 --sleep-subtitles 1 \
    -o "$WORKDIR/%(id)s.%(ext)s" "$URL" >/dev/null 2>&1
  cands=("$WORKDIR/$ID".*.vtt)
  if (( ${#cands[@]} > 0 )); then
    SUB_FILE="${cands[0]}"
    langpart=$(basename "$SUB_FILE" .vtt)   # <id>.es / <id>.es-orig
    langpart="${langpart##*.}"              # es / es-orig
    SUB_LANG="${langpart%%-*}"              # es
  fi
fi

if [[ -z "$SUB_FILE" ]]; then
  echo "STATUS=NO_SUBTITLES"
  print_meta
  echo "ERROR_MESSAGE=この動画には利用可能な字幕(手動/自動)がありませんでした"
  exit 2
fi

# --- 3. VTTを整形(重複除去) + 語数/文字数カウント ---
TRANSCRIPT_FILE="$WORKDIR/$ID.transcript.txt"
read -r WORDS CHARS < <(python3 - "$SUB_FILE" "$TRANSCRIPT_FILE" <<'PY'
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
text = " ".join(out)
text = re.sub(r"\s+", " ", text)
# HTMLエンティティと話者交代マーカー(>>)の整形
text = text.replace("&gt;&gt;", "\n\n› ").replace("&gt;", ">").replace("&amp;", "&").replace("&#39;", "'").replace("&quot;", '"')
text = text.replace(">> ", "\n\n› ").replace(">>", "\n\n› ")
text = re.sub(r"\n{3,}", "\n\n", text).strip()
open(dst, "w", encoding="utf-8").write(text)
# 語数(空白区切り。日本語では実質無意味なので文字数も併記)と文字数を出力
print(len(text.split()), len(text))
PY
)

# --- 4. マニフェスト出力 ---
echo "STATUS=OK"
print_meta
echo "SUB_LANG=$SUB_LANG"
echo "WORDS=$WORDS"
echo "CHARS=$CHARS"
echo "TRANSCRIPT_FILE=$(cd "$(dirname "$TRANSCRIPT_FILE")" && pwd)/$(basename "$TRANSCRIPT_FILE")"
