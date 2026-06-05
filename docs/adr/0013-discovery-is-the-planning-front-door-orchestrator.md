---
status: accepted
---

# /discovery is the planning front-door orchestrator; it absorbs the old tracking utility

`/discovery` is now a phase-gated **orchestrator** that takes a Jira ticket,
GitHub issue, prompt, or local file and runs shape → architect → discover: a
**Three-Amigos panel** (PM + Architect + QA, run as parallel Sonnet subagents)
synthesised by Opus into one plan, with a **devil's-advocate** subagent attacking
the merged plan for scope creep each round. It then **materialises** the plan as
tracked work items in the backend declared by the project's `discovery:` config
and hands off to `/workflow` or `/spec-pipeline`.

This replaces the former `commands/Mr Will/discovery.md`, a thin
architecture-tracking *setup utility* that the orchestrator contract explicitly
marked "not an orchestrator". The new command **absorbs** it: when work is
already tracked, it re-enters in track/reconcile mode (dispatching the unchanged
`discovery-init` / `discovery-check` / `discovery-audit` skills) instead of
re-planning. The name `/discovery` is reused for the larger command.

## Why these shapes

- **Three Amigos are complementary, not competing.** Unlike `/solve` — a
  *tournament* that fans out N rival fixes and converges on one winner — the
  amigos are distinct roles (scope / approach / test bar) whose outputs are
  **merged**, never eliminated. Convergence is role-synthesis. The
  devil's-advocate, by contrast, reuses `/solve`'s adversarial-verifier
  mechanism verbatim, retargeted from "is this fix correct?" to "is this scope
  justified?".
- **Backend declared in `CLAUDE.md`, not inferred.** A `discovery:` fenced YAML
  block (`backend: jira | github | local`, mirroring the `spec_pipeline` block)
  decides where Phase 4 creates real work items. It is a **hard precondition**:
  absent config → halt and guide, never guess a backend, because the backend
  determines where durable items are created.

## Considered options

- **A distinct name (`/intake`, `/shape`)** — rejected by the user; `/discovery`
  is the intended name and the old utility was a subset.
- **Rename the old `/discovery` → `/arch-track`, keep both** — rejected: the old
  utility's whole job (materialise + track) is Phase 4 of the new command, so
  two commands would duplicate it. Absorbing is cleaner.
- **Clone `/solve`'s convergence wholesale** — rejected: a refute-and-eliminate
  panel is wrong for complementary roles (you never pick Architect *over* QA).
  Only the *attack* mechanism is borrowed.
- **External config-reader script (like `spec-pipeline`'s
  `read-pipeline-config.sh`)** — not done. Commands in this repo (`solve`,
  `workflow`) read config inline; only the `spec-pipeline` *skill* uses a script
  because it runs unattended. The `discovery:` schema and parse-and-halt logic
  live inline in the command, consistent with the command convention.

## Consequences

- Registered in the `ORCHESTRATORS` list in
  `tests/python/test_orchestrator_conformance.py` and flipped to "yes" in the
  orchestrator-contract scope table (it was the table's lone "no"). It satisfies
  all five contract checks; `make test` is green (135 passing).
- The `github`-only and `local` materialisation paths are **net-new** — the
  existing `discovery-init` / `discovery-jira` skills are JIRA-coupled
  (`discovery-init` keys its GitHub master issue to a JIRA story). The `jira`
  backend reuses them; `github` creates issues + sub-issues directly via `gh`
  (mirroring `discovery-init`'s patterns, JIRA-free); `local` writes plan +
  story docs via the `pm` / `story-to-spec` shapes.
- The `discovery/` bucket skills keep their names — renaming them remains the
  deferred [[0012-reconcile-orphaned-doc-tooling-and-clarify-shape-stage]] item.
  The new command calls them as-is, so "discovery" now names both the command
  and the tracking-skill bucket; this is tolerated because the command *drives*
  those skills (one cohesive feature), not an unrelated collision.
- README "Choosing an orchestrator" now frames `/discovery` as the feature
  planning front door, paired against `/solve` (the bug front door).
