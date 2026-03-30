# Issue Commands Reference

## issue list (ls, search)

List/search issues in a project.

```bash
# Basic listing
jira issue list
jira issue ls

# Search with text
jira issue list "Feature Request"

# Filter by type, status, priority
jira issue list -tBug -s"In Progress" -yHigh

# Filter by assignee/reporter
jira issue list -a "john@example.com"
jira issue list -r "reporter@example.com"

# Filter by labels (multiple)
jira issue list -lbackend -l"high prio"

# Filter by date
jira issue list --created today
jira issue list --created week
jira issue list --created month
jira issue list --created -10d  # last 10 days
jira issue list --updated -2w   # updated in last 2 weeks

# Plain output with specific columns
jira issue list --plain --columns key,status,assignee

# Raw JQL query (conditions only, ORDER BY is not supported in -q)
jira issue list -q"status = 'In Progress' AND assignee = currentUser()"

# Sorting (use --order-by instead of ORDER BY in JQL)
jira issue list --order-by updated             # Updated date descending (default)
jira issue list --order-by updated --reverse   # Updated date ascending
jira issue list --order-by rank --reverse      # Same order as Jira UI
jira issue list -a"John Doe" --order-by updated  # Combine with filters

# Pagination
jira issue list --paginate 20        # first 20
jira issue list --paginate 10:50     # 50 items starting from 10
```

### Key Flags
| Flag | Description |
|------|-------------|
| `-t, --type` | Filter by issue type (Bug, Story, Task, etc.) |
| `-s, --status` | Filter by status (can use multiple) |
| `-y, --priority` | Filter by priority |
| `-a, --assignee` | Filter by assignee (`x` for unassigned) |
| `-r, --reporter` | Filter by reporter |
| `-l, --label` | Filter by label (can use multiple) |
| `-C, --component` | Filter by component |
| `-P, --parent` | Filter by parent (Epic key) |
| `-q, --jql` | Raw JQL query (conditions only, no ORDER BY) |
| `--created` | Filter by created date (today/week/month/year/-Nd) |
| `--updated` | Filter by updated date |
| `--order-by` | Sort field (default: created). Available: created, updated, priority, status, rank, etc. |
| `--reverse` | Reverse sort order (default DESC → ASC) |
| `--plain` | Plain text output |
| `--columns` | Columns to show: TYPE,KEY,SUMMARY,STATUS,ASSIGNEE,REPORTER,PRIORITY,RESOLUTION,CREATED,UPDATED,LABELS |

---

## issue view (show)

Display issue details.

```bash
jira issue view ISSUE-123

# Show 5 recent comments
jira issue view ISSUE-123 --comments 5

# Raw JSON output
jira issue view ISSUE-123 --raw
```

---

## issue create

Create a new issue.

```bash
# Interactive mode
jira issue create

# Non-interactive
jira issue create -tBug -s"Bug title" -b"Description" -yHigh -lbug -a"assignee@example.com"

# With Epic link
jira issue create -tStory -s"Story title" -P EPIC-123

# Create in different project
jira issue create -pOTHER -tTask -s"Task in other project"

# Custom fields
jira issue create -tStory -s"Story" --custom story-points=3

# From template file
jira issue create -tTask -s"Task" --template /path/to/template.md

# From stdin
echo "Description" | jira issue create -tTask -s"Task title"

# Open in browser after creation
jira issue create -tTask -s"Task" --web
```

### Key Flags
| Flag | Description |
|------|-------------|
| `-t, --type` | Issue type (Bug, Story, Task, Sub-task, Epic) |
| `-s, --summary` | Title/summary |
| `-b, --body` | Description |
| `-y, --priority` | Priority |
| `-a, --assignee` | Assignee |
| `-r, --reporter` | Reporter |
| `-l, --label` | Labels (can use multiple) |
| `-C, --component` | Components (can use multiple) |
| `-P, --parent` | Parent issue (Epic or parent task) |
| `--custom` | Custom fields (key=value) |
| `--fix-version` | Fix version |
| `--template` | Template file for description |
| `--web` | Open in browser after creation |
| `--no-input` | Disable interactive prompts |

---

## issue edit (update, modify)

Edit an existing issue.

```bash
jira issue edit ISSUE-123

# Edit specific fields
jira issue edit ISSUE-123 -s"New summary" -b"New description"

# Change priority and add labels
jira issue edit ISSUE-123 -yHigh -lurgent -lbug

# Remove label (prefix with -)
jira issue edit ISSUE-123 --label -urgent

# Non-interactive
jira issue edit ISSUE-123 -s"Updated summary" --no-input

# From stdin
echo "New description" | jira issue edit ISSUE-123 --no-input
```

---

## issue move (transition, mv)

Transition issue to another status.

```bash
jira issue move ISSUE-123 "In Progress"
jira issue move ISSUE-123 Done

# With comment
jira issue move ISSUE-123 Done --comment "Completed the work"

# With resolution
jira issue move ISSUE-123 Done -R "Fixed"

# Reassign during transition
jira issue move ISSUE-123 "Code Review" -a "reviewer@example.com"
```

---

## issue assign (asg)

Assign issue to a user.

```bash
# Assign to user
jira issue assign ISSUE-123 "john@example.com"
jira issue assign ISSUE-123 "John Doe"

# Assign to self
jira issue assign ISSUE-123 $(jira me)

# Assign to default assignee
jira issue assign ISSUE-123 default

# Unassign
jira issue assign ISSUE-123 x
```

---

## issue comment

Manage issue comments.

```bash
# Add comment (interactive)
jira issue comment add ISSUE-123

# Add comment with body
jira issue comment add ISSUE-123 -b"This is my comment"

# From stdin
echo "Comment from stdin" | jira issue comment add ISSUE-123
```

---

## issue delete

Delete an issue.

```bash
jira issue delete ISSUE-123
```

---

## issue clone

Clone/duplicate an issue.

```bash
jira issue clone ISSUE-123
```

---

## issue link / unlink

Link or unlink issues.

```bash
# Link issues
jira issue link ISSUE-123 ISSUE-456

# Unlink issues
jira issue unlink ISSUE-123 ISSUE-456
```

---

## issue watch

Add user to issue watchers.

```bash
jira issue watch ISSUE-123
```

---

## issue worklog

Manage work logs.

```bash
jira issue worklog ISSUE-123
```
