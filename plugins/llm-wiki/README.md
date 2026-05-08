# llm-wiki

Andrej Karpathy が提唱する **LLM Wiki** パターンを Obsidian Vault 上に構築・維持する Claude Code 用スキル。ソース原本を変更せず、要約と Wiki ページの相互リンクで知識を蓄積していく。

## インストール

`taat-marketplace` 経由でインストール:

```
/plugin marketplace add TAATHub/claude-code
/plugin install llm-wiki@taat-marketplace
```

インストール後、後述の[セットアップ](#セットアップ)で `LLM_WIKI_VAULT_ROOT` を設定すれば利用開始。

## 仕組み

1. **ingest** — Web Clipper・URL・手動ノートのいずれの入口からも、`sources/<genre>/` のソースを読み込み、要点を抽出して Wiki ページを生成
2. **save** — 直前の Claude Code 会話を `source_kind: conversation` として取り込み、議論や設計判断を Wiki 化
3. **query** — Wiki 横断検索 + 統合回答 + 必要に応じた新ページ提案
4. **lint** — 矛盾・孤立ページ・欠落リンク・古い情報を 5 観点で監査（レポートのみ、自動修正なし）
5. **recompile** — 取り込み済みソースをスキーマ進化に合わせて再評価（メンテナンス用）
6. **init** — 新ジャンルや Vault 全体のスケルトン生成

## 動詞ディスパッチ

| 動詞 | 用途 |
|---|---|
| `init <ジャンル>` | 新ジャンルのスケルトン生成（初回は `init _root`） |
| `ingest [パス\|URL]` | ソース取り込み + コンパイル（引数なしは未取り込み全件処理） |
| `save [タイトル]` | 直前会話を `source_kind: conversation` として取り込み + コンパイル |
| `recompile <パス>` | 取り込み済みソースの再コンパイル（メンテナンス用） |
| `query <質問>` | Wiki 検索・統合回答・必要なら新ページ提案 |
| `lint` | Vault 健全性チェック（レポート出力のみ） |

## 設計の特徴

### 取り込み状態は frontmatter `type` で判定

`sources/<genre>/<file>.md` の取り込み状態は **frontmatter の `type: source-summary` の有無** で判定する。`log.md` の文字列 grep に依存しない（Unicode 正規化や引用符差異の問題を回避）。

- `type: source-summary` あり → 取り込み済み（`recompile` で再処理可）
- `type` フィールドなし、または他の値 → 未取り込み（次回 `ingest` の対象）

### 内部 Phase A / Phase B 構造

ingest は内部的に「Phase A（収集確定）」と「Phase B（コンパイル）」の 2 段階に分かれている。Phase B 完了時にのみ `type: source-summary` を立てる設計のため、途中失敗時は再実行で安全に復旧できる（冪等）。

### ジャンル単位のディレクトリ分割 + 知識マップ

`wiki/<genre>/` でディレクトリを切り、各ジャンルに `_overview.md`（知識マップ）と `index.md`（カタログ）を持つ。`_overview.md` は **構造変化があった時のみ** 更新する（毎ページ追加では更新しない）。

## ディレクトリ構造

```
<Vault>/llm-wiki/           # = $WIKI_ROOT
├── index.md                # 全体カタログ（ジャンル一覧）
├── wiki/<genre>/
│   ├── index.md            # ジャンル内ページカタログ
│   ├── log.md              # ジャンル内操作ログ（追記専用）
│   ├── _overview.md        # ジャンル概要・知識マップ
│   └── <ページ名>.md
└── sources/<genre>/        # ソース要約（原本は別所在）
```

## 前提

- Obsidian Vault が既に存在すること
- Web Clipper でソースを `sources/<genre>/` に保存する運用を推奨

## セットアップ

このスキルは Vault のルートパスを `LLM_WIKI_VAULT_ROOT` 環境変数で受け取る。恒久的な設定は次の 2 通りのいずれか。

### 方法 1: シェル起動スクリプト

`~/.zshrc` などに追加:

```bash
export LLM_WIKI_VAULT_ROOT="$HOME/ObsidianVault"
```

### 方法 2: Claude Code の `settings.json` / `settings.local.json`

`env` ブロックに記載すると Claude Code 起動時に自動で環境変数として注入される。

```json
{
  "env": {
    "LLM_WIKI_VAULT_ROOT": "/absolute/path/to/Vault"
  }
}
```

書き込み先の選択肢:

| 設定ファイル | 適用範囲 | git 管理 |
|---|---|---|
| `~/.claude/settings.json` | ユーザー全体（全プロジェクト） | — |
| `<project>/.claude/settings.json` | プロジェクト内 | コミット対象 |
| `<project>/.claude/settings.local.json` | プロジェクト内・個人ローカル | コミット対象外 |

個人の Vault パスを共有しないなら `~/.claude/settings.json` か `.claude/settings.local.json` が無難。

### 方法 3: 初回利用時にスキルが質問（フォールバック）

恒久設定が未設定なら、`init _root` 等の操作時に Vault パスを質問する。回答した値は **そのセッション内のみ** 保持される（次回セッションでも環境変数が未設定なら再度尋ねる）。

## 入口の使い分け

| シナリオ | 推奨動詞 |
|---|---|
| Web 記事を読んだ | Web Clipper で `sources/<genre>/` に保存 → `/llm-wiki ingest` |
| URL をその場で取り込みたい | `/llm-wiki ingest <URL>` |
| 手書きメモを Wiki 化 | `sources/<genre>/` に手動で配置 → `/llm-wiki ingest` |
| 会話で得た知見を残す | `/llm-wiki save` |
| Wiki 構造を進化させた後 | `/llm-wiki recompile <パス>` |

## 安全側の方針

- 自動コミットしない（git 操作はユーザーが明示指示時のみ）
- ソース原本は変更不可
- 破壊的操作（ページ削除・大規模リネーム）の前確認
- lint はレポートのみ、自動修正しない

## 使い方

```
/llm-wiki init _root
/llm-wiki init ai
/llm-wiki ingest sources/ai/article.md
/llm-wiki query "LLM Wikiパターンとは？"
/llm-wiki lint
```

## 設計の参考

- Andrej Karpathy が X で提唱した LLM Wiki パターン
- AgriciDaniel/claude-obsidian（単一 Vault + hot.md キャッシュ設計）
- ekadetov/llm-wiki（マルチ wiki + ingest/compile 分離 + qmd RAG）

本プラグインはジャンル単位の意味的分割と `_overview.md` による知識マップを重視している点が固有。
