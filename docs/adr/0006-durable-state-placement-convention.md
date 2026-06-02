---
status: accepted
---

# Cross-agent state has a designated store per state-kind

Orchestrators keep durable cross-agent state in several places (GitHub issues,
JIRA, Obsidian audit logs, `PLANS_DIR`, tmp files, attempt-logs), chosen
per-orchestrator with no shared rule — the last open item from
[[0001-canonical-agent-orchestration-architecture]]. We codify the existing,
mostly-coherent practice as a convention: each *kind* of state has a designated
store, recorded as a table in
[`docs/orchestrator-contract.md`](../orchestrator-contract.md) under "State
placement". We are ratifying what already works, not migrating any orchestrator
off its current store.

The mapping: branch-independent story/architecture state → GitHub issues; ticket
lifecycle → JIRA; durable run record → the Obsidian audit log; plans / discovery
notes / blocked reports → `PLANS_DIR`; cross-subagent state that must survive the
run → a durable shared file in `PLANS_DIR`; transient same-cycle handoff → a tmp
file passed by path.

## Considered options

- **Consolidate onto a single durable store** (e.g. everything cross-run in the
  Obsidian audit log). Rejected: it would undo the deliberate branch-independent
  GitHub-issue design that `discovery-init`/`-check`/`-audit` rely on (state that
  must outlive any one branch and be team-visible), and collapse stores that
  serve genuinely different lifetimes and audiences.
- **Leave it undocumented.** Rejected: the within-run cross-subagent case had
  already drifted (tmp-by-path in `spec-pipeline` vs a durable attempt-log in
  `uitest-pipeline`), and a new orchestrator had no rule to follow.

## Consequences

- The one genuine ambiguity — within-run cross-subagent state — now has an
  explicit rule: post-mortem / multi-phase state lives in `PLANS_DIR`; one-shot
  same-cycle handoffs use a tmp file by path. Both pass large state to subagents
  by path, never inlined.
- No code or orchestrator changes were needed — every current store placement
  already fits the table. The convention is documentation that new orchestrators
  (and the contract's skeleton) point to.
- This closes the last open follow-up from
  [[0001-canonical-agent-orchestration-architecture]]. A3 was settled separately
  in [[0005-keep-audit-codebase-prose-not-workflow]].
