---
allowed-tools:
    - Bash
    - AskUserQuestion
argument-hint: "[--target staged|all] [--language en|ja] [追加ヒント]"
description: Conventional Commits 形式で git コミットを作成するスキル。`--target` でコミット対象（staged/all）、`--language` でメッセージ言語（en/ja）を指定できる。「コミット作成」「create-commit」「commit を作って」などのリクエストで使用。
name: create-commit
---

# Create Commit

Conventional Commits 形式で、簡潔・一貫性のあるコミットを作成するスキル。

## 引数のパース

`$ARGUMENTS` から以下のオプションを解釈する（順序不問・大文字小文字無視）。

### `--target <staged|all>`

コミット対象を制御する。

| 値 | 動作 |
|----|------|
| `all` （**デフォルト**） | `git add -A` で全変更をステージしてからコミット |
| `staged` | ステージ済みファイルのみをコミット（`git add` しない） |

### `--language <en|ja>`

コミットメッセージの言語を制御する。

| 値 | 動作 |
|----|------|
| `en` / `english` （**デフォルト**） | 英語で記述 |
| `ja` / `jp` / `japanese` | 日本語で記述（subject / body とも） |

### その他の引数

オプション以外のトークンは、コミット意図のヒントとしてメッセージ生成時の参考にする。

### 値が省略された場合

`--target` や `--language` の値が省略された場合は、それぞれのデフォルト（`all` / `en`）を採用する。

## Step 1: 現在の状態を取得

以下を並列に実行する:

- `git status --short`
- `git branch --show-current`
- `git log --oneline -10`
- 差分:
  - `--target all`（デフォルト）→ `git diff HEAD`
  - `--target staged` → `git diff --cached`

差分が空（コミット対象なし）の場合は、コミットせずユーザーにその旨を報告して終了する。

## Step 2: ステージング

`--target all`（デフォルト）の場合のみ `git add -A` を実行する。

ただし、変更ファイル一覧に以下のパターンが含まれる場合は、自動で add せず `AskUserQuestion` で続行可否を確認する:

- `.env`, `.env.*`
- `*credentials*`, `*secret*`, `*token*`, `*.pem`, `*.key`
- `id_rsa`, `id_ed25519` 等の鍵ファイル

`--target staged` の場合はステージ済みのものをそのまま使い、追加 `add` は行わない。

## Step 3: コミットメッセージの生成

### フォーマット

```
<type>[(<scope>)]: <subject>

<body>
```

### Subject ルール

- **命令形**（imperative mood）で書く。英語は「add」「fix」「remove」など、日本語は「〜を追加」のような統一形（「追加した」のような過去形は使わない）
- **50 文字以内** を目安
- 末尾に句点（`.` / `。`）を付けない
- 英語の場合は小文字始まり
- `<scope>` は変更が単一モジュール/領域に閉じている場合のみ括弧で付ける（例: `feat(auth):`）。横断的な変更なら省略

### Prefix（type）一覧

差分から最も適切な type を **1 つ** 選ぶ。複数の性質が混ざる場合は最も主要なものを選ぶ。

| type | 用途 |
|------|------|
| `feat` | 新機能の追加、ユーザに見える挙動の追加 |
| `fix` | バグ修正 |
| `docs` | ドキュメント変更のみ（README、コメント、JSDoc 等） |
| `style` | フォーマット・空白・セミコロン等、ロジック非変更のスタイル変更 |
| `refactor` | リファクタリング（外部挙動を変えない内部改善） |
| `perf` | パフォーマンス改善 |
| `test` | テストの追加・修正のみ |
| `chore` | ビルド設定・依存更新・CI・ツール設定など雑務 |

### Body ルール

- **2〜3 行程度** で「**何を**」「**なぜ**」を簡潔に書く（**実装方法は書かない**）
- 1 行あたり 72 文字程度で折り返す
- 自明に小さな変更（typo 修正・1 行のリネーム等）は body を省略してよい
- 箇条書きにする場合も合計 2〜3 行に収まる範囲で

## Step 4: コミット実行

`git commit` を `-m` 2 個で実行する（subject と body を分離）。body を省略する場合は `-m` 1 個のみ。

body は HEREDOC で渡す形を取る:

```bash
git commit -m "feat(auth): add password reset endpoint" -m "$(cat <<'EOF'
Provide a way for users to recover access without contacting support.
Sends a one-time token via email consumed by the reset POST handler.
EOF
)"
```

**禁則事項**:

- `--no-verify` を勝手に付けない（pre-commit hook を尊重する）
- `--amend` は行わない（常に新規コミット）
- `Co-Authored-By` 行は付けない（個人ローカル運用前提）
- `git push` は行わない

## Step 5: 結果報告

コミット完了後、以下を表示して終了する:

- `git log -1 --stat` の出力（ハッシュ・メッセージ・変更ファイル一覧）
- pre-commit hook が失敗した場合は、その出力を提示し原因を簡潔に説明する（自動で `--no-verify` を付けない／勝手に再コミットしない）

## 補足

- type 判定で迷ったら、差分の **行数比** ではなく **意図** を優先する（例: 関数追加に伴う test 追加なら `feat`、純粋なテスト追加のみなら `test`）
- スコープが付けられる場合は付けたほうが grep 性が高まる（例: `fix(llm-wiki): correct lint regex`）
- 1 コミット 1 関心事の原則を守る。明らかに異質な変更が混在しているなら、staged を分割するようユーザーに提案する（自動分割はしない）

## 使用例

| 入力 | 動作 |
|------|------|
| （引数なし） | 全変更を英語でコミット |
| `--target staged` | ステージ済みのみを英語でコミット |
| `--language ja` | 全変更を日本語でコミット |
| `--target staged --language jp` | ステージ済みのみを日本語でコミット |
| `--language japanese 認証バグの修正` | 全変更を日本語でコミット、追加ヒント「認証バグの修正」を反映 |
