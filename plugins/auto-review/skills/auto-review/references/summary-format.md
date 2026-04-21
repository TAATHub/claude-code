# レビュー対応サマリー 出力テンプレート

SKILL.md の「ステップ3: レビュー対応サマリー」で使用する出力フォーマット。

## 出力テンプレート

```markdown
## レビュー対応サマリー

**レビューループ**: N回実施（終了理由: [指摘なしで完了 / 全指摘却下で完了 / 最大回数(3回)到達]）

### 対応した指摘

#### [Round 1] general-reviewer #1 / simplify-reviewer #2

**[指摘の要点を一言で]**

- **指摘内容**:

  [該当箇所（ファイル/関数名）と、レビュアーが何をどう問題視したかを2〜3文で。
  背景やリスクも含める]

- **修正内容**:

  [どのファイル/何を/どう変えたかを2〜3文で。
  副次的に解消された他の指摘があれば併記]

#### [Round 2] architecture-reviewer #1

**[指摘の要点]**

- **指摘内容**:

  [2〜3文で具体的に]

- **修正内容**:

  [2〜3文で具体的に]

### 対応しなかった指摘

#### [Round 1] codex-reviewer #1

**[指摘の要点]**

- **指摘内容**:

  [2〜3文で具体的に]

- **対応しない理由**:

  [意図的な設計判断 / スコープ外 / 別PR対応 など、判断根拠を2〜3文で]
```

## 良い例 / 悪い例

**悪い例**（見出しに識別子と要点が詰まっている、本文も1行で背景が不明）:

```markdown
#### general-reviewer #1: RAF cleanup 順序問題
- **指摘内容**: tick() で RAF cleanup の順序がおかしい
- **修正内容**: cancelled フラグを追加した
```

**良い例**（見出しはレビュアー識別子のみ、要点は直下の太字行、各ラベルの後に空行を入れて本文を別段落にする）:

```markdown
#### [Round 1] general-reviewer #1

**useBubblePosition の RAF cleanup 順序問題**

- **指摘内容**:

  useBubblePosition hook の tick() は先頭で次フレームの requestAnimationFrame を登録する実装。
  unmount 直後にも1回余計に tick が走る可能性があり、visible の高速トグル時に競合リスクがある。

- **修正内容**:

  cancelled フラグを導入し、cleanup で cancelled=true を立てた上で cancelAnimationFrame。
  tick 冒頭で cancelled チェックを追加。同パターンを useOverlayState にも適用した。
```
