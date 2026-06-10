#!/usr/bin/env bash
#
# fetch_apple_session.sh — Apple Developer の動画セッションページから
#   公式トランスクリプト・章ごとSummary・サンプルコード・関連リンクを取得する
#
# 使い方:
#   fetch_apple_session.sh <Apple Developer video URL> [work_dir]
#   例: fetch_apple_session.sh "https://developer.apple.com/videos/play/wwdc2026/279/" .tmp/apple-session
#
# 動作:
#   1. curl でセッションページのHTMLを取得
#   2. 4つの supplement を抽出:
#      - transcript-content → 逐語トランスクリプト全文(原語=英語)
#      - summary(chapter-summary) → 章ごと要約 [{time,title,summary}]
#      - sample-code(code-source) → 公式Swiftサンプルコード [{time,title,code}]
#      - 関連ドキュメントリンク
#   3. メタ情報マニフェスト(KEY=VALUE形式)をstdoutへ出力。各成果物ファイルのパスも含む
#
# 供給網ハードニング:
#   本スクリプトは curl(システム標準) と python3 標準ライブラリ(re/json/html)のみを使う。
#   PyPI/npm 等の第三者パッケージを実行時取得しないため、yt-dlp 経路より供給網リスクが低い。
#
# 前提: curl と python3 が利用可能であること。ネットワーク接続が必要。

set -uo pipefail

URL="${1:-}"
WORKDIR="${2:-.tmp/apple-session}"

die() {
  echo "STATUS=ERROR"
  echo "ERROR_MESSAGE=$1"
  exit "${2:-1}"
}

if [[ -z "$URL" ]]; then
  die "Apple Developer の動画URLが指定されていません"
fi

# URL検証: developer.apple.com の /videos/play/<event>/<session>/ 形式か
if [[ ! "$URL" =~ developer\.apple\.com/videos/play/ ]]; then
  echo "STATUS=NOT_APPLE_VIDEO"
  echo "ERROR_MESSAGE=Apple Developer の動画ページURL(developer.apple.com/videos/play/...)ではありません"
  exit 3
fi

mkdir -p "$WORKDIR" || die "作業ディレクトリの作成に失敗しました: $WORKDIR"

HTML_FILE="$WORKDIR/page.html"

# --- 1. HTML取得 ---
if ! curl -sL --fail --max-time 60 \
     -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15" \
     "$URL" -o "$HTML_FILE"; then
  die "ページの取得に失敗しました(URL不正/ネットワーク不可/非公開の可能性): $URL"
fi

# --- 2. 解析(抽出) ---
# python3 が全抽出を行い、stdoutへマニフェスト本体を出力する。
python3 - "$URL" "$WORKDIR" "$HTML_FILE" <<'PY'
import re, sys, json, html, os

url, workdir, html_file = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(html_file, encoding="utf-8", errors="replace").read()

def fail(status, msg):
    print(f"STATUS={status}")
    print(f"ERROR_MESSAGE={msg}")
    sys.exit(2)

# --- event / session を URL から ---
m = re.search(r'/videos/play/([^/]+)/(\d+)', url)
event = m.group(1) if m else ""
session = m.group(2) if m else ""
vid = f"{event}-{session}" if event else (session or "apple-session")

# --- タイトル ---
title = ""
mt = re.search(r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"', src)
if mt:
    title = html.unescape(mt.group(1)).strip()
if not title:
    mt = re.search(r'<title>(.*?)</title>', src, re.S)
    if mt:
        title = html.unescape(re.sub(r'\s+', ' ', mt.group(1))).strip()
# 末尾の " - WWDC.. - Videos - Apple Developer" や " (1)" を除去
title = re.sub(r'\s*-\s*Videos\s*-\s*Apple Developer.*$', '', title)
title = re.sub(r'\s*-\s*WWDC\d+\s*$', '', title)
title = re.sub(r'\s*\(\d+\)\s*$', '', title).strip()

# --- 尺(秒) : data-chapter-end-time の最大値 ---
duration = "NA"
ends = [int(x) for x in re.findall(r'data-chapter-end-time="(\d+)"', src)]
if ends:
    total = max(ends)
    h, r = divmod(total, 3600)
    mm, ss = divmod(r, 60)
    duration = f"{h:02d}:{mm:02d}:{ss:02d}"

# --- 公開日: og:.. / time 要素 ---
upload_date = ""
md = re.search(r'<meta[^>]+(?:property|name)="(?:video:release_date|uploadDate|article:published_time)"[^>]+content="([^"]+)"', src)
if md:
    upload_date = re.sub(r'[^0-9]', '', md.group(1))[:8]

def strip_tags(s):
    return html.unescape(re.sub(r'<[^>]+>', '', s))

# --- トランスクリプト本文 ---
transcript = ""
j = src.find('id="transcript-content"')
if j != -1:
    # 終端: トランスクリプト後に現れる sample-code / summary の supplement content 開始位置
    stops = [src.find('data-supplement-id="sample-code"', j),
             src.find('id="sample-code"', j),
             src.find('id="summary"', j),
             src.find('Related Videos', j)]
    stops = [c for c in stops if c != -1]
    end = min(stops) if stops else j + 80000
    body = src[j:end]
    t = re.sub(r'<[^>]+>', ' ', body)
    t = html.unescape(t)
    t = t.replace('id="transcript-content">', '', 1)
    t = re.sub(r'[ \t\n]+', ' ', t).strip()
    t = re.sub(r'\.([A-Z])', r'. \1', t)          # 文間スペース補正
    t = re.sub(r'(\d)([A-Z][a-z])', r'\1 \2', t)  # "harmonics.3D" 等の結合補正
    transcript = t

if not transcript:
    fail("APPLE_PARSE_ERROR",
         "トランスクリプト本文を抽出できませんでした(HTML構造の変更/ログイン要求/字幕なしの可能性)")

transcript_file = os.path.join(workdir, f"{vid}.transcript.txt")
open(transcript_file, "w", encoding="utf-8").write(transcript)

# --- 章ごと Summary: <li>TIME - <a..>TITLE</a></li><li class="chapter-summary"><p>..</p></li> ---
summary_items = []
for t, ttl, s in re.findall(
        r'<li>([\d:]+)\s*-\s*<a[^>]*>(.*?)</a></li>\s*<li class="chapter-summary"><p>(.*?)</p></li>',
        src, re.S):
    summary_items.append({
        "time": t.strip(),
        "title": strip_tags(ttl).strip(),
        "summary": strip_tags(s).strip(),
    })
summary_file = os.path.join(workdir, f"{vid}.summary.json")
open(summary_file, "w", encoding="utf-8").write(json.dumps(summary_items, ensure_ascii=False, indent=1))

# --- サンプルコード: <p>TIME - <a..>TITLE</a></p><pre class="code-source"><code>..</code></pre> ---
code_items = []
for t, ttl, code in re.findall(
        r'<p>([\d:]+)\s*-\s*<a[^>]*>(.*?)</a></p>\s*<pre class="code-source"><code>(.*?)</code></pre>',
        src, re.S):
    c = html.unescape(re.sub(r'<[^>]+>', '', code)).replace('\r', '')
    c = '\n'.join(line.rstrip() for line in c.split('\n')).strip('\n')
    code_items.append({
        "time": t.strip(),
        "title": strip_tags(ttl).strip(),
        "code": c,
    })
code_file = os.path.join(workdir, f"{vid}.code.json")
open(code_file, "w", encoding="utf-8").write(json.dumps(code_items, ensure_ascii=False, indent=1))

# --- 関連リソース: <h2>Resources</h2> 配下の <li class="document"> のみ(グローバルナビ除外) ---
# 出力形式は "TITLE :: URL"。タイトルが無ければURLのみ。
related = []
rm = re.search(r'<h2>Resources</h2>(.*?)</ul>', src, re.S)
if rm:
    block = rm.group(1)
    for href, ttl in re.findall(r'<li class="document"><a href="([^"]+)"[^>]*>(.*?)</a>', block, re.S):
        if href.startswith('/'):
            href = "https://developer.apple.com" + href
        ttl = strip_tags(ttl).strip()
        related.append(f"{ttl} :: {href}" if ttl else href)

abspath = lambda p: os.path.abspath(p)

# --- マニフェスト出力 ---
print("STATUS=OK")
print("SOURCE=apple")
print(f"ID={vid}")
print(f"EVENT={event}")
print(f"SESSION={session}")
print(f"TITLE={title}")
print(f"DURATION={duration}")
print(f"UPLOAD_DATE={upload_date}")
print(f"URL={url}")
print("SUB_LANG=en")
print(f"CHARS={len(transcript)}")
print(f"CHAPTERS={len(summary_items)}")
print(f"CODE_BLOCKS={len(code_items)}")
print(f"TRANSCRIPT_FILE={abspath(transcript_file)}")
print(f"SUMMARY_FILE={abspath(summary_file)}")
print(f"CODE_FILE={abspath(code_file)}")
print("RELATED=" + " | ".join(related))
PY
