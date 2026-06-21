# proposals — 修正提案の共通システム

`curiosity` と `lint` が生成する修正提案を `_proposals/` に隔離保存し、対話的レビューを経て Wiki 本体に反映する共通フレームワーク。`ingest` / `save` / `recompile` / `query` が「即時 Wiki 更新」であるのと対照的に、**提案 → 承認 → 適用** の 3 段階を踏む。

## 役割

Wiki 本体への書き込みを伴う変更を、リスクの大小にかかわらず一度ファイルとして可視化することで:

- LLM 生成テキストの幻覚を Wiki に持ち込む前にユーザーが確認できる
- 機械的に修正できる小さな変更も同じパイプラインで扱える
- 反映済み/保留/却下が `_proposals/` のフォルダ状態で追跡可能
- `curiosity` と `lint` で実装を共通化できる

## ディレクトリ構造

```
wiki/<genre>/_proposals/
├── <YYYY-MM-DD>__<kind>__<origin>-<serial>.md   # pending
├── applied/                                      # apply 済みアーカイブ
│   └── <YYYY-MM-DD>__<kind>__<origin>-<serial>.md
└── rejected/                                     # reject 済みアーカイブ
    └── <YYYY-MM-DD>__<kind>__<origin>-<serial>.md
```

`_proposals/` は対象ジャンルの配下に置く。ジャンル横断ページの提案は「主ジャンル」を自動判定して、その配下に配置する（後述）。

`_proposals/` ディレクトリは **最初の書き込み時に lazy 作成** する（`mkdir -p`）。`init` で先に作る必要はない。`applied/` / `rejected/` も同様に必要時に作成する。

## ファイル命名規約

```
<YYYY-MM-DD>__<kind>__<origin>-<serial>.md
```

例:

- `2026-05-25__new-page__curiosity-001.md`
- `2026-05-25__link-fix__lint-042.md`
- `2026-05-25__contradiction__curiosity-003.md`

`<serial>` は同一日・同一 origin 内の通し番号。採番ルール: 書き出し前に `Glob "$WIKI_ROOT/wiki/*/_proposals/**/*.md"` で **pending / applied / rejected すべて**を含む全 `_proposals/` 配下を走査し、同一日・同一 origin の最大 serial + 1 を採用する（applied / rejected も含むので、途中失敗時の再実行でも採番衝突しない）。Wiki 全体（ジャンル跨ぎ）でユニークである必要はない。日付＋kind＋origin＋serial の 4 つでファイル単位の識別子として十分。

## frontmatter スキーマ

```yaml
---
type: proposal
origin: curiosity | lint
kind: new-page | append | contradiction | contradiction-found | missing-page | stale-fix | link-fix | orphan-fix | weak-relation | ingest-incomplete
target: "[[対象ページ]]"        # 必ず wikilink でラップ。new-page / missing-page では「まだ作られていない新規候補ページ名」を `[[<候補名>]]` 形式で記載。ingest-incomplete では対象ソース `[[sources/<genre>/<file>]]` を記載
status: pending | applied | rejected
risk_flags: []                    # 任意 (詳細は下記「必須・任意」)。空なら省略可
confidence: high | medium | low
cross_genre: ["<genre1>", "<genre2>"]   # 横断する場合のみ、主ジャンルは除く
created: YYYY-MM-DD
applied: YYYY-MM-DD               # applied/ に移動時にのみ追加
rejected: YYYY-MM-DD              # rejected/ に移動時にのみ追加
---
```

### 必須・任意

- 必須: `type`, `origin`, `kind`, `target`, `status`, `confidence`, `created`
- 任意: `risk_flags`（リスクがある場合のみ。リスクなしの場合は `[]` または省略）、`cross_genre`（横断時のみ）、`applied`（apply 時に追加）、`rejected`（reject 時に追加）

提案ファイル新規生成時の `status` は必ず `pending`。apply で `applied`、reject で `rejected` に遷移する。

`risk_flags` が空 (`[]` または省略) の提案 = 「機械的に判定可能、無条件 apply 可」の最小ノイズ提案を意味する。本ドキュメント中では「リスクなし」と表記する（「リスク無し」「`risk_flags` 空」も同義）。

## 本文テンプレート

```markdown
# 提案概要

<一行で何を反映したいかを示す>

## 起点

<curiosity の場合: どの問いから生まれたか / 対象ページ / pair-wise なら相方ページ>
<lint の場合: どの検出項目から (例: 5a 欠落リンク) / 検出箇所 file:line>

## 提案内容

<反映する文面そのもの。new-page なら本文全体、append なら追記すべきテキスト、link-fix なら before/after の差分>

## 信頼度・リスク

<risk_flags に応じた注意書き。必須セクション>

- ⚠️ **ハルシネーション可能性** (該当時): 本文中の主張 X は sources/<genre>/<file> の raw 本文（旧 `source-summary` なら要約）には直接の記述がなく、LLM による推論を含みます。該当ソースの raw 本文（または `source_url:` の原典）での裏取りを推奨
- ⚠️ **判断必須** (該当時): 反映方針が複数あり得ます (例: 矛盾解消で「両論併記」か「片方更新」か)
- ⚠️ **低精度検出** (該当時): キーワード重複度ベースの弱い候補で、誤検知の可能性があります
- critic 評価: <既存ページとの重複なし / 論理整合性 / sources/ 引用の充足度 など>

## 根拠

- [[sources/<genre>/<source>]]: <参照した記述>
- 既存 [[関連ページ]]: <対比・補強の関係>
- critic 判定: <一行サマリ>
```

`## 信頼度・リスク` は必須。`risk_flags` が空でも「critic 評価: OK」だけは書く。

## kind 一覧

**本セクションが kind の正典**。`curiosity.md` / `lint.md` は対応する kind を本表から参照する。新しい kind を追加する場合は必ずここから更新する。

10 種類。`origin` 別の発生源と典型的な `risk_flags` を整理する。

| kind | origin | 何を提案するか | typical risk_flags |
|---|---|---|---|
| `new-page` | curiosity | 既存にない新しい統合知見をページ化 | `hallucination-possible` |
| `append` | curiosity | 既存ページに新しい論点を追記 | `hallucination-possible` |
| `contradiction` | curiosity | 既存ページと新ソースの矛盾を発見 | `judgment-required` |
| `contradiction-found` | lint | lint 1 で検出されたページ間矛盾 | `judgment-required` |
| `missing-page` | lint | lint 3 の不足ページ候補を本文生成して提案 | `hallucination-possible` |
| `stale-fix` | lint | lint 4 の古い情報の更新案 | `judgment-required` |
| `link-fix` | lint | lint 5a のベタテキスト → `[[ページ]]` 置換 | （なし） |
| `orphan-fix` | lint | lint 2 の孤立ページに対するリンク元候補 | `judgment-required` |
| `weak-relation` | lint | lint 5b のキーワード重複ベースの関連候補 | `low-precision` |
| `ingest-incomplete` | lint | lint 6 の取り込み未完了ソース（`type` 済み × log エントリなし）の log 補完 | `judgment-required` |

**confidence の初期値の目安**:
- `link-fix`: `high` (機械的に判定可能)
- `missing-page`: `low` 寄り (本文生成あり、原本未参照のリスクが特に強い)
- 上記以外: critic 判定により high〜low の幅。標準ケースで `medium`

`contradiction` (curiosity 起点) と `contradiction-found` (lint 起点) を別 kind として分けているのは、検出ロジックが大きく異なるため (前者は新ソースとの照合、後者は既存ページ間の Grep 比較)。将来 apply 処理を分岐させる余地を残す目的もある。`missing-page` も `new-page` と機能的には近いが、検出経路 (lint vs curiosity) と幻覚リスクの強さが異なるため分離している。

## risk_flags の意味

| flag | 意味 | レビュー時の推奨スタンス |
|---|---|---|
| `hallucination-possible` | 本文生成あり。原本未参照部分に幻覚リスク | sources/ または原本で裏取り後に apply |
| `judgment-required` | 反映方針が複数あり、ユーザー判断必須 | 提案内容を踏み台に手動で edit してから apply |
| `low-precision` | 検出ロジックの誤検知前提 | 半数以上は reject される想定でレビュー |

複数フラグの同時付与もあり得る。表示時はカンマ区切りで全て見せる。

## confidence の使い分け

`risk_flags` がリスクの種類を表すのに対し、`confidence` は「critic が判定した提案そのものの妥当性」を表す。

- `high`: 機械的に一意に決まる、または critic が複数観点で OK と判定
- `medium`: critic は OK だが、原本未参照などの留保がある
- `low`: critic が留保付きで通した、または検出精度が元々低い (`low-precision` 付き提案)

レビュー UI では `risk_flags` と `confidence` を併記する。

## ジャンル横断の主ジャンル自動選択

提案内容がジャンル横断する場合、critic が以下のロジックで主ジャンルを決定:

1. 提案内容に出現する `[[ページ]]` のジャンルを集計
2. 最頻ジャンルを主ジャンルとする
3. 同数の場合の tie-breaker:
   - `curiosity` 起点: サンプリング元ページのジャンルを優先
   - `lint` 起点: 検出対象ページのジャンルを優先
4. 提案ファイルを **主ジャンル** の `_proposals/` に配置
5. frontmatter の `cross_genre` に横断ジャンルを記録（主ジャンルを除く）

レビュー時にユーザーが「主ジャンル誤り」と判断したら、`edit` で frontmatter を直すか、ファイルを別ジャンルへ手動移動する。`cross_genre` フィールドが残るので、後で再配置の手がかりになる。

## apply セマンティクス

`apply` を選んだ際の処理は `kind` ごとに異なる。各処理の末尾で:

- 対象ページの `updated` を today に (curiosity のサンプリング指標として機能する)
- 対象ジャンルの `log.md` に追記
- 提案ファイルに `applied: today` を追加し、`status: applied` に変更
- 提案ファイルを `_proposals/applied/` へ `mv` で移動

### kind 別の処理

| kind | apply時の処理 |
|---|---|
| `new-page` | `wiki/<genre>/<新ページ名>.md` を作成。frontmatter を整形し、本文をコピー。`index.md` に追記（カテゴリ判断）。`_overview.md` の更新トリガーに該当すれば更新 |
| `append` | 対象ページを Read。提案で指定されたセクション（または末尾 `## 詳細` 内）に Edit で追記 |
| `contradiction` / `contradiction-found` | 対象ページの該当箇所を Edit で更新、または `## 補足` セクションを新設して両論を併記。sources セクションに新ソースを追加 |
| `missing-page` | `new-page` と同じだが、apply 前に「ハルシネーション可能性が強い」旨を AskUserQuestion で再確認 |
| `stale-fix` | 提案で指定されたセクションを Edit で更新 |
| `link-fix` | 対象ファイル内の該当ベタテキストを `[[<ページ>]]` に Edit で置換 (位置情報 `<file>:<line>` は提案ファイルの参照情報。Edit は old_string/new_string マッチングで実行) |
| `orphan-fix` | リンク元候補ページの `## 関連ページ` セクションに `- [[<孤立ページ>]] — <理由>` を追記。frontmatter の `related` にも追加 |
| `weak-relation` | 両ページの `## 関連ページ` セクションに相互リンクを追記。frontmatter の `related` も両方更新。なお `low-precision` リスクのため reject されるケースが多い前提だが、apply された場合の処理は本行通り |
| `ingest-incomplete` | 対象ソースの `generated_pages` を `wiki/<genre>/log.md` に補う。log の動詞はソースの `source_kind` で選ぶ（`conversation` なら [save.md](save.md) Step 8 の `- save: [[...]]（会話由来）` 形式、それ以外は [ingest.md](ingest.md) B-6 の `- ingest: [[...]]` 形式）。サブ項目（新規 / 更新 / 分割など、選んだ正典のログ例に従う）は generated_pages を各正典フォーマットに転記する（フォーマット文字列は再定義せず両正典に従う）。`generated_pages` が空/未設定なら生成ページを特定できないため log は補完せず「`/llm-wiki recompile <パス>` で再特定」を案内する。**共通処理の例外**: (a) log 追記は本処理が担うため共通処理側の log 追記は二重に行わない、(b) `updated` は対象ソース frontmatter を today にする（target が wiki ページではなくソースのため）、(c) recompile 案内のみで終え log 未補完だった場合は `applied` にせず `pending` のまま残す |

### 既存ページの構造尊重

`append` / `contradiction` / `stale-fix` / `orphan-fix` / `weak-relation` は **既存ページの本文構造を尊重する**。セクション丸ごとの差し替えは行わず、Edit による追記・部分更新のみ。大規模な書き換えが必要そうな場合は、apply ではなく `edit` でユーザーが提案を編集してから再度 apply する流れにする。

## 対話的レビューフロー

`curiosity` / `lint` の実行末尾で発火する共通フロー。

### Step 1: レビュー開始の確認

提案を `_proposals/` に書き出した直後に AskUserQuestion で:

```
<N>件の提案が保存されました。
  ⚠️ リスクあり: <M>件
  ✓ リスクなし: <N-M>件

今レビューしますか?
  - yes: 順番にレビュー
  - later: 後で。次回 curiosity/lint 起動時にリマインド
  - apply-all-safe: リスクなしのみ全件 apply (リスクありは保留)
```

### Step 2: 各提案のレビュー

`yes` を選んだ場合、リスクあり → リスクなしの順で 1 件ずつ表示:

```
[<i>/<N>] <アイコン> <kind>: <target> (genre: <genre>)
  origin: <curiosity | lint>
  risk_flags: <list> | confidence: <level>
  cross_genre: <list>  (横断時のみ)

<本文プレビュー>

選択:
  - apply: そのまま反映
  - edit:  提案ファイルを編集してから反映
  - skip:  保留 (pending のまま残す)
  - reject: 却下 (_proposals/rejected/ へ退避)
  - quit:  レビュー終了 (残りは pending のまま)
```

アイコンは `risk_flags` に応じて変える:

- `⚠️`: `hallucination-possible` または `judgment-required` を含む
- `?`: `low-precision` のみ
- なし: `risk_flags` 空 (= リスクなし)

### Step 3: 完了レポート

```
レビュー完了:
  - apply: <数>件
  - edit→apply: <数>件
  - skip: <数>件 (pending のまま残存)
  - reject: <数>件

pending 残存: 各ジャンルの _proposals/ を参照
```

## pending リマインド

`curiosity` / `lint` を次回起動した際の冒頭で、`_proposals/` に残っている pending 提案を案内する。

```
[冒頭リマインド]
⚠️ pending な提案が残っています:
  - wiki/ai/_proposals/: <N>件 (⚠️<M>件)
  - wiki/swift/_proposals/: <N>件

先にレビューしますか?
  - yes: pending を順にレビュー
  - no:  新しい curiosity/lint サイクルを開始
```

`yes` を選んだら、Step 2 のフローを pending 提案に対して走らせる。

## 安全側のルール

- **apply は kind 別の処理を厳密に守る**。本文の構造を尊重し、追記中心。セクション丸ごとの差し替えはユーザー確認を経由する
- **reject = `_proposals/rejected/` への mv 退避**。物理削除はしない。frontmatter に `rejected: YYYY-MM-DD` を追加し `status: rejected` に変更してから移動する。却下理由を残したい場合は本文末尾に `## 却下理由` を追記してから reject、または skip して `pending` のまま残し次回リマインドで再判断
- **skip = `status: pending` のまま**。次回リマインド対象に残る
- **apply 時に対象ページの `updated` を today に**。これで `curiosity` のサンプリング指標が自然に動く
- **applied/ に移動時、frontmatter に `applied: YYYY-MM-DD` を追加**。`status: applied` に変更
- **`apply-all-safe` でも対象ページ数が多い場合は途中で進捗を出す**（10 件超なら 5 件ごとに「continue? (y/n)」を挟む）。`curiosity` / `lint` がこの条項を呼び出す
- **横断ページの主ジャンル誤りは edit で修正可**。`cross_genre` フィールドが残っているので、レビュー時にユーザーが気付ける
- **自動コミットしない**。Vault が Git 管理下でも、git 操作はユーザーが明示的に指示した場合のみ

## 他動詞との関係

SKILL.md の「即時更新 vs 提案経由」セクションが概観を提供する。本表は proposals 視点での各動詞の関与を補足する。

| 動詞 | proposals との関係 |
|---|---|
| `ingest` | 提案を生成しない（即時 Wiki 更新）|
| `save` | 提案を生成しない（即時 Wiki 更新）|
| `recompile` | 提案を生成しない（既存ページの追記・リンク更新は直接 Edit）|
| `query` | 提案を生成しない。ただし `log.md` への追記で curiosity の除外集合に貢献する |
| `curiosity` | 提案を生成する主要動詞 |
| `lint` | 提案を生成する主要動詞 |

判断基準の詳細は SKILL.md「即時更新 vs 提案経由」セクションを参照。
