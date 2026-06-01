---
name: discovery-init
description: >
  Creates the GitHub architecture master issue and per-subtask sub-issues for
  a story, establishing the branch-independent state store that drives
  architecture drift detection throughout the workflow. Run once per story
  (STORY_KEY) — only when no master issue exists. Called by Phase 2.5 of the
  /workflow command after Phase 2 has created the JIRA subtasks.
compatibility:
  tools:
    - mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources
    - mcp__plugin_atlassian_atlassian__getJiraIssue
    - AskUserQuestion
---

# discovery-init

## When to run

Phase 2.5 of `/workflow`, **after Phase 2 has created the JIRA subtasks**, when
the master issue lookup returns no result:

```bash
gh issue list \
  --search "[${STORY_KEY}] Architecture in:title" \
  --label architecture \
  --json number,title,state \
  --limit 5
```

Empty result → this skill. Non-empty result → use `discovery-check` instead.

Do NOT run this skill manually against the skills repo.

---

## Step 1 — Confirm repository

Verify the active repository is the **project repo**, not the skills repo:

```bash
git remote -v
```

The remote URL must match the project being worked on. If it points to the
skills repo, halt and ask the user which repository to use before continuing.

---

## Step 2 — Ensure labels exist

Create the two labels needed. Both commands are idempotent — the `--force`
flag means they succeed even if the label already exists:

```bash
gh label create "architecture" \
  --description "Architecture master issue" \
  --color "0075ca" \
  --force

gh label create "arch:${STORY_KEY}" \
  --description "Architecture tracking for ${STORY_KEY}" \
  --color "e4e669" \
  --force
```

Labels must exist before any `gh issue create` or `gh issue list --label`
command references them.

---

## Step 3 — Read the parent JIRA ticket

Load the full Atlassian cloud context:

```
ToolSearch("select:mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources,mcp__plugin_atlassian_atlassian__getJiraIssue")
```

1. Call `mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources` to
   get the `cloudId`.
2. Call `mcp__plugin_atlassian_atlassian__getJiraIssue` with the `cloudId` and
   `STORY_KEY` to retrieve the full ticket including description, ACs, and
   acceptance criteria.

---

## Step 4 — Create the master issue

Create with overview body and labels. The architecture goes into the **first
comment** (Step 6), not the body.

```bash
gh issue create \
  --title "[${STORY_KEY}] Architecture — ${STORY_TITLE}" \
  --body "## Overview

${STORY_SUMMARY}

## Subtasks

<!-- populated in Step 7 -->" \
  --label "architecture" \
  --label "arch:${STORY_KEY}"
```

Capture the returned issue number as `MASTER_ISSUE_NUMBER`.

---

## Step 5 — Post full architecture as first comment

Read the ticket details from Step 3 and synthesise the end-to-end architecture.
Post it as the **first comment** on the master issue. This comment — not the
body — is the canonical architecture document. `discovery-check` reads and
edits this comment for drift.

The comment must include all of:
- **Types**: new and existing types involved, with their roles
- **Services**: which services are created, modified, or removed
- **Data flow**: how data moves through the system end-to-end
- **Concurrency model**: actor boundaries, MainActor constraints, async entry points
- **Constraints**: things the implementation must not violate
- **Non-goals**: what is explicitly out of scope for this story

```bash
gh issue comment ${MASTER_ISSUE_NUMBER} \
  --body "## Architecture

### Types
...

### Services
...

### Data flow
...

### Concurrency model
...

### Constraints
...

### Non-goals
..."
```

Do not invent architecture that is not derivable from the ticket content.
If the ticket lacks enough information to write any section, note it as
`Unknown — to be determined during subtask discovery` rather than guessing.

---

## Step 6 — Create sub-issues

For each JIRA subtask created in Phase 2 (in order), create one GitHub sub-issue:

```bash
gh issue create \
  --title "[${SUBTASK_KEY}] Technical approach — ${SUBTASK_TITLE}" \
  --body "## Technical approach

${TECHNICAL_APPROACH}

---
Part of #${MASTER_ISSUE_NUMBER}

**JIRA:** [${SUBTASK_KEY}](https://easygo.atlassian.net/browse/${SUBTASK_KEY})" \
  --label "arch:${STORY_KEY}"
```

`TECHNICAL_APPROACH` is derived from the JIRA subtask's description and the
master architecture — what specifically this subtask must do, the types it will
touch, and any concurrency constraints that apply. Do not write generic filler.

Capture all returned sub-issue numbers as `SUB_ISSUE_NUMBERS`.

### Partial failure

If `gh issue create` fails after some sub-issues have already been created:

1. List the sub-issue numbers that succeeded.
2. Name the subtask that failed.
3. Ask via `AskUserQuestion`:
   - **Retry**: attempt the failed sub-issue again
   - **Accept partial result**: continue to Step 7 with what was created; note the gap
   - **Abort**: leave created sub-issues as-is, do not proceed to Step 7

Never auto-rollback created GitHub issues.

---

## Step 7 — Update master issue checklist

Edit the master issue body to replace the placeholder comment with the
populated checklist. The checklist must match the JIRA subtask order:

```bash
gh issue edit ${MASTER_ISSUE_NUMBER} \
  --body "## Overview

${STORY_SUMMARY}

## Subtasks

- [ ] #${SUB_ISSUE_1} ${SUBTASK_1_TITLE} (${SUBTASK_1_KEY})
- [ ] #${SUB_ISSUE_2} ${SUBTASK_2_TITLE} (${SUBTASK_2_KEY})
..."
```

---

## Output

Emit on completion:

```
MASTER_ISSUE_NUMBER: <n>
ARCH_LABEL: arch:${STORY_KEY}
SUB_ISSUE_NUMBERS: [<n1>, <n2>, ...]
```

No files are written. No commits are made. All state is in GitHub.

The orchestrator records `MASTER_ISSUE_NUMBER` and `ARCH_LABEL` in the
context bundle for all subsequent phases.

---

## Anti-patterns

- **Never create issues in the skills repo.** Verify with `git remote -v` first.
- **Never invent architecture.** Only derive from the ticket content; flag
  unknown sections explicitly.
- **Never auto-rollback.** On partial failure, surface and ask — mirror
  `spec-pipeline`'s partial-failure pattern.
- **Never skip label creation.** `--label` in `gh issue create` fails silently
  if the label does not exist. Always run Step 2 first.
