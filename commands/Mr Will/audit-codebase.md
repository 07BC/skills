# Mr Will: Audit Codebase

## Codebase → Findings → Prioritised Remediation → Workflow Handoff

---

## Overview

This command audits the codebase against the target architecture and produces
a prioritised remediation plan. It is the companion to `workflow` — audit
output feeds directly into `workflow` input, one batch at a time.

The orchestrator (Opus) owns all branching. Sonnet subagents handle the
per-layer audit execution so the orchestrator's context isn't burned reading
every file in the codebase.

---

## Variables

Define these once. Every later phase references them.

| Variable | Source | Example |
| --- | --- | --- |
| `SUBAGENT_MODEL` | constant | `claude-sonnet-4-6` |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` | `kick-tvos` |
| `PLANS_DIR` | `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans` | per global plan-storage rule |
| `AUDIT_DIR` | scope-dependent (see below) | — |
| `SCOPE` | flag — `ticket` or `all` | — |
| `SCOPE_KEY` | ticket key (`NAT-1234`) or `full-YYYY-MM-DD` | — |

`AUDIT_DIR = ${PLANS_DIR}/audit/${SCOPE_KEY}` — every artefact this command
produces lives under that directory in the obsidian vault.

---

## Flags

This command supports two scope modes. You must specify one:

```
/audit-codebase --scope=ticket NAT-1234
```

Audits files relevant to the ticket's acceptance criteria. Findings are
created as Jira subtasks on the ticket. Use when remediating a known problem.

```
/audit-codebase --scope=all
```

Audits the entire codebase. Findings are written to local docs only — no
Jira interaction. Use for health checks, onboarding, or pre-milestone sweeps.

The phases below run the same way in both modes, differing only where the
phase body checks `SCOPE`.

---

## Phase 0 — Preflight — Opus, plan mode

Apply skill `pipeline-preflight`. The skill produces signals (working tree
state, base branch position, progress-doc drift). When any signal fires,
the orchestrator asks via `AskUserQuestion` and follows the same
Reconcile / Proceed / Abort semantics that `workflow.md` Phase 0 documents.

Do not proceed to Phase 1 until preflight emits `Pre-flight clean.` or the
user chooses Proceed anyway.

---

## Phase 1 — Orientation — Opus, plan mode

Read the following before doing anything:

1. Apply skill `swift-architect` (read-only; for the target-architecture
   summary).
2. `CLAUDE.md` — follow every linked doc from it.
3. If `SCOPE=ticket`: the Jira ticket via Atlassian MCP, plus every
   acceptance criterion on the ticket.
4. All files in `docs/` — these are the target architecture.

Resolve the scope key:

- `SCOPE=ticket`: `SCOPE_KEY = ${TICKET-KEY}` (e.g. `NAT-1234`).
- `SCOPE=all`: `SCOPE_KEY = full-$(date +%Y-%m-%d)`.

Produce a one-paragraph audit baseline:

- What the target architecture expects.
- What layers and patterns are authoritative.
- For `SCOPE=ticket`: which files are in scope based on the ticket AC.

Write the baseline to `${AUDIT_DIR}/baseline.md`.

---

## Phase 2 — Codebase Discovery — Opus, plan mode

Map the in-scope files:

- `SCOPE=ticket`: identify files touched by or related to the ticket AC.
  Group by layer (Services, Views, Actors, Models, Tests).
- `SCOPE=all`: list every Swift file grouped by folder. Identify all
  layers present. Note any folder or file that does not map to a known
  layer in the target architecture.

Do not flag findings yet — discovery only.

Write the map to `${AUDIT_DIR}/codebase-map.md` with files grouped under
these layer headings:

```
## Domain models and API types
## Actors and services
## Views and view composition
## Tests
## Unmapped
```

The four named layers are the per-subagent audit boundaries used in
Phase 3.

---

## Phase 3 — Audit Execution — Spawn Sonnet subagents per layer

Spawn one `model: SUBAGENT_MODEL, mode: normal` subagent per non-empty
layer from Phase 2. Each subagent receives the prompt below with its
layer-specific file list inlined.

> Apply skill `swift-code-review`. The bundle below contains the layer
> file list and the target-architecture summary — do not re-read those
> from disk.
>
> [layer files inline]
> BASELINE: <full contents of ${AUDIT_DIR}/baseline.md>
>
> Review every file in the layer. Apply the full BLOCKER / WARNING /
> SUGGESTION checklist per the severity mapping in `swift-code-review`.
>
> Report findings as a structured list. Each finding must include:
>
> - file path and line (where applicable)
> - severity: `BLOCKER` / `WARNING` / `SUGGESTION`
> - category: Correctness / Concurrency / Code Quality / Naming /
>   Structure / SwiftUI / Comments / Testing / Platform / Scope
> - one-line description of the violation
> - one-line description of what correct looks like

Run the four layer subagents in parallel where possible. The orchestrator
consolidates the four structured reports into a single findings file at
`${AUDIT_DIR}/findings.md`, grouped first by severity then by file.

**Crash recovery.** If any subagent returns no usable result, apply skill
`subagent-reliability` before consuming a retry slot.

---

## Phase 4 — Prioritisation — Opus, plan mode

Read `${AUDIT_DIR}/findings.md`.

Group findings into remediation batches. Each batch must:

- Be implementable as a single `workflow` run.
- Contain findings from the same file or closely related files.
- Have a clear, testable definition of done.
- Not depend on another batch that hasn't been completed first.

Order batches by dependency and severity:

1. `BLOCKER` findings that other work depends on — first.
2. `BLOCKER` findings that are independent — second.
3. `WARNING` findings — third.
4. `SUGGESTION` findings — last.

For each batch, apply skill `swift-discovery` to produce a discovery note
in the canonical format. This means each batch is ready to be picked up by
`workflow` as a subtask with zero translation. Write each note to
`${PLANS_DIR}/[BATCH-KEY]-discovery.md` where `BATCH-KEY` is either the
Jira subtask key (Phase 5, `SCOPE=ticket`) or a synthetic
`${SCOPE_KEY}-batch-N` identifier (`SCOPE=all`).

Write the prioritised batch list itself (index of batch keys, severities,
and one-line titles) to `${AUDIT_DIR}/remediation-plan.md`:

```markdown
## Batch N — [Short title]
Severity: [BLOCKER|WARNING|SUGGESTION]
Depends on: [Batch X, or none]
Discovery note: ${PLANS_DIR}/[BATCH-KEY]-discovery.md
```

---

## Phase 5 — Jira Sync — Opus, plan mode — `SCOPE=ticket` only

> Skip this phase when `SCOPE=all`. Proceed directly to Phase 6.

For each batch in `${AUDIT_DIR}/remediation-plan.md`:

1. Create a Jira subtask as a child of the audit ticket via Atlassian MCP.
2. Subtask title: `[Batch N] [Short title]`.
3. Subtask description: paste the batch block from the remediation plan
   plus a link to the discovery note path.
4. Set Jira priority by severity:
   - `BLOCKER` → Critical
   - `WARNING` → High
   - `SUGGESTION` → Medium (or `Low` if the project uses a five-tier scale)
5. Record the subtask key returned by Jira and rename the discovery note
   file to use the Jira key (so `workflow` can pick it up by ticket).

After all subtasks are created, add a comment to the parent ticket:

```
| Subtask | Severity | Files | Status |
|---|---|---|---|
| NAT-XXXX | BLOCKER | FooService.swift | To Do |
| NAT-XXXX | WARNING | BarView.swift | To Do |
```

---

## Phase 6 — Audit Report — Opus, plan mode

Write the final report to `${AUDIT_DIR}/report.md`.

Report must contain:

1. **Audit baseline** — from Phase 1.
2. **Findings summary** — total count by severity and category.
3. **Remediation plan** — batch list with discovery note paths (and Jira
   subtask keys linked when `SCOPE=ticket`).
4. **Risks** — findings that, if left unaddressed, will block future work.
5. **Next step** — `Run /workflow <BATCH-KEY>` for the first batch.

Report to the user:

- Total findings (by severity and category).
- For `SCOPE=ticket`: number of Jira subtasks created.
- For `SCOPE=all`: total number of remediation batches.
- The first batch key to hand to `workflow`.

---

## Halt Conditions

The orchestrator must halt and report (never silently continue) if:

- No `docs/` folder or architecture docs are found in Phase 1.
- The codebase map in Phase 2 is empty.
- Any Phase 3 subagent returns no usable result after applying skill
  `subagent-reliability` (recover-in-place / resume / re-spawn).
- Any required Jira MCP call fails (`SCOPE=ticket` only).

On halt: report the reason to the user and write a halt summary to
`${AUDIT_DIR}/blocked.md`. Do not attempt to audit without a readable
target architecture.

---

## Output Summary

Every artefact lives under `${AUDIT_DIR} = ${PLANS_DIR}/audit/${SCOPE_KEY}`.

| Artefact | Location |
|---|---|
| Baseline | `${AUDIT_DIR}/baseline.md` |
| Codebase map | `${AUDIT_DIR}/codebase-map.md` |
| Raw findings | `${AUDIT_DIR}/findings.md` |
| Remediation plan (index) | `${AUDIT_DIR}/remediation-plan.md` |
| Per-batch discovery notes | `${PLANS_DIR}/[BATCH-KEY]-discovery.md` |
| Final report | `${AUDIT_DIR}/report.md` |
| Jira subtasks (`SCOPE=ticket` only) | Child tickets of `[TICKET-KEY]` |

---

## Handoff to `workflow`

Once this command completes, run `/workflow <BATCH-KEY>` once per
remediation batch, in the order specified in the remediation plan. Each
batch already has a `swift-discovery`-shaped note ready in `${PLANS_DIR}`
— `workflow` Phase 3 picks it up without re-running discovery.

- `SCOPE=ticket`: pass the Jira subtask key directly. `workflow` derives
  the discovery-note path from the key.
- `SCOPE=all`: pass the synthetic batch key (e.g.
  `full-2026-05-27-batch-1`).

---

**Model & mode:** Opus, plan mode for orchestration. Sonnet subagents
handle Phase 3 (per-layer audit) only. Opus runs every branching
decision and every Jira call.
