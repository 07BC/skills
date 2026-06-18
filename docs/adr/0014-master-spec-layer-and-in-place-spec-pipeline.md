---
status: accepted
---

# A GitHub-backed master-spec layer, and an in-place spec-pipeline

The spec pipeline had four standing failures: nothing tracked child specs back to
a master, so they drifted; the engineer's work had no independent reviewer; large
work was decomposed ad-hoc with no durable hierarchy; and test coverage was weak.
A root-cause check found a fifth, mechanical cause underneath three of those:
commit `da5fc1c` (2026-05-24) deleted the eight leaf agents the pipeline
dispatches by `subagent_type` (`engineer`, `spec-distiller`, `planner`,
`test-writer`, `concurrency-auditor`, `task-reviewer`, `swift-spec-review`,
`spec-scope-guardian`). The SKILL kept dispatching them, so every phase silently
ran through a generic fallback agent with no specialist instructions.

We restore the deleted agents and add a two-tier, GitHub-backed architecture with
a single traceability spine.

**Ownership split.** Jira owns the user story and its acceptance criteria (the
product *what*). GitHub owns the *technical* spec decomposition (the *how*).
`/spec-master` (new) reads a Jira story, freezes a stable AC ID per criterion
(`<KEY>-ACn`, immutable once written), decomposes the work via the repurposed
`spec-scope-guardian`, and creates a GitHub **master issue** plus native **child
sub-issues** (`gh api graphql addSubIssue` — within the "always `gh`" rule). The
master issue is the single source of truth and the rendered traceability matrix.

**The traceability spine.** Stable AC IDs thread master → child (`covers:`) → task
(`implements:`) → test (`// AC:`). `check-traceability.sh` gates the child scope
deterministically (scope-creep, unplanned, untested); `drift-auditor` adds a
semantic master↔child pass; master-scope coverage (every AC covered by some child)
is checked against GitHub in `/spec-master`. The same spine mechanises both drift
detection and "every AC has a test".

**Dual review.** One engineer implements; two diverse-lens reviewers
(`task-reviewer` = spec-correctness, `quality-reviewer` = architecture/quality)
review the same task diff in parallel, blind to each other, and **both** must PASS,
on top of the self-gated `concurrency-auditor`.

**Test rigour.** Every covered AC maps to ≥1 named test, plus a changed-line
coverage floor (`coverage_floor`, default 90, via `coverage-gate.sh`) with a
documented exclusions file for the genuinely-untestable.

**In-place execution.** `/spec-pipeline` no longer creates a git worktree; it runs
on a fresh branch in the current checkout (the user sets up a worktree manually if
they want isolation). Child specs are sequenced by a hard stop: a child does not
start until every `depends_on` child is merged to main.

## Considered options

- **Bolt the four features onto the existing worktree pipeline.** Rejected: the
  pipeline was not "working but missing features" — its review/test agents were
  deleted. The honest fix is restore-then-strengthen, and the user explicitly
  chose in-place execution and GitHub-backed tracking.
- **Master spec in Obsidian or in-repo, not GitHub.** Rejected: the user wants the
  spec tree as GitHub issues with native sub-issues (team-visible, branch-
  independent, progress-tracked). Jira stays the story/AC system of record per the
  ownership split.
- **A drift-checker agent instead of a matrix.** Rejected as the primary
  mechanism: judgment-based drift is not reproducible. The deterministic matrix is
  the gate; the agent is a semantic backstop on top of it.
- **GitHub sub-issues via the GitHub MCP `sub_issue_write`.** Rejected: the MCP is
  not the `gh` CLI and would violate the author's "always `gh`, never REST/curl/
  octokit" rule. `gh api graphql` drives the same native mutation within the rule.

## Consequences

- **Supersedes the worktree-isolation distinction in
  [[0003-workflow-and-spec-pipeline-are-distinct-aligned-tools]].** With
  `/spec-pipeline` now in-place, it converges with `/workflow`'s execution model.
  The remaining distinction is scope: `/spec-pipeline` ships a whole child spec
  through the engineer→dual-review→test loop under a master; `/workflow` drives a
  single subtask. ADR 0003's argument-style and alignment guidance still holds.
- `/spec-master` is a new orchestrator: it carries `disable-model-invocation: true`
  (outward GitHub side effects, per [[0004-skill-species-invocation-frontmatter]])
  and is added to the conformance list in `test_orchestrator_conformance.py`.
- State placement ([[0006-durable-state-placement-convention]]) is unchanged and
  reinforced: branch-independent spec state → GitHub issues; durable run record →
  the Obsidian audit log; same-cycle handoffs → tmp files by path.
- New config keys `github_repo` and `coverage_floor` join the `spec_pipeline`
  schema; both have safe fallbacks.
- The pipeline gains GitHub and `gh api graphql` as runtime dependencies for the
  `--from-issue` path; the other input modes (`--from-jira/-spec/-prompt`) skip
  the sequencing/drift/master-reconcile steps and run as standalone specs.
