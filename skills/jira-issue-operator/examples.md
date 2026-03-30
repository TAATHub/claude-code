# JIRA CLI 使用例

実際の操作例をまとめたドキュメントです。

## 1. 自分担当でステータスが"OPEN"のチケット一覧を取得

```bash
jira issue list -q"status = 'OPEN' AND assignee = currentUser()" --plain
```

**説明**: JQLを使用して、自分にアサインされていてステータスがOPENのチケットを検索します。

**出力例**:
```
TYPE            KEY         SUMMARY                                 STATUS
Task / タスク   ISSUE-001   ログイン画面のUIを改善する              OPEN
Bug / バグ      ISSUE-002   検索機能でエラーが発生する              OPEN
```

---

## 2. 自分担当で最新のアクティブスプリントにあるチケット一覧を取得

```bash
# アクティブスプリントの確認
jira sprint list --state active --plain

# 自分担当のチケットを取得
jira issue list -q"sprint in openSprints() AND assignee = currentUser()" --plain
```

**説明**: `openSprints()`関数でアクティブなスプリントを指定し、自分担当のチケットのみをフィルタリングします。

**出力例**:
```
TYPE            KEY         SUMMARY                                 STATUS
Task / タスク   ISSUE-003   新機能の実装                            DOING
Task / タスク   ISSUE-004   テストコードの追加                      DOING
Bug / バグ      ISSUE-005   パフォーマンス改善                      DOING
```

---

## 3. エピックの子タスクを作成し、自分をアサインしてスプリントに追加

### Step 1: 親エピックの確認

```bash
jira issue view ISSUE-100 --plain
```

### Step 2: アクティブスプリントIDの取得

```bash
jira sprint list --state active --plain
```

**出力例**:
```
ID      NAME                START                   END                     STATE
123     Sprint 2024-01      2024-01-01 10:00:00     2024-01-14 00:00:00     active
```

### Step 3: 子タスクの作成（自分をアサイン）

```bash
jira issue create -tTask -s"チケットタイトル" -P ISSUE-100 -a "$(jira me)" --no-input --raw
```

**オプション説明**:
- `-tTask`: タイプをTaskに指定
- `-s"..."`: サマリー（タイトル）
- `-P ISSUE-100`: 親エピックを指定
- `-a "$(jira me)"`: 自分をアサイン
- `--no-input`: 対話プロンプトを無効化
- `--raw`: JSON形式で出力

**出力例**:
```json
{"id":"12345","key":"ISSUE-101"}
```

### Step 4: スプリントに追加

```bash
jira sprint add 123 ISSUE-101
```

### Step 5: 作成したチケットの確認

```bash
jira issue view ISSUE-101 --plain
```

---

## 4. よく使うJQL検索パターン

### 自分担当の全チケット

```bash
jira issue list -q"assignee = currentUser()" --plain
```

### 特定ステータスのチケット

```bash
jira issue list -q"status = 'DOING' AND assignee = currentUser()" --plain
```

### 複数ステータスのチケット

```bash
jira issue list -q"status in ('OPEN', 'DOING') AND assignee = currentUser()" --plain
```

### 特定エピック配下のチケット

```bash
jira issue list -q"'Epic Link' = ISSUE-100" --plain
```

### 今週作成されたチケット

```bash
jira issue list -q"created >= startOfWeek() AND assignee = currentUser()" --plain
```

---

## 5. ワンライナー集

### 自分のユーザーIDを取得

```bash
jira me
```

### チケットをブラウザで開く

```bash
jira open ISSUE-001
```

### チケットのステータス変更

```bash
jira issue move ISSUE-001 "DOING"
```

### チケットのアサイン変更

```bash
# 自分にアサイン
jira issue assign ISSUE-001 $(jira me)

# アサイン解除
jira issue assign ISSUE-001 x
```
