# uitest

End-to-end XCUITest command. Takes a story from AC to PR-ready artefacts
in one continuous session. You write the tests, run them, debug them, and
produce the PR outputs — all without stopping for external input.

Usage:

```
/uitest PROJ-123
/uitest <story-file-path>
/uitest <pasted-AC>
```

---

## Variables

| Variable | Source | Example |
| --- | --- | --- |
| `SUBAGENT_MODEL` | constant | `claude-sonnet-4-6` |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` | `myapp` |
| `PLANS_DIR` | `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans` | per global plan-storage rule |
| `SLUG` | derived from the story key or title | `proj-123-compose-button` |
| `ATLASSIAN_CLOUD_ID` | declared in `CLAUDE.md` (`pipeline` config block), or resolved at runtime via `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources` | per project |
| `SCHEME`, `DESTINATION`, `UI_TEST_TARGET` | derived in Phase 0 from `CLAUDE.md` | — |

---

## Before you start

Read these files now, before doing anything else:

1. Apply skill `swift-uitest`.
2. `CLAUDE.md`.
3. Any existing UI test target files:

   ```bash
   find . -name '*UITests*.swift' | sort
   ```
4. `swift-uitest/references/accessibility-ids.md` (create if absent).
5. `swift-uitest/references/page-objects.md` (create if absent).

Do not begin Phase 0 until you have read all of the above.

Print the gate summary now, then update it at every phase transition:

```
Phase -1 — Preflight:   [ ]
Phase 0 — AC Intake:    [ ]
Phase 1 — Plan:         [ ]
Phase 2 — Execute:      [ ]
Phase 3 — Debug:        [ ]
Phase 4a — PR gate:     [ ]
Phase 4b — Review prompt: [ ]
Phase 4c — PR desc:     [ ]
```

Use `x` (not a check-mark emoji) when a phase completes.

---

## Phase -1 — Preflight — Opus, plan mode

Apply skill `pipeline-preflight`. The skill produces signals (working tree
state, base branch position, progress-doc drift). When any signal fires,
the orchestrator asks via `AskUserQuestion` and follows the same
Reconcile / Proceed / Abort semantics that `workflow.md` Phase 0 documents.

Do not proceed to Phase 0 until preflight emits `Pre-flight clean.` or
the user chooses Proceed anyway.

---

## Phase 0 — AC Intake — Opus, plan mode

### Get the story

- If the argument is a Jira key (e.g. `PROJ-123`): fetch it via Atlassian
  MCP. Use `ATLASSIAN_CLOUD_ID` from `CLAUDE.md`. Extract summary,
  description, AC items, story type, linked tickets.
- If the argument is a file path: read the file.
- If AC is pasted directly: parse it from the conversation.
- If both Jira key and pasted AC are present: Jira is canonical.

### Derive build targets

Read `CLAUDE.md` for `SCHEME`, `DESTINATION`, and the UI test target
(`UI_TEST_TARGET`). If any value is missing, halt and ask the user
before continuing. Do not invent defaults.

### Classify each AC item

For each item ask: can this be verified by driving the app UI, without
reading app internals or asserting on computed values?

- Observable screen state → `auto`
- Network response reflected in UI → `auto` (note the dependency)
- Business logic / formula correctness → `manual` (unit-test territory —
  exclude from this pipeline)
- OS / system UI (permission dialogs, IAP sheets, keyboard) → `partial`

Produce this table inline:

```
Normalised AC — [ticket/story key]

# | Original AC | Class | Notes
--|-------------|-------|------
1 | …           | auto  | …
2 | …           | partial | needs keyboard handling
3 | …           | manual | unit test instead
```

Gate: if `manual > auto + partial`, halt and explain why XCUITest is the
wrong tool for this story. Record the auto / partial / manual count in
`${PLANS_DIR}/uitest-plan-${SLUG}.md` regardless.

Update gate summary. Mark Phase 0 done.

---

## Phase 1 — Plan — Opus, plan mode

Think through the full test suite before writing any Swift. For each
`auto` and `partial` AC item, work out:

1. Test class — one `XCTestCase` subclass per screen or flow. Check
   `swift-uitest/references/page-objects.md`: reuse existing classes
   before creating new ones.
2. Test method name — `test_[condition]_[expectedOutcome]` format.
3. Pre-conditions — what state must the app be in at the start? Logged
   in? On a specific screen? A launch argument set?
4. Steps — the ordered sequence of UI interactions, named at the
   accessibility-identifier level. Write the identifier, not the label
   (e.g. `tap buttons[compose.publish]`, not `tap Publish`).
5. Assertions — the exact `XCTAssert*` calls that confirm the outcome.
6. Missing accessibility identifiers — identifiers this test requires
   that are absent from `accessibility-ids.md`. List them explicitly;
   you will add them to the app target in Phase 2.
7. Page Objects needed — new Page Object structs required. Name and list
   their properties only; implement them in Phase 2.

Output the plan as a written document (prose plus bullets, no Swift)
and save it to `${PLANS_DIR}/uitest-plan-${SLUG}.md`.

If any AC item cannot be planned without information you do not have
(unknown screen structure, no existing accessibility identifiers,
ambiguous navigation path), explore the codebase before continuing:

```bash
grep -rn 'accessibilityIdentifier\|accessibilityLabel' --include='*.swift' .
find . -name '*.swift' -path '*/Views/*' | sort
```

Do not invent identifiers. Flag gaps in the plan.

### Required output: "Unknowns to probe"

Every plan file MUST include an `## Unknowns to probe` section, even if
the value is `None.`. Free-form "Risks" prose at the bottom of the plan
is NOT a substitute — this section is a contract Phase 2 and Phase 3
both consume.

An Unknown is anything the plan cannot resolve from reading code alone:
- An accessibility identifier modifier applied in a way you haven't seen
  succeed before (e.g. on a `Toggle` inside a custom view inside a
  conditional inside a `Form Section`).
- A new XCUI element-type assumption (e.g. assuming a SwiftUI
  `DatePicker` surfaces as `app.datePickers["…"]` when none of the
  registered Page Objects has proven it).
- A query against a SwiftUI primitive that historically absorbs
  modifiers (segmented `Picker`, `Chart`, `Form Section`).
- A timing assumption (e.g. "the recompute lands within 300 ms" when the
  flow has multiple chained debounces).

Render the section as a table:

```
## Unknowns to probe

| # | Unknown | Probe (single minimal test or sim check) | If probe fails |
|---|---------|-------------------------------------------|----------------|
| 1 | <one-sentence statement of what is uncertain> | <name the smallest test method(s) that prove it, or the `xcrun simctl` / `xcrun xctrace` check> | <one-line orchestrator hypothesis to attach to Phase 3 when the probe fails> |
```

The "If probe fails" column is load-bearing: it is the orchestrator
hypothesis the Triage Gate hands to the debug skill's Fast Path so
Phase 3 does not re-discover what Phase 1 already predicted.

If a plan has zero genuine unknowns (every identifier is already in the
registry and proven on the same widget shape, every Page Object exists
and is exercised by green tests), the section reads exactly `None.` —
Phase 2 will then collapse its Probe Pass and proceed straight to the
Full Pass.

Update gate summary. Mark Phase 1 done.

---

## Phase 2 — Execute — Sonnet, normal mode

Phase 2 runs as a contract with up to TWO PASSES driven by the plan's
"Unknowns to probe" section. The Probe Pass exists to catch
plan-predicted failures cheaply (one test + one run) before the full
suite is written against an unproven assumption.

- If the plan's `## Unknowns to probe` section is `None.`, the Probe
  Pass collapses into the Full Pass — same prompt as the legacy
  one-pass form.
- Otherwise, dispatch the Probe Pass subagent first. Only on a clean
  Probe Pass do you dispatch the Full Pass.

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below.

> Apply skill `swift-uitest`. The plan below is the source of truth —
> implement exactly what it describes.
>
> [contents of ${PLANS_DIR}/uitest-plan-${SLUG}.md]
> SCHEME: [SCHEME]
> DESTINATION: [DESTINATION]
> UI_TEST_TARGET: [UI_TEST_TARGET]
>
> CRITICAL — READ THIS BEFORE WRITING A SINGLE LINE:
>
> You are writing XCUITests. You are NOT writing unit tests. You are
> NOT using Swift Testing. You are NOT writing `@Test` functions. You
> are NOT using `#expect`. `import Testing` does not exist in a UITest
> target.
>
> If you find yourself typing `import Testing` or `@Test`, stop. Wrong
> thing.
>
> Cap your wall-clock at 8 minutes. If you cannot reach a verifiable
> build + test result within that budget, stop and report what you
> tried and what remains unknown. Do not continue past 8 minutes — the
> orchestrator treats a budget exit as a Triage Gate signal and will
> escalate.
>
> ### Two-pass execution
>
> Read the plan's `## Unknowns to probe` section first. If it says
> `None.`, execute the Full Pass directly. Otherwise execute the Probe
> Pass first; only proceed to the Full Pass if every probe test ran
> green.
>
> #### PROBE PASS (only when Unknowns to probe is non-empty)
>
> 1. Add ONLY the accessibility identifiers needed for the probe tests
>    named in the plan's `## Unknowns to probe` section.
> 2. Update the Page Objects with ONLY the elements those probe tests
>    reference.
> 3. Write ONLY the probe tests named in that section. Typically that
>    is the simplest baseline test plus the smallest existence/visibility
>    test that exercises each Unknown row.
> 4. Build, then run ONLY the probe tests.
> 5. If every probe test passes, proceed to FULL PASS.
> 6. If any probe test fails, STOP. Report:
>    - the name(s) of the failing probe test(s),
>    - the matched `## Unknowns to probe` row(s),
>    - the verbatim failure output,
>    - the list of files created or modified so far.
>    Exit. Do not write the remaining tests. Do not attempt a fix —
>    the orchestrator will route through Phase 3.
>
> #### FULL PASS
>
> 1. Add every remaining accessibility identifier from the plan to the
>    app target.
>    - Add `.accessibilityIdentifier("…")` to the correct SwiftUI element.
>    - Use dot-namespaced lowercase: `screen.element[.variant]`.
>    - Update `swift-uitest/references/accessibility-ids.md` after each
>      addition.
> 2. Create or update Page Object structs as described in the plan.
>    - One struct per screen or flow, in the UI test target.
>    - Update `swift-uitest/references/page-objects.md`.
> 3. Write the remaining test methods in the correct `XCTestCase` class.
> 4. Ensure `setUpWithError()` follows this structure exactly:
>
>    ```swift
>    override func setUpWithError() throws {
>        continueAfterFailure = false
>        app = XCUIApplication()
>        // Only include if the app has a login flow:
>        // UITestCredentials.inject(into: app)
>        app.launchArguments += ["--uitesting"]
>        app.launch()
>    }
>    ```
> 5. Every `XCUIElement` interaction must be preceded by
>    `waitForExistence(timeout:)`. Never use `Thread.sleep` or `sleep()`.
>    Never use `firstMatch` without a wait.
> 6. Build the app target to confirm zero errors before running tests.
>    Prefer MCP Xcode tools when Xcode is open:
>
>    ```
>    ToolSearch("select:mcp__xcode__BuildProject,mcp__xcode__GetBuildLog")
>    ```
>
>    Fall back to `xcodebuildmcp-cli` (see that skill) or raw
>    `xcodebuild` when Xcode is not open.
> 7. Run the UI test target. Prefer MCP:
>
>    ```
>    ToolSearch("select:mcp__xcode__RunSomeTests")
>    ```
>
>    If credentials are required: read from environment, never hardcode.
>    Capture the full output.
>
> Report: which pass ran (Probe / Full / Probe+Full), files created or
> modified, build result, and per-test results. If the Probe Pass
> stopped, name the matched Unknown row(s).

### After running

- If all tests pass (or the Probe Pass collapsed because the plan had
  no Unknowns and the Full Pass ran clean): update gate summary, mark
  Phase 2 done, skip to Phase 4a (Phase 3 is N/A).
- If the Probe Pass stopped on a probe failure: do not proceed to the
  Full Pass. Go to Phase 3 with the matched Unknown row attached as
  the orchestrator hypothesis (Triage Gate condition B).
- If the Full Pass produced failures: do not proceed to Phase 4. Go to
  Phase 3.
- If the subagent exited the 8-minute budget without a verifiable
  result: go to Phase 3 directly; the orchestrator treats this as a
  signal that the failure likely matches a plan-predicted unknown or a
  same-line cluster.

**Crash recovery.** If the subagent returns no usable result, apply
skill `subagent-reliability`.

---

## Phase 3 — Debug — Triage Gate, then Sonnet escalating to Opus

Triggered only if Phase 2 produced failures or exited its wall-clock
budget without a verifiable result.

### Shared attempt log

At the start of Phase 3, create `${PLANS_DIR}/uitest-${SLUG}-attempt-log.md`
with a header:

```
# UI test debug attempt log — ${SLUG}

Phase 2 failure summary: <one paragraph>
Plan reference: ${PLANS_DIR}/uitest-plan-${SLUG}.md
Branch: <current branch>
```

Every Phase 3 subagent prompt (Triage Gate dispatches and skill-driven
attempts alike) MUST be prefixed with:

> Read `${PLANS_DIR}/uitest-${SLUG}-attempt-log.md` in full before
> doing anything else. After your run completes, append a
> `## Attempt N — <model> — <approach summary>` block with: the
> commands you ran (verbatim), the resulting test status, and any
> hypothesis you formed. Do not delete or rewrite earlier blocks.

This is the only piece of Phase 3 state that survives subagent
boundaries — keep it accurate.

### Triage Gate (run BEFORE applying the debug skill)

Inspect the Phase 2 failure set before dispatching anything:

**A. Same-line cluster** — if N >= 2 failing tests all fail at the
   SAME source line / assertion message (string-equality on the
   `XCTAssert*` message is the simplest matcher; the `:line:` location
   in the xcresult is the canonical one), treat them as ONE root
   cause. Dispatch the debug skill's **Opus diagnosis phase directly**,
   supplying:
   - the verbatim failure text,
   - the list of N test names that share it,
   - a one-line orchestrator hypothesis if you have one (otherwise
     write `unknown — same-line cluster diagnosis required`).

   After Opus returns the diagnosis memo, run the skill's final Sonnet
   fix attempt (Phase 4 of the skill) against that diagnosis. Skip the
   two Sonnet pre-attempts entirely.

**B. Plan-predicted failure** — if the failure message or assertion
   matches any row from the Phase 1 plan's `## Unknowns to probe`
   section, dispatch the debug skill's **Opus diagnosis phase
   directly**, supplying:
   - the verbatim failure text,
   - the matched Unknown row verbatim, labelled
     `Orchestrator hypothesis: <row>`.

   This is the most common Fast Path under the probe-pass contract:
   the Probe Pass surfaced a probe failure tied to a specific Unknown
   row, and that row already names the predicted root cause. Skip the
   two Sonnet pre-attempts entirely.

**C. Otherwise** (diverse failures, no plan match, no same-line
   cluster) — enter the skill's Standard Path ladder as today:
   Sonnet attempt 1 → Sonnet attempt 2 → Opus diagnosis → Sonnet final
   fix.

Conditions A and B are mutually compatible — when both fire, prefer B
(more specific hypothesis) and mention the cluster in the prompt.

### Apply skill

Apply skill `swift-uitest-debug`. The skill exposes two paths now:

- **Fast Path** — entered when the Triage Gate matched A or B above.
  The skill's `Inputs Required` accepts `Orchestrator hypothesis`; when
  present, the skill skips its own Sonnet attempts 1 and 2 and goes
  straight to the Opus diagnosis phase, then the final Sonnet fix.
- **Standard Path** — entered when the Triage Gate matched C. The
  skill runs its full two-Sonnet ladder before Opus diagnosis.

Track the attempt log via the shared file above. Do not exceed the
escalation ceiling. If Opus diagnosis plus the final Sonnet fix still
fails, the test is **declared unautomatable** — surface this to the
user, replace the failing test with a manual test plan step in the PR
description (Phase 4c), and continue. Do not weaken the test or remove
assertions.

When all remaining tests pass, update gate summary, mark Phase 3 done
(or skip if no failures occurred), and proceed to Phase 4a.

---

## Phase 4a — PR Gate — Opus, plan mode

Apply skill `swift-pr-gate`. The skill runs build / tests / scope /
branch / PR description / Jira gates and produces the gate summary.

For this UI-test PR, the inputs are:

- **Ticket**: key from Phase 0.
- **Description**: "Adding XCUITest coverage for [story summary]".
- **Files in scope**: UI test target files written or modified in Phase 2
  plus any app-target files modified for accessibility identifiers.
- **Touches persistence**: No (UI test targets do not own persistence).
- **Bug fix**: Yes if the story type is a bug; No otherwise.

If the gate returns BLOCKED, surface the blocking items inline and do
not continue to 4b until they are resolved.

If the gate returns READY TO RAISE PR, update gate summary and continue.

---

## Phase 4b — Review prompt — Opus, plan mode

Apply skill `prompt:review`. Generate the review prompt with:

- PR purpose: "Adding XCUITest coverage for [story summary]".
- Changed files: UI test target files plus app-side identifier files.
- Ticket: key from Phase 0.
- Constraints: Must not break existing UI tests. Must not use Swift
  Testing.

Save the generated prompt as `${PLANS_DIR}/pr-review-${SLUG}.md` and
report the path to the user.

Update gate summary. Mark Phase 4b done.

---

## Phase 4c — PR description — Opus, plan mode

`swift-pr-gate` Gate 5 already produced a PR description from the
template (Summary / Root Cause / Solution / Changes / Tests / Test Plan).
This phase supplements it with two UI-test-specific sections.

Append the following to the gate's PR description:

```markdown
## AC coverage

| #   | AC item            | Test method            | Status |
| --- | ------------------ | ---------------------- | ------ |
| 1   | [original AC text] | test_condition_outcome | auto   |
| 2   | [original AC text] | (manual — see below)   | manual |

## Manual test plan (where automation declined)

1. [If login required]: Set `UI_TEST_USERNAME` and `UI_TEST_PASSWORD` in
   the scheme (Edit Scheme → Test → Environment Variables).
2. Run scheme [UI_TEST_TARGET] on the project's declared destination.
3. All new tests must pass. No existing UI tests may regress.
4. For each `manual` row above, describe the manual step a reviewer
   would take and the expected observable outcome.
```

Save the final PR description (gate body plus this addendum) to
`${PLANS_DIR}/pr-description-${SLUG}.md`. The PR creation step in
`swift-pr-gate` uses this file via `--body-file`.

Update gate summary. Mark Phase 4c done.

Print the final completed gate summary.

---

## Halt Conditions

The orchestrator must halt and report (never silently continue) if:

- Phase 0 classification has `manual > auto + partial`.
- Phase 2 build fails and Phase 3's escalation ladder exhausts without
  a green test run.
- Phase 4a `swift-pr-gate` returns BLOCKED that can't be resolved
  inline.

On halt: write a summary to `${PLANS_DIR}/uitest-${SLUG}-blocked.md`.

---

## Model intent

These are hints for how to weight reasoning at each phase.

| Phase | Reasoning weight |
| --- | --- |
| 0 — AC classification | Careful — wrong classification wastes the whole run |
| 1 — Plan | Deep — this is where coverage gaps and identifier gaps are caught |
| 2 — Execute | Mechanical — follow the plan exactly, no improvisation |
| 3 — Debug | Escalating — triage first, fix precisely, escalate on schedule |
| 4 — PR artefacts | Thorough but fast — reading plus pattern matching |

Spend the most tokens on Phase 1. If the plan is right, Phase 2 is
straightforward. If the plan is wrong, Phase 2 produces tests that pass
but cover nothing useful.

---

**Model & mode:** Opus, plan mode for orchestration. Sonnet subagents
handle Phase 2 (execute) and Phase 3 (debug, escalating to Opus
diagnosis when capped). Opus runs every branching decision.
