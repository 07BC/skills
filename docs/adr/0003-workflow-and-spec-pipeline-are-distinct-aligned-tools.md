---
status: accepted
---

> **Partially superseded by [[0014-master-spec-layer-and-in-place-spec-pipeline]].**
> `spec-pipeline` is now in-place (no worktree), so the worktree-vs-in-place
> distinction below no longer holds. The scope distinction (whole child spec vs
> single subtask) and the argument-style / alignment guidance still stand.

# workflow and spec-pipeline are two distinct orchestrators, kept aligned rather than merged

`workflow` (a command) and `spec-pipeline` (a skill) both take an input to a PR,
but they do genuinely different jobs: `workflow` drives a *single subtask*
in-place on a branch, tied into the GitHub architecture-drift tracking
(`discovery-init` / `discovery-check` / `discovery-audit`) and the JIRA subtask
lifecycle; `spec-pipeline` ships a *whole spec* of many tasks autonomously inside
a disposable git worktree, with JIRA scope-splitting and named leaf-agent
definitions. We keep both as separate tools, document when to reach for which,
and align their surface conventions (the Phase/Stage wording, the argument style,
and the `SUBAGENT_MODEL` variable) so they read as siblings rather than strangers.

## Considered options

- **Merge into one mode-flagged orchestrator** (subtask vs whole-spec, in-place
  vs worktree). Rejected: highest effort and risk, and it would force one state
  model and one isolation model onto two jobs whose differences (granularity,
  isolation, state store, JIRA semantics) are the whole point.
- **Deprecate one.** Rejected: both are in active use for their respective jobs.

## Consequences

- Write a short "when to use which" note (in the README orchestrator/pipeline
  section, and cross-linked from both tools) so the choice is explicit.
- Align surface conventions across the two: settle on one of Phase/Stage, one
  argument style (positional vs `--flag`), and the shared `SUBAGENT_MODEL`
  variable name. This directly resolves the two PARTIAL drift items the triage
  surfaced (`spec-pipeline` "Stage" vs `workflow` "Phase"; `audit-codebase`
  `--scope=` flags vs positional args elsewhere).
- This is the concrete, scoped half of the broader consolidation flagged in
  [[0001-canonical-agent-orchestration-architecture]]; the remaining open items
  there (audit-codebase Phase 3 as a `Workflow` script; executor-vs-policy skill
  labelling; a single durable-state convention) are untouched by this decision.
