# curiosity — Wiki 全体を能動的に点検・成長させる

`curiosity` は **既存 Wiki ページを起点に自動で質問を生成し、自答した結果を提案として `_proposals/` に書き出す** 動詞。`ingest` 起点では活性化されない領域（あまり質問されない・新ソースが流入しないジャンル）を意図的に耕すことで、Wiki 全体の活性度を保つ。

引数: `curiosity [--budget <N>]` （`--budget` 省略時はデフォルト 5 ページ）

## 役割

`ingest` / `save` / `recompile` は **新ソース・新会話を Wiki に流し込む** 流入経路で、Wiki の人気領域を中心に活性化させる。`curiosity` はその逆で、**LLM 主導で Wiki 全体を点検する** 流出側の操作。

両者の対比:

| 観点 | ingest / save 系 | curiosity |
|---|---|---|
| 起点 | 新ソース・新会話 | 既存 Wiki ページ |
| 活性化される領域 | 流入のある領域に集中 | 古い・忘れられた領域を強制的に点検 |
| ユーザー操作 | ソースを投入する | 起動するだけ |
| Wiki 本体への反映 | 即時 | 提案経由（[proposals.md](proposals.md)） |

`curiosity` の効果は Karpathy 原典の *"exploration compounds knowledge"* に対応する。学術的には curiosity-driven exploration / self-questioning と呼ばれるアプローチ群の応用。

## 実行フロー

7 つの Phase で構成する。

### Phase 0: pending リマインド

実行冒頭で各ジャンルの `_proposals/` をスキャンし、pending な提案が残っていればユーザーに案内する。

```
⚠️ pending な提案が残っています:
  - wiki/ai/_proposals/: 5件 (⚠️3件)
  - wiki/swift/_proposals/: 2件

先にレビューしますか?
  - yes: pending を順にレビュー（[proposals.md](proposals.md) のフローに従う）
  - no:  新しい curiosity サイクルを開始
```

`yes` を選んだら [proposals.md](proposals.md) の対話的レビューフローを起動し、レビュー完了後に Phase 1 へ進むかユーザーに再確認する。

### Phase 1: サンプリング

「最近耕されていないページ」を `updated` ベースで抽出する。frontmatter の追加メタデータは使わず、既存の `updated` フィールドのみを指標として使う。

#### 除外集合の構築

直近 30 日に curiosity / query / ingest / save / recompile で触れられたページを除外集合に入れる。情報源は各ジャンルの `log.md`:

- `Glob "$WIKI_ROOT/wiki/*/log.md"` で全ジャンルの log.md を取得
- 各 log.md を Read し、`## YYYY-MM-DD` セクションのうち **直近 30 日** のものを対象に
- エントリ中に登場する `[[ページ名]]` をすべて抽出 → 除外集合へ
- 抽出対象のエントリ種別: `curiosity:` / `query:` / `ingest:` / `save:` / `recompile:`

#### 候補ページの抽出

- 各ジャンルの `$WIKI_ROOT/wiki/<genre>/index.md` を Read してページ一覧を取得
- 各ページの `updated` を Read（frontmatter のみ）
- 除外集合に含まれるページを除く
- `updated` 古い順にソート

#### ジャンル均等化

サンプリングはジャンル横断で公平に行う:

- ジャンル数 = `G`、budget = `N` のとき、各ジャンルから `ceil(N / G)` ページを抽出
- 抽出は各ジャンル内で `updated` 古い順
- 全ジャンル合算で `N` を超えたら、最古ジャンル順に切り捨てる
- ジャンル内のページが枯渇したら（全ページが直近 30 日に触れられている）、そのジャンルは「1 周完了」として除外し、他ジャンルから補充

#### 抽出結果の表示

```
Phase 1 完了:
  サンプリング戦略: anti-recency (updated 古い順) + ジャンル均等化
  budget: <N>
  除外集合: <M>件 (直近30日の curiosity/query/ingest/save/recompile 対象)

  抽出ページ:
    - [[ページX]] (genre: ai, updated: 2025-12-01)
    - [[ページY]] (genre: swift, updated: 2026-01-15)
    - ...
```

### Phase 2: 質問生成

抽出した各ページから 1〜2 問の質問を生成する。質問の種類は 3 種を組み合わせる:

#### 単体問い

抽出ページ 1 つを起点に、そのページの内容を深掘る問い。

```
- 「[[ページA]] の主張Xは、最近の事例Yでも成立するか?」
- 「[[ページA]] が触れていない側面はあるか?」
- 「[[ページA]] の論点を別のジャンルに適用するとどうなるか?」
```

#### 反証問い

抽出ページの主張に対して、意図的に反証を探す問い。Wiki の自浄作用を作る。

```
- 「[[ページA]] の主張Xが間違っているとしたら、どのような根拠があり得るか?」
- 「[[ページA]] と矛盾する事例は他のページに存在するか?」
```

#### 横断問い (pair-wise)

抽出されたページ 2 つを組み合わせる問い。Wiki のジャンル間や概念間に新しい結節点を作る素材になる。

```
- 「[[ページA]] と [[ページB]] は補完関係か対立関係か?」
- 「[[ページA]] の概念を [[ページB]] の文脈で適用すると何が起きるか?」
```

#### 生成方針

- 抽出ページ 1 つあたり: 単体問い 1 + 反証問い 0〜1（ページ内容に応じて）
- 抽出ページ全体から pair-wise を 1〜2 組生成（ジャンル内・ジャンル間の両方を狙う）
- 合計質問数の目安: `budget * 1.5` 程度

### Phase 3: query 実行

各質問を [query.md](query.md) の検索フローで自答する。ただし `curiosity` 内部からの呼び出しでは:

- query の Phase 6（保存判断）と Phase 8（log.md 追記）は **行わない**
- 代わりに、答えと参照ページを Phase 4 の critic に渡す
- query の Read 上限（8 ページ）は質問ごとに独立して適用

### Phase 4: critic 評価

各質問の答えに対して、critic agent が以下を評価する:

1. **既存ページの繰り返しか?** — 答えが既存ページの単純な言い換えなら価値なし
2. **sources/ に根拠があるか?** — `[[sources/<genre>/<source>]]` 形式の引用が含まれているか
3. **Wiki の空白を埋めるか?** — 既存ページに無い新切り口・統合が含まれているか
4. **幻覚リスクは?** — 答えのうち sources/ に直接の記述がない部分があるか

評価結果から、答えを 4 カテゴリのいずれかに振り分ける:

| カテゴリ | 条件 | proposals 生成 |
|---|---|---|
| A. 新規ページ価値あり | 新切り口あり + sources/ 根拠あり + 既存と非重複 | `kind: new-page` |
| B. 既存ページに追記すべき | 特定の既存ページの空白を埋める | `kind: append` |
| C. 既存ページと矛盾発見 | 既存ページの主張と新情報が矛盾 | `kind: contradiction` |
| D. 価値なし | 既存ページの繰り返し / 根拠薄弱 | proposals 作らず、log にだけ記録 |

### Phase 5: proposals 書き出し

A / B / C と判定されたものを [proposals.md](proposals.md) に従って `_proposals/` に書き出す:

- 配置先: 対象ページが属するジャンルの `wiki/<genre>/_proposals/`
- ジャンル横断する場合: [proposals.md](proposals.md) の「ジャンル横断の主ジャンル自動選択」ロジックに従って主ジャンルを決定
- ファイル命名: `<YYYY-MM-DD>__<kind>__curiosity-<serial>.md`
- frontmatter / 本文構造は [proposals.md](proposals.md) の「frontmatter スキーマ」「本文テンプレート」に従う

各 kind の典型的な risk_flags:

| kind | risk_flags | confidence |
|---|---|---|
| `new-page` | `[hallucination-possible]` | medium |
| `append` | `[hallucination-possible]` | medium |
| `contradiction` | `[judgment-required]` | medium |

`hallucination-possible` を付ける根拠: 答えに含まれる主張のうち sources/ に直接の記述がない部分（LLM 推論）が必ず含まれるため。critic がこの該否を判定し、提案ファイルの `## 信頼度・リスク` セクションに具体的な該当箇所を明記する。

### Phase 6: log.md 追記

抽出された **全ページ**（Phase 5 で proposals が作られたか否かに関わらず）を log.md に記録する。これが次回 curiosity 実行時の除外集合になる。

各ジャンルの `log.md` に追記:

```markdown
## YYYY-MM-DD

- curiosity: [[ページX]], [[ページY]] を点検
  - 生成質問: <N>件
  - critic 評価: A=<n>件, B=<n>件, C=<n>件, D=<n>件
  - proposals: <パス>, <パス>
```

複数ジャンルにまたがるサンプリングがあった場合、各ジャンルの log.md に**そのジャンルに属するページのみを抽出した形** で追記する（除外集合の判定がジャンル単位で行われるため）。

### Phase 7: 対話的レビュー

Phase 5 で書き出した proposals に対して、[proposals.md](proposals.md) の「対話的レビューフロー」を起動する:

1. `<N>件の提案が保存されました。今レビューしますか?` (yes / later / apply-all-safe)
2. 各提案を順に表示し、`apply` / `edit` / `skip` / `reject` / `quit` の選択
3. 完了レポート

レビューで `later` を選んだ場合、次回 `curiosity` または `lint` 起動時の Phase 0 でリマインドされる。

## 完了レポート

```markdown
# Curiosity サイクル完了 — <today>

サンプリング: <N>ページ (ジャンル均等化)
  抽出: [[X]], [[Y]], ...

質問生成: <M>問 (単体<a>, 反証<b>, 横断<c>)

critic 評価:
  A 新規ページ価値あり: <n>件
  B 既存追記推奨: <n>件
  C 矛盾発見: <n>件
  D 価値なし (破棄): <n>件

proposals 書き出し:
  - wiki/ai/_proposals/: <n>件
  - wiki/swift/_proposals/: <n>件

対話的レビュー結果:
  apply: <n>件
  edit→apply: <n>件
  skip: <n>件
  reject: <n>件
```

## サンプリングが収束した場合

すべてのジャンルで「直近 30 日に触れていないページがゼロ」の場合、Wiki は十分活性化している状態。この場合は以下のメッセージを出して終了する:

```
すべてのページが直近 30 日に curiosity / query / ingest / save / recompile で
触れられています。今は curiosity を実行する必要はありません。
古いページを意図的に点検したい場合は、`--budget` を大きくするか、
除外期間を縮める（将来の機能拡張）か、特定ページに対して直接 query を実行してください。
```

## 重要な制約

- **proposals 経由のみ Wiki 反映**。curiosity が直接 Wiki 本体を書き換えることはない
- **log.md 追記は全抽出ページに対して行う**（Approve 問わず）。これが除外集合の真実の置き場
- **既存 Wiki ページの `updated` は触らない**。curiosity 自体は読み取り操作で、Wiki ページの `updated` は apply 時に proposals 経由で更新される
- **質問生成は LLM の判断**。プロンプトに「単体・反証・横断」のバランスを指示し、特定の質問種別だけに偏らないようにする
- **critic は同じ LLM でも別の指示で動かす**。「修正側」と「検証側」で観点を変えて、相関エラーを減らす

## 実行頻度の目安

- **週次**: 中規模 Vault (50〜200 ページ) では週 1 回、`--budget 5` 程度が目安
- **月次**: 大規模 Vault (200 ページ以上) では月 1 回、`--budget 10` 程度
- **手動**: 構造変更直後や、特定ジャンルを集中的に育てたいときに ad-hoc 実行

`lint` と組み合わせる場合: lint で構造的健全性を検査、curiosity で内容的活性度を試験、と役割を分けて両方を回す運用が想定される。
