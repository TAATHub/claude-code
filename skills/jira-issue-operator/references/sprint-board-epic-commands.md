# Sprint, Board, Epic Commands Reference

## Sprint Commands

### sprint list (ls)

List sprints or sprint issues.

```bash
# List all sprints (interactive view)
jira sprint list

# Table view
jira sprint list --table

# Plain output
jira sprint list --table --plain

# Filter by state
jira sprint list --state active
jira sprint list --state future
jira sprint list --state closed
jira sprint list --state "active,future"

# View specific sprint issues
jira sprint list 123

# Current/Previous/Next sprint
jira sprint list --current
jira sprint list --prev
jira sprint list --next

# Plain output with columns
jira sprint list --plain --columns name,start,end,state
jira sprint list 123 --plain --columns type,key,summary,status
```

### Key Flags
| Flag | Description |
|------|-------------|
| `--state` | Filter by state: future, active, closed |
| `--current` | Current active sprint |
| `--prev` | Previous sprint |
| `--next` | Next planned sprint |
| `--table` | Table view |
| `--plain` | Plain text output |
| `--columns` | Sprint: ID,NAME,START,END,COMPLETE,STATE / Issues: TYPE,KEY,SUMMARY,STATUS,ASSIGNEE,etc. |
| `--show-all-issues` | Show issues from all projects |

---

### sprint add

Add issues to a sprint.

```bash
jira sprint add SPRINT_ID ISSUE-123 ISSUE-456
```

---

### sprint close

Close a sprint.

```bash
jira sprint close SPRINT_ID
```

---

## Board Commands

### board list

List boards in a project.

```bash
jira board list

# Plain output
jira board list --plain
```

---

## Epic Commands

### epic list

List epics in a project.

```bash
jira epic list

# Plain output
jira epic list --plain

# Filter by status
jira epic list -sDone

# With JQL
jira epic list -q"summary ~ 'feature'"
```

---

### epic create

Create a new epic.

```bash
# Interactive
jira epic create

# Non-interactive
jira epic create -n"Epic Name" -s"Epic Summary" -b"Description"
```

---

### epic add

Add issues to an epic.

```bash
jira epic add EPIC-123 ISSUE-456 ISSUE-789
```

---

### epic remove

Remove issues from an epic.

```bash
jira epic remove ISSUE-456 ISSUE-789
```
