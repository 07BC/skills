# Orchestrators get a feasibility front-door and a convergence stop-loss

## Context & decision

The Remove-KickText session burned ~5 hours and ~120 lines of shippable code before the user forced a rethink. A four-lens audit found the waste was not a missing feature but a **self-contradictory locked plan that nobody read for internal consistency**, executed by `/workflow`: it demanded a UILabel/TextKit renderer pass snapshot baselines recorded from the *old* CoreText renderer, pixel-for-pixel, while *never re-recording* them. A backend swap changes pixels by definition, so the invariant forbade the plan's own mechanism — the bar was unsatisfiable. The existing per-phase stop-loss never fired because the triage loop was **hand-driven outside the phases**, and two stale-bundle "Suite passed (0 tests)" false-greens were trusted. `/solve` (ADR-0009) eventually rescued it, but only because the human invoked it, late.

We therefore add four guardrails (`commands/Mr Will/solve.md` + `commands/Mr Will/workflow.md`):

1. **`/solve` Phase 1 feasibility / contradiction check** — prove the Constraints & invariants and the Definition of fixed are *jointly* achievable before fan-out; the Definition of fixed must name its oracle, and for any cross-implementation rewrite the oracle must be re-recordable-on-approval or a structural assertion, never an immutable baseline from the prior implementation. Plus an Overview routing rule: a locked plan pinning output to such an oracle must pass `/solve` feasibility before `/workflow` implements it.
2. **`/workflow` Phase 1 premise / internal-consistency read** — read a supplied plan *against itself* for a constraint that forbids its own mechanism. A contradiction read, **not** a re-litigation of intent; it fires only on a genuine collision, and a plan being *locked* does not exempt it.
3. **`/workflow` Phase 6 real-green gate** — a green counts only with executed-test-count > 0 (≥ expected, parsed from the result bundle), from a clean build for the trusted green, and never on a subagent's self-reported "pixel-identical / different pass".
4. **`/workflow` run-level Convergence Checkpoint** — catches a stuck *approach* (including hand-driven cycles that escape the per-phase budgets), tripping on **empirical** non-progress (N cycles without real-green progress, a recurring failure-class, a predicted fix that changes nothing twice, or a user cost-concern in any phrasing) and escalating into `/solve`.

## Considered options (rejected)

- **A "challenge the user's locked plan" gate that fires every run.** Rejected: re-litigates a deliberately-locked plan, would reject hard-but-correct approaches on speculation, and trains the user to ignore it. The contradiction read (guardrail 2) is the safe form — it fires only when a constraint genuinely collides with the plan's mechanism.
- **A subjective-slowness escalation tripwire.** Rejected: this is exactly the failure class CLAUDE.md warns about for tvOS focus bugs, where the correct fix is genuinely slow; a stopwatch-triggered escalation abandons correct-but-hard work and thrashes between approaches. The checkpoint trips on empirical zero-net-progress, not elapsed time.
- **Adding diagnostic machinery inside `/solve`.** Rejected as the *primary* fix: `/solve` worked; it was invoked late. The only `/solve` change is the upstream feasibility front-door (guardrail 1); the rest live in `/workflow`, where the waste occurred.

## Consequences

- Builds on ADR-0009 (`/solve` as the diagnostic front door): the Convergence Checkpoint and the feasibility routing make `/solve` reachable *automatically* from a stuck `/workflow`, not only by manual invocation.
- The lesson is anchored on the **learnable** defect (a plan contradiction + an escaped stop-loss + trusted false-greens), not the unlearnable one ("predict that CoreText can't pixel-match TextKit").
- Full post-mortem (evidence + the four lenses): `~/Developer/obsidian/remove-kick-text/plans/postmortem-remove-kicktext-false-starts.md`.
- `pipeline-preflight` and the orchestrator-conformance tests may want a check that both commands still parse/contain their phase headers after these insertions.
