---
name: llm-wiki
description: LLMが永続的なナレッジベース(LLM Wiki)を構築・維持するスキル。Obsidian Vault配下にソースドキュメントを取り込み、相互参照付きのノートとして整理する。「LLM Wiki」「Wikiに記録」「Wiki検索」「ingest」「save」「wiki query」「wiki lint」「wiki init」「wiki recompile」などのリクエストで使用。
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - WebFetch
  - AskUserQuestion
  - Bash(date*)
  - Bash(ls*)
  - Bash(mkdir*)
  - Bash(find*)
---

# LLM Wiki

Andrej Karpathy が提唱する「LLM Wiki」を Obsidian Vault 上に構築・維持するスキル。ソース原本を変更せず、要約とWikiページの相互リンクで知識を蓄積していく。

## Vault パス（要設定）

このスキルは Obsidian Vault のルートパスを `LLM_WIKI_VAULT_ROOT` 環境変数で受け取る。**初回利用時にユーザー環境に合わせて設定**する。

- `LLM_WIKI_VAULT_ROOT` — Obsidian Vault のルート絶対パス（例: `~/ObsidianVault`、`~/Documents/Obsidian/MyVault`、iCloud 同期 Vault など）
- `WIKI_ROOT = $LLM_WIKI_VAULT_ROOT/llm-wiki` — references 内で多用する内部短縮形

### 設定方法

恒久的な設定方法は次の 2 通り。

1. **シェル起動スクリプト**: `~/.zshrc` 等に `export LLM_WIKI_VAULT_ROOT="<path>"` を追加
2. **Claude Code の `settings.json` / `settings.local.json`**: `env` ブロックに記載

   ```json
   {
     "env": {
       "LLM_WIKI_VAULT_ROOT": "/absolute/path/to/Vault"
     }
   }
   ```

   `~/.claude/settings.json`（ユーザー全体）、プロジェクト内 `.claude/settings.json`（コミット対象）、`.claude/settings.local.json`（個人ローカル）のいずれでも可。Claude Code 起動時に自動で環境変数として注入される。

恒久的に設定していない場合は、初回操作時にスキルが `AskUserQuestion` で尋ねる（**そのセッション内のみ**保持。次セッションでも未設定なら再度尋ねる）。

LLM が操作を始める前に `LLM_WIKI_VAULT_ROOT` を解決する手順:

1. 環境変数 `LLM_WIKI_VAULT_ROOT` が設定されていればそれを使う
2. 未設定なら、`AskUserQuestion` で「Obsidian Vault の絶対パスを教えてください」と確認
3. 確認した値はセッション内で保持し、同セッション内では繰り返し尋ねない
4. 同時に「次回以降のために `LLM_WIKI_VAULT_ROOT` を環境変数として設定することを推奨」する旨を 1 行案内する

> Bash で扱うときは必ずダブルクォートで括る（パスにスペースを含む可能性があるため）。例: `ls "$WIKI_ROOT/wiki"`

## ディレクトリ構造

```
<Vault>/llm-wiki/           # = $WIKI_ROOT
├── index.md                # 全体カタログ（ジャンル一覧）
├── wiki/<genre>/
│   ├── index.md            # ジャンル内ページカタログ
│   ├── log.md              # ジャンル内操作ログ（追記専用）
│   ├── _overview.md        # ジャンル概要・知識マップ
│   └── <ページ名>.md
└── sources/<genre>/        # ソース要約のみ（原本は別所在）
```

## 動詞ディスパッチ

ユーザー入力に応じて該当する詳細仕様を `references/` から読み込み、その手順に従う。

| 動詞 | 用途 | 詳細 |
|---|---|---|
| `init <ジャンル>` | 新ジャンルのスケルトン生成（初回は引数 `_root` で全体構造） | [references/init.md](references/init.md) |
| `ingest [パス\|URL]` | ソース取り込み + コンパイル（引数なしは未取り込み全件処理） | [references/ingest.md](references/ingest.md) |
| `save [タイトル]` | 直前会話を `source_kind: conversation` として取り込み + コンパイル | [references/save.md](references/save.md) |
| `recompile <パス>` | 取り込み済みソースの再コンパイル（メンテナンス用、引数必須） | [references/recompile.md](references/recompile.md) |
| `query <質問>` | Wiki検索・統合回答・必要なら新ページ提案 | [references/query.md](references/query.md) |
| `lint` | Vault健全性チェック（レポート出力のみ） | [references/lint.md](references/lint.md) |

## 取り込み状態の判定

`sources/<genre>/<file>.md` の取り込み状態は **frontmatter の `type` フィールド** で判定する。

- `type: source-summary` あり → 取り込み済み（`ingest` の対象外、`recompile` で再処理可）
- `type` フィールドなし、または他の値 → 未取り込み（`ingest` で処理）

Web Clipper 出力（`tags: ["clippings"]` のみで `type` 未指定）、手動作成ノート、URL ingest の Phase A 直後の生ファイルはすべて「未取り込み」として扱われる。詳細は [references/conventions.md](references/conventions.md) の「`type: source-summary` はコンパイル完了マーカー」セクション。

## 共通ルール

- **記述規約**（frontmatter / wikilink / 言語）: [references/conventions.md](references/conventions.md)
- **判断基準**（ページ新規/更新/分割、query結果の保存可否）: [references/decision-rules.md](references/decision-rules.md)

## 前提

- Obsidian Vault 本体は既に存在する前提（`LLM_WIKI_VAULT_ROOT` で指す）。なければユーザーに作成を依頼する。
- 初回は `init _root` で `$WIKI_ROOT/` 直下の `index.md`、`wiki/`、`sources/` を生成する。
- 各操作の最後に必ず `wiki/<genre>/log.md` に追記し、何をしたかを残す。

## 安全側の方針

- **自動コミットしない**: Vaultが Git管理下でも、git操作はユーザーが明示的に指示した場合のみ。
- **ソース原本は変更不可**: `sources/` には要約とメタデータのみ保存し、原本ファイルは触らない。
- **破壊的操作の前確認**: ページ削除・大規模リネームはユーザー確認を取ってから実施。
- **日付は実時刻**: frontmatter の `created`/`updated` や log エントリは Bash の `date` コマンドで取得した値を使う。
