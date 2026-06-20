# 記述規約

LLM Wiki 内のすべてのページが従う共通規約。

## 言語

タイトル・本文・コメントすべて **日本語** で書く。コードブロック内の識別子・コマンド・URLは原文のまま。

## frontmatter

すべてのページに YAML frontmatter を付ける。

### Wikiページ用

```yaml
---
title: "ページタイトル"
genre: <genre>
type: concept | entity | source | source-summary | comparison | synthesis | overview | log | genre-index | root-index
sources: ["[[ソース名1]]", "[[ソース名2]]"]
related: ["[[関連ページ1]]", "[[関連ページ2]]"]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

### type の使い分け

| type | 用途 |
|---|---|
| `concept` | 抽象概念・理論・手法 |
| `entity` | 具体的なツール・製品・人物 |
| `source` | 単一ソースの **raw 原文**（`sources/<genre>/` 配下。本文は無加工、frontmatter にメタ付与） |
| `source-summary` | **旧仕様**。単一ソースの要約（`sources/<genre>/` 配下）。新規には使わず、既存ファイルの完了マーカーとしてのみ有効 |
| `comparison` | 複数概念の比較表 |
| `synthesis` | 複数ソース由来の統合知見（横断ページ）|
| `overview` | ジャンル概要 (`_overview.md` 専用) |
| `log` | 操作ログ (`log.md` 専用) |
| `genre-index` | ジャンル内カタログ (`wiki/<genre>/index.md` 専用) |
| `root-index` | 全体カタログ (`$WIKI_ROOT/index.md` 専用) |
| `proposal` | curiosity/lint が生成する修正提案 (`_proposals/` 配下、詳細は [proposals.md](proposals.md)) |

### 必須・任意

- 必須: `title`, `genre`(ルート以外), `type`, `created`, `updated`
- 任意: `sources`, `related`, `source_url`, `source_kind`, `fetched_at`, `generated_pages` (`source` / `source-summary` で使用)

ただし `type: proposal` は **本規約の対象外**。proposal ファイルは [proposals.md](proposals.md) の「frontmatter スキーマ」に従う独自のフィールド構成を持つ（`title` / `updated` は不要、代わりに `origin` / `kind` / `target` / `status` / `confidence` などを使用）。

### `source_kind` の値

`source` / `source-summary` の `source_kind` フィールドに使う値:

| 値 | 用途 |
|---|---|
| `web` | Web 記事・ブログ・X ポストなど |
| `pdf` | PDF 文書 |
| `book` | 書籍 |
| `article` | 学術論文・技術記事 |
| `code` | GitHub リポジトリ・ソースコード |
| `conversation` | Claude Code との対話セッション（`/llm-wiki save` 由来） |
| `note` | ユーザー手動作成のメモ |

### `type: source` はコンパイル完了マーカー

`sources/<genre>/` 配下のファイルにおいて **`type` が取り込み済み値（`source` または旧 `source-summary`）かどうかが ingest 完了状態を表す唯一の真実**。新規 ingest は raw 原文を保持して `type: source` を立てる。`type: source-summary` は旧仕様の要約済みファイルで、完了状態としてそのまま有効（再取り込みはしない）。

| 状態 | frontmatter の `type` | 意味 |
|---|---|---|
| 未取り込み（コンパイル待ち） | フィールドなし、または `source`/`source-summary` 以外 | 次回 `/llm-wiki ingest` の対象 |
| 取り込み済み（raw） | `type: source` | コンパイル完了。本文は raw 原文。再処理したい場合は `recompile` |
| 取り込み済み（旧要約） | `type: source-summary` | 旧仕様で要約済み。完了状態として有効。再処理は `recompile` |

検出は frontmatter のこのフィールド 1 つで判定する。`log.md` の文字列 grep に依存しない（Unicode 正規化や引用符差異の問題を避けるため）。

#### 未取り込みファイルが取りうる形

未取り込みファイルは「**投入経路（場所）**」と「**出自・状態**」の 2 軸で整理される。

##### 投入経路（場所による分類）

- **`inbox/` 配下**: ジャンル未確定。`ingest` の triage フェーズで既存ジャンルへ振り分けてから処理される
- **`sources/<genre>/` 配下**: ジャンル確定済み。`ingest` で直接 Phase B に進む

##### 出自・状態（frontmatter による分類）

- **Web Clipper 出力**: `tags: ["clippings"]` だけがあり、`type` フィールドなし
- **手動作成ノート**: ユーザーが直接置いたメモ。frontmatter なし、または `type` 未指定
- **URL ingest の Phase A 直後**: WebFetch で取得した生コンテンツが保存され、`type` 未設定
- **Phase B が途中で失敗**: 部分的な書き換えがあっても `type` が立っていなければ未完了扱い

両軸は直交する（例: 「`inbox/` 配下の Web Clipper 出力」「`<genre>` 配下の手動メモ」など）。

#### 手動でメモを作る際の注意

ジャンルが未確定 / 迷う場合は `inbox/` に置く。ジャンルが確定しているなら `sources/<genre>/` に直接置いてもよい。いずれの場合も:

- frontmatter の `type` を **書かない**（推奨）。次の `/llm-wiki ingest` で自動的に処理される
- `type: source`（や旧 `source-summary`）を最初から書くと未取り込み判定がスキップされてしまう
- 既に `type: source`/`source-summary` 済みのファイルを再評価したい場合は `/llm-wiki recompile <パス>` を使う

#### Web Clipper の保存先

Obsidian Web Clipper の保存先を `inbox/` に向ける運用を推奨。Clipping 時にジャンルを判断する必要がなく、ingest 実行時にまとめて triage できる。既に `Clippings/` 等別フォルダで運用している場合は、ingest 前に手動で `inbox/` に移すか、保存先を切り替える。

### 日付

- フォーマットは `YYYY-MM-DD`
- Bash の `date +%Y-%m-%d` で取得した値を使う（手書きしない）
- 新規作成時は `created = updated = today`
- 更新時は `updated` のみ today に書き換え、`created` は触らない

## wikilink 記法

- ページ参照: `[[ページ名]]`（ファイル名のみ、相対パスを使わない）
- 別名表示: `[[ページ名|表示テキスト]]`
- セクション参照: `[[ページ名#セクション名]]`
- ジャンル間リンクも同じ記法（Obsidian がパスを解決する）

ページ名にスラッシュは含めない（Obsidian側で曖昧になるため）。同名衝突したら接尾辞で区別する（例: `インデックス_RDB`）。

## ファイル名と title

- ファイル名: ページタイトルそのままの日本語ファイル名でよい（Obsidianが扱える）
- スペースは含めない方が wikilink が安定する。複合語はそのまま続けるか中黒「・」で区切る
- 例: `SELECT最適化.md`、`B木インデックス.md`、`PostgreSQL概要.md`

## ページ本文の構造（推奨）

```markdown
# <タイトル>

## 概要

<2〜5行で要旨>

## 詳細

<本論>

## 関連ページ

- [[関連ページ1]] — <一行説明>
- [[関連ページ2]]

## ソース

- [[sources/<genre>/<source>]]
```

`## 関連ページ` と `## ソース` は本文末尾に置き、frontmatter の `related` / `sources` と内容を一致させる。

## 操作ログ (log.md)

- 追記専用、古いエントリは消さない
- 日付セクション (`## YYYY-MM-DD`) 配下に箇条書き
- 内容は「何を」「どのページに対して」「なぜ」が分かる粒度

## ジャンル index (`index.md`)

各ジャンルの **カタログ** を担う。新ページ追加のたびに更新する。`_overview.md`（知識マップ）とは役割を明確に分ける。

### 標準セクション構造

```markdown
---
title: "<ジャンル日本語名> Index"
genre: <genre>
type: genre-index
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <ジャンル日本語名>

このジャンルのページカタログ。構造的・横断的な視点は `_overview.md` を参照。

## ページ一覧

### <カテゴリ名1>

- [[ページ名]] — <12〜30文字程度の1行サマリ>

### <カテゴリ名2>

- [[ページ名]] — <12〜30文字程度の1行サマリ>

## 未分類

<!-- カテゴリ判断が困難なページはここに追加（将来の lint で検出予定） -->
```

### 追記フォーマット（正典）

`index.md` の「## ページ一覧」配下にページを追記するときの形式。`init` テンプレート、`ingest` B-6, `save` Step 8 はすべてこの形式に従う。

```
- [[ページ名]] — <12〜30文字程度の1行サマリ>
```

- **サマリ**: ページの中核を簡潔に表現する 12〜30 文字程度の説明文。生成元は呼び出し元によって異なる:
  - `ingest`: B-2 の要点抽出から
  - `save`: Step 1 の要点抽出から
  - `init` の root index: `_overview.md` 冒頭概要から（ジャンル新設直後で `_overview.md` が空なら、暫定的に `<TODO>` プレースホルダ可）
- **カテゴリ振り分け**:
  - 既存の `### <カテゴリ>` セクションに収まれば末尾に追記
  - 新カテゴリが必要なら新セクションを追加
  - カテゴリ判断が困難なら `## 未分類` セクションに追記
- **カテゴリ命名**: ジャンルに応じて柔軟に。例: 基礎概念 / 設計パターン / 運用 / トラブルシューティング

### root index (`$WIKI_ROOT/index.md`)

ジャンル一覧を保持する。各行も同様に 1 行サマリを付ける:

```
- [[<genre>/index|<日本語名>]] — <12〜30文字程度の1行サマリ>
```

サマリの生成元はジャンル新設時の `_overview.md` 冒頭概要。

### 役割分担（`_overview.md` との関係）

| ファイル | 役割 | 更新頻度 |
|---|---|---|
| `index.md` | **カタログ**（ページ一覧、簡潔な一行説明、カテゴリ別） | 新ページ追加のたびに必ず |
| `_overview.md` | **知識マップ**（構造的・横断的な視点） | 構造変化時のみ |

`index.md` はフラットな目次、`_overview.md` は階層的な地図、というイメージ。

## ジャンル概要 (`_overview.md`)

各ジャンルの「知識マップ」を担う中心ファイル。新規ページが入るたびに **必ずしも更新する必要はないが**、ジャンルの構造が変化したときに更新する。`index.md`（カタログ、毎回更新）との役割分担は「ジャンル index (`index.md`)」セクションの「役割分担」表を参照。

### 標準セクション構造

```markdown
---
title: "<ジャンル名> Overview"
genre: <genre>
type: overview
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <ジャンル名> 概要

<このジャンルが扱う範囲の 2〜5 行の説明>

## 想定する読者・視点

<このジャンルの知識を誰が・どんな目的で参照するか。記述粒度の指針>

## 知識マップ

<ジャンル内の主要トピックとその相互関係をツリー or 箇条書きで表現>

\`\`\`
<genre>
├─ <カテゴリA>
│   ├─ [[ページ1]]（一行説明）
│   └─ [[ページ2]]
└─ <カテゴリB>
    └─ [[ページ3]]
\`\`\`

## 横断テーマ

- **<横断テーマ名>**: 複数ページにまたがる中核的な論点。3 ページ以上で扱われる発想や対立軸を箇条書きで
```

### 更新トリガー（このいずれかに該当する時に更新）

- 新カテゴリが必要になる新ページが追加された（既存「## ページ一覧」のどのカテゴリにも収まらない）
- 既存カテゴリの中で **3 ページ以上** が同じ細分テーマを持っており、サブカテゴリの細分化が妥当
- 既存ページが分割され、上位概念が浮上した
- 横断テーマ（`## 横断テーマ`）に追加すべき新しい対立軸・問題意識が出た

### 更新しないでよいケース

- 既存カテゴリに自然に収まる単一の新ページ追加
- 既存ページの軽微な更新
- 新ページが他ページと関連はあるが、ジャンルの構造を変えない

## 禁止事項

- ソース raw 本文の改変（`sources/` 配下の本文は取得した原文のまま。更新してよいのは frontmatter メタ（`type`/`generated_pages`/`updated` 等）のみで、本文テキストは触らない）
- frontmatter なしのページ作成
- 相対パスでの wikilink (`[[../foo/bar]]`)
- 英語のみのページタイトル（コードや製品名はOK、ただしページタイトル全体は日本語ベース）
