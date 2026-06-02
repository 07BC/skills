---
name: pipeline-preflight
disable-model-invocation: true
description: >
  Pre-flight checks for spec-driven pipelines (`/workflow`, `/spec-pipeline`).
  Run before a discovery note is written or any subagent is spawned. Surfaces
  drift between the repo's actual state and the docs the pipeline trusts —
  e.g. merged PRs not marked Done in the progress doc, picked stories flagged
  out-of-scope, dirty working trees. Always cite this skill from pipeline
  orchestrators; never inline its rules. Triggers: any pipeline orchestrator
  starting up. Do not auto-fire on user messages.
---

# Pipeline preflight

Spec-driven pipelines (`/workflow`, `/spec-pipeline`, anything that turns a
story into a PR) trust three pieces of state when they begin:

1. The picked spec file is in scope and worth implementing now.
2. The project's progress doc reflects what is actually merged on `main`.
3. The working tree is clean enough that the pipeline's commits will be its
   own and nothing else.

When any of those is wrong, the pipeline either does avoidable work or makes
decisions on stale assumptions. Run these checks before any other phase.

This skill is read by orchestrators. It does not auto-fire on human messages.

---

## When to run

Pipeline orchestrators call this skill **before** their architect / discovery
phase, immediately after input detection but before any read of architecture
docs.

The orchestrator owns user-facing decisions — this skill produces signals; it
does not branch the pipeline.

---

## CLAUDE.md config schema

Pipelines look for a fenced YAML block in `CLAUDE.md`:

```yaml pipeline
progress_doc: docs/specs/progress.md
base_branch: main
branch_prefix: nat-
stop_list:
  - V1.1
  - V1.2
  - V2
  - "out of scope"
  - "do not start"
stop_legends:
  - "🔵"
  - "⚪"
```

Every key is optional — defaults are listed alongside each check below.
If the block is absent entirely, all checks fall back to defaults.

---

## Checks

### 1. Merged-PR vs progress-doc drift

Read the project's progress doc:

- Path from `progress_doc` in the config block.
- Default fall-back: `docs/specs/progress.md`.
- If neither exists, skip this check and continue — no drift to detect.

Then list the last 5 merged PRs on `origin/main`:

```bash
gh pr list --state merged --limit 5 --json number,title,mergedAt,mergeCommit,headRefName
```

For each merged PR, mark it as "found in progress doc" if any of these
match anywhere in the doc:

- PR number with leading `#` (e.g. `#10`)
- Merge-commit short SHA (first 7 chars)
- PR title (substring match, case-insensitive)
- Branch name (`headRefName`, substring match)

The four-way match handles squash-merged PRs that lose their original SHA
and progress docs that record decisions by story title rather than PR
number.

**Drift** = any of the last 5 merged PRs that matches none of the four.

### 2. Picked-story scope check

Read the first 30 lines of the picked spec file. If any of these markers
appear, surface them to the user:

- Any value in `stop_list` from the config block (substring match,
  case-insensitive). Defaults: `V1.1`, `V1.2`, `V2`, `out of scope`,
  `do not start`.
- Any character in `stop_legends` from the config block adjacent to the
  story title. Defaults: `🔵`, `⚪`.

This catches the case where a user picks a story by number but the project
build order has it queued behind unfinished work.

### 3. Working-tree cleanliness

```bash
git status --porcelain
```

If non-empty, list the dirty files. Includes both staged and unstaged
changes plus untracked files.

### 4. Branch position

Confirm `HEAD` is on `main` (or the project's declared base branch). If on a
feature branch already, list it and ask before continuing — the pipeline may
have been started mid-flow.

---

## Output

When any check returns a signal, emit a single one-block summary and ask the
user how to proceed via `AskUserQuestion`. Do not auto-resolve.

Suggested question structure:

> **Pre-flight detected:**
> - {drift summary}
> - {out-of-scope summary}
> - {dirty tree summary}
>
> How would you like to proceed?
> - Reconcile first (recommended) — update the progress doc / pick a different story / clean the tree
> - Proceed anyway — record the drift in the discovery note's "open issues"
> - Abort and let me reconcile manually

The orchestrator owns what each option does. Recommended semantics:

| Option | Orchestrator action |
| --- | --- |
| **Reconcile first** | Make the reconciliation edit (update progress doc, pick a different story, clean the tree), then re-run this skill until it emits `Pre-flight clean.` |
| **Proceed anyway** | Record the override under "Open issues" in the discovery note (Phase 3). Continue. |
| **Abort** | Halt with no blocked report — this is a user choice, not a failure. |

When all checks pass, emit one line: `Pre-flight clean.` and continue.

---

## Anti-patterns

- **Inlining these checks in each pipeline.** If the rule lives in
  `workflow.md` and not also in `spec-pipeline/SKILL.md`, the next time the
  user upgrades one they'll forget the other. Cite this skill from both.
- **Auto-resolving drift.** Do not write to the progress doc, switch stories,
  or stash dirty changes without the user's explicit "yes". The pipeline's
  job is to surface, not to fix.
- **Skipping the check on "small" stories.** The drift hides equally well in
  small stories; the cost of the check is sub-second; running it always is
  the cheapest path.

---

## Verification

After this skill runs successfully on a real pipeline invocation:

- Total preflight wall-clock < 5 seconds (no LLM calls, only `gh` and `git`).
- A deliberately-stale progress doc entry is detected on the next run.
- A picked V1.1 story is flagged before discovery is written.
- A pre-existing modification on `main` blocks the pipeline until cleared.
