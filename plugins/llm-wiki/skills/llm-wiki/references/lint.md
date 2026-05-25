# lint — Vault 健全性チェック

`lint` は Vault を読み取り、6 つの観点で問題候補を検出し、修正案を **proposals** として `_proposals/` に書き出す。修正の反映はユーザーの対話的レビューを経て行う。

引数で対象を絞れる: `lint <genre>` でジャンル限定、引数なしで Vault 全体。

## 動作方針

検出 → 修正案生成 → `_proposals/` に書き出し → 対話的レビュー、の 4 段で動作する。詳細は [proposals.md](proposals.md) を参照。

すべての検出項目を proposals 化する。検出ロジックが LLM 判断を含むもの・誤検知が多いものは `risk_flags` を付けてレビュー時にユーザーが判断できるようにする。

## チェック項目

### 1. 矛盾検出（Contradictions）

- ページAとページBで同一トピックについて矛盾する記述がないか
- 数値・年代・定義の食い違いを優先
- 検出方法: `Grep` で同じキーワードを含むページを集め、関連箇所を読み比べる

**proposals 生成**:

- `kind: contradiction-found`
- `risk_flags: [judgment-required]`
- `confidence: medium`
- 提案内容: 「両論併記」「ページAを更新」「ページBを更新」のいずれかを critic が推奨方針として書く（ただし最終判断はユーザー）

### 2. 孤立ページ（Orphans）

- 他のどのページからも `[[該当ページ]]` でリンクされていないページ
- ただし `_overview.md` `index.md` `log.md` は例外（リンクされなくても問題なし）
- 検出方法: 全ページの `[[...]]` 出現と全ページのファイル名を集合演算

**proposals 生成**:

- `kind: orphan-fix`
- `risk_flags: [judgment-required]`
- `confidence: medium`
- 提案内容: critic が「リンク元として妥当な候補ページ」を 1〜3 個推奨する。ユーザーは候補から選ぶか、削除・統合を判断する

### 3. 不足ページ（Missing pages）

- 複数ページで頻繁に言及されているが、独立ページが存在しないコンセプト
- 検出方法: 各ページから固有名詞・コンセプト名を抽出し、ファイル一覧と突き合わせ
- 完璧な抽出は難しいので「3ページ以上で言及 × 独立ページなし」程度の閾値で報告

**proposals 生成**:

- `kind: missing-page`
- `risk_flags: [hallucination-possible]`（強）
- `confidence: low` または `medium`
- 提案内容: critic がコンセプトの定義・関連ページ・想定 sources を踏まえて新ページの本文ドラフトを書く。**幻覚リスクが特に高い** ため、提案ファイルに原本未参照の記述を含むことを明記する

### 4. 古い情報（Stale）

- frontmatter `updated` が古い × 新しいソースが取り込まれて関連知識が更新されている可能性
- 検出方法: 各ページの `updated` と、その `sources` に含まれるソースの `updated` を比較
- 1年以上更新されていないページは年単位で `updated` が古い旨を併記

**proposals 生成**:

- `kind: stale-fix`
- `risk_flags: [judgment-required]`
- `confidence: medium`
- 提案内容: critic が「どのセクションを、どう更新すべきか」の案を書く。recompile を推奨する場合もあり、その旨を併記

### 5. 相互参照不足（Weak cross-references / Backlink audit）

新ページを作るたびに ingest が逐次 backlink を張らない方針のため、定期 lint がこの役割を担う。**5a と 5b の 2 つの観点で並行実行** する。

#### 5a. タイトル文字列ベースの欠落リンク検出（高精度）

「ベタテキストでページタイトルが出現しているのに `[[<タイトル>]]` 形式になっていない」ケースを機械的に検出する。誤検知が少ないため、**追加すべきリンクの主候補**として扱う。

検出手順:

1. 全 wiki ページのタイトル一覧を `Glob "$WIKI_ROOT/wiki/**/*.md"` から収集
2. **タイトル長 4 文字以上**かつ **ブラックリスト未掲載** のものを audit 対象とする（誤検知抑制）
3. ジャンルごとに対象タイトルをまとめ、batched Grep で 1 ジャンル 1 回の検索:
   ```
   Grep -E "(タイトル1|タイトル2|...)" wiki/<genre>/*.md -n -B 1 -A 1
   ```
4. クロスジャンル検出のため Vault 全体に対しても 1 回 batched Grep を回す
5. Grep 出力から以下を **除外**:
   - マッチ行が `#` で始まる（見出し）
   - マッチ行を含むコードブロック内（前後の ` ``` ` フェンス検査）
   - frontmatter 内（先頭〜2 番目の `---` ライン区間）
   - マッチ行が `>` で始まる（blockquote）
   - 同じファイルに既に `[[<タイトル>]]` が存在する
   - 自分自身のページ内のマッチ
6. 残ったものを「明確な追加候補」としてリスト

タイトルが短い／一般的すぎるものは検出しない。例:

```
# audit 対象外（タイトル短すぎ・一般語）
- 3 文字以下: Go, Web, AI（誤検知が多すぎる）
- ブラックリスト: データ, システム, 概要（一般語）
```

**proposals 生成**:

- `kind: link-fix`
- `risk_flags: []`（リスクなし）
- `confidence: high`
- 提案内容: 対象ファイル `<file>:<line>` のベタテキストを `[[<ページ>]]` に置換する単純な差分。`risk_flags` 空のため、対話的レビューの `apply-all-safe` で一括反映される対象

#### 5b. キーワード重複度ベースの関連性検出（低精度・補完用）

タイトル一致しなくても、内容上明らかに関連するペアを補完的に拾う。

- 各ページから主要キーワード（固有名詞・専門用語）を抽出
- `related` 不在のペアの中で、キーワード重複度が閾値以上のものを「弱い候補」としてリスト
- 5a で既に検出されているペアは除外（重複報告を避ける）

**proposals 生成**:

- `kind: weak-relation`
- `risk_flags: [low-precision]`
- `confidence: low`
- 提案内容: 両ページの `## 関連ページ` セクションへの相互リンク追記案、および `related` フィールドの更新案。誤検知前提なのでユーザーの判断必須

## proposals の書き出し

各検出項目で生成した proposals を `_proposals/` に書き出す:

- 配置先: 対象ページが属するジャンルの `wiki/<genre>/_proposals/`
- ジャンル横断する場合: [proposals.md](proposals.md) の「ジャンル横断の主ジャンル自動選択」ロジックに従って主ジャンルを決定
- ファイル命名: `<YYYY-MM-DD>__<kind>__lint-<serial>.md`
- frontmatter / 本文構造は [proposals.md](proposals.md) の「frontmatter スキーマ」「本文テンプレート」に従う

## 完了レポート

proposals 書き出しの後、サマリレポートをコンソールに出力:

```markdown
# Lint レポート — <today>

対象: <vault全体 / ジャンル名>
スキャンページ数: <n>

## 検出サマリ

| 項目 | 検出数 | proposals 生成 |
|---|---|---|
| 1. 矛盾候補 | <n> | <n> 件 (judgment-required) |
| 2. 孤立ページ | <n> | <n> 件 (judgment-required) |
| 3. 不足ページ候補 | <n> | <n> 件 (hallucination-possible) |
| 4. 古い情報候補 | <n> | <n> 件 (judgment-required) |
| 5a. 欠落リンク候補 | <n> | <n> 件 (リスクなし) |
| 5b. 関連性候補 | <n> | <n> 件 (low-precision) |

## ジャンル別 proposals 配置

- wiki/ai/_proposals/: <n>件 (⚠️<m>件)
- wiki/swift/_proposals/: <n>件 (⚠️<m>件)
- ...

合計: <N>件の proposals を生成しました。
```

`⚠️` は `hallucination-possible` または `judgment-required` を含む提案を示す。

## 対話的レビュー

完了レポートの直後、[proposals.md](proposals.md) の「対話的レビューフロー」に従ってレビューを起動する:

1. レビュー開始の確認 (`yes` / `later` / `apply-all-safe`)
2. 各提案を順に表示し、`apply` / `edit` / `skip` / `reject` / `quit` の選択
3. 完了レポート

`apply-all-safe` を選んだ場合、`risk_flags` 空の提案（主に 5a `link-fix`）が一括で反映される。これは過去の bulk-link 化作業（70〜80 ファイルへの一括リンク追記）を半自動化する効果を持つ。

## 重要な制約

- **proposals 経由のみ反映可**。lint が直接 Wiki 本体を書き換えることはない。すべての修正はユーザーの `apply` を経由する
- **`risk_flags` 空の link-fix は `apply-all-safe` で一括反映可**。これは「機械的に判定可能、誤検知ゼロ前提」の最小ノイズ提案として扱う
- **検出が網羅的でないことを完了レポートに明記**し、「最終判断はユーザー」と添える
- **`updated` の更新は apply 時のみ**。lint 自体は読み取り操作（および `_proposals/` への書き出し）で、Wiki ページの `updated` は触らない

## ingest との関係

ingest が新ソースから新規ページを作る際、5a タイプの backlink 張りはその場で行わない設計のため、lint がこの役割を引き受ける。Vault が一定規模に達したら週次〜月次で lint を回し、`apply-all-safe` で link-fix を一括反映する運用が想定される。
