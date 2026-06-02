---
status: accepted
---

# Canonical agent-orchestration architecture for spec-to-PR pipelines

The skill library has independently converged on one agent architecture across
five orchestrators (`workflow`, `uitest-pipeline`, `audit-codebase`,
`discovery`, `spec-pipeline`): **Opus orchestrates and owns every branching
decision; Sonnet leaf agents execute and never branch.** We are adopting this
shape as the house standard for any spec-driven pipeline, and treating the
*divergence between the existing copies* as debt to pay down rather than as
independent designs to maintain. The recurring elements that define the pattern:

- **Two-tier model split** — orchestrator (Opus, plan mode) decides; leaf agents
  (Sonnet, normal mode) do the work. Verbatim across orchestrators: *"No
  subagent makes a branching decision."*
- **Phase/stage gates** with a printed checklist, a per-phase **retry budget**,
  explicit **halt conditions**, and a **blocked report** written to a known path.
- **Context bundle** built once and passed inline so leaf agents never re-read
  `CLAUDE.md` or the discovery note from disk. Large state is passed **by path**
  (tmp file / discovery note), not inlined in prompts.
- **Phases communicate through validated structured artefacts**, not prose — e.g.
  `## Unknowns to probe` is a contract grep-validated before handoff.
- **Escalation ladders** — cheap attempts first, escalate to Opus diagnosis on a
  defined trigger (same-line failure cluster, plan-predicted failure).
- **Crash ≠ failure** — `subagent-reliability` recovers a subagent that returned
  no usable result without consuming retry budget.
- **State externalised** because subagent memory is ephemeral — GitHub issues as
  a branch-independent store, append-only audit logs, shared attempt-logs.
- **Flat, not nested** — the Agent tool is gated to top-level sessions in this
  Claude Code build (subagents cannot dispatch subagents), so orchestrators
  drive leaf agents inline rather than nesting.

## Considered options

- **Let each orchestrator keep its own mechanics** (status quo). Rejected: the
  copies have already drifted — `audit-codebase` skips `pipeline-preflight`,
  severity vocabularies differ, and `workflow` (command) and `spec-pipeline`
  (skill) are two divergent answers to the same spec→PR job (in-place branch vs
  disposable worktree; "Sonnet + apply skill" vs named leaf-agent definitions;
  discovery-note state vs append-only audit log). Drift is now the dominant cost.
- **Migrate orchestrators to the `Workflow` harness primitive**, which natively
  provides `pipeline()`/`parallel()` fan-out, retry, schema-validated returns,
  token budgets, and worktree isolation. Rejected as a blanket move: the markdown
  orchestrators are portable, version-controlled, human-readable, slash-command
  invokable, and persist across sessions; Workflow scripts are ephemeral and
  session-bound. Adopted narrowly instead — see consequences.

## Consequences

- The shared orchestrator scaffold (variables → model confirmation → preflight →
  phase gates → retry table → halt conditions → context bundle → output summary)
  should be extracted so the copies stop drifting. **Decided in
  [[0002-orchestrator-scaffold-as-template-plus-conformance-check]]**: a `docs/`
  template plus a conformance check, not a runtime-cited skill.
- **`workflow` and `spec-pipeline` need reconciling. Decided in
  [[0003-workflow-and-spec-pipeline-are-distinct-aligned-tools]]**: keep both as
  distinct tools (single-subtask in-place vs whole-spec worktree), document when
  to use which, and align their surface conventions so they read as siblings.
- **`audit-codebase` Phase 3** (per-layer parallel fan-out with consolidated,
  schema-shaped findings) is the clearest candidate to run as an actual
  `Workflow` script; the phase-gated prose pipelines with human confirmation
  points stay as markdown.
- Skills should distinguish two species — **executor** (does work) vs
  **orchestrator-policy** (read by orchestrators, never auto-fires, never
  inlined) — via a convention (bucket or `audience: orchestrator` frontmatter).
- A single convention for **where durable cross-agent state lives** should be
  written down; today it is chosen per-orchestrator (GitHub issues, JIRA, tmp
  files, attempt-logs, Obsidian audit logs).

> Note: this file follows the `ADR-FORMAT.md` convention embedded in the
> `grill-with-docs` skill. The `skills-adr` skill (which now owns this format
> for skill-library decisions) was created alongside this ADR and lives at
> `skills/documentation/skills-adr/`.
