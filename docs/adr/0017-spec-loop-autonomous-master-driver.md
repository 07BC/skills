---
status: accepted
---

# spec-loop — an autonomous master-driver above spec-pipeline

`/spec-pipeline` ships **one** child spec and stops at a per-child PR;
`/spec-decomposition` mints a master + child sub-issues but writes no code. Nothing
takes a *master* and drives it to completion. Doing that by hand means invoking
`/spec-pipeline --from-issue <#>` per child, in dependency order, merging each PR
before the next can start — a long, attended, error-prone sequence. We add
`/spec-loop`: a top-level orchestrator that drives a whole master to one PR
autonomously.

This ADR records the decisions that distinguish spec-loop from the pipeline. They
were settled by grilling, not derived from the existing tools, so they need to be
written down.

**A new standalone skill, not a pipeline flag.** spec-loop is its own orchestrator,
not `spec-pipeline --loop`. The pipeline and its spec-* agents are **not modified**.
spec-loop reuses the proven *inner per-child contract* (pipeline Steps 6–9:
distil → plan → per-task engineer/test/concurrency/dual-review → commit) **by
reference** — the pipeline SKILL stays the authority — applying exactly two deltas:
(1) the sequencing predicate is *committed on this branch* rather than *merged to
main*, because everything lives on one branch; (2) pipeline Phase 5 (the per-child
PR) is skipped. This keeps the two tools clearly distinct without cloning ~1000
lines of engine that would drift.

**One branch, one PR.** All children are implemented on a single branch, committing
per task across every child. The loop runs unattended through the whole master and
stops at exactly one PR for human review. spec-loop commits freely but **never**
auto-creates or auto-merges the PR — `/git-pr` remains the human-gated boundary.

**Git is the resume source of truth.** A long autonomous run will be interrupted.
On re-invoke, done-ness is derived from the branch (task commits + plan `✅`
markers). The committed `docs/specs/<master>-progress.md` tracker and any GitHub
sub-issue checkboxes are *rendered from* git, never trusted as truth — so they
cannot drift. `render-progress.sh` is a pure formatter over a children manifest the
loop computes from git each child.

**Two input modes.** GitHub mode (`--from-master <#>`) drives existing sub-issues.
Local mode (`--from-master-doc <path>`) supports a master with no GitHub: the frozen
AC IDs live in the master doc frontmatter, and spec-loop runs the decomposition
brain (`spec-scope-guardian` + `spec-distiller`) itself to generate local child
spec/plan files, then drives them. Per-child `check-traceability.sh` already works
without GitHub (`covers:` comes from the spec frontmatter); the only genuinely-new
check is master-level coverage — every master AC claimed by some child — which is a
new dedicated `check-master-coverage.sh`, leaving the pipeline's gate scripts
untouched.

**The completion oracle reuses existing gates.** The master is complete only when:
every child is done; per-child traceability passes for each; every master AC is in
some child's `covers`; the branch tests pass and changed-line coverage ≥ the floor;
and `spec-branch-reviewer`, pointed at the **master**, PASSes the whole-diff review.
A BLOCKED master review maps each blocker to the child(ren) it touches and re-runs
only those, bounded by the shared sweep ceiling.

**Termination is guaranteed three ways.** A finite shared ceiling
(`spec_loop_max_sweeps`, default 8) caps all sweeps including master-review fix
sweeps; a stall detector halts any sweep that advances no child and adds no commit;
and a stuck child (gate exhaustion **or** an unresolvable ambiguity such as a
distiller open-question or an engineer design fork) is **parked** if nothing depends
on it (the loop continues) or **halts** the run if a dependent is thereby blocked.
There are no prompts mid-loop — parked children and their open questions are
*reported*, and a run ending with any parked child is an escalation, not a success.

**Children run strictly sequentially.** One child at a time on the single branch.
Parallel independent children were rejected: commit/diff interleaving on one branch
is a real hazard and complicates git-as-truth resume, for a wall-clock gain that an
unattended overnight run does not need.

## Consequences

- A fourth tracker (`progress.md`) joins the audit log, plan `✅` markers, and
  `master-plan.md`. It is the committed, human-facing master view, rendered from git
  so it cannot diverge from the machine records.
- spec-loop is registered as a no-autofire orchestrator skill
  (`disable-model-invocation: true`, stays user-invocable) and added to the
  orchestrator-conformance and skill-taxonomy tests.
- The pipeline's "merged to main" sequencing semantics now have a second reading
  ("committed on this branch") that lives only in spec-loop's driver, not in the
  pipeline — a deliberate divergence to keep the engine single-sourced.
