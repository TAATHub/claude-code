# create-commit

[Conventional Commits](https://www.conventionalcommits.org/) 形式で git コミットを作成する Claude Code 用スキル。コミット対象（staged/all）とメッセージ言語（英語/日本語）をオプションで切り替えられる。

## 仕組み

1. **引数パース** — `--target` と `--language` を解釈し、デフォルト（全変更・英語）を上書き
2. **状態取得** — `git status` / `git diff` / `git branch` / `git log` を並列に取得
3. **ステージング** — `--target all` の場合に `git add -A`（機密ファイル疑いがある場合は確認）
4. **メッセージ生成** — Conventional Commits（`feat`/`fix`/`docs`/`style`/`refactor`/`perf`/`test`/`chore`）から最適な type を選び、subject（命令形・50 文字以内）と body（2〜3 行・72 文字折返し）を生成
5. **コミット実行** — `git commit -m <subject> -m <body>` を実行。`--no-verify`/`--amend`/`Co-Authored-By` は付与しない
6. **結果報告** — `git log -1 --stat` を表示。pre-commit hook 失敗時は原因のみ報告し勝手に再試行しない

## オプション

### `--target <staged|all>`

| 値 | 動作 |
|----|------|
| `all`（デフォルト） | `git add -A` で全変更をステージしてからコミット |
| `staged` | ステージ済みのみコミット |

### `--language <en|ja>`

| 値 | 動作 |
|----|------|
| `en` / `english`（デフォルト） | 英語で記述 |
| `ja` / `jp` / `japanese` | 日本語で記述 |

## 使い方

```
/create-commit                                # 全変更を英語でコミット
/create-commit --target staged                # ステージ済みのみ英語
/create-commit --language ja                  # 全変更を日本語
/create-commit --target staged --language jp  # ステージ済みのみ日本語
/create-commit --language ja 認証バグの修正    # ヒント付き
```

トリガーフレーズ（「コミット作成」「commit を作って」等）からの自動起動にも対応する。

## 参考

- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [LLM 駆動の Git コミットメッセージ生成（Zenn）](https://zenn.dev/saka1/articles/647a177cc5f7b8)
- [Git コミットメッセージの prefix（Qiita）](https://qiita.com/SMZXB/items/53c6e5ff4bcd6e6ababc)
