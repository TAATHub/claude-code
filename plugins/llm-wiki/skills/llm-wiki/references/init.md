# init — ジャンル/ルートのスケルトン生成

`init <ジャンル>` は新規ジャンルの空のスケルトンを作る。`init _root` は Vault 全体の初期化で、初回のみ実行する。

## ケース1: `init _root`（初回のみ）

`WIKI_ROOT = $LLM_WIKI_VAULT_ROOT/llm-wiki` 直下に以下を作る。

```
$WIKI_ROOT/
├── index.md           # 全体カタログ
├── wiki/              # 空ディレクトリ
└── sources/
    └── _inbox/        # 未分類ソースの一時置き場（Web Clipper 等の受け皿）
```

### ディレクトリ作成

`$WIKI_ROOT` 自体および `wiki/` `sources/` `sources/_inbox/` を `mkdir -p` で作成する（既に存在しても安全）:

```bash
mkdir -p "$WIKI_ROOT/wiki" "$WIKI_ROOT/sources/_inbox"
```

`$LLM_WIKI_VAULT_ROOT` が存在しない場合（パス間違い・Vault 未作成）はエラーで停止し、ユーザーに Vault パスの確認を促す。

`sources/_inbox/` はジャンル未確定のソースの一時置き場。`ingest` 実行時に triage フェーズで既存ジャンルへ振り分けられる。詳細は [ingest.md](ingest.md) の「Phase A-0: Inbox triage」セクション。

### `$WIKI_ROOT/index.md` テンプレート

```markdown
---
title: "LLM Wiki Index"
type: root-index
created: <today>
updated: <today>
---

# LLM Wiki

このVaultはLLMが構築・維持するナレッジベース。詳細は各ジャンルの `wiki/<genre>/index.md` を参照。

## ジャンル一覧

<!-- 追記フォーマット: - [[<genre>/index|<日本語名>]] — <12〜30文字程度の1行サマリ> -->
```

ジャンル追加時の追記フォーマット・サマリ生成元・カテゴリ規約は [conventions.md](conventions.md) の「ジャンル index (`index.md`)」セクションを参照。

`<today>` は `date +%Y-%m-%d` で取得。

### 既に `_root` 初期化済みの場合

`$WIKI_ROOT/index.md` が存在していたら基本的に何もせず「初期化済み」と報告して終了する。ただし、後方互換のため `sources/_inbox/` ディレクトリが未作成なら `mkdir -p "$WIKI_ROOT/sources/_inbox"` だけは実行し、その旨を併記する（既存 vault のスキーマ追従用）。

## ケース2: `init <ジャンル>`（例: `init rdb`）

ジャンル名はスラッグ形式（小文字英数+ハイフン）にユーザーに揃えてもらう。日本語ジャンル名は別タイトルとして frontmatter に保持する。

### 生成物

```
$WIKI_ROOT/wiki/<genre>/
├── index.md
├── log.md
└── _overview.md
$WIKI_ROOT/sources/<genre>/   (空ディレクトリ)
```

### `wiki/<genre>/index.md` テンプレート

```markdown
---
title: "<ジャンル日本語名> Index"
genre: <genre>
type: genre-index
created: <today>
updated: <today>
---

# <ジャンル日本語名>

このジャンルのページカタログ。構造的・横断的な視点は `_overview.md` を参照。

## ページ一覧

<!-- 追記フォーマット: - [[ページ名]] — <12〜30文字程度の1行サマリ> -->

### <カテゴリ例>

<!-- - [[ページ名]] — <12〜30文字程度の1行サマリ> -->

## 未分類

<!-- カテゴリ判断が困難なページはここに追加（将来の lint で検出予定） -->
```

ページ追加時の追記フォーマット・カテゴリ振り分けルール・サマリ生成元・「## 未分類」の扱いは [conventions.md](conventions.md) の「ジャンル index (`index.md`)」セクションが正典。`_overview.md` との役割分担も同セクションの表を参照。

### `wiki/<genre>/log.md` テンプレート

```markdown
---
title: "<ジャンル日本語名> Log"
genre: <genre>
type: log
created: <today>
updated: <today>
---

# 操作ログ

追記専用。古いエントリは消さない。

## <today>

- ジャンル初期化
```

### `wiki/<genre>/_overview.md` テンプレート

```markdown
---
title: "<ジャンル日本語名> Overview"
genre: <genre>
type: overview
created: <today>
updated: <today>
---

# <ジャンル日本語名> 概要

このジャンルが扱う範囲・前提・主要トピックの構造。ingestを重ねながら更新する。

## 想定する読者・視点

<!-- 何のための知識か、どんな視点で書くか -->

## 知識マップ

<!-- 主要コンセプトと相互関係 -->
```

### 全体 index 更新

`$WIKI_ROOT/index.md` の「ジャンル一覧」セクションに新規ジャンル行を追加（既にあればスキップ）し、frontmatter の `updated` を today に更新する。

- 追記フォーマット（`- [[<genre>/index|<ジャンル日本語名>]] — <12〜30文字程度の1行サマリ>`）は [conventions.md](conventions.md) の「ジャンル index (`index.md`)」セクションが正典
- サマリは `_overview.md` 冒頭の概要から要約する
- 新設直後で `_overview.md` が空のまま追加する場合はサマリを `<TODO>` プレースホルダにし、後続の ingest 時点で更新する

## 既存ジャンル時の挙動

`$WIKI_ROOT/wiki/<genre>/` が既に存在する場合は何もせず「ジャンル `<genre>` は既に存在します」と警告して終了する。上書きはしない。

## 完了レポート

生成したファイルパスを箇条書きで列挙し、次に何をすべきか（`ingest <パス>` の例）を1行示す。
