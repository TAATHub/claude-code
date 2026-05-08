# ingest — ソース取り込み

`ingest [パス|URL]` はソースを取り込み Wiki ページを生成する。

内部的には **Phase A（収集確定）** と **Phase B（コンパイル）** の 2 段階だが、ユーザー視点では 1 コマンドで完結する。Phase B 完了時にのみ source-summary の frontmatter `type: source-summary` が立つので、途中失敗時は再実行で安全に復旧できる（冪等）。

## 検出方式

未取り込み判定は **frontmatter の `type` フィールド** で行う。`log.md` の文字列 grep には依存しない。

```python
# 検出ロジック（疑似コード）
for fp in glob('sources/*/*.md'):
    fm = parse_frontmatter(fp)
    if fm.get('type') != 'source-summary':
        # 未取り込み（Web Clipper 生 / 手動ノート / Phase B 失敗）
        target.append(fp)
```

## 呼び出しモード

| 呼び出し | 動作 |
|---|---|
| `/llm-wiki ingest` | `sources/**/*.md` をスキャン → `type: source-summary` でない全ファイルを順次処理 |
| `/llm-wiki ingest <パス>` | 指定ファイルを処理（既に取り込み済みなら警告して終了、`recompile` を案内） |
| `/llm-wiki ingest <URL>` | WebFetch → `sources/<genre>/<slug>.md` 保存（Phase A）→ そのまま Phase B へ。`source_url` 重複時はユーザー確認 |

`<パス>` には `.md`, `.txt`, `.pdf`, 画像など Read で読めるものを指定可。PDF は Read の `pages` パラメータで分割読込。

## Phase A: 収集の確定

ファイルを `sources/<genre>/` に着地させ、ジャンルを確定する段階。

### A-1. 入力の解釈

- **既存パス指定**: ファイルが既に `sources/<genre>/...` 配下にある（Web Clipper 出力 / 手動ノート / 過去 Phase A 完了分）
  - ジャンルはディレクトリ名から確定
  - そのまま Phase B へ
- **`sources/` 外のパス指定**: `Read` で内容取得 → ジャンル判定 → `sources/<genre>/<slug>.md` にコピー保存（原本は触らない）
- **URL 指定**: `WebFetch` で内容取得（取得日時を `fetched_at` として記録）→ ジャンル判定 → `sources/<genre>/<slug>.md` に保存

### A-2. URL 重複チェック（URL 指定時のみ）

`sources/**/*.md` の frontmatter `source_url` を全件確認:

- **一致するファイルあり**: ユーザーに次の選択肢を提示
  1. 既存ファイルを上書き更新（content が変わった可能性あり、`type` を未設定に戻して Phase B で再処理）
  2. 別 slug で新規保存（履歴として残す、`<slug>-2026-05-06` のような接尾辞）
  3. スキップ
- **一致なし**: 通常通り新規保存

### A-3. ジャンル判定（パス未確定時）

- 既存ジャンル一覧（`$WIKI_ROOT/wiki/*/`）を `Glob` で取得
- ソースの主題が既存ジャンルのどれに最も近いかを判断
- 判断が割れる/該当なしの場合、ユーザーに確認
- 新規ジャンルが必要なら `init <genre>` を先に実行

### A-4. 生 frontmatter で保存（URL/sources外パスの場合）

```yaml
---
title: "<タイトル>"
source_url: "<URL or 原本パス>"
fetched_at: <today>
created: <today>
tags:
  - "clippings"   # 任意。Web Clipper 出力との一貫性を保つ
---

<取得した本文>
```

**この時点では `type` を立てない**。Phase B 完了時に立てる。

## Phase B: コンパイル

Wiki ページを生成・更新し、最後に `type: source-summary` を立てて完了印とする段階。

### B-1. 既存 Wiki 状態の把握

- `$WIKI_ROOT/wiki/<genre>/index.md` を Read
- `_overview.md` を Read
- 関連しそうな既存ページを `Grep` で探す（タイトル・本文両方）

### B-2. 要点抽出

- 主要コンセプト、エンティティ、結論、矛盾点、未解決点を抽出
- 重要ソースは抽出結果をユーザーに提示し議論可。軽量ソースは確認をスキップしてよい

### B-3. Wiki ページの作成・更新

[references/decision-rules.md](decision-rules.md) の三層判定（新規 / 更新 / 分割）に従う。

- **新規**: `$WIKI_ROOT/wiki/<genre>/<ページ名>.md` を [references/conventions.md](conventions.md) のテンプレートで作成
- **更新**: `Edit` で該当セクションを書き換え or 末尾追記。frontmatter `updated` を today に
- **分割**: 元ページから対象セクションを切り出し、新ページ作成。元ページには要約と `[[新ページ]]` リンクを残す

各ページの `sources` / `related` フロントマターを正しく更新する。

**1ソース → 複数ページ更新は正常**。既存ページとの接点を積極的に見つけて相互リンクを増やす。

### B-4. ソースファイルを source-summary 形式に書き換え（type は未設定のまま）

`sources/<genre>/<slug>.md` の本文と frontmatter を構造化要約に置き換える。**ただし `type: source-summary` フィールドはまだ立てない**（B-6 完了印として B-6 末尾で立てる）。frontmatter は次の形:

```yaml
---
title: "<ソースタイトル>"
genre: <genre>
type: source-summary       # ← Phase B 完了印。B-4 では未設定のままとし、B-6 の log 追記の直前にここを書き換えて立てる
source_url: "<URLまたは原本パス>"
source_kind: web | pdf | book | article | code
author:
  - "[[著者名]]"           # 任意
published: <YYYY-MM-DD>    # 任意
fetched_at: <YYYY-MM-DD>
created: <today>
updated: <today>
tags:
  - "clippings"            # 元の Web Clipper 由来なら維持
---

# <ソースタイトル>

## 出典

<著者・媒体・公開日など>

## 要約

<3〜10行程度の要約>

## 主要トピック

- [[Wikiページ1]]
- [[Wikiページ2]]

## 引用・キーフレーズ

> <重要な引用>

## ソースから生成・更新したWikiページ

- [[ページ名]] — 新規 / 更新 / 分割

## 元コンテンツ（要旨）

<本文の要旨。長文クリッピングはここに圧縮して保持>
```

### B-5. `_overview.md` の更新判定（条件付きで実行）

`_overview.md` の知識マップは **構造変化があった時のみ** 更新する。新ページ追加のたびに必ず更新するわけではない（[references/conventions.md](conventions.md) の「ジャンル概要」セクション参照）。

#### 更新トリガー（このいずれかに該当する時のみ）

- **新カテゴリが必要**: 既存「## ページ一覧」のどのカテゴリにも収まらない新ページが追加された
- **サブカテゴリ細分化**: 既存カテゴリ内で 3 ページ以上が同じ細分テーマを持ち、サブカテゴリ化が妥当
- **構造変化**: ページ分割で上位概念が浮上、または既存カテゴリの境界が変わった
- **横断テーマ追加**: `## 横断テーマ` に追記すべき新しい対立軸・問題意識が浮上

#### 更新内容

トリガーに該当する場合のみ:

- `_overview.md` の「## 知識マップ」を編集
  - 新カテゴリのツリーノードを追加
  - 既存カテゴリの細分化（既存リスト構造を保ちつつ追記）
  - 分割によって変わった上下関係の反映
- 必要なら「## 横断テーマ」に新しい論点を 1 行追加
- frontmatter `updated` を today に

#### 更新しないケース

- 既存カテゴリに自然に収まる単一の新ページ追加
- 既存ページの軽微な追記
- ジャンル構造に影響しない関連ページの増加

判断に迷ったら **更新しない側に倒す**。`_overview.md` は頻繁に書き換えるものではない。後で構造化が必要だと気付いたら `recompile` または手動編集で対応。

### B-6. index / log 更新と type 立て（最終ステップ）

順序が重要:

1. `$WIKI_ROOT/wiki/<genre>/index.md` の「ページ一覧」に新規ページを追記、frontmatter `updated` を today に
   - 既存カテゴリに収まる場合はそのカテゴリ末尾に
   - 新カテゴリが必要な場合は適切な位置に新セクション追加（B-5 で `_overview.md` を更新したならそれと整合させる）
2. ソース source-summary の frontmatter に `type: source-summary` を追加（B-4 で書き換えた本文は既にこの形式に整っており、`type` の 1 行を追加するだけ）
3. `$WIKI_ROOT/wiki/<genre>/log.md` に追記:

```markdown
## <today>

- ingest: [[sources/<genre>/<source-slug>]]
  - 新規: [[ページA]], [[ページB]]
  - 更新: [[ページC]]（<理由>）
  - 分割: [[元ページ]] → [[新ページ]]
  - _overview.md 更新: <更新理由>（該当した場合のみ）
```

**Phase B の最終アクション順序は「index 更新 → type 立て → log 追記」とする**。これにより以下が両立する:

- `type: source-summary` あり + log エントリあり = 完全に完了
- `type: source-summary` なし = 未取り込み（Web Clipper raw / 手動ノート / Phase B 失敗のいずれも検出される）
- `type: source-summary` あり + log エントリなし = 異常状態（type 立て後に log 追記で失敗）。lint で検出可

## 冪等性ルール

| 失敗ポイント | 残る状態 | 復旧方法 |
|---|---|---|
| WebFetch 失敗（URL ingest） | ファイル未作成 | 同じ URL で再実行 |
| Phase A 途中失敗 | 部分ファイルが残るか未作成 | 引数なし `/llm-wiki ingest` で再検出される |
| B-3 で Wiki ページ部分作成 | 部分ページあり、ソース `type` 未設定 | 引数なし再実行で B-1 から再走。既存ページは「更新」ルートで処理 |
| B-4 で書き換え失敗 | ソースは生のまま、`type` 未設定 | 同上 |
| B-5 で `_overview.md` 更新失敗 | `_overview.md` 部分編集の可能性、`type` 未設定 | 同上（再実行で B-5 から再走） |
| B-6 の type 立て前で失敗 | `type` 未設定、log 未追記 | 同上（再実行で B-1 から再走） |
| B-6 の type 立て後 / log 追記前で失敗 | `type` あり + log エントリなし（異常状態） | lint で検出 → ユーザーに log を補完してもらう |

**設計原則**: `type: source-summary` を立てるのは B-6 の中で **index 更新が終わり、log 追記の直前** に行う。これより前のステップで type を立ててはいけない（途中失敗時の再検出を可能にするため）。

## 部分作成された Wiki ページの扱い

Phase B が B-3 の途中で失敗したケースでは、新ページの一部だけが作られている可能性がある。

- 引数なし再実行で B-1 から再走
- 既存ページがあれば decision-rules の「更新」ルートで処理（Edit による追記）
- ページ内容が重複したセクションを生むリスクがあるため、B-3 開始時に **既に存在するが log にエントリのないページ** が見つかったら警告:

```
⚠ 検出: wiki/<genre>/<page>.md は存在するが log に記録がない。
  Phase B 部分失敗の痕跡の可能性。
  → このまま更新を続けますか？ [Y]es / [n]o / [d]iff
```

## 完了レポート

- 取り込んだソース（パス）
- 影響したジャンル
- 新規 / 更新 / 分割 した Wiki ページのリスト
- 要レビュー事項（曖昧だった判定など）
- スキャンモード時は処理した件数とスキップした件数
