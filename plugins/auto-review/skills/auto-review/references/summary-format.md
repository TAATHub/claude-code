# レビュー対応サマリー

SKILL.md の「ステップ3: レビュー対応サマリー」で使用する出力フォーマットの詳細仕様。

## サマリーの目的

「修正判断が適切だったかをユーザーがダブルチェックできること」が目的。
ユーザーが流し読みしただけで **どの Round で・何が問題で・どう直したか / なぜ直さなかったか** を把握できるように書く。Round と対応有無の切れ目が一目で分かることを最優先する。

## 全体構造

サマリーは以下の構造で出力する：

1. **ループサマリー**: 実施回数と終了理由を1行で
2. **Round ごとの表**: Round 1, Round 2, ... の順に H2 見出しで区切り、各 Round 内に1つの表を置く
3. 表の中で「対応した指摘」「対応しなかった指摘」を `対応` 列 (`✅` / `❌`) で区別する。**別セクションには分けない**（Round と対応有無の2軸でセクションを分けると視認性が落ちるため、対応有無は列で表現する）

## 表のカラム仕様

各 Round の表は以下のカラム構成にする：

| カラム | 内容 |
|---|---|
| `#` | Round 内での通し番号（1, 2, 3, ...） |
| `レビュアー` | reviewers.yml の name をそのまま使う。複数レビュアーが同じ指摘をしている場合はスラッシュ併記（例: `general-reviewer #1 / architecture-reviewer #1`） |
| `要点` | 指摘の要点を一言で（10〜30文字程度）。コードを特定できる固有名詞を含める |
| `指摘内容` | 何がどういう理由で問題なのかを **1〜2文** で。該当ファイル・関数名を含める |
| `対応` | `✅` （修正した） / `❌` （見送った）のいずれか |
| `修正/見送り理由` | 対応した場合は「どのファイル/何を/どう変えたか」を1〜2文で。見送った場合は「なぜ対応不要と判断したか」を1〜2文で |

## 記載ルール

- 各 Round の H2 見出しは `## Round N` とする
- 1 Round 1 表。指摘が0件の Round は省略してよい（その場合はループサマリー側に「Round N は指摘なし」と書く）
- 表のセル内では改行を使わず `<br>` も使わない（Markdown レンダラ依存を避けるため）。長くなる場合は読点で区切って詰める
- セル内に縦棒 `|` が必要な場合は `\|` でエスケープする
- コードを特定できる固有名詞（ファイル名・関数名・変数名）は **必ず** セル内に含める
- `要点` と `指摘内容` を冗長に重複させない。要点は見出し、指摘内容はその根拠と具体箇所を書く
- 複数レビュアーが同じ指摘をした場合は `レビュアー` 列にスラッシュ併記し、行を分けない

## ループ結果の記載

サマリー冒頭に1行で記載する：

```
**レビューループ**: N回実施（終了理由: [指摘なしで完了 / 全指摘却下で完了 / 最大回数(3回)到達]）
```

## 出力テンプレート

```markdown
## レビュー対応サマリー

**レビューループ**: 3回実施（終了理由: 最大回数(3回)到達）

## Round 1

| # | レビュアー | 要点 | 指摘内容 | 対応 | 修正/見送り理由 |
|---|---|---|---|---|---|
| 1 | general-reviewer #1 / architecture-reviewer #1 | debug-log の二重 emit と payload schema 不整合 | main.tsx の console wrapper が `{level,msg,ts}` を emit する一方、既存 debugBridge.ts の sendLogToDebugServer は `{level,message,time}` を JSON 文字列で emit しており、OverlayConsole マウント時に1回の console.log で2通の debug-log event が異なるスキーマで送出される | ✅ | console wrapping ロジックを main.tsx から debugBridge.ts の module top-level に集約し emit を一本化。OverlayConsole.tsx の sendLogToDebugServer 呼び出しは削除して表示専用に縮退 |
| 2 | general-reviewer #2 / architecture-reviewer Nit / simplify-reviewer #1 | scripts/test_consent_mock.py への古いドキュメント参照 | 実体は Node 版 scripts/ws-consent-mock.mjs に置き換わったが、main.tsx / App.tsx / ConsentMockOverlay.tsx の3箇所のコメントが旧 Python スクリプト名を参照しており grep 経由で辿った作業者を混乱させる | ✅ | 3ファイル機械的に scripts/ws-consent-mock.mjs に置換。残留参照ゼロを grep で確認 |
| 3 | codex-reviewer P1 | iOS WKWebView で AudioContext.resume() が user gesture 内で同期 dispatch されない | AudioPlaybackController.start() が audioWorklet.addModule() を await した後に resume() を呼んでいたため、gesture handler から呼ばれた場合でも gesture スコープが消費された後の dispatch になり、iOS WKWebView では resume() が永遠に pending のままになる | ✅ | start() 内の処理順を組み替え、addModule の await より前に `void this.context.resume().catch(() => {})` で fire-and-forget dispatch する形に変更。状態遷移は waitUntilRunning の statechange 監視で観測する責務分離は維持 |

## Round 2

| # | レビュアー | 要点 | 指摘内容 | 対応 | 修正/見送り理由 |
|---|---|---|---|---|---|
| 1 | general-reviewer #1 | waitUntilRunning が AudioContext closed で無限待ちになる | 関数冒頭の早期 return は `state === "running"` のみで、closed 状態で入った場合は Promise 分岐へ進む。closed からは状態遷移が起きないので、cancel を渡さない呼び出しは永遠に未解決のままになる | ✅ | 早期 return に `if (ctx.state === "closed") return false;` を追加。1行で leak を解消 |
| 2 | general-reviewer #2 | 同意モック中断時に AudioWorklet リングバッファが残り声が残る | cancel フラグは JS 側の streamChunks ループのみを止め、既に pushChunk 済みの最大 500ms 分のバッファは worklet 側で再生され続ける。ユーザーが「許可する/許可しない」を押した直後に声が残る UX 問題 | ❌ | ConsentMockOverlay の useEffect cleanup でフラッシュする方針は別タスクで対応予定。本 PR スコープ外として保留 |

## Round 3

Round 3 は指摘なしで完了。
```

## 良い例 / 悪い例

**悪い例**（Round の切れ目が無く、対応有無も流し読みでわからない）:

```markdown
### 対応した指摘

[Round 1] general-reviewer #1 ...
[Round 1] codex-reviewer P1 ...
[Round 2] general-reviewer #1 ...

### 対応しなかった指摘

[Round 2] general-reviewer #2 ...
```

**良い例**（Round で H2 を切り、Round 内は表1つ、対応列で見送りも同じ表に並べる）:

```markdown
## Round 1

| # | レビュアー | 要点 | 指摘内容 | 対応 | 修正/見送り理由 |
|---|---|---|---|---|---|
| 1 | general-reviewer #1 | useBubblePosition の RAF cleanup 順序問題 | tick() が先頭で次フレームの RAF を登録するため、unmount 直後に1回余計に tick が走り visible 高速トグル時に競合する | ✅ | cancelled フラグを導入し cleanup で立てた上で cancelAnimationFrame。tick 冒頭で cancelled チェックを追加。useOverlayState にも同パターンを適用 |
```
