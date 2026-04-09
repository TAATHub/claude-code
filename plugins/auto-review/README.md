# review

Claude Code 用の並列セルフレビュープラグイン。複数のレビュアーが同時にコードを分析し、批判的評価で妥当な指摘のみ自動修正する。

[shibayu36氏のセルフレビュー自動化](https://blog.shibayu36.org/entry/2026/03/23/173000)にインスパイアされて作成。

## 仕組み

1. **並列レビュー** — `reviewers.yml` に定義された全レビュアーを Agent ツールで同時起動
2. **批判的評価** — 各指摘を鵜呑みにせず、技術的妥当性を独自に判断
3. **自動修正** — 妥当な指摘のみ適用、却下分は理由付きで報告
4. **サマリー** — 対応・却下の一覧をダブルチェック可能な形式で出力

## デフォルトレビュアー

| 名前 | 観点 |
|------|------|
| `general-reviewer` | コード品質・セキュリティ・パフォーマンスを多角的に |
| `architecture-reviewer` | アーキテクチャ設計の俯瞰的レビュー |
| `codex-reviewer` | Codex CLI による別モデル視点 |
| `simplify-reviewer` | 可読性・一貫性・保守性、やりすぎ検出 |

## カスタマイズ

`skills/auto-review/reviewers.yml` を編集してレビュアーを追加・削除・変更できる。
エージェント定義は `skills/auto-review/agents/` にmdファイルとして配置する:

```yaml
reviewers:
  - name: my-reviewer
    role: カスタムレビュアー
    agent: agents/my-reviewer.md
```

## 前提条件

- `codex` CLI がインストール済みであること（`codex-reviewer` 用）

## 使い方

```
/auto-review    # 現在のブランチの変更をレビュー＋自動修正
```
