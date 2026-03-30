# JQL (Jira Query Language) Reference

## Basic Syntax

```
field operator value
```

## Common Fields

| Field | Description | Example |
|-------|-------------|---------|
| `project` | Project key | `project = PROJ` |
| `status` | Issue status | `status = "In Progress"` |
| `assignee` | Assigned user | `assignee = currentUser()` |
| `reporter` | Issue reporter | `reporter = "john@example.com"` |
| `priority` | Priority level | `priority = High` |
| `type` | Issue type | `type = Bug` |
| `labels` | Issue labels | `labels = urgent` |
| `component` | Component | `component = Backend` |
| `sprint` | Sprint name/ID | `sprint = "Sprint 1"` |
| `epic` | Epic link | `"Epic Link" = EPIC-123` |
| `parent` | Parent issue | `parent = STORY-123` |
| `created` | Created date | `created >= -7d` |
| `updated` | Updated date | `updated >= startOfDay()` |
| `resolved` | Resolved date | `resolved >= startOfMonth()` |
| `duedate` | Due date | `duedate <= endOfWeek()` |
| `summary` | Issue summary | `summary ~ "feature"` |
| `description` | Description | `description ~ "bug"` |
| `text` | Any text field | `text ~ "search term"` |

## Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Equals | `status = Done` |
| `!=` | Not equals | `status != Done` |
| `~` | Contains text | `summary ~ "bug"` |
| `!~` | Not contains | `summary !~ "test"` |
| `>`, `>=`, `<`, `<=` | Comparison | `priority >= High` |
| `IN` | In list | `status IN (Open, "In Progress")` |
| `NOT IN` | Not in list | `type NOT IN (Epic, Sub-task)` |
| `IS` | Is empty/null | `assignee IS EMPTY` |
| `IS NOT` | Is not empty | `assignee IS NOT EMPTY` |
| `WAS` | Was value | `status WAS "In Progress"` |
| `CHANGED` | Field changed | `status CHANGED` |

## Logical Operators

```jql
# AND
project = PROJ AND status = Open

# OR
priority = High OR priority = Highest

# NOT
NOT status = Done

# Parentheses for grouping
(status = Open OR status = "In Progress") AND assignee = currentUser()
```

## Date Functions

| Function | Description |
|----------|-------------|
| `now()` | Current timestamp |
| `currentUser()` | Logged in user |
| `startOfDay()` | Start of today |
| `endOfDay()` | End of today |
| `startOfWeek()` | Start of current week |
| `endOfWeek()` | End of current week |
| `startOfMonth()` | Start of current month |
| `endOfMonth()` | End of current month |
| `startOfYear()` | Start of current year |
| `endOfYear()` | End of current year |

## Relative Dates

```jql
# Last 7 days
created >= -7d

# Last 2 weeks
updated >= -2w

# Last 1 month
created >= -1M

# Next 3 days
duedate <= 3d
```

## Common JQL Examples

```jql
# My open issues
assignee = currentUser() AND status != Done

# Unassigned high priority bugs
type = Bug AND priority >= High AND assignee IS EMPTY

# Issues created this week
created >= startOfWeek()

# Overdue issues
duedate < now() AND status != Done

# Issues updated in last 24 hours
updated >= -24h

# Issues in current sprint
sprint in openSprints()

# Issues without epic
"Epic Link" IS EMPTY

# Recently resolved
resolved >= -7d

# My watching issues
watcher = currentUser()

# Issues with comments from me
comment ~ currentUser()
```

## Usage with JIRA CLI

```bash
# Use -q flag for JQL queries (conditions only, no ORDER BY)
jira issue list -q"status = 'In Progress' AND assignee = currentUser()"

# Complex query
jira issue list -q"project = PROJ AND type = Bug AND priority >= High AND created >= -30d"

# Search across all projects
jira issue list -q"text ~ 'search term' AND project IS NOT EMPTY"
```

## Sorting Results

**重要**: jira-cliでは、JQL内に`ORDER BY`句を含めることはできない。ソートには`--order-by`オプションを使用する。

```bash
# デフォルトのソート順: created DESC

# 更新日時でソート（降順がデフォルト）
jira issue list --order-by updated

# 昇順でソート
jira issue list --order-by updated --reverse

# UIと同じ順序で表示（rank順）
jira issue list --order-by rank --reverse

# JQLと組み合わせる
jira issue list -q"assignee = currentUser()" --order-by updated

# 利用可能なソートフィールド: created, updated, priority, status, rank, etc.
```

### --order-by と --reverse

| オプション | 説明 |
|------------|------|
| `--order-by <field>` | ソートフィールド指定（デフォルト: created） |
| `--reverse` | ソート順を反転（デフォルトDESC → ASC） |
