# init — ジャンル/ルートのスケルトン生成

`init <ジャンル>` は新規ジャンルの空のスケルトンを作る。`init _root` は Vault 全体の初期化で、初回のみ実行する。

## ケース1: `init _root`（初回のみ）

`WIKI_ROOT = $LLM_WIKI_VAULT_ROOT/llm-wiki` 直下に以下を作る。

```
$WIKI_ROOT/
├── index.md           # 全体カタログ
├── wiki/              # 空ディレクトリ
└── sources/           # 空ディレクトリ
```

### ディレクトリ作成

`$WIKI_ROOT` 自体および `wiki/` `sources/` を `mkdir -p` で作成する（既に存在しても安全）:

```bash
mkdir -p "$WIKI_ROOT/wiki" "$WIKI_ROOT/sources"
```

`$LLM_WIKI_VAULT_ROOT` が存在しない場合（パス間違い・Vault 未作成）はエラーで停止し、ユーザーに Vault パスの確認を促す。

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

<!-- ジャンル追加時に1行ずつ追記 -->
```

`<today>` は `date +%Y-%m-%d` で取得。

### 既に `_root` 初期化済みの場合

`$WIKI_ROOT/index.md` が存在していたら何もせず「初期化済み」と報告して終了する。

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

このジャンルのページカタログ。`_overview.md` も参照。

## ページ一覧

<!-- ページ追加時に [[ページ名]] を1行ずつ追記 -->
```

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

`$WIKI_ROOT/index.md` の「ジャンル一覧」セクションに `- [[<genre>/index|<ジャンル日本語名>]]` を追記（既にあればスキップ）し、frontmatter の `updated` を today に更新する。

## 既存ジャンル時の挙動

`$WIKI_ROOT/wiki/<genre>/` が既に存在する場合は何もせず「ジャンル `<genre>` は既に存在します」と警告して終了する。上書きはしない。

## 完了レポート

生成したファイルパスを箇条書きで列挙し、次に何をすべきか（`ingest <パス>` の例）を1行示す。
