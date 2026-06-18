# Orchestrator contract

The canonical structure every spec-driven **orchestrator** in this repo follows.
An orchestrator is a command or skill that drives multi-step work by spawning
subagents and gating phases — currently `workflow`, `uitest`,
`audit`, `solve`, and `spec-pipeline`.

This contract exists because the orchestrators independently converged on one
shape and the copies were drifting (see
[ADR 0001](./adr/0001-canonical-agent-orchestration-architecture.md)). Rather
than a runtime-cited skill, the shared structure lives here as a template plus a
conformance check (see [ADR 0002](./adr/0002-orchestrator-scaffold-as-template-plus-conformance-check.md)).
The *behavioural* policy that belongs at runtime is already factored into cited
skills (`pipeline-preflight`, `subagent-reliability`) — this contract is about
structure, not behaviour.

The conformance check lives at `tests/python/test_orchestrator_conformance.py`
and runs under `make test`.

---

## Scope

| File | In scope? | Why |
|---|---|---|
| `commands/Mr Will/workflow.md` | yes | phase-gated, spawns subagents |
| `commands/Mr Will/uitest.md` | yes | phase-gated, spawns subagents |
| `commands/Mr Will/audit.md` | yes | phase-gated, spawns subagents |
| `commands/Mr Will/solve.md` | yes | phase-gated, fans out solver + verifier subagents |
| `skills/engineering/spec-pipeline/SKILL.md` | yes | phase-gated, dispatches leaf agents |
| `skills/engineering/spec-master/SKILL.md` | yes | phase-gated; decomposes a story and dispatches spec-scope-guardian |
| `commands/Mr Will/discovery.md` | yes | phase-gated three-amigos panel; fans out amigo + devil's-advocate subagents |

When adding a new orchestrator, add its path to the `ORCHESTRATORS` list in the
conformance test.

---

## Required (enforced by the conformance check)

Each is matched by concept, not by a literal heading — accepted synonyms are
listed so legitimately-different orchestrators (e.g. `spec-pipeline`) still pass.

1. **Model & mode declared.** State which model orchestrates and in what mode.
   Accepted: a `Running as: …` line, a `## Model & mode` (or `Model intent`)
   note.
2. **Preflight cited.** The orchestrator runs `pipeline-preflight` before its
   first phase. Accepted: the literal string `pipeline-preflight`.
3. **A failure section.** A dedicated section describing how the run halts and
   reports. Accepted: `Halt Conditions`, `Escalation`, or `Failure modes`.
4. **Subagent-crash recovery cited.** The orchestrator cites
   `subagent-reliability` for subagents that return no usable result. Accepted:
   the literal string `subagent-reliability`.
5. **Phase structure.** At least three phase/step headings. Accepted: `##`-level
   headings beginning with `Phase`, `Stage`, or `Step`.

## Recommended (not enforced — legitimately variable)

- **Variables / config block.** A one-time definitions block (`## Variables`),
  or a fenced config block read from `CLAUDE.md` (`spec-pipeline`'s approach).
- **Context bundle or by-path state.** Either a context bundle built once and
  passed inline so subagents never re-read from disk (`workflow`), or large
  state written to a file and passed by path (`spec-pipeline`). Pick one;
  don't inline large state in every prompt.
- **Explicit retry / cycle budget.** A per-phase retry budget (`workflow`) or a
  whole-run cycle budget (`spec-pipeline`).

## Argument-style convention

Settled in [ADR 0003](./adr/0003-workflow-and-spec-pipeline-are-distinct-aligned-tools.md):

- Take a **positional, auto-detected primary input** (Jira key / spec path /
  prompt) where one obvious input exists — `workflow`, `uitest`, and
  `spec-pipeline`'s positional Jira shorthand all do this.
- Use `--flags` **only for a genuine mode** that cannot be inferred from the
  argument. `audit --scope=ticket|all` is the sanctioned exception:
  ticket-vs-all is a real mode, not inferable from an input.

---

## State placement

Where an orchestrator keeps cross-agent state depends on how long it must live
and who must see it. Settled in
[ADR 0006](./adr/0006-durable-state-placement-convention.md).

| State kind | Store | Why |
|---|---|---|
| Story / architecture state that must survive across branches and sessions | GitHub issue (master + per-subtask sub-issues) | branch-independent, team-visible, queryable via `gh` |
| Ticket lifecycle — status, links, comments | JIRA | external system of record |
| Durable run record / audit trail | Obsidian audit log (vault, append-only) | survives the worktree; human-readable post-mortem |
| Plans, discovery notes, blocked reports | `PLANS_DIR` in the Obsidian vault | the global plan-storage rule already mandates this |
| Cross-subagent state that must survive the whole run | a durable shared file in `PLANS_DIR` (e.g. an attempt-log) | the only state that crosses subagent boundaries; must be durable and inspectable |
| Transient same-cycle handoff between two subagents | a tmp file passed by path (`$TMPDIR/…`) | consumed within the cycle; no need to persist — the OS reaps it |

**The rule for the last two** (the one place orchestrators drifted): if the
state is a post-mortem record or is read across more than one phase, put it in
`PLANS_DIR`; if it is a one-shot handoff consumed in the same cycle, use a tmp
file by path. Either way, pass large state to subagents **by path** — never
inline it in every prompt.

---

## Skeleton

Copy this when authoring a new orchestrator, then delete the guidance comments.

```markdown
# <Orchestrator name>

## <one-line purpose>

<Overview: what it drives, single-subtask vs whole-spec, who decides.>

## Variables
<!-- one-time definitions: SUBAGENT_MODEL, PROJECT_NAME, PLANS_DIR, … -->

## Model confirmation
> Running as: [model name and version] — [plan mode / normal mode]

## Phase 0 — Preflight
Apply skill `pipeline-preflight`. Surface signals via `AskUserQuestion`
(Reconcile / Proceed / Abort). Continue only on `Pre-flight clean.` or Proceed.

## Phase 1..N — <work>
<!-- Each phase: who runs it (Opus decides / Sonnet executes), its retry budget
     inline, and what it hands to the next phase. Cite `subagent-reliability`
     wherever a subagent is spawned. Pass state via a context bundle or by path. -->

## Halt Conditions
<!-- Every condition under which the orchestrator halts and writes a blocked
     report instead of continuing. -->

## Model & mode
<!-- Opus orchestrates (owns all branching); Sonnet leaf agents execute. -->
```
