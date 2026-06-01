# Discovery

## Architecture tracking — standalone entry point

Sets up or advances architecture tracking for a story without running the
full implementation pipeline. Use when you want to establish GitHub issues
before picking up the first subtask, manually trigger a drift check, or
import an existing architecture document for a story that already has JIRA
subtasks.

---

## Input

```
/discovery NAT-XXXX [path/to/architecture.md]
```

- `NAT-XXXX` — the **parent** JIRA story key (not a subtask key)
- `path/to/architecture.md` — optional path to an existing architecture
  document. Required when JIRA subtasks already exist for the story.

---

## Model confirmation

State on a single line before proceeding:

> Running as: [model name and version] — [plan mode / normal mode]

---

## Step 1 — Confirm repository

```bash
git remote -v
```

GitHub issues must land in the **project repo**, not the skills repo. If the
remote does not match the expected project, halt and ask the user.

---

## Step 2 — Check for an existing master issue

```bash
gh issue list \
  --search "[NAT-XXXX] Architecture in:title" \
  --label architecture \
  --json number,title,state \
  --limit 5
```

**Master issue exists →** apply skill `discovery-check` with the current
story context and halt. The story is already being tracked; no init needed.

**No master issue →** continue to Step 3.

---

## Step 3 — Check for existing JIRA subtasks

```
ToolSearch("select:mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources,mcp__plugin_atlassian_atlassian__getJiraIssue")
```

1. Call `getAccessibleAtlassianResources` to get the `cloudId`.
2. Call `getJiraIssue` with the parent story key to retrieve its child issues
   (subtasks). Look for a `subtasks` or `children` array in the response.

**Subtasks found + arch doc provided →** **import mode**. Continue to Step 4A.

**Subtasks found + no arch doc provided →** halt with:

```
Error: NAT-XXXX already has subtasks. Provide an architecture document:

  /discovery NAT-XXXX path/to/architecture.md

This prevents Opus from guessing an architecture for work already scoped.
```

**No subtasks + arch doc provided →** **full init with provided doc**. Apply
skill `discovery-init` passing `ARCH_DOC_PATH`. The skill will use the doc
instead of synthesising architecture from the ticket, then create JIRA
subtasks and GitHub issues.

**No subtasks + no arch doc →** **full init**. Apply skill `discovery-init`
with no extra parameters. The skill reads the ticket and generates everything
from scratch.

---

## Step 4A — Import mode (subtasks exist, arch doc provided)

Read the architecture document from disk:

```bash
cat "${ARCH_DOC_PATH}"
```

Confirm the file is non-empty. If empty or unreadable, halt and ask the user
to check the path.

Apply skill `discovery-init` passing:
- `ARCH_DOC_PATH` — the path to the pre-existing architecture document
- `EXISTING_SUBTASK_KEYS` — the list of subtask keys from Step 3

The skill will:
- Post the arch doc content as the first comment on the master issue
  (no architecture synthesis from JIRA)
- Create GitHub sub-issues from the existing subtasks
  (no `createJiraIssue` calls)

---

## Output

Report the result:

```
Master issue: #<number>
Sub-issues created: #<n1> (NAT-XXXX-1), #<n2> (NAT-XXXX-2), ...
Arch label: arch:NAT-XXXX
Mode: import | full-init | check
```

---

## Model & mode

Opus, plan mode — this command makes branching decisions based on live JIRA
and GitHub state; Opus must own all forks.
