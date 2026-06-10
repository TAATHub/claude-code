---
allowed-tools:
    - Bash
    - Read
    - Write
    - AskUserQuestion
    - WebSearch
    - WebFetch
argument-hint: <Apple Developer video URL> [出力先パス]
description: Apple Developerの動画セッション(WWDC/Tech Talks等)ページから公式トランスクリプト・章ごとSummary・サンプルコード・関連リンクを取得し、要約＋詳細解説＋全文をMarkdownファイルに書き出すスキル。yt-dlpではなくページHTMLから一次情報を抽出する。「WWDCの文字起こし」「Apple Developerセッション」「developer.apple.comの動画をMarkdownに」「apple-developer-video」などのリクエストで使用。
name: apple-developer-video
---

# Apple Dev Session Transcript

Apple Developer の動画セッションページ（`developer.apple.com/videos/play/...`）から、
**公式トランスクリプト・章ごとSummary・サンプルコード・関連リンク**を取得し、
**要約＋詳細解説（サンプルコードをインライン配置）＋整形済み全文トランスクリプト**を1つのMarkdownファイルに書き出す。

> YouTube版（youtube-transcriptスキル）との違い: Apple公式ページは yt-dlp では字幕トラックを取得できない。
> 本スキルはページHTMLに埋め込まれた4つの supplement（transcript / summary / sample-code / 関連リンク）を
> **一次情報**として抽出する。公式トランスクリプトは原語(英語)逐語で、API名・サンプルコードが公式表記で確定するため、
> YouTube自動字幕より上位。同一セッションがYouTubeにもある場合は本スキルを優先する。

## 前提

- `curl` と `python3` が利用可能であること。ネットワーク接続が必要。
- **供給網ハードニング**: 本スキルの取得スクリプトは `curl`（システム標準）と `python3` 標準ライブラリのみを使う。
  PyPI/npm 等の第三者パッケージを実行時取得しないため、yt-dlp 経路より供給網リスクが低い（バージョン固定の管理も不要）。
- スクリプトは**絶対パスで直接実行**する（`cd` を含む compound command は使わない）。
  スクリプト本体: `${CLAUDE_PLUGIN_ROOT}/skills/apple-developer-video/scripts/fetch_apple_session.sh`
  （プラグインのインストール先により実体パスは異なる。実行時はそのフルパスを使う）

## Step 1: 入力の解釈

`$ARGUMENTS` を受け取り、空白で分割して解釈する。

- 先頭の `http`/`https` で始まるトークン → **Apple Developer 動画URL**
  （`developer.apple.com/videos/play/<event>/<session>/` 形式。例: `.../wwdc2026/279/`）
- 2つ目のトークンがあれば → **出力先パス**（ディレクトリ or ファイルパス）
- **URLが無い場合**: `AskUserQuestion` でURLを尋ねる
- **URLがApple Developer動画でない場合**（YouTube等）: 本スキルの対象外。youtube-transcriptスキルの利用を案内する
- **出力先が無い場合**: `AskUserQuestion` で保存先を尋ねる
  - 選択肢例: 「llm-wiki/inbox に保存」「カレントディレクトリに保存」「パスを直接指定」
  - 「llm-wiki/inbox」が選ばれた場合の実パスは環境依存。`/llm-wiki` スキルが管理する Vault の
    `llm-wiki/inbox` を使う（パスをハードコードせず、ユーザーの環境に合わせて解決する）。

## Step 2: 取得

一時作業ディレクトリは**プロジェクト内の `.tmp/apple-session`**（`/tmp` は使わない）。

スクリプトを絶対パスで実行する:

```bash
/絶対パス/scripts/fetch_apple_session.sh "<URL>" ".tmp/apple-session"
```

stdout にKEY=VALUE形式のマニフェストが出力される。`STATUS` を確認する:

- `STATUS=OK`: 以下を取得。
  - メタ: `SOURCE`(=apple。下流で取得元を判別するための識別子) `ID` `EVENT` `SESSION` `TITLE` `DURATION` `UPLOAD_DATE`(空のことあり) `URL` `SUB_LANG`(=en) `CHARS` `CHAPTERS` `CODE_BLOCKS`
  - `TRANSCRIPT_FILE`: 逐語トランスクリプト全文(原語=英語)。`Read` で読み込む。
  - `SUMMARY_FILE`: 章ごと要約のJSON配列 `[{time,title,summary}]`。`Read` で読み込む。
  - `CODE_FILE`: 公式サンプルコードのJSON配列 `[{time,title,code}]`。`Read` で読み込む（`CODE_BLOCKS=0` の回もある）。
  - `RELATED`: 関連ドキュメントリンク。`TITLE :: URL` を ` | ` で連結（無いこともある）。
  - `WARN`(任意): 出力された場合はHTML構造変化の兆候(章Summary・サンプルコードが両方0件)。ユーザーへの報告に一言添える。
- `STATUS=NOT_APPLE_VIDEO`: Apple Developer動画URLでない。youtube-transcriptスキルを案内して終了。
- `STATUS=APPLE_PARSE_ERROR`: HTML構造変化/ログイン要求/トランスクリプト無しの可能性。
  その旨を伝え、同一セッションのYouTubeミラーがあれば youtube-transcript での取得を提案して終了。
- `STATUS=ERROR`: `ERROR_MESSAGE` を提示して終了。

## Step 3: Markdownファイルの生成

`Read` したトランスクリプト・Summary・Code を**一次情報**として、以下の構成でMarkdownを組み立てる。
**要約・解説は日本語**で書く（トランスクリプト本文・サンプルコードは原語・原文のまま）。

````markdown
# <TITLE> 文字起こしと解説

- **動画**: <URL>
- **投稿者/チャンネル**: Apple Developer（<EVENT大文字> Session <SESSION>）
- **尺**: <DURATION>
- **公開日**: <UPLOAD_DATEがあればYYYY-MM-DDに整形。無ければEVENTから推定し「(推定)」を付すか省略>
- **出典**: **Apple Developer公式ページ**の Transcript / Summary / Code 各タブ（ページHTMLから抽出した一次情報）
- **取得日**: <`date +%Y-%m-%d` で取得した現在日付>

> 本ドキュメントはApple Developer公式ページの **Transcript（逐語全文）・Summary（章ごと要約）・Code（サンプルコード）** を一次情報として統合・整理したもの。
> 全文・サンプルコード・API名は公式表記に準拠する（推定補正なし）。日本語の要約・解説は筆者による。
> 公式サンプルコードは「詳細解説」の各該当トピック内にインラインで配置している。

---

## TL;DR（要約）

> Apple公式ページの「Summary」タブの内容を反映（原文の主張に忠実）。各章の詳細は詳細解説を参照。

<SUMMARY_FILE を基に、全体像を1〜2文で述べたあと、要点を3〜6項目の箇条書きに絞る。
 章を全件列挙しない・タイムスタンプを羅列しない（章ごとの詳細は「詳細解説」に委ねる）。
 TL;DRは読者が全体像を素早く掴むためのものに留める。
 重要なAPI名・用語は公式表記のまま太字やコードスパンで示す。>

## 詳細解説

<トランスクリプトの流れに沿って章立て(SUMMARY_FILEの章見出しとタイムスタンプを使う)。
 各章で重要な用語・主張・手順・数値・API名を漏らさずまとめる。
 CODE_FILE の各サンプルコードは、対応するトピックの説明直後に
 「公式サンプルコード（<time>）：」の小見出しを付けてインライン配置する（```swift フェンス）。
 LODやreverb等リスト項目に紐づくコードは、リスト子要素としてインデント配置し階層を崩さない。>

## 関連リソース（公式ページより）

<RELATED を箇条書き。`TITLE :: URL` を [TITLE](URL) のMarkdownリンクにする。
 RELATEDが空ならこのセクションは省略。>

## 全文トランスクリプト（公式英語・逐語）

<Readした逐語全文をそのまま掲載（改変しない。要約・解説の根拠として残す）。>
````

### 内容生成の指針

- **TL;DR**: SUMMARY_FILE（公式Summary）を基に、全体像（1〜2文）＋要点3〜6項目に絞る。章を全件列挙せず、章ごとの詳細は詳細解説に委ねる。冗長な章テーブルやタイムスタンプの羅列は作らない。
- **詳細解説**: トランスクリプトの流れに沿って章立て。長い動画でも省略せずカバー。
  API名・コマンド・固有名詞は公式表記（TRANSCRIPT/SUMMARY/CODEで確定したもの）に従い、**推定補正はしない**。
- **サンプルコード**: CODE_FILE の内容を改変せず、対応トピックの直後にインライン配置（別セクションにまとめない）。
- **全文**: 逐語トランスクリプトを改変せず掲載。

### Web検索による補強（限定的）

Apple公式トランスクリプト/Summary/Codeは一次情報のため、原則として追加のWeb検索は不要。
ただし「動画が前提とする背景知識の補足」や「言及された別セッション/ドキュメントの所在特定」に限り、
`WebSearch`（必要なら `WebFetch`）で補ってよい。補強した情報は本文中で「（補足: …）」と区別し、出典URLを添える。
全文トランスクリプトには外部情報を混ぜない。

## Step 4: ファイル書き出し

- **ファイル名**: タイトルから生成。OSで使えない文字 `/ \ : * ? " < > |` は全角や `-` に置換し、前後空白を除去。
  例: `<安全化したタイトル> 文字起こしと解説.md`
- **保存先**: Step 1で確定した出力先。
  - ディレクトリ → その直下に上記ファイル名で保存
  - ファイルパス（`.md`で終わる）→ そのパスに保存
- `Write` で書き出す。

## Step 5: 後片付けと報告

- `.tmp/apple-session` 配下の一時ファイル（`page.html`, `*.transcript.txt`, `*.summary.json`, `*.code.json`）を削除する。
- ユーザーに、作成したファイルへの**クリック可能なMarkdownリンク**と、取得した章数・サンプルコード数・主な内容の要点を報告する。
- 保存先が llm-wiki/inbox の場合、「`/llm-wiki ingest` でwikiノート化できる」と一言添えてよい（自動実行はしない）。

## エラー時の扱い

- `curl`/`python3` が見つからない・ネットワーク不可 → 原因を伝え、取得できないことを明示。
- `NOT_APPLE_VIDEO` → 対象外。YouTube動画なら youtube-transcript スキルを案内。
- `APPLE_PARSE_ERROR` → HTML構造変化/ログイン要求/トランスクリプト無しの可能性。
  スクリプトの抽出ロジック（`id="transcript-content"` 等）の更新が必要かもしれない旨を伝える。
  YouTubeミラーがあれば youtube-transcript での取得を提案。
- 非公開/地域制限などで取得不可 → その旨を伝える。
