# Mr Will: Solve

## Problem → Understand → Fan out for fixes → Converge on one approach → Hand off to /workflow

---

## Overview

This command is a **diagnostic and solution-design panel** for a single bug or
architecture problem. A team of subagents understands the problem, fans out to
propose competing fixes, and converges on one approved approach. Its output is
an **approved fix-plan**, not code.

It is the missing front door to the implementation chain:

```
/solve            →  approved fix-approach  →  /workflow  →  PR
(diagnose + design)   (PLANS_DIR doc)           (implements known work)
```

Use `/solve` when you do **not yet know the fix** — a bug whose root cause is
unclear, or an architecture problem with several plausible approaches. Once the
approach is approved, `/workflow` implements it. `/solve` never writes
implementation code or opens a PR.

The orchestrator (Opus) owns every branching decision — which angles to fan out
on, which proposal wins, whether to loop. Subagents (Sonnet) explore, propose,
and attack; no subagent makes a branching decision.

**Input required before launching:**

- One of (auto-detected, positional):
  - A free-form problem description — the default
  - A Jira ticket key (e.g. `PROJ-123`) — auto-detected via `^[A-Z]+-[0-9]+$`
  - A file path naming the problem (a spec, a stack trace, a failing test) —
    auto-detected by file existence

---

## Variables

Define these once. Every later phase references them rather than restating
the paths or values.

| Variable | Source | Example |
| --- | --- | --- |
| `SUBAGENT_MODEL` | constant | `claude-sonnet-4-6` |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` | `myapp` |
| `PLANS_DIR` | `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans` | per global plan-storage rule |
| `SOLVE_DOC` | `${PLANS_DIR}/solve/${slug}.md` | the single durable artefact this command produces |
| `slug` | kebab-cased problem title | `chatviewmodel-merge-message-arrays` |

When a phase says "spawn a Sonnet subagent" it always means
`model: SUBAGENT_MODEL, mode: normal`.

---

## Input — detect and normalise

Run as a single step:

1. **Normalise.** Strip a leading `@` if present (mention-style refs).
2. **Classify** the normalised argument:
   - Matches `^[A-Z]+-[0-9]+$` → `mode = jira` (read the ticket via Atlassian MCP)
   - Is a path to an existing file → `mode = file` (read it as the problem source)
   - Otherwise → `mode = prompt`
3. Derive `slug` from the problem title once understood; until then use a
   provisional slug.

Announce the resolved mode and argument before proceeding.

---

## Model Confirmation

State on a single line:

> Running as: [model name and version] — [plan mode / normal mode]

Do not proceed to Phase 0 until this line has been output.

---

## Phase 0 — Preflight

### Opus, plan mode

Apply skill `pipeline-preflight`.

When any signal fires (dirty working tree, drift, wrong base branch), ask the
user via `AskUserQuestion` with three options. The orchestrator owns what each
option does:

| Option | Orchestrator action |
| --- | --- |
| **Reconcile first** | Resolve the signal, then re-run pipeline-preflight. Do not proceed until it emits `Pre-flight clean.` |
| **Proceed anyway** | Record the override in the problem model (Phase 1, "Open issues"). Continue. |
| **Abort** | Halt with no blocked report. A user choice, not a failure. |

When preflight emits `Pre-flight clean.`, continue to Phase 1 without further
prompting.

> `/solve` is read-only with respect to the working tree — it never commits or
> branches. Preflight here is a hygiene gate so the diagnosis reflects a known
> state, not a setup step.

---

## Phase 1 — Understand

### Opus, plan mode

This phase ends with a **problem model** the rest of the panel reasons over.
It is also where the panel decides its own shape — this is the adaptive core.

1. **Read the problem.** Read `CLAUDE.md` and follow every linked doc. Read the
   problem source (the prompt, the Jira ticket, or the named file).
2. **Map the blast radius.** When the affected area is wider than the
   orchestrator can hold in context, spawn one or more **`code-explorer`**
   subagents (`agentType: feature-dev:code-explorer`) to trace the execution
   path and dependencies. Pass each a narrow question; never "read the whole
   module." Apply skill `subagent-reliability` if any returns no usable result.
3. **Clarify with the user.** Surface the genuine unknowns via `AskUserQuestion`
   — public-API constraints, observed-vs-allowed behaviour, what "fixed" must
   mean. Do not guess answers a one-line question would settle.
4. **Decide the fan-out.** Choose how many solver subagents to spawn (2–4) and
   the **distinct angle** each takes. Derive the angles from the problem — do
   not hardcode them. Examples of angle axes, not a fixed list: data-flow vs
   public-API surface; minimal-diff vs clean-redesign; preserve-behaviour vs
   change-the-contract; risk-first vs ergonomics-first.

Write the problem model to `SOLVE_DOC` with these sections:

- **Symptom** — what is observably wrong, or the architecture smell
- **Root-cause hypotheses** — ranked
- **Constraints & invariants** — what must NOT change (public API, observability, behaviour)
- **Blast radius** — files / types / call sites in scope
- **Definition of fixed** — the testable bar the chosen approach must clear
- **Fan-out plan** — the solver count and each angle, with one line of rationale
- **Open issues** — any preflight override or unresolved unknown

Do not propose a fix in this phase. Do not write implementation code.

---

## Solver Context Bundle

Build once, after the problem model is written. Pass inline in every solver and
verifier prompt so subagents never re-read `CLAUDE.md` or `SOLVE_DOC` from disk.

```
PROBLEM: <full contents of SOLVE_DOC at end of Phase 1>
CLAUDE_MD: <full contents of ./CLAUDE.md>
CONSTRAINTS: <the Constraints & invariants section, verbatim>
DEFINITION_OF_FIXED: <the Definition of fixed section, verbatim>
```

---

## Phase 2 — Diverge (fan out for fixes)

### Spawn N Sonnet subagents — normal mode, in parallel

Spawn one subagent per angle from the Phase 1 fan-out plan, each with
`agentType: feature-dev:code-architect` (the agent type confers the architect
behaviour — do not also cite it as a skill). Give each the **same** Solver
Context Bundle plus its assigned angle:

> You are designing an architecture, not implementing it. The bundle below is
> everything you need — do not re-read these files from disk.
>
> [solver context bundle]
> ANGLE: <this solver's assigned angle and its rationale>
>
> Propose ONE approach to fix the problem **from your assigned angle**. You are
> not implementing it. Return:
>
> - **Approach** — what changes, in terms of types / signatures / data flow
> - **Why it fixes the root cause** — tie back to the ranked hypotheses
> - **Invariants honoured** — how each item in CONSTRAINTS is preserved
> - **Migration & test impact** — what callers must change; what must be tested
> - **Risks & tradeoffs** — where this approach is weakest
> - **Confidence** — high / medium / low, with the deciding factor
>
> Do not hedge across multiple approaches. Commit to one and defend it.

**Retry budget: 1 attempt per solver to recover from a subagent-reported
failure.** Crash recovery (raw API error, timeout, socket-closed) applies skill
`subagent-reliability` first, before consuming the retry slot.

Return control to the orchestrator when all solvers report. The orchestrator
reads every proposal before continuing.

---

## Phase 3 — Converge and attack

### Opus, plan mode — with Sonnet adversarial verifiers

1. **Synthesise.** The orchestrator forms a single **candidate approach**. This
   may be one solver's proposal outright, or a merge that grafts the best idea
   from a runner-up onto the strongest base.
2. **Attack.** Spawn 2–3 Sonnet **adversarial verifier** subagents in parallel.
   Each is prompted to *refute* the candidate, defaulting to refuted when
   uncertain, each through a distinct lens (does it actually fix the root cause;
   does it break a stated invariant; does it introduce a regression or migration
   hazard):

   > [solver context bundle]
   > CANDIDATE: <the synthesised candidate approach>
   > LENS: <root-cause | invariants | regression-and-migration>
   >
   > Try to refute this candidate through your lens. Default to `refuted: true`
   > if you are not confident it holds. Return `{ refuted, reason }`.

   Apply skill `subagent-reliability` for any verifier that returns no usable
   result.
3. **Decide.** If a majority of verifiers refute, or no candidate survives,
   **loop back to Phase 2** with refined angles informed by the refutations.

**Cycle budget: 2 diverge↔converge rounds.** If round 2 still yields no
surviving candidate → halt + blocked report (see Halt Conditions).

---

## Phase 4 — Approve and hand off

### Opus, plan mode

1. Write the final, surviving approach to `SOLVE_DOC`, appending:
   - **Chosen approach** — the approved design
   - **Why this over the alternatives** — name each rejected proposal and the deciding reason
   - **Migration & test plan** — concrete enough for `/workflow` discovery to consume
   - **Definition of done** — restated from Phase 1, now testable against the approach
2. Present to the user via `AskUserQuestion`:

   | Option | Action |
   | --- | --- |
   | **Approve & hand to /workflow** | Offer to launch `/workflow` with `SOLVE_DOC` as the spec-path input. |
   | **Revise** | Take the user's note and loop back to Phase 2 or Phase 3 as appropriate. |
   | **Stop here** | Leave `SOLVE_DOC` as the deliverable; do not launch `/workflow`. |

`/solve` never edits source or opens a PR. The handoff is the boundary.

---

## Halt Conditions

The orchestrator must halt and write a blocked report (never silently continue)
if:

- Phase 1 cannot establish a Definition of fixed because a required clarifying
  answer is not provided
- Every solver in Phase 2 fails after its retry slot
- The Phase 3 cycle budget (2 rounds) is exhausted with no surviving candidate
- A required Jira MCP call fails (Jira mode only)

On halt: write a summary of the problem model, the proposals seen, and why no
approach survived to `${PLANS_DIR}/solve/${slug}-blocked.md`.

If `mode = jira`: add a comment to the ticket linking the blocked report. Do not
transition the ticket — `/solve` does not own its lifecycle.

---

## Model & mode

**Opus orchestrates** in plan mode and owns all branching — the fan-out shape,
the synthesis, the loop-or-ship decision. **Sonnet subagents** explore
(`code-explorer`), propose (`code-architect`), and attack (adversarial
verifiers); none makes a branching decision. State is kept in the single
`SOLVE_DOC` under `PLANS_DIR` and passed to subagents by the inline context
bundle, never re-read from disk.
