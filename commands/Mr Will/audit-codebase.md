# Mr Will: Audit Codebase
## Codebase → Findings → Prioritised Remediation

---

## Overview

This command audits the codebase against the target architecture and produces
a prioritised remediation plan. It is the companion to `ticket-to-pr` — audit
output feeds directly into `ticket-to-pr` input, one subtask at a time.

The orchestrator (Opus) owns all phases. There are no Sonnet subagents —
this workflow is entirely analysis and judgement, not execution.

---

## Flags

This command supports two modes. You must specify one:

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

---

## Mode: --scope=ticket

**Input required:** Jira ticket key (e.g. `NAT-1234`)

### Phase 1 — Orientation (ticket)
#### Opus, plan mode

Read the following before doing anything:
1. `[SKILL: ~/.claude/skills/user/swift-architect/SKILL.md]`
2. `CLAUDE.md` — follow every linked doc from it
3. The Jira ticket via Atlassian MCP
4. All acceptance criteria on the ticket
5. All files in `docs/` — these are the target architecture

Do not proceed until you have read all of the above.

Produce a one-paragraph audit baseline:
- What the target architecture expects
- What layers and patterns are authoritative
- Which files are in scope based on the ticket AC

Write baseline to: `docs/audit/[TICKET-KEY]/baseline.md`

### Phase 2 — Scoped Discovery (ticket)
#### Opus, plan mode

Map only the files relevant to the ticket scope:

1. Identify files touched by or related to the ticket AC
2. List them grouped by layer (Services, Views, Actors, Models, etc.)
3. Note any file that does not map to a known layer in the target arch
4. Do not flag findings yet — discovery only

Write the map to: `docs/audit/[TICKET-KEY]/codebase-map.md`

### Phase 3 — Audit Execution (ticket)
#### Opus, plan mode

Read:
1. `[SKILL: ~/.claude/skills/user/swift-code-review/SKILL.md]`
2. `docs/audit/[TICKET-KEY]/codebase-map.md`

Audit every file in scope against the target architecture. For each file check:

**Architecture conformance**
- No ViewModels present
- Views bind only to `@Observable` services via `@Environment` or init injection
- Domain logic not placed in views
- No god objects or coordinator types

**Swift 6 concurrency**
- No `DispatchQueue` where actor/async should be used
- `Mutex` used instead of `NSLock`
- No `@unchecked Sendable` without documented justification
- No retain cycles in `Task { }` closures
- `actor` used only where mutable shared state genuinely requires it
- `@MainActor @Observable final class` for services

**Swift quality**
- No force cast or force try without explanation
- No abbreviations in type or method names
- No inline comments
- No `class func` — use `static func`
- Named constants over magic literals

**Test coverage**
- Public methods have Swift Testing coverage
- No XCTest used for unit tests
- No XCUITest mixed into unit test targets

**Scope creep indicators**
- Files that touch more than one layer
- Types with more than one responsibility
- Services that own UI state or vice versa

For each finding record:
- File and line (where applicable)
- Finding category (Architecture / Concurrency / Quality / Tests / Scope)
- Severity: `blocking` | `major` | `minor`
- One-line description of the violation
- One-line description of what correct looks like

Write all findings to: `docs/audit/[TICKET-KEY]/findings.md`

### Phase 4 — Prioritisation (ticket)
#### Opus, plan mode

Read `docs/audit/[TICKET-KEY]/findings.md`.

Group findings into remediation batches. Each batch must:
- Be implementable as a single `ticket-to-pr` run
- Contain findings from the same file or closely related files
- Have a clear, testable definition of done
- Not depend on another batch that hasn't been completed first

Order batches by dependency and severity:
1. `blocking` findings that other work depends on — first
2. `blocking` findings that are independent — second
3. `major` findings — third
4. `minor` findings — last

Write the prioritised batch list to:
`docs/audit/[TICKET-KEY]/remediation-plan.md`

Format each batch as:

```
## Batch N — [Short title]
Severity: [blocking|major|minor]
Depends on: [Batch X, or none]
Files in scope: [list]
Findings addressed: [finding IDs or descriptions]
Definition of done: [one sentence]
```

### Phase 5 — Create Jira Subtasks (ticket)
#### Opus, plan mode

For each batch in `docs/audit/[TICKET-KEY]/remediation-plan.md`:

1. Create a Jira subtask as a child of the audit ticket via Atlassian MCP
2. Subtask title: `[Batch N] [Short title]`
3. Subtask description: paste the batch block from the remediation plan
4. Set priority in Jira:
   - `blocking` → Critical
   - `major` → High
   - `minor` → Medium
5. Record the subtask key returned by Jira

After all subtasks are created, add a comment to the parent ticket:

```
| Subtask | Severity | Files | Status |
|---|---|---|---|
| NAT-XXXX | blocking | FooService.swift | To Do |
| NAT-XXXX | major | BarView.swift | To Do |
```

### Phase 6 — Audit Report (ticket)
#### Opus, plan mode

Write final report to: `docs/audit/[TICKET-KEY]/report.md`

Report must contain:
1. **Audit baseline** — from Phase 1
2. **Findings summary** — total count by severity and category
3. **Remediation plan** — batch list with Jira subtask keys linked
4. **Risks** — findings that, if left unaddressed, will block future work
5. **Next step** — "Run `ticket-to-pr` for [NAT-XXXX] first"

Report to the user:
- Total findings (by severity)
- Number of Jira subtasks created
- The first subtask key to hand to `ticket-to-pr`

---

## Mode: --scope=all

**Input required:** none

### Phase 1 — Orientation (all)
#### Opus, plan mode

Read the following before doing anything:
1. `[SKILL: ~/.claude/skills/user/swift-architect/SKILL.md]`
2. `CLAUDE.md` — follow every linked doc from it
3. All files in `docs/` — these are the target architecture

Do not proceed until you have read all of the above.

Set the output folder to: `docs/audit/full-[YYYY-MM-DD]/`
where `[YYYY-MM-DD]` is today's date.

Produce a one-paragraph audit baseline:
- What the target architecture expects
- What layers and patterns are authoritative

Write baseline to: `docs/audit/full-[YYYY-MM-DD]/baseline.md`

### Phase 2 — Full Codebase Discovery (all)
#### Opus, plan mode

Map the entire codebase:

1. List every Swift file grouped by folder
2. Identify all layers present (Services, Views, Actors, Models, etc.)
3. Note any folder or file that does not map to a known layer in the target arch
4. Do not flag findings yet — discovery only

Write the map to: `docs/audit/full-[YYYY-MM-DD]/codebase-map.md`

### Phase 3 — Audit Execution (all)
#### Opus, plan mode

Read:
1. `[SKILL: ~/.claude/skills/user/swift-code-review/SKILL.md]`
2. `docs/audit/full-[YYYY-MM-DD]/codebase-map.md`

Audit every file in the codebase against the target architecture using the
same checklist as `--scope=ticket` Phase 3 above.

Work layer by layer — complete one layer before moving to the next:
1. Domain models and API types
2. Actors and services
3. Views and view composition
4. Tests

Write all findings to: `docs/audit/full-[YYYY-MM-DD]/findings.md`

### Phase 4 — Prioritisation (all)
#### Opus, plan mode

Read `docs/audit/full-[YYYY-MM-DD]/findings.md`.

Group findings into remediation batches using the same rules as
`--scope=ticket` Phase 4 above.

Write the prioritised batch list to:
`docs/audit/full-[YYYY-MM-DD]/remediation-plan.md`

### Phase 5 — Audit Report (all)
#### Opus, plan mode

**No Jira interaction in this phase.** Write local docs only.

Write final report to: `docs/audit/full-[YYYY-MM-DD]/report.md`

Report must contain:
1. **Audit baseline** — from Phase 1
2. **Findings summary** — total count by severity and category
3. **Remediation plan** — full batch list in priority order
4. **Risks** — findings that, if left unaddressed, will block future work
5. **Suggested next step** — which batch to tackle first and why

Report to the user:
- Total findings (by severity and category)
- Number of remediation batches
- Suggested first batch to hand to `ticket-to-pr`
- Path to the full report

---

## Halt Conditions (both modes)

The orchestrator must halt and report (never silently continue) if:
- No `docs/` folder or architecture docs are found in Phase 1
- The codebase map in Phase 2 is empty
- Any Jira MCP call fails (`--scope=ticket` only)

On halt: report the reason to the user and stop. Do not attempt to audit
without a readable target architecture.

---

## Output Summary

### --scope=ticket

| Artefact | Location |
|---|---|
| Baseline | `docs/audit/[TICKET-KEY]/baseline.md` |
| Codebase map | `docs/audit/[TICKET-KEY]/codebase-map.md` |
| Raw findings | `docs/audit/[TICKET-KEY]/findings.md` |
| Remediation plan | `docs/audit/[TICKET-KEY]/remediation-plan.md` |
| Final report | `docs/audit/[TICKET-KEY]/report.md` |
| Jira subtasks | Child tickets of `[TICKET-KEY]` |

### --scope=all

| Artefact | Location |
|---|---|
| Baseline | `docs/audit/full-[YYYY-MM-DD]/baseline.md` |
| Codebase map | `docs/audit/full-[YYYY-MM-DD]/codebase-map.md` |
| Raw findings | `docs/audit/full-[YYYY-MM-DD]/findings.md` |
| Remediation plan | `docs/audit/full-[YYYY-MM-DD]/remediation-plan.md` |
| Final report | `docs/audit/full-[YYYY-MM-DD]/report.md` |

---

## Handoff to ticket-to-pr

Once this command completes, run `ticket-to-pr` once per remediation batch,
in the order specified in the remediation plan. Each batch is already scoped
and sequenced — for `--scope=ticket`, pass the Jira subtask key directly.
For `--scope=all`, use the batch definition from the remediation plan as
the ticket input.

---

**Model & mode:** Opus, plan mode — pure analysis and judgement workflow.
No execution subagents. Opus runs all phases.
