---
name: jira-issue-operator
description: Jira/JIRAの操作を行うスキル。jira-cliを使用してJiraの操作を行う。Issue作成・編集・検索、Sprint管理、Epic操作、JQLクエリなどをサポート。「Jiraでチケット作って」「JiraのIssueを確認して」「スプリントのタスク一覧」「jql検索して」などJira関連の操作リクエストで使用。
---

# JIRA CLI Skill

JIRA CLIを使用してJIRAの各種操作を実行する。

## Quick Reference

### Issue操作

```bash
# 一覧表示
jira issue list
jira issue list -tBug -s"In Progress"

# 詳細表示
jira issue view ISSUE-123

# 作成
jira issue create -tTask -s"タイトル" -b"説明"

# 編集
jira issue edit ISSUE-123 -s"新タイトル"

# ステータス変更
jira issue move ISSUE-123 "In Progress"

# アサイン
jira issue assign ISSUE-123 "user@example.com"
jira issue assign ISSUE-123 $(jira me)  # 自分にアサイン
jira issue assign ISSUE-123 x           # アサイン解除
```

### Sprint操作

```bash
# スプリント一覧
jira sprint list
jira sprint list --current

# スプリントにIssue追加
jira sprint add SPRINT_ID ISSUE-123
```

### Epic操作

```bash
# Epic一覧
jira epic list

# EpicにIssue追加
jira epic add EPIC-123 ISSUE-456
```

### JQL検索

```bash
# JQL条件で検索（ORDER BY句は-qオプションでは使用不可）
jira issue list -q"status = 'In Progress' AND assignee = currentUser()"

# ソートは--order-byオプションで指定（デフォルト: created DESC）
jira issue list --order-by updated
jira issue list -a"John Doe" --order-by updated  # フィルタと組み合わせ
```

## Command Selection Guide

| 目的 | コマンド |
|------|----------|
| Issue一覧を見たい | `jira issue list` |
| 特定Issueの詳細 | `jira issue view ISSUE-KEY` |
| 新規Issue作成 | `jira issue create` |
| Issue編集 | `jira issue edit ISSUE-KEY` |
| ステータス変更 | `jira issue move ISSUE-KEY STATE` |
| アサイン変更 | `jira issue assign ISSUE-KEY USER` |
| コメント追加 | `jira issue comment add ISSUE-KEY` |
| ブラウザで開く | `jira open ISSUE-KEY` |
| Sprint一覧 | `jira sprint list` |
| 現在のSprint | `jira sprint list --current` |
| Epic一覧 | `jira epic list` |
| Board一覧 | `jira board list` |
| 自分の情報 | `jira me` |

## Common Options

| オプション | 説明 |
|------------|------|
| `-p, --project` | プロジェクト指定 |
| `--plain` | プレーンテキスト出力 |
| `--no-input` | 対話プロンプト無効化 |
| `--web` | 操作後にブラウザで開く |

## Detailed References

- **実践的な使用例**: [examples.md](examples.md)
- **Issue操作の詳細**: [references/issue-commands.md](references/issue-commands.md)
- **Sprint/Board/Epic操作**: [references/sprint-board-epic-commands.md](references/sprint-board-epic-commands.md)
- **JQL構文リファレンス**: [references/jql-reference.md](references/jql-reference.md)
