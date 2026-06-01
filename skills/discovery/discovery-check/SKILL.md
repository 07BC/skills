---
name: discovery-check
description: >
  Reconciles completed subtask work (closes GitHub sub-issues, ticks master
  checklist, moves JIRA to Testing) and checks the current subtask's technical
  approach against the master architecture — updating both if drift is detected.
  Called by Phase 2.5 of the /workflow command on every subsequent run after
  discovery-init has created the master issue. Opus judges drift; Sonnet handles
  the gh and JIRA writes.
compatibility:
  tools:
    - mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources
    - mcp__plugin_atlassian_atlassian__getJiraIssue
    - mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue
    - mcp__plugin_atlassian_atlassian__transitionJiraIssue
    - AskUserQuestion
---

# discovery-check

## When to run

Phase 2.5 of `/workflow`, when the master issue lookup returns a result:

```bash
gh issue list \
  --search "[${STORY_KEY}] Architecture in:title" \
  --label architecture \
  --json number,title,state \
  --limit 5
```

Non-empty result → this skill. Empty result → use `discovery-init` instead.

---

## Part A — Reconcile sweep

### Responsibility: Sonnet subagent

The orchestrator delegates this section to a Sonnet subagent. Sonnet performs
all `gh` and JIRA writes; it does not make drift judgements.

### A1 — List open sub-issues

```bash
gh issue list \
  --label "arch:${STORY_KEY}" \
  --state open \
  --json number,title,body \
  --limit 50
```

Exclude the sub-issue for the **current subtask being picked up now** (matched
by `CURRENT_SUBTASK_KEY` in the body). Work through the remaining open issues.

### A2 — Check JIRA status

For each open sub-issue (excluding the current one):

```
ToolSearch("select:mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources,mcp__plugin_atlassian_atlassian__getJiraIssue")
```

1. Extract the JIRA subtask key from the sub-issue body (the `[NAT-XXXX-N]`
   prefix in the title, or the JIRA link in the body).
2. Call `mcp__plugin_atlassian_atlassian__getJiraIssue` to read the current status.

**Completion signal:** JIRA status = **In Review** or **Done**. This is the
signal Phase 8 sets synchronously when it raises a PR. Do not rely on PR links
in the sub-issue body — they are not populated by Phase 8.

### A3 — Close completed sub-issues

For each sub-issue whose JIRA status is In Review or Done:

1. Close the GitHub sub-issue with a one-line comment:

   ```bash
   gh issue comment ${SUB_ISSUE_NUMBER} \
     --body "Closed — ${SUBTASK_KEY} is ${JIRA_STATUS}."

   gh issue close ${SUB_ISSUE_NUMBER}
   ```

2. Tick its checkbox in the master issue body. Read the current body, replace
   `- [ ] #${SUB_ISSUE_NUMBER}` with `- [x] #${SUB_ISSUE_NUMBER}`, then write:

   ```bash
   gh issue edit ${MASTER_ISSUE_NUMBER} --body "${UPDATED_BODY}"
   ```

3. Transition the JIRA subtask to **Testing**:

   ```
   ToolSearch("select:mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue,mcp__plugin_atlassian_atlassian__transitionJiraIssue")
   ```

   Call `getTransitionsForJiraIssue` and find the transition whose `name`
   matches "Testing" (case-insensitive substring). If no such transition is
   available from the current status, **record the gap and surface it** — do
   not force a transition that does not exist. Some boards have Testing before
   In Review; do not assume the path is forward.

### A4 — Final-run detection

After the reconcile sweep, count the remaining open sub-issues (excluding
the current one).

- If **zero remain** → set `FINAL_RUN=true`. The current subtask is the last
  one; Phase 2.5 will trigger the audit after Phase 8.
- Otherwise → set `FINAL_RUN=false`.

---

## Part B — Drift judgment

### Responsibility: Opus orchestrator

The orchestrator (Opus, plan mode) reads the architecture and makes the drift
judgment. Do not delegate this section to a Sonnet subagent.

### B1 — Read the architecture

```bash
gh issue view ${MASTER_ISSUE_NUMBER} --json comments
```

The architecture is in the **first comment** on the master issue (not the body).
The body holds the overview and checklist.

Also read the current subtask's sub-issue body:

```bash
gh issue view ${CURRENT_SUB_ISSUE_NUMBER} --json body,title
```

### B2 — Judge: is there drift?

Consider two questions:

1. Can this subtask be implemented as written in its sub-issue body without
   violating the architecture in the first comment?
2. Does anything now understood about the codebase or this subtask invalidate
   an assumption that the architecture was based on?

If the answer to both is "no" → **no drift**. Emit `DRIFT: clean`.

If the answer to either is "yes" → **drift detected**. Proceed to B3.

Do not invoke drift for normal in-scope subtask work. Drift means the
architecture is wrong or the subtask cannot be implemented as specified. Minor
wording differences or implementation detail choices do not count.

### B3 — Update architecture on drift

1. Emit `DRIFT: changed:<one-line summary>`.

2. Edit the master issue's **first comment** to reflect the corrected
   architecture. Use `gh issue edit-comment` with the comment ID (retrieved
   from `gh issue view --json comments`):

   ```bash
   gh issue edit-comment ${COMMENT_ID} --body "${CORRECTED_ARCHITECTURE}"
   ```

3. Re-read every **open** sub-issue (all, including the current one):

   ```bash
   gh issue list --label "arch:${STORY_KEY}" --state open --json number,title,body
   ```

   For each, judge whether its technical approach is still valid against the
   corrected architecture. If invalid, edit its body to realign:

   ```bash
   gh issue edit ${SUB_ISSUE_NUMBER} --body "${UPDATED_BODY}"
   ```

4. Post a comment on the master issue summarising what changed and why:

   ```bash
   gh issue comment ${MASTER_ISSUE_NUMBER} \
     --body "## Architecture drift recorded

   **Summary:** ${DRIFT_SUMMARY}

   **What changed:** ${WHAT_CHANGED}

   **Why:** ${WHY_CHANGED}

   **Sub-issues updated:** ${UPDATED_SUB_ISSUE_NUMBERS}"
   ```

---

## Output

Emit on completion:

```
DRIFT: clean
FINAL_RUN: false
```

or

```
DRIFT: changed:<one-line summary>
FINAL_RUN: true|false
UPDATED_ISSUES: [<n1>, <n2>, ...]
RECONCILED_ISSUES: [<n1>, <n2>, ...]
```

The orchestrator passes `FINAL_RUN` forward; if `true`, it triggers
`discovery-audit` after Phase 8 rather than halting normally.

---

## Anti-patterns

- **Do not transition the in-progress subtask** in the reconcile sweep —
  only sweep sub-issues for subtasks other than the one now being picked up.
- **Treat JIRA status as truth**, not the GitHub checklist — the checklist
  is a display; JIRA is the authoritative completion signal.
- **Do not rewrite architecture for normal in-scope work** — only on genuine
  divergence (implementation is impossible as specified, or a core assumption
  is wrong).
- **Do not force JIRA transitions** that are not available — record and surface
  missing transitions instead.
- **Do not call gh on the skills repo.** The master issue lives in the project
  repo. Confirm the active repo context before writing.
