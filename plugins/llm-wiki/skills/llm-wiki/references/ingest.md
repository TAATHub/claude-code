# ingest — ソース取り込み

`ingest [パス|URL]` はソースを取り込み Wiki ページを生成する。

内部的には **Phase A（収集確定）** と **Phase B（コンパイル）** の 2 段階だが、ユーザー視点では 1 コマンドで完結する。Phase B 完了時にのみ source-summary の frontmatter `type: source-summary` が立つので、途中失敗時は再実行で安全に復旧できる（冪等）。

## 検出方式

未取り込み判定は **frontmatter の `type` フィールド** で行う。`log.md` の文字列 grep には依存しない。`sources/_inbox/` 配下はジャンル未確定として別扱いし、triage（Phase A-0）の対象とする。スキャン構造は **直下 1 階層のみ**（`sources/<genre>/<file>.md`）を前提とし、ジャンルディレクトリ内のサブディレクトリは想定しない。

```python
# 検出ロジック（疑似コード）
inbox_targets = glob('sources/_inbox/*.md')           # 全件 triage 対象（type 不問）
genre_targets = []
for fp in glob('sources/*/*.md'):                      # 直下 1 階層のジャンルディレクトリを走査
    if fp.startswith('sources/_inbox/'):
        continue                                       # inbox は inbox_targets で扱う
    fm = parse_frontmatter(fp)
    if fm.get('type') != 'source-summary':
        # 未取り込み（Web Clipper 生 / 手動ノート / Phase B 失敗）
        genre_targets.append(fp)
# 処理順: inbox_targets を triage で振り分け → 移動先と genre_targets を合流して Phase B
```

## 呼び出しモード

| 呼び出し | 動作 |
|---|---|
| `/llm-wiki ingest` | `sources/_inbox/*.md` を triage（Phase A-0）→ `sources/<genre>/*.md` のうち `type: source-summary` でないものを順次処理 |
| `/llm-wiki ingest <パス>` | A-1 の入力解釈に従って処理（4 ケース: `sources/<genre>/` 配下 / `sources/_inbox/` 配下 / sources 外パス / URL）|
| `/llm-wiki ingest <URL>` | WebFetch → ジャンル判定（A-3）→ `sources/<genre>/<slug>.md` 保存（Phase A）→ Phase B。**URL 経路は `_inbox` を経由しない**。`source_url` 重複時はユーザー確認 |

`<パス>` には `.md`, `.txt`, `.pdf`, 画像など Read で読めるものを指定可。PDF は Read の `pages` パラメータで分割読込。

> `_inbox` のスキャン対象は **`*.md` 1 階層のみ**。`.txt`/`.pdf`/画像/サブディレクトリ等を取り込みたい場合は `/llm-wiki ingest <パス>` で直接指定する（A-1 の「sources 外パス指定」ルートで処理される）。

## Phase A-0: Inbox triage

`sources/_inbox/` 配下のジャンル未確定ファイルを既存ジャンルへ振り分ける段階。`/llm-wiki ingest`（引数なし）または `/llm-wiki ingest sources/_inbox/<file>` の場合に走る。inbox が空なら丸ごとスキップして A-1 に進む。

### A-0-1. Triage 対象の収集と特殊ケース分類

Glob ツールに `$WIKI_ROOT/sources/_inbox/*.md` パターンを渡して候補を取得（直下 1 階層・`.md` のみ）。各ファイルを 1 件ずつ Read し、frontmatter で 4 通りに分類:

| frontmatter | 扱い |
|---|---|
| `type: source-summary` あり | **異常状態**。警告ログを出して `_inbox` に残置（triage 対象から除外）。完了レポートの「要レビュー事項」に列挙し、「該当 genre が `wiki/<genre>/` に存在するなら手動で `sources/<genre>/` に移動して `recompile` する」「存在しないなら `type` フィールドを除去して再 ingest する」のリカバリ案内を併記する |
| `genre: <値>` あり、かつ `wiki/<値>/` ディレクトリが存在 | **fast path**。**A-0-2 と A-0-3 をともにバイパス** して A-0-4 のファイル移動へ直行する。frontmatter の `genre` 値が triage 結果として確定する |
| `genre: <値>` あり、かつ `wiki/<値>/` が存在しない（typo / 未 init） | 通常の triage 対象に戻す（A-0-2 で再判定。提案ジャンルとして frontmatter の値も候補に含めて提示） |
| 上記以外（frontmatter なし / `genre` フィールドなし） | 通常の triage 対象（A-0-2 へ） |

### A-0-2. ジャンル判定（段階化）

通常の triage 対象に対し以下の手順で判定:

1. **軽量フィルタ**: 既存ジャンル一覧を `Glob "$WIKI_ROOT/wiki/*/index.md"` で取得し、ジャンルスラッグと `index.md` 冒頭情報からマッチ候補を **上位 3 件以下** に絞る。ジャンル数が概ね 5 件以下なら軽量フィルタは省略してよい
2. **詳細評価**: 軽量フィルタで残った候補ジャンルの `_overview.md` のみ Read（特に「想定する読者・視点」「知識マップ」）。inbox ファイルの本文（タイトル・先頭数百行・主要キーワード）と突き合わせる
3. **確信度を 3 段階で付与**:

| 確信度 | 条件 | A-0-3 での挙動 |
|---|---|---|
| 高 | 単一既存ジャンルに明確にマッチ | 全件「高」なら確認画面を省略して直行（下記参照） |
| 中 | 複数候補に該当しうる | 確認画面で要承認 |
| 低 / 該当なし | 既存ジャンルどれにも収まらない | 新ジャンル候補を **1〜3 件** 提案、要承認 |

各ファイルについて内部記録: ファイルパス / 提案ジャンル（既存スラッグ または 新ジャンル候補リスト）/ 確信度 / 判定根拠（1 行）

### A-0-3. バッチ確認

#### 確認画面の発火条件

- **全件「高」確信のみ**: 確認画面を **スキップ** して A-0-4 へ直行（完了レポートで結果を報告）
- **確信度が「高」でないもの（中 または 低）が 1 件でも含まれる**: 確認画面を出す

#### 一括確認モード (`AskUserQuestion`)

判定済み一覧を表形式でテキスト提示してから、`AskUserQuestion` で 3 択を尋ねる:

```
未分類ソース <件数> 件を検出（_inbox 内）:

# | ファイル | 提案ジャンル | 確信度 | 備考
1 | swift-async.md | swift | 高 | Swift Concurrency 解説
2 | llm-bench.md | ai | 高 | LLM ベンチマーク議論
3 | db-tuning.md | rdb | 中 | performance 系の新ジャンルもあり得る
4 | ds-talk.md | (新ジャンル候補: data-science / ml / analytics) | 低 | 既存ジャンルに該当なし
5 | misc.md | (該当なし) | 低 | 主題不明 — スキップ推奨
```

`AskUserQuestion` の選択肢:
- 全件提案通り承認 → A-0-4 へ
- 個別調整モードへ → 下記の per-item 確認へ
- 中断（`_inbox` に残置）→ 呼び出しモードに応じて分岐:
  - 引数なしモード（`/llm-wiki ingest`）: A-0 を抜けて A-0-5 の合流ルール（`genre_targets` を Phase B-1 から処理、A-1〜A-4 はスキップ）に進む
  - 単一ファイル指定モード（`/llm-wiki ingest sources/_inbox/<file>`）: ingest 全体を終了

新ジャンル候補は **スラッグ（小文字英数+ハイフン）と対応する日本語名** をペアで提示する（例: `data-science` (データサイエンス)）。

triage 対象が **1 件のみ**の場合、表形式の一括確認は冗長になるため、一括確認モードを省略して直接「個別調整モード」相当の per-item 確認に縮約してよい（既存ジャンル選択 / 新ジャンル候補から選ぶ / カスタム入力 / スキップ）。

#### 個別調整モード（一括確認モードで「個別調整モードへ」を選んだ場合のみ）

各ファイルについて順に `AskUserQuestion` で次の選択肢を提示:

- 提案ジャンル（既存）をそのまま採用
- 新ジャンル候補から 1 件選ぶ（提案がある場合）
- 既存ジャンルから別スラッグを選ぶ
- カスタム入力（別の新ジャンルスラッグを指定）
- このファイルをスキップ（`_inbox` に残置）

カスタム入力が選ばれたときは続けて `AskUserQuestion` で「ジャンルスラッグ（小文字英数+ハイフン）」と「ジャンル日本語名」を順次尋ねる。`AskUserQuestion` が自由入力をサポートしない実装環境では、選択肢ベース（既存ジャンル一覧から選ぶ）にフォールバックする。

### A-0-4. ファイル移動と新ジャンル作成

A-0-1 fast path で確定したファイル、および A-0-3 で「全件承認」または「個別調整モード」で確定した各ファイルについて、1 ファイルずつ原子的に処理:

1. **新ジャンルが必要な場合**: `init <genre>` を先に実行（[init.md](init.md) ケース 2 のフロー）して `wiki/<genre>/` と `sources/<genre>/` を生成。
   - 同じ新ジャンルが triage 中に複数件で必要な場合、最初の 1 件で `init` を呼び、2 件目以降は既存判定（`wiki/<genre>/` が存在）でスキップする
   - `init` の完了レポートは独立に出さず、ingest 全体の完了レポートに統合する

2. **slug 正規化**: inbox の元ファイル名から拡張子を除いた文字列を `<slug>` のベースとする。詳細は [conventions.md](conventions.md) の「ファイル名と title」セクションを正典とし、最低限の追加規則として:
   - スペースは取り除く（複合語として連結）か中黒「・」で区切る
   - `/`, `\`, `:`, `?`, `*`, `"`, `<`, `>`, `|` などの OS 予約文字は除去
   - 過度に長いタイトル（コードポイント長 50 程度を目安）は意味の切れ目で切り詰める

3. **同名衝突チェック**: 移動先 `sources/<genre>/<slug>.md` が既に存在する場合:
   - 初回衝突: 接尾辞 `<slug>-<today>.md`（例: `<slug>-2026-05-08.md`）
   - 同日内で再衝突: 連番 `<slug>-<today>-2.md`, `<slug>-<today>-3.md`...（`-2` から開始: 既存ファイル + `<today>` 接尾辞分の 2 ファイルが既にあるため）

4. **ファイル移動**: `Bash` で `mv "$WIKI_ROOT/sources/_inbox/<original>" "$WIKI_ROOT/sources/<genre>/<final-slug>.md"` を実行（`<final-slug>` は step 3 の衝突回避を反映した最終ファイル名。同一ファイルシステム内なら原子的）

5. **frontmatter 整備**: 移動後のファイルに対して:

   **frontmatter ありの場合** — `genre` フィールドを次の 3 ケースで処理:

   | 既存の `genre` フィールド | Edit 操作 |
   |---|---|
   | キーが存在しない | frontmatter ブロック先頭（`---` 直後）に `genre: <triage結果>` 行を挿入 |
   | 既存値が triage 結果と一致 | 何もしない |
   | 既存値が triage 結果と異なる | `genre: <旧値>` を `genre: <triage結果>` に置換 |

   `title` フィールドが既存 frontmatter に欠けている場合（Web Clipper の `tags: ["clippings"]` のみの出力など）は、A-0-4 では補完しない。Phase B-4 の構造化要約書き換えで本文から抽出した正式タイトルを `title` として書き込むため、ここでは `genre` のみ整備すれば十分。

   **frontmatter なしの場合** — `Edit` で冒頭に YAML ブロックを新規挿入:
   ```yaml
   ---
   title: "<元 inbox ファイル名（拡張子除去前）から推定したタイトル>"
   genre: <triage結果>
   created: <today>
   ---
   ```
   残りのフィールド（`type` / `source_url` / `source_kind` / `fetched_at` / `updated` 等）は Phase B-4 で構造化要約に置き換える際にまとめて整備する。`title` も B-4 で本文から抽出した正式タイトルが得られたら、Edit で上書きしてよい（A-0-4 の暫定値より B-4 の抽出値を優先する）。

6. スキップ指定の項目は `_inbox` にそのまま残置（次回 ingest で再 triage の対象）

### A-0-5. Phase B への合流とトランザクション境界

- A-0-3 のバッチ確認は **全件分** が確定してから A-0-4 のファイル移動を開始する（per-file の確認と移動をインターリーブしない）
- A-0-4 の **全件移動完了後** に Phase B を per-file 逐次で開始する（並列実行しない）

A-0 で移動済みのファイル群は、A-1 の「既存パス指定（`sources/<genre>/...` 配下）」分岐に合流。A-2 〜 A-4 はスキップして直接 Phase B-1 から処理する。引数なし scan で集めた既存ジャンル配下の未取り込みファイルも同列に Phase B へ進む。

## Phase A: 収集の確定

ファイルを `sources/<genre>/` に着地させ、ジャンルを確定する段階。

### A-1. 入力の解釈

- **既存パス指定 (`sources/<genre>/...` 配下)**: ファイルが既にジャンルディレクトリ配下にある（Web Clipper 出力 / 手動ノート / 過去 Phase A 完了分 / A-0 で移動済み分）
  - ジャンルはディレクトリ名から確定
  - そのまま Phase B へ
- **既存パス指定 (`sources/_inbox/` 配下)**: ジャンル未確定。Phase A-0（Inbox triage）の対象とする
- **`sources/` 外のパス指定**: `Read` で内容取得 → ジャンル判定（A-3）→ `sources/<genre>/<slug>.md` にコピー保存（原本は触らない）
- **URL 指定**: `WebFetch` で内容取得（取得日時を `fetched_at` として記録）→ ジャンル判定（A-3）→ `sources/<genre>/<slug>.md` に保存

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
| A-0 triage 中断（ユーザー [n] / 例外） | inbox ファイルはそのまま残置 | 引数なし `/llm-wiki ingest` で再 triage |
| A-0-4 ファイル移動の途中失敗 | 一部ファイルは `sources/<genre>/` へ移動済み、残りは inbox に残る | 残り inbox ファイルは次回 triage、移動済みは genre_targets として通常 Phase B で拾われる |
| A-0-4 step 4 (mv) 完了後・step 5 (frontmatter 整備) 失敗 | 移動済みだが `genre` フィールドが未追記の状態 | genre_targets として再検出され、Phase B-4 の frontmatter 全面書き換えで吸収される（B-4 のテンプレートが `genre` を必ず含むため復旧可） |
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
- 要レビュー事項（曖昧だった判定など。A-0-1 で `type: source-summary` 異常状態として残置されたファイルもここに列挙）
- スキャンモード時は処理した件数とスキップした件数

### A-0 triage の追加項目（A-0 が走った場合のみ）

- triage 対象件数（`_inbox` 内検出件数）
- 振り分け結果の内訳: 既存ジャンルへ移動 / 新ジャンル作成 + 移動 / 異常状態で残置 / ユーザースキップで残置 / fast path 直行
- 新規作成したジャンルのスラッグ一覧（init 経由）
- 各ファイルのジャンル判定根拠（1 行ずつ）
