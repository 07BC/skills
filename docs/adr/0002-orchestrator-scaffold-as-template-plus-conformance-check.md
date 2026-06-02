---
status: accepted
---

# Shared orchestrator scaffold lives in a template plus a conformance check, not a runtime skill

The five orchestrators (`workflow`, `uitest-pipeline`, `audit-codebase`,
`discovery`, `spec-pipeline`) each re-implement the same *structural* scaffold:
a variables block, the `Running as: [model]` confirmation line, the phase-gate
format, a retry-budget table, halt conditions, the context bundle, and an output
summary. We will capture this scaffold once as a `docs/` orchestrator template
that authors copy when writing a new orchestrator, backed by a conformance check
(a test) that asserts every orchestrator contains the required sections. We will
**not** make it a runtime-cited skill, because the scaffold is structure, not
behaviour — and the *behavioural* policy that genuinely belongs at runtime is
already factored into cited skills (`pipeline-preflight`, `subagent-reliability`,
per [[0001-canonical-agent-orchestration-architecture]]).

## Considered options

- **Cited runtime skill** — an `orchestrator-contract` skill each orchestrator
  applies, like `pipeline-preflight`. Rejected: it adds a read to every run for
  content that is structural boilerplate rather than a procedure, and a skill
  body cannot enforce that an orchestrator actually *has* the sections — only a
  check can.
- **Leave as-is** — accept the duplication and rely on discipline. Rejected: the
  triage that preceded this decision already found the copies drifting
  (`audit-codebase` had skipped a preflight step; severity vocabularies differed
  before they were aligned).

## Consequences

- Author the template under `docs/` enumerating the required orchestrator
  sections, with the canonical format for each.
- Write a conformance check that fails when an orchestrator (command or skill)
  is missing a required section. It guards structure; it does not dedupe content.
- Bring the five existing orchestrators into conformance — the cheapest place to
  surface the residual drift the triage flagged.
- The behavioural-policy skills (`pipeline-preflight`, `subagent-reliability`)
  stay cited and are out of scope here — this decision is only about the
  structural scaffold.
