---
name: discovery-audit
description: >
  Audits the completed story against its master architecture — comparing what
  was planned against what was built, identifying necessary deviations, and
  producing a durable post-implementation record. Called by Phase 2.5 of the
  /workflow command when FINAL_RUN is true, after Phase 8 of the final subtask.
  Also handles the final subtask's own close/reconcile that the reconcile sweep
  couldn't do (it runs before the subtask is in progress).
compatibility:
  tools:
    - mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources
    - mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue
    - mcp__plugin_atlassian_atlassian__transitionJiraIssue
    - AskUserQuestion
---

# discovery-audit

## When to run

Called by Phase 2.5 of `/workflow` when `discovery-check` returns
`FINAL_RUN: true` — meaning the current subtask was the last open one. This
skill is triggered **after Phase 8 succeeds** for that final subtask.

Do not invoke manually unless reviewing a completed story retroactively.

---

## Step 1 — Close the final subtask

The reconcile sweep in `discovery-check` skips the in-progress subtask by
design. That means the final subtask's own GitHub sub-issue and checklist box
were never closed by a later run (there is no later run). This step closes
the loop before the audit begins.

### 1a — Close the final sub-issue

```bash
gh issue comment ${FINAL_SUB_ISSUE_NUMBER} \
  --body "Closed — ${FINAL_SUBTASK_KEY} complete. Audit running."

gh issue close ${FINAL_SUB_ISSUE_NUMBER}
```

### 1b — Tick the final checklist box

Read the master issue body, replace `- [ ] #${FINAL_SUB_ISSUE_NUMBER}` with
`- [x] #${FINAL_SUB_ISSUE_NUMBER}`, and write:

```bash
gh issue edit ${MASTER_ISSUE_NUMBER} --body "${UPDATED_BODY}"
```

### 1c — Move the final JIRA subtask to Testing

```
ToolSearch("select:mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue,mcp__plugin_atlassian_atlassian__transitionJiraIssue")
```

Call `getTransitionsForJiraIssue` for the final subtask key. Find the
"Testing" transition (case-insensitive substring match on `name`). If
available, call `transitionJiraIssue`. If not available, record the gap and
continue — do not halt the audit for a JIRA transition that the board doesn't
support.

---

## Step 2 — Read the completed story

Gather all source material for the audit:

### 2a — Master issue

```bash
gh issue view ${MASTER_ISSUE_NUMBER} --json title,body,comments,state
```

Read:
- Body: the overview and completed checklist
- First comment: the final architecture (may have been updated by drift events)
- All subsequent comments: drift records written during the story

### 2b — All sub-issues

```bash
gh issue list \
  --label "arch:${STORY_KEY}" \
  --state closed \
  --json number,title,body,comments \
  --limit 50
```

For each closed sub-issue, read the body (technical approach) and all
comments. Drift update comments are especially relevant.

---

## Step 3 — Produce the audit

Write a structured assessment covering:

### Architecture conformance

For each section of the master architecture (Types, Services, Data flow,
Concurrency model, Constraints, Non-goals):

- Did the implementation follow the plan?
- If it deviated, what changed and which subtask introduced the deviation?
- Was the deviation recorded as a drift event, or was it silent?

### Drift events

List each drift event recorded during the story (from master issue comments
tagged `## Architecture drift recorded`). For each:

- Was the drift justified?
- Did the updated architecture propagate correctly to affected sub-issues?

### Non-goal adherence

Did any subtask implement something in the Non-goals section? If so, name it.

### Overall verdict

- `VERDICT: pass` — implementation substantially matches the architecture;
  all deviations were recorded and justified.
- `VERDICT: fail:<findings>` — one or more significant unrecorded deviations,
  silent architecture violations, or non-goal scope creep. List each finding
  concisely.

---

## Step 4 — Post audit as closing comment

Post the full audit as a comment on the master issue, then close it:

```bash
gh issue comment ${MASTER_ISSUE_NUMBER} \
  --body "## Architecture audit

**Verdict:** ${VERDICT}

### Architecture conformance
${CONFORMANCE_SUMMARY}

### Drift events
${DRIFT_EVENTS_SUMMARY}

### Non-goal adherence
${NON_GOALS_SUMMARY}

### Findings
${FINDINGS_OR_NONE}"

gh issue close ${MASTER_ISSUE_NUMBER}
```

If `VERDICT: fail`, do **not** close the master issue automatically. Surface
the findings to the user via `AskUserQuestion` first:

- **Acknowledge and close**: user accepts the findings; close the master issue
- **Investigate**: user wants to open follow-up tickets; list the findings,
  ask which should become new work items before closing

---

## Step 5 — Save durable copy to Obsidian

Save a copy of the audit to the Obsidian vault. This is a post-mortem read
artifact — the pipeline never reads it back.

```
${PLANS_DIR}/${STORY_KEY}-architecture-audit.md
```

`PLANS_DIR` is defined in the workflow variables as
`${HOME}/Developer/obsidian/${PROJECT_NAME}/plans`.

Write the same content as Step 4 under a top-level heading:

```markdown
# Architecture Audit — ${STORY_KEY}

**Master issue:** #${MASTER_ISSUE_NUMBER}
**Verdict:** ${VERDICT}

[full audit content]
```

---

## Output

Emit on completion:

```
VERDICT: pass
AUDIT_PATH: ${PLANS_DIR}/${STORY_KEY}-architecture-audit.md
```

or

```
VERDICT: fail:<concise findings list>
AUDIT_PATH: ${PLANS_DIR}/${STORY_KEY}-architecture-audit.md
```

On `VERDICT: fail`, the orchestrator surfaces findings to the user and does
not close the master issue until the user confirms.

---

## Anti-patterns

- **Do not close the master issue on `VERDICT: fail`** without user confirmation.
- **Do not skip the final-subtask close** (Step 1) — without it, the checklist
  is incomplete and the master issue body does not reflect reality.
- **Do not save the audit to the project repo** — Obsidian only (per the global
  plan-storage rule). The Obsidian copy is a read artifact; the canonical
  record is the GitHub closing comment.
- **Do not write a generic audit.** Cite specific sub-issues, drift events, and
  architecture sections by name. The audit should be legible to someone who
  wasn't in the session.
