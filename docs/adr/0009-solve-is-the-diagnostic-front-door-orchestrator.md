---
status: accepted
---

# solve is a diagnostic + solution-design orchestrator, one stage before workflow

`solve` (a command under `Mr Will/`) is a new orchestrator that takes a single
bug or architecture problem, *understands* it, fans out competing fixes across
parallel solver subagents, attacks each with adversarial verifiers, and converges
on one **approved fix-approach** written to `PLANS_DIR`. It deliberately stops at
the plan — it never writes implementation code or opens a PR. It exists because
the existing chain assumed the fix was already known: `audit-codebase` *finds*
work and `workflow` *implements* a known unit, but nothing covered the
diagnose-and-design stage that happens when you have a problem but not yet a
solution. `solve` fills that gap and hands its approved approach to `workflow`:

```
solve  →  approved fix-approach (PLANS_DIR)  →  workflow  →  PR
```

It follows the orchestrator contract (Opus decides, Sonnet executes; preflight,
phase gates, halt conditions, by-path state) and is registered in the conformance
check. Its one structural novelty is an adaptive Phase 1: the orchestrator
derives the fan-out shape — how many solvers and what angles — from the problem
itself rather than hardcoding a fixed panel, which is what "as agentic as
possible" demanded.

## Considered options

- **Fold the capability into `workflow`** (a "diagnose" mode flag). Rejected:
  `workflow` is an implementation pipeline driven by a *known* spec; diagnosis is
  a different job with a different output (a plan, not a PR) and would couple two
  concerns. Same reasoning as [[0003-workflow-and-spec-pipeline-are-distinct-aligned-tools]].
- **Carry `solve` through to implementing the fix itself.** Rejected: it would
  duplicate everything `workflow` already does and re-couple diagnosis to
  implementation. Stopping at the approved plan keeps each tool single-purpose
  and lets `solve` also serve pure architecture decisions that never become a PR.
- **Build it on the `Workflow` primitive** for the parallel fan-out. Rejected for
  the same reason as [[0005-keep-audit-codebase-prose-not-workflow]]: this repo's
  orchestrators are prose, Opus-driven, and phase-gated; a deterministic
  `Workflow` script contradicts the adaptive Phase 1 that is the whole point.
- **Author it as a skill in `engineering/`.** Rejected: it needs explicit
  invocation and a user dialogue before fanning out, so auto-fire is a liability;
  a command beside `workflow` / `audit-codebase` is the right species and home.

## Consequences

- Registered in the `ORCHESTRATORS` list in
  `tests/python/test_orchestrator_conformance.py`; the contract intro and scope
  table in `docs/orchestrator-contract.md`, the repo `CLAUDE.md` orchestrator
  list, and the README (commands table, chain narrative, contract list) all now
  name `solve` for parity with the other four orchestrators.
- `solve` reuses the existing `feature-dev:code-explorer` and
  `feature-dev:code-architect` agent types rather than introducing new agent
  files — a role is promoted to `agents/` only once a second orchestrator reuses
  it.
- The chain now has three distinct entry points by intent: `audit-codebase`
  (find work across the whole codebase), `solve` (design a fix for one known
  problem), and `workflow` / `spec-pipeline` (implement known work to a PR).
