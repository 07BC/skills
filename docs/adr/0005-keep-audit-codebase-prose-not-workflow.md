---
status: accepted
---

# audit-codebase stays a prose orchestrator; its Phase 3 is not a Workflow script

ADR [[0001-canonical-agent-orchestration-architecture]] flagged `audit-codebase`
Phase 3 — a per-layer parallel fan-out with consolidated findings — as the
clearest candidate to run as a real `Workflow` script (the harness primitive that
provides `parallel()` fan-out, schema-validated subagent returns, and JS
consolidation). We have decided **not** to convert it. `audit-codebase` stays a
markdown prose orchestrator like its three siblings; Phase 3 instead gains an
explicit JSON findings schema so the parallel layers still consolidate
deterministically, without adopting the primitive.

## Considered options

- **Convert Phase 3 to a `Workflow` script.** Rejected for three reasons: (1)
  `Workflow` is a session tool the model calls and requires explicit user
  opt-in — baking it into a slash-command that runs in a normal session is
  awkward and borderline on that rule; (2) [[0002-orchestrator-scaffold-as-template-plus-conformance-check]]
  just unified all four orchestrators under one prose contract, and converting
  one would make it the odd one out, undercutting that uniformity; (3) the
  marginal benefit is small — Phase 3 already dispatches layers in parallel via
  the Agent tool and already specifies the finding fields.
- **A standalone saved `Workflow` script alongside the command.** Rejected: two
  tools for one job — the exact overlap [[0003-workflow-and-spec-pipeline-are-distinct-aligned-tools]]
  warned against.

## Consequences

- Phase 3 now specifies an explicit JSON array schema (file, line, severity,
  category, violation, correct) with enumerated severity/category values, so
  consolidation into `findings.md` is deterministic. Invalid JSON from a layer
  re-spawns that one layer rather than being hand-repaired.
- The `Workflow` primitive remains available for genuinely new, session-scoped
  fan-out work where deterministic parallelism or schema validation is worth the
  cost — this decision is specifically about not retrofitting it onto an existing
  prose orchestrator, not a blanket rejection of `Workflow`.
- Revisit if the prose fan-out proves unreliable at scale (e.g. many layers,
  frequent JSON drift) — that empirical pain would reopen the conversion.
