---
name: spec-validation
description: Validate one or more drafted technical specs against the live codebase with a multi-lens agent panel, then reconcile findings back into the spec as source of truth. Use after a fix has been designed (e.g. by /solve) and written up as a Jira ticket, GitHub issue, or markdown spec — but BEFORE implementation (/workflow) — to confirm every file path, line, symbol, and proposed diff is real, the fix actually resolves the stated cause, and nothing is missed. Triggers on "validate this spec", "check these specs against the code", "are these tickets accurate", "spec validation", or any time a spec will become the implementation source of truth.
---

# Spec Validation

Turn a drafted spec into a *trustworthy* spec. A spec written from static reasoning routinely contains wrong line numbers, a misidentified root cause, or a fix that won't compile. This skill spawns a panel of read-only agents that verify the spec **against the live code**, then folds their findings back into the spec so the artefact reviewers and implementers rely on is correct.

Use it on the output of `/solve`, `discovery-jira`, or any hand-written spec — before `/workflow` or an engineer implements it. It does not write implementation code.

## Why a panel (not one reviewer)

One reviewer conflates "is it accurate" with "will it work" with "what's missing" and does all three shallowly. Splitting into fixed lenses forces each agent to do one job well, and disagreement between lenses surfaces the spec's weakest claim. In practice the completeness/soundness lenses are what catch a *wrong root cause* — the most expensive spec defect, because everything downstream inherits it.

## Workflow

1. **Collect the specs and their checkable claims.** For each spec, extract the concrete, falsifiable assertions: file paths, line numbers, symbol names, the proposed code diff, and each acceptance criterion. These are what the panel verifies — vague prose can't be validated.

2. **Spawn the panel — one agent per lens, each validating ALL specs.** Default to 3 lenses (scale to 2 for a trivial spec, 4+ for a high-stakes one). Use read-only reviewer subagents (a code-review agent type if one exists, else general-purpose). Run them in parallel. **Each agent MUST read the actual source files — never trust the spec's own claims.** Pass every spec inline (or have the agent fetch it, e.g. `gh issue view <n>`), plus the lenses below.

   - **Code-accuracy** — every file path, line number, symbol, type, and API in the spec matches the real code; the proposed diff would compile (check isolation/availability/signatures). Report each inaccuracy with the corrected value and `file:line`.
   - **Fix-soundness** — does the proposed change actually resolve the stated root cause? Reason about mechanism (does breaking *this* edge release *that* object; does setting *this* config take effect where claimed). Flag any new bug/regression/race the fix introduces. Name the single strongest gap. Default to skeptical: if the root cause itself looks wrong, say so and give the real one with evidence.
   - **Completeness & AC-testability** — sibling defects or other call sites the spec misses; net-new code the spec references as if it exists; acceptance criteria that are not actually testable with the available tooling (e.g. a raw C-heap leak is not Swift-Testing-assertable — it needs Instruments). Propose the concrete addition for each gap.

3. **Reconcile — the orchestrator decides, not the subagents.** Read every agent's findings. For each spec form a verdict per lens (`ACCURATE`/`ISSUES`, `SOUND`/`CAVEATS`/`UNSOUND`, `COMPLETE`/`GAPS`) and a consolidated correction list. When two lenses converge on the same defect (especially a wrong root cause), treat it as confirmed.

4. **Fold findings back into the source of truth.** Edit the spec/ticket/issue so the corrected version *is* the artefact people read:
   - Wrong line/symbol/path/API → fix in place.
   - **Wrong root cause or unsound fix → rewrite** the Problem/Solution sections, don't just append a caveat. Record the rejected hypothesis under "Alternatives rejected" so the mistake isn't re-made.
   - Missing call site / sibling defect → add to Affected Files / Solution.
   - Untestable AC → rewrite it to the verification that actually works.
   - Add a short "Validated by N-agent review" note stating the verdicts and what changed. Mirror a one-line summary onto the linked Jira/GitHub counterpart if the spec lives in two places.

5. **Report** the per-spec verdicts, the corrections applied, and any residual caveat the implementer must know (e.g. "soft cache cap — bounded not exact").

## Rules

- Subagents are **read-only** and **read the live code**; the orchestrator owns every judgment and every edit. No subagent edits the spec.
- A spec whose root cause changed is not "patched" — it is rewritten. Downstream work inherits the premise.
- Cite `file:line` for every claim, in both agent findings and the reconciled spec.
- Keep lenses distinct — if two agents would check the same thing, drop one or sharpen its lens.
- This skill validates and corrects specs only. It never implements the fix or opens a PR — hand the corrected spec to `/workflow` or an engineer.
