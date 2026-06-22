# Agentic Workflow Coordinator

## Spec / Jira Ticket → Subtasks → Discovery → Engineer → Test → Quality → Review → PR

---

## Overview

This coordinator manages a single subtask end-to-end. It is launched once per
subtask. The orchestrator (Opus) owns all branching decisions. Subagents
(Sonnet) handle all execution. No subagent makes a branching decision.

> **Related:** to ship a *whole spec* of many tasks autonomously in a disposable
> worktree, use `/spec-pipeline` instead. `/workflow` is the single-subtask,
> in-place, architecture-tracked tool; `/spec-pipeline` is the whole-ticket,
> hands-off one. See `docs/adr/0003-workflow-and-spec-pipeline-are-distinct-aligned-tools.md`.

**Input required before launching:**

- One of:
  - A Jira ticket key (e.g. `PROJ-123`) — auto-detected via `^[A-Z]+-[0-9]+$`
  - A spec file path (e.g. `docs/stories/01-project-setup.md`) — auto-detected by file existence
  - A free-form description — fallback when neither of the above matches
- The specific subtask to work on (by title or subtask key, if applicable)

The target branch is **derived**, not supplied — see Phase 0.5.

---

## Variables

Define these once. Every later phase references them rather than restating
the paths or values.

| Variable | Source | Example |
| --- | --- | --- |
| `SUBAGENT_MODEL` | constant | `claude-sonnet-4-6` |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` | `myapp` |
| `PLANS_DIR` | `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans` | per global plan-storage rule |
| `SCHEME`, `DESTINATION`, `TEST_TARGET` | derived in Phase 1 from `CLAUDE.md` | — |
| `PROJECT_KIND` | detected in Phase 1 (`xcode` or `spm`) | — |
| `BASE_BRANCH` | declared in `CLAUDE.md`, fall back to `main` | — |
| `BRANCH_PREFIX` | declared in `CLAUDE.md`, fall back to project Jira key | `proj-` |

When a phase says "spawn a Sonnet subagent" it always means
`model: SUBAGENT_MODEL, mode: normal`.

---

## Input — detect and normalise

Run as a single step:

1. **Normalise.** Strip a leading `@` if present (mention-style refs). If the
   argument names a story number and the project's spec dirs contain a
   matching file, suggest the resolved path via `AskUserQuestion`.
2. **Classify** the normalised argument:
   - Matches `^[A-Z]+-[0-9]+$` → `mode = jira`
   - Is a path to an existing file → `mode = spec`
   - Otherwise → `mode = prompt`
3. **Resolve near-misses.** If the file does not exist but a single close
   match exists under `docs/stories/` / `docs/specs/` / any spec dir
   declared in `CLAUDE.md`, name the file and confirm via `AskUserQuestion`.
   Never auto-resolve silently.

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

The skill produces signals (merged-PR vs progress-doc drift, out-of-scope
story markers, dirty working tree, wrong base branch). When any signal
fires, the orchestrator asks the user via `AskUserQuestion` with three
options. The orchestrator owns what each option does:

| Option | Orchestrator action |
| --- | --- |
| **Reconcile first** | Update progress doc / pick a different story / clean the tree, then re-run pipeline-preflight. Do not proceed to Phase 0.5 until preflight emits `Pre-flight clean.` |
| **Proceed anyway** | Record the override in the discovery note's "Open issues" section (Phase 3). Continue to Phase 0.5. |
| **Abort** | Halt with no blocked report. This is a user choice, not a failure. |

When preflight emits `Pre-flight clean.`, continue to Phase 0.5 without
further prompting.

---

## Phase 0.5 — Branch

### Opus, plan mode

Derive the branch name: `${BRANCH_PREFIX}${ticket-number}-${kebab-title}`.

- If on `BASE_BRANCH` and the derived branch does not exist → create it from
  `BASE_BRANCH`.
- If already on the derived branch with prior commits from this pipeline →
  resume.
- If on an unrelated branch → halt and ask the user.

Do not proceed to Phase 1 until `HEAD` is on the derived branch and the
working tree is clean.

---

## Phase 1 — Orientation

### Opus, plan mode

Read the following before doing anything:

1. `CLAUDE.md` — follow every linked doc from it
2. If `mode = jira`: the Jira ticket via Atlassian MCP
3. All acceptance criteria (from the ticket or spec file)

**Derive build targets from CLAUDE.md.** Look for build / test commands and
extract:

- `PROJECT_KIND` — `xcode` if the commands use `xcodebuild`, `spm` if they
  use `swift build` / `swift test`.
- `SCHEME` — the value passed to `-scheme` (xcode only).
- `DESTINATION` — the full string passed to `-destination` (xcode only).
- `TEST_TARGET` — the value passed to `-only-testing:` in any
  `xcodebuild test` command. If multiple test targets exist, prefer the
  one named like `*UnitTests` / `*Tests` and ignore UI test targets.
- `BASE_BRANCH` — declared base branch; fall back to `main`.
- `BRANCH_PREFIX` — declared branch prefix; fall back to the project's
  Jira key (lowercased) plus `-`.

If any of these cannot be derived, ask the user before continuing. Do not
invent defaults.

Do not proceed until you have read all of the above.

**Premise / internal-consistency read (when the input is a fully-specified
plan or carries a load-bearing invariant).** Before any implementation,
read the plan *against itself*, not only against the code: identify its
central premise and any invariant marked hard/never/must, and ask whether a
constraint **forbids the plan's own mechanism**. Classic self-contradictions:
"swap renderer/parser/serialiser A→B" + "match A's recorded baselines exactly,
never re-record" (a backend swap changes output by definition); "pixel/byte
identical across two engines"; "output pinned to an oracle recorded under a
different implementation". This is a contradiction read, **not** a
re-litigation of intent — it fires only when a constraint and the plan's own
mechanism genuinely collide, and the plan being *locked* does not exempt it.
If a collision is found, do NOT proceed on faith — ask via `AskUserQuestion`:

| Option | Action |
| --- | --- |
| **Relax the invariant** | Adopt the revised bar (e.g. re-record the oracle from the new implementation on sign-off; perceptual not pixel tolerance). Record it in the discovery note "Definition of done". |
| **Prove it first (spike)** | Run the smallest experiment that confirms/refutes feasibility before committing the full plan. |
| **Route to `/solve`** | If the premise itself is the open question, hand the plan to `/solve` Phase 1 feasibility before implementing. |
| **Proceed as specified** | Record the feasibility risk in the discovery note "Open issues"; the Convergence Checkpoint will catch non-convergence if the premise fails. |

A user-supplied plan is the highest-leverage place to surface a contradiction
— everything downstream inherits its premise. (Remove-KickText precedent: the
plan's "never re-record CoreText baselines while swapping to a UILabel/TextKit
renderer" was self-contradictory and cost ~5h before it was named.)

---

## Phase 2 — Decompose AC → Create Subtasks in Jira

### Opus, plan mode — Jira mode only

> Skip this phase when `mode = spec` or `mode = prompt`. Proceed to Phase 3
> using the spec file or free-form input as the subtask definition.

Using the acceptance criteria from the Jira ticket:

1. Decompose the AC into discrete, independently-implementable subtasks.
2. Each subtask must:
   - Be completable in a single engineer subagent session
   - Have a clear, testable definition of done
   - Map to one logical unit of work (one service, one view, one actor, etc.)
3. Create each subtask in Jira as a child of the parent ticket via Atlassian MCP.
4. **Add a `Non-goals` comment** to the parent ticket listing AC items
   that are explicitly out of scope for this round — Phase 3 will read this
   list when writing the discovery note.
5. Record the subtask keys returned by Jira — you will update them with
   status as the workflow progresses.

Do not begin implementation until all subtasks are created and confirmed in Jira.

---

## Phase 2.5 — Architecture Tracking

### Opus, plan mode

Look up the master issue in the **project repo** (not the skills repo):

```bash
gh issue list \
  --search "[${STORY_KEY}] Architecture in:title" \
  --label architecture \
  --json number,title,state \
  --limit 5
```

**No master issue (first run):** apply skill `discovery-init` after Phase 2
has created the JIRA subtasks. The skill creates the GitHub master issue
(overview + subtask checklist) and one sub-issue per JIRA subtask. Record
`MASTER_ISSUE_NUMBER` and `ARCH_LABEL` in the context bundle.

**Master issue exists (subsequent run):** apply skill `discovery-check`.
Delegate the reconcile sweep (gh issue close/comment, JIRA→Testing, checkbox
ticks) to a Sonnet subagent; the orchestrator (Opus) makes the drift judgment
itself. If it returns `DRIFT: changed:<summary>`, the master issue's first
comment now holds the corrected architecture — pass it into Phase 3 so the
discovery note reflects the current architecture. Carry the returned
`FINAL_RUN` flag forward.

**Final subtask (`FINAL_RUN: true`):** the reconcile sweep skips the
in-progress subtask, so after Phase 8 succeeds the orchestrator must apply
skill `discovery-audit`. That skill closes the final sub-issue, ticks its
checkbox, moves its JIRA to Testing, runs the audit, and closes the master
issue. On `VERDICT: fail`, surface findings to the user; do not close the
master issue without confirmation.

> Skip this phase entirely when `mode = spec` or `mode = prompt` (no STORY_KEY
> to look up and no JIRA subtasks were created in Phase 2).

---

## Phase 3 — Discovery

### Opus, plan mode

Apply skill `implementation-brief` for the current subtask. The skill produces a
discovery note at `${PLANS_DIR}/[SUBTASK-KEY]-discovery.md` with the
required sections:

- Baseline
- Types in scope (Existing / New)
- Injection
- Patterns to follow
- Concurrency notes
- Edge cases to handle
- Failure paths to handle
- Must NOT touch
- Definition of done

If `mode = jira`, include the `Non-goals` list from Phase 2 in the
"Must NOT touch" section.

**Validate before handing off.** After the skill runs, grep the discovery
note for each required section header. If any is missing → re-run
`implementation-brief` with a `MISSING_SECTIONS:` note. Do not spawn Phase 4
against an incomplete discovery note.

Do not write any implementation code in this phase.

---

## Subagent Context Bundle

Build the bundle once per subtask after Phase 3 succeeds. Pass it inline in
every later subagent prompt so subagents never re-read `CLAUDE.md` or the
discovery note from disk.

```
SUBTASK: [SUBTASK-KEY] — [Title]
STORY_KEY: [parent JIRA key passed to /workflow]
MASTER_ISSUE_NUMBER: [from discovery-init, or the Phase 2.5 lookup; blank in spec/prompt mode]
ARCH_LABEL: arch:[STORY_KEY]
DISCOVERY: <full contents of ${PLANS_DIR}/[SUBTASK-KEY]-discovery.md>
CLAUDE_MD: <full contents of ./CLAUDE.md>
SCHEME: [SCHEME]
DESTINATION: [DESTINATION]
TEST_TARGET: [TEST_TARGET]
PROJECT_KIND: [PROJECT_KIND]
```

References to "the context bundle" below mean this block.

---

## Phase 4 — Engineer Execution

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below.

> Apply skill `swift-engineering`. The bundle below contains everything you
> need — do not re-read these files from disk.
>
> [context bundle]
>
> Implement the subtask according to the discovery note. Follow every
> constraint listed under "Must NOT touch". The discovery note is the
> source of truth — apply `swift-engineering` rules to *how* you build,
> but follow the discovery note for *what* to build.
>
> If the discovery note is inconsistent with the codebase (a service
> doesn't exist where claimed, a constraint is impossible, types
> contradict), **halt and emit `BOUNCE: [one-line reason]`**. Do not
> implement around it.
>
> For Swift 6 isolation errors that aren't trivially resolvable inline,
> apply skill `swift-engineering` (fix concurrency mode) on the affected file.
>
> Build must pass with zero errors and zero warnings. Prefer the MCP Xcode
> tools when Xcode is open:
>
> ```
> ToolSearch("select:mcp__xcode__BuildProject,mcp__xcode__GetBuildLog,mcp__xcode__XcodeListNavigatorIssues")
> ```
>
> Fall back to Bash when Xcode is not open:
>
> ```bash
> xcodebuild build -scheme [SCHEME] -destination '[DESTINATION]'    # PROJECT_KIND=xcode
> swift build                                                       # PROJECT_KIND=spm
> ```
>
> Report: list of files created or modified, build result, and the
> `BOUNCE:` line if applicable.

**Retry budget: 2 build-fix attempts.** If the subagent reports build
failure, spawn a fix subagent with the build output. On the second build
failure → halt + blocked report (see Halt Conditions).

**Bounce-back: 1 attempt per subtask.** If the subagent reports
`BOUNCE:`, return to Phase 3 with the bounce reason and re-spawn
`implementation-brief`. If the re-bounce → halt + blocked report.

**SourceKit diagnostics.** When `<new-diagnostics>` fire after the
subagent reports completion but the subagent's own build was clean, apply
the "Build vs SourceKit truth" rule in skill `swift-engineering`. One ack
line, no re-spawn.

**Crash recovery.** If the subagent returns no usable result (raw API
error, timeout, socket-closed), apply skill `subagent-reliability` before
consuming a retry slot.

Return control to the orchestrator when the subagent reports completion.
The orchestrator reads the file list and build result before continuing.

---

## Phase 5 — Test Authoring

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below.

> Apply skill `swift-testing`. The bundle below contains everything you
> need — do not re-read these files from disk.
>
> [context bundle]
> PHASE_4_FILES: <list of files created or modified in Phase 4>
>
> Write Swift Testing tests covering:
>
> - The happy path for every public method introduced in Phase 4
> - Every edge case listed in the discovery note
> - Every failure path that can be expressed without a live network
>
> Apply every `swift-testing` rule verbatim — including the `.serialized`
> ban, the actor-mock rule, and the no-process-global-state rule. Do not
> weaken any rule to make a test pass.
>
> Report: list of test files created and number of test cases written.

**Retry budget: 1 attempt to recover from a subagent-reported failure.**
Crash recovery applies skill `subagent-reliability` first.

Return control to the orchestrator when the subagent reports completion.

---

## Phase 6 — Test Execution Loop

### Opus, plan mode (orchestrator decision point)

Run the tests. Prefer MCP Xcode tools when available:

```
ToolSearch("select:mcp__xcode__RunSomeTests,mcp__xcode__RunAllTests")
```

Fall back to Bash:

```bash
# PROJECT_KIND=xcode
xcodebuild test -scheme [SCHEME] -destination '[DESTINATION]' -only-testing:[TEST_TARGET]

# PROJECT_KIND=spm
swift test
```

**Retry budget: 3 fix attempts.**

A green result is **not trusted** until it passes the **real-green gate**:

1. **Executed-test count > 0 (and ≥ expected).** If the run reports
   "0 tests" / "Suite passed (0 tests)", or fewer executed tests than the
   suite contains, treat it as a HARD FAILURE (stale bundle ran nothing),
   not a pass. Parse the *executed* count from the result bundle, not the
   artefact count (e.g. snapshot PNG count legitimately differs).
2. **Clean build for the trusted green.** The first green of a session, and
   any green immediately after a change to test infrastructure or a
   snapshot/golden suite, must come from a clean build (`xcodebuild clean`,
   or clear DerivedData) before it is believed.
3. **Never accept a subagent's self-reported pass / "pixel-identical /
   zero-delta / different simulator pass"** when your own last run
   disagreed — require the artefact (diff image, the executed-count line)
   or re-run the assertion yourself.

Only after the real-green gate passes does exit 0 count as a pass: proceed to
Phase 6.5. (Remove-KickText precedent: two stale-bundle false-greens — "Suite
passed (0 tests)" — masked a real regression and corrupted a triage round.)

If tests fail:

1. Capture the full failure output.
2. Spawn `model: SUBAGENT_MODEL, mode: normal`:
   > The following tests failed. Fix the implementation to make them pass.
   > Do not change the tests. Do not change anything outside the failing scope.
   > Failure output: [full output]
3. Re-run the tests.
4. After 3 failed attempts → write a blocked report to
   `${PLANS_DIR}/[SUBTASK-KEY]-blocked.md`. If `mode = jira`, transition
   the subtask to `Blocked` via Atlassian MCP with the failure summary.
   Halt; do not proceed to Phase 6.5.

---

## Phase 6.5 — Swift Quality Pass

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below.

> Apply skill `swift-engineering` (rewrite mode) to every implementation file from Phase 4.
> Do NOT touch test files authored in Phase 5.
>
> [context bundle]
> PHASE_4_FILES: <list of files created or modified in Phase 4>
>
> This is a style and structure pass. Do NOT change behaviour. Do NOT
> rename public API. Do NOT restructure control flow. If a rule requires
> a public API rename, halt and surface it — do not perform it.
>
> Confirm the build passes with zero errors and zero warnings, then
> re-run the tests using the Phase 6 command (`xcodebuild test
> -only-testing:[TEST_TARGET]` or `swift test`). Both must pass.
>
> Report: list of files modified, summary of style changes, build result,
> and test result.

**Retry budget: 1 fix attempt for build/test regressions introduced by
the quality pass.** Spawn a targeted fix subagent with the failure output
and instruction to revert only the style change that caused the regression.

If still broken after the fix attempt → halt + blocked report.

The orchestrator confirms both build and test results before continuing
to Phase 7.

---

## Phase 7 — Code Review

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below. Code
review runs as a subagent so the orchestrator doesn't burn context
reading every changed file.

> Apply skill `swift-code-review`.
>
> [context bundle]
> PHASE_4_FILES: <list>
> PHASE_5_FILES: <list>
> PHASE_6_5_FILES: <list>
>
> Review every file in PHASE_4_FILES, PHASE_5_FILES, and PHASE_6_5_FILES.
> Apply the full BLOCKER / WARNING / SUGGESTION checklist.
>
> Verify the **Definition of done** from the discovery note is observable
> in the diff or in a passing test. List each DoD criterion and which
> file/test demonstrates it.
>
> Report: structured findings list, DoD verification, and a
> PASS / FAIL verdict.

**Retry budget: 1 review-fix attempt.** If the reviewer returns FAIL:

1. Spawn a targeted Sonnet fix subagent with the BLOCKER findings listed
   explicitly as the task.
2. Re-spawn `swift-code-review` on the fixed files only.
3. If still FAIL → halt + flag for manual review.

If no BLOCKERs and DoD verified → proceed to Phase 7.5.

---

## Phase 7.5 — UI Verification (optional)

### Opus, plan mode

Trigger when any file in PHASE_4_FILES or PHASE_6_5_FILES is a SwiftUI
`View`. Otherwise skip.

Apply skill `verify` (or `swift-uitest` for tvOS) to launch the app on
simulator and confirm the affected screens render and navigate without
regressions. For unwired views or pure component changes, an automated
preview snapshot is sufficient.

If the manual verification surfaces a regression → spawn a Sonnet fix
subagent with the regression description. Cap at 1 attempt; on failure,
halt + flag for manual review.

---

## Phase 8 — PR Gate + PR Creation

### Opus, plan mode

Apply skill `swift-pr-gate`. The skill runs every gate (build, tests,
scope, branch name, PR description, Jira status) and produces the gate
summary.

If any gate fails → halt + report. Do not raise a PR from a broken state.

Once all gates pass:

1. Use the gate's synthesised PR description (template-conformant, not the
   raw discovery note).
2. Create the PR:

   ```bash
   gh pr create \
     --title "[SUBTASK-KEY]: [Subtask title]" \
     --body-file [body-file from gate] \
     --base [BASE_BRANCH] \
     --head [branch-name]
   ```

3. If `mode = jira`:
   - Transition the Jira subtask to `In Review` via Atlassian MCP.
   - Add the PR URL as a comment on the Jira subtask.
4. Report the PR URL to the user.

---

## Phase 9 — Post-PR Comment Loop (optional)

### Opus, plan mode

When the user returns with reviewer feedback on the PR, apply skill
`pr-comment-review`. The skill triages each comment, applies fixes via
Sonnet subagents, and posts replies.

This phase is user-triggered — the orchestrator does not poll for review
comments on its own.

---

## Halt Conditions

The orchestrator must halt and report (never silently continue) if:

- Phase 4 build fails after 2 attempts
- Phase 4 bounce-back exhausted (1 attempt)
- Phase 6 tests fail after 3 attempts
- Phase 6.5 build or tests fail after 1 fix attempt
- Phase 7 code review fails after 1 fix attempt
- Phase 7.5 UI verification surfaces a regression after 1 fix attempt
- Any `swift-pr-gate` gate fails
- `gh pr create` fails
- Any required Jira MCP call fails (Jira mode only)
- `discovery-audit` returns `VERDICT: fail` and the user does not confirm close → surface findings; do not silently close the master issue

On halt: write a summary to `${PLANS_DIR}/[SUBTASK-KEY]-blocked.md`.

If `mode = jira`: transition the Jira subtask to `Blocked` with a comment.

---

## Retry Budget Summary

| Phase | Retry budget | Halt action |
| --- | --- | --- |
| Phase 4 build | 2 attempts | Halt + blocked report |
| Phase 4 bounce-back | 1 attempt | Halt + blocked report |
| Phase 5 test authoring | 1 attempt | Halt + blocked report |
| Phase 6 test loop | 3 attempts | Halt + blocked report + Jira update (Jira mode only) |
| Phase 6.5 quality build/test | 1 attempt | Halt + blocked report |
| Phase 7 review fix | 1 attempt | Halt + flag for manual review |
| Phase 7.5 UI verify fix | 1 attempt | Halt + flag for manual review |
| Convergence (run-level) | 4 cycles w/o real-green progress · recurring failure-class · user cost-concern | Checkpoint `AskUserQuestion` → rethink-via-`/solve`, relax-bar, continue, or abort |

The budget counts subagent **failures** (build broken, test failed, scope
violated — anything the subagent reported as a failure). Subagent
**crashes** (no usable result returned, raw API error, socket-closed,
timeout) are a different failure mode — apply skill `subagent-reliability`
first. A "recover-in-place" or "resumed" outcome does NOT consume a retry
slot; a "re-spawn fresh" outcome does.

---

## Convergence Checkpoint (run-level)

The per-phase budgets above catch a stuck *task*. This catches a stuck
*approach* — and applies even to build/test/compare cycles the orchestrator
runs **by hand**, which otherwise escape every per-phase budget (in the
Remove-KickText session the triage loop was hand-driven *outside* the phases,
so the Phase 6 cap never fired and ~5h elapsed at near-zero net yield).

Maintain, across the whole subtask, a run-level meter:

- `fix_cycles_since_green` — edit→build→test cycles since the last
  **real-green** (Phase 6 gate) on a clean build. Reset ONLY on a real green —
  never on a 0-test green or a subagent's self-reported pass.
- `net_loc` — non-test source lines added minus removed since Phase 1.
- `failure_class` — the assertion / symptom class of the current failures.

**Trip the checkpoint when ANY holds** (empirical non-progress — NOT subjective
slowness; a correct-but-hard approach must not be abandoned on a stopwatch):

- `fix_cycles_since_green >= 4` with no reduction in the failing-assertion count
- the **same `failure_class` recurs across 3+ cycles** (the approach is
  relocating the symptom, not converging)
- a fix the orchestrator predicted would resolve a failure **changes nothing**
  twice (the causal model is wrong — you are fighting the oracle, not a bug)
- the **user voices a cost/progress concern** in any phrasing ("not much done",
  "taking a while", "should this be faster/parallel") — a HARD prompt to
  surface the meter, answered with the numbers, not a defence of the loop

On trip, present the meter and ask via `AskUserQuestion`:

| Option | Action |
| --- | --- |
| **Rethink (hand to `/solve`)** | Halt the loop; launch `/solve` with the current state + recurring `failure_class` as the problem. Non-convergence is the symptom `/solve` Phase 1 reasons over. |
| **Relax the bar** | Take the user's reframe (drop an invariant, re-record the oracle); update the discovery note "Definition of done"; reset the meter; continue. |
| **Continue as-is** | Record the override in "Open issues"; reset the trip counter once — it re-trips at the next threshold. |
| **Abort** | Halt, no blocked report. A user choice. |

Escalation is mandatory once tripped: a micro-fix that goes green *after* the
trip does not retroactively reset it — do not "do the small fixes and keep
going".

**Delegate slow loops.** If a single test run exceeds ~2 min (simulator
snapshot/UI suites) and the loop will iterate more than twice, do not
hand-drive run→read→fix→re-run from the orchestrator — spawn one Sonnet
subagent that owns the whole run-fix-re-run cycle with a fixed iteration cap
and the convergence metric, reporting back only final state + meter + verdict.

---

**Model & mode:** Opus, plan mode — this is an orchestrator prompt with
branching logic; Opus must own all decisions.
Sonnet subagents handle Phases 4, 5, 6.5, and 7 only.
