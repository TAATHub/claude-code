---
allowed-tools:
    - Bash
    - Read
    - Write
    - AskUserQuestion
argument-hint: <YouTube URL> [出力先パス]
description: YouTube動画のリンクから文字起こし(トランスクリプト/スクリプト)を取得し、要約・詳細解説・全文をMarkdownファイルに書き出すスキル。yt-dlpで字幕を取得し日本語優先で整形する。「YouTubeの文字起こし」「動画のトランスクリプト」「この動画をMarkdownに」「youtube-transcript」などのリクエストで使用。
name: youtube-transcript
---

# YouTube Transcript

YouTube動画の字幕を取得し、**要約＋詳細解説＋整形済み全文トランスクリプト**を1つのMarkdownファイルに書き出す。

## 前提

- `uv`/`uvx` が利用可能であること（`yt-dlp` は `uvx` が都度取得する）。
- ネットワーク接続が必要。
- スクリプトは**絶対パスで直接実行**する（`cd` を含む compound command は使わない）。
  スクリプト本体: `${CLAUDE_PLUGIN_ROOT}/skills/youtube-transcript/scripts/fetch_transcript.sh`
  （プラグインのインストール先により実体パスは異なる。実行時はそのフルパスを使う）

## Step 1: 入力の解釈

`$ARGUMENTS` を受け取り、空白で分割して解釈する。

- 先頭の `http`/`https` で始まるトークン → **YouTube URL**
- 2つ目のトークンがあれば → **出力先パス**（ディレクトリ or ファイルパス）
- **URLが無い場合**: `AskUserQuestion` でYouTube URLを尋ねる
- **出力先が無い場合**: `AskUserQuestion` で保存先を尋ねる
  - 選択肢例: 「llm-wiki/inbox に保存」「カレントディレクトリに保存」「パスを直接指定」
  - llm-wiki/inbox の絶対パス: `/Users/taat/Library/Mobile Documents/iCloud~md~obsidian/Documents/WikiVault/llm-wiki/inbox`

## Step 2: 字幕・メタ情報の取得

一時作業ディレクトリは**プロジェクト内の `.tmp/yt-transcript`**（`/tmp` は使わない）。

スクリプトを絶対パスで実行する:

```bash
/絶対パス/scripts/fetch_transcript.sh "<URL>" ".tmp/yt-transcript"
```

stdout にKEY=VALUE形式のマニフェストが出力される。`STATUS` を確認する:

- `STATUS=OK`: `TITLE` `UPLOADER` `DURATION` `UPLOAD_DATE` `URL` `SUB_LANG` `WORDS` `TRANSCRIPT_FILE` を取得。
  `TRANSCRIPT_FILE` のパスを `Read` で読み込み、整形済みトランスクリプト本文を得る。
- `STATUS=NO_SUBTITLES`: 字幕が存在しない。ユーザーにその旨を伝えて終了（無理に本文生成しない）。
- `STATUS=ERROR`: `ERROR_MESSAGE` を提示して終了。

> 補足: スクリプトは日本語字幕(手動/自動/翻訳)を優先し、無ければ原語(英語等)にフォールバックする。
> `SUB_LANG` が `en` 等の場合、トランスクリプト全文は原語のまま。要約・解説は日本語で書く。

## Step 3: Markdownファイルの生成

`Read` した整形済みトランスクリプトを**一次情報**として、以下の構成でMarkdownを組み立てる。
要約・解説は**日本語**で書く（トランスクリプト本文は原語のまま掲載）。

````markdown
# <動画タイトル> 文字起こしと解説

- **動画**: <URL>
- **投稿者/チャンネル**: <UPLOADER>
- **尺**: <DURATION>
- **公開日**: <UPLOAD_DATE を YYYY-MM-DD に整形>
- **字幕言語**: <SUB_LANG>（ja=日本語 / en=英語 など。自動字幕の場合はその旨注記）
- **取得日**: <`date +%Y-%m-%d` で取得した現在日付>

> 本ドキュメントは公式/投稿者の字幕(yt-dlpで取得)を一次情報として要約・整理したもの。
> 自動字幕の場合は聞き起こし誤りを含む可能性があるため、重要箇所は原典で確認すること。

---

## TL;DR（要約）

<動画全体の要点を箇条書き3〜6点で。>

## 詳細解説

<トランスクリプトを章立てして解説。トピックごとに見出しを立て、
重要な用語・主張・手順・コード・数値を漏らさずまとめる。
話者が複数いる場合は役割や発言の対応も補足する。>

## 全文トランスクリプト

<Readした整形済み全文をそのまま掲載。話者交代マーカー「›」は維持する。>
````

### 内容生成の指針

- **要約**: 動画のジャンルを問わず要点を端的に。技術動画ならAPI/手順/数値、対談なら主張/結論。
- **詳細解説**: トランスクリプトの流れに沿って章立て。長い動画でも省略せずカバーする。
  コード・コマンド・固有名詞は正確に。字幕由来で不確かな箇所は「（字幕の聞き起こし、要確認）」と明記。
- **全文**: 整形済みトランスクリプトを改変せず掲載（要約・解説の根拠として残す）。

## Step 4: ファイル書き出し

- **ファイル名**: 動画タイトルから生成。OSで使えない文字 `/ \ : * ? " < > |` は全角や `-` に置換し、前後空白を除去。
  例: `<安全化したタイトル> 文字起こしと解説.md`
- **保存先**: Step 1で確定した出力先。
  - 出力先がディレクトリ → その直下に上記ファイル名で保存
  - 出力先がファイルパス（`.md`で終わる）→ そのパスに保存
- `Write` で書き出す。

## Step 5: 後片付けと報告

- `.tmp/yt-transcript` 配下の一時ファイル（`*.vtt`, `*.transcript.txt`）を削除する。
- ユーザーに、作成したファイルへの**クリック可能なMarkdownリンク**と、取得した字幕言語・語数・主な内容の要点を報告する。
- 保存先が llm-wiki/inbox の場合、「`/llm-wiki ingest` でwikiノート化できる」と一言添えてよい（自動実行はしない）。

## エラー時の扱い

- `uvx`/`yt-dlp` が見つからない・ネットワーク不可 → 原因を伝え、字幕が取れないことを明示。
- 字幕なし(`NO_SUBTITLES`) → 文字起こし不可。自動文字起こし(音声認識)はこのスキルの範囲外と伝える。
- 非公開/年齢制限/地域制限などで取得不可 → その旨を伝える。
