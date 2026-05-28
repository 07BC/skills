---
name: swift-uitest-debug
description: >
  Diagnoses and fixes failing XCUITest UI tests using a structured Sonnet-to-Opus
  escalation. Two paths: a Standard Path runs two Sonnet attempts before Opus
  diagnosis; a Fast Path skips straight to Opus diagnosis when an orchestrator
  hypothesis is supplied or when N >= 2 failing tests share an assertion line.
  Use when a UI test is failing after being written or after a code change, when
  xcodebuild reports XCUITest failures, when a test passes locally but fails on
  CI, or when the swift-uitest-pipeline debug phase is invoked. Triggers on:
  "this test is failing", "fix this UI test", "debug uitest", "uitest is broken",
  "XCUITest failure", or any failing xcresult output shared in chat. Always use
  this skill — do not attempt to diagnose UI test failures ad hoc.
---

# Swift UI Test Debug Skill

You diagnose and fix failing XCUITest tests. You operate under a strict
escalation budget: two Sonnet attempts before Opus takes over diagnosis.
Never exceed this budget — escalating costs less than spinning in place.

A **Fast Path** short-circuits the two Sonnet attempts when the caller
already has signal (an orchestrator hypothesis) or when the failure
pattern is a same-line cluster across multiple tests. See `Phase 0` and
`Fast Path` below.

---

## Inputs Required

Before starting, confirm you have all of the following. If any are missing,
ask for them before producing a prompt.

| Input | Source |
|---|---|
| Failure output | xcodebuild log, xcresult, or paste from Xcode |
| Failing test name(s) | Explicit — e.g. `LoginUITests.test_validLogin_showsHomeScreen` |
| What changed | "nothing" is a valid answer; so is a diff or commit SHA |
| Attempt count | How many fix attempts have already been made (0, 1, or 2) |
| Orchestrator hypothesis (optional) | Free text from a calling pipeline orchestrator that already has signal — e.g. a matched "Unknowns to probe" row from a Phase 1 plan, or a same-line cluster summary. When populated, triggers the **Fast Path** in Phase 0. Absent does NOT automatically mean Standard Path — Phase 0's Same-Line Cluster heuristic can also trigger Fast Path independently. |

---

## Phase 0 — Triage (always first, always Haiku)

Before writing any prompt, classify the failure. Read the failure output and
assign it to one of these categories:

| Category | Symptoms | Likely cause |
|---|---|---|
| **Element not found** | `XCTAssertTrue failed — waitForExistence returned false` | Missing `accessibilityIdentifier`, wrong query type, element behind scroll |
| **Timing** | Intermittent pass/fail, `XCTNSPredicateExpectation` timeout | Timeout too short, network dependency, animation not settled |
| **Navigation** | Test navigates to wrong screen, unexpected alert, modal blocking | Launch state not reset, leftover state from previous test |
| **Credential / env** | `precondition failed`, empty username, auth failure mid-test | `UI_TEST_USERNAME` or `UI_TEST_PASSWORD` not set in scheme / CI |
| **Compile error** | Build fails before tests run | Wrong import, `import Testing` used instead of `import XCTest` |
| **Flake** | Passes on retry without code change | Race condition, timing, simulator instability |

State the category at the top of every debug session. If the category is
**Credential / env** or **Compile error**, fix it directly — these are not
test logic failures and do not consume an attempt.

### Same-Line Cluster heuristic

Before assigning a category, scan the failure set. If N >= 2 failing tests
fail at the SAME source line / assertion message (string-equality on the
`XCTAssert*` message is the simplest matcher; the `file:line` location in
the xcresult is the canonical one), treat them as ONE root cause for the
rest of this session.

Record the cluster on the line below the category at the top of the
debug session, e.g.:

```
Category: Element not found
Same-line cluster: 4 tests share assertion `lumpSumAmountField.waitForExistence(timeout: 3) — Lump sum amount field must appear after enabling the toggle` at ScenarioLumpSumUITests.swift:67
```

A same-line cluster triggers the **Fast Path** below — do not diagnose
N tests as N independent failures.

---

## Fast Path — skip the two Sonnet attempts

Enter the Fast Path when EITHER of the following is true after Phase 0:

- An **Orchestrator hypothesis** was supplied in the Inputs Required
  block (a calling pipeline has matched a plan-predicted unknown), OR
- The **Same-Line Cluster heuristic** fired (N >= 2 tests share an
  assertion).

Fast Path is the entire ladder under those conditions:

1. Skip Phase 1 (Sonnet attempt 1) and Phase 2 (Sonnet attempt 2)
   entirely. Do not produce their prompts.
2. Go directly to **Phase 3 — Opus Diagnosis**. Use the amended prompt
   structure (see Phase 3 below): the `Attempt 1` / `Attempt 2`
   sections are replaced by `Orchestrator hypothesis` and/or
   `Same-line cluster` sections.
3. After Opus returns the diagnosis memo, run **Phase 4 — Sonnet Fix
   from Opus Diagnosis** as normal.

Total Fast Path ladder is two prompts (Opus → Sonnet), not four
(Sonnet → Sonnet → Opus → Sonnet).

If neither Fast Path condition is met, proceed to Phase 1 — Standard
Path — as today.

When both conditions fire (orchestrator hypothesis AND same-line
cluster), prefer the hypothesis — it is the more specific signal —
and include the cluster summary as supporting context in the same
Phase 3 prompt.

---

## Phase 1 — Attempt 1 (Sonnet, normal mode) — Standard Path only

Produce a Claude Code prompt using this structure:

```
CRITICAL — READ THIS BEFORE ANYTHING ELSE:

You are debugging an XCUITest. You are NOT rewriting the test from scratch.
You are NOT switching to Swift Testing. You are NOT adding new test cases.
Your only job is to make the failing test pass without breaking others.

## Skill
Read ~/.claude/skills/swift-uitest/SKILL.md before doing anything else.

## Failure
[Paste the full failure output — do not truncate]

## Failing test
[Full test name: ClassName.methodName]

## Failure category
[One of: Element not found | Timing | Navigation | Credential/env | Compile error | Flake]

## Investigation steps
1. Read the failing test in full.
2. Run the failing test once to reproduce: [xcodebuild command]
3. Based on the failure category:

   Element not found:
   - Search the app codebase for the accessibility identifier used in the test.
   - If missing from the app, add it. Do not rename it in the test.
   - If present, check the element type: textField vs secureTextField vs button.

   Timing:
   - Identify every waitForExistence and XCTNSPredicateExpectation in the test.
   - Increase the timeout on the one closest to the failure point.
   - Check whether an animation or network call precedes the wait.

   Navigation:
   - Add a screenshot attachment immediately before the failing assertion.
   - Confirm the app is on the expected screen at that point.
   - If not, trace back to the previous navigation step.

   Flake:
   - Add a predicate wait for `isHittable` before the failing interaction.
   - Never add Thread.sleep. Never use sleep().

4. Make the minimal change that addresses the root cause.
5. Run the test again to confirm it passes.

## Constraints
- Touch the MINIMUM number of files
- Do NOT rewrite the test
- Do NOT introduce new test cases
- Do NOT change test names or method signatures
- Do NOT use Thread.sleep or sleep()
- Do NOT add print() statements

## Verification
- [xcodebuild command] must exit 0
- No other tests in the target must fail

**Model & mode:** Sonnet, normal mode — targeted fix, category identified
```

After producing this prompt, record: **Attempt 1 dispatched.**

---

## Phase 2 — Attempt 2 (Sonnet, normal mode) — Standard Path only

If attempt 1 fails, produce a second Sonnet prompt. This prompt must differ
from the first in its investigation angle — do not repeat the same approach.

```
## Skill
Read ~/.claude/skills/swift-uitest/SKILL.md before doing anything else.

## Context
Attempt 1 failed. The original failure was:
[original failure]

After attempt 1, the failure is now:
[new failure output — required, do not proceed without this]

## Second angle investigation
[Choose the angle NOT taken in attempt 1:]

If attempt 1 looked at the test → now look at the app:
  - Does the screen being tested match what the test expects?
  - Is there a state issue (e.g. already logged in, wrong initial route)?
  - Does the launch argument `--uitesting` change app behaviour in a relevant way?

If attempt 1 looked at the app → now look at the test setup:
  - Is setUpWithError() resetting all state before launch?
  - Is there a residual XCUIApplication from a prior test?
  - Is continueAfterFailure = false set?

## Constraints
[Same as attempt 1]

## Verification
[Same as attempt 1]

**Model & mode:** Sonnet, normal mode — second angle, same constraint envelope
```

After producing this prompt, record: **Attempt 2 dispatched. Escalation ceiling reached.**

---

## Phase 3 — Opus Diagnosis

Entry conditions:

- **Standard Path**: after Phase 1 and Phase 2 both failed. The
  `Attempt 1` and `Attempt 2` sections of the prompt are populated; the
  `Orchestrator hypothesis` and `Same-line cluster` sections are
  omitted.
- **Fast Path** (from Phase 0): the `Orchestrator hypothesis` and/or
  `Same-line cluster` sections are populated; the `Attempt 1` and
  `Attempt 2` sections are omitted.

Do not produce another fix prompt. Produce a diagnosis-only prompt for
Opus. Include only the sections that apply to the entry path.

```
## Skill
Read ~/.claude/skills/swift-uitest/SKILL.md before doing anything else.

## Situation
[Standard Path:] Two Sonnet attempts have failed to fix this XCUITest.
[Fast Path:] A calling orchestrator (or the Same-Line Cluster heuristic)
identified this failure as a known unknown; the Standard Path Sonnet
attempts were skipped by design.

Your job is DIAGNOSIS ONLY. Do not write code. Do not produce a fix.
Produce a written root cause analysis only.

## Original failure
[failure output from attempt 0]

## Orchestrator hypothesis  (Fast Path only — omit on Standard Path)
[verbatim text from the calling pipeline — e.g. an "Unknowns to probe"
row pasted from the Phase 1 plan]

## Same-line cluster  (Fast Path only — omit on Standard Path)
[N tests share assertion line / message — list of test names + the
verbatim assertion text + `file:line`]

## Attempt 1  (Standard Path only — omit on Fast Path)
Approach taken: [summary]
Result: [failure output after attempt 1]

## Attempt 2  (Standard Path only — omit on Fast Path)
Approach taken: [summary]
Result: [failure output after attempt 2]

## Diagnosis task
Answer each of the following in writing:

1. What is the precise line and condition that is failing?
2. Standard Path: Why did the Sonnet attempts not fix it? (Identify the
   gap in their reasoning.)
   Fast Path: Standard Path skipped — write "Standard Path skipped; the
   Orchestrator hypothesis / Same-line cluster above is the starting
   point of the diagnosis." and proceed to question 3.
3. What is the true root cause? (Name the iOS API behaviour, simulator
   condition, or architectural issue — not the symptom.)
4. What is the minimal correct fix? Describe it in plain English. Do
   not write code.
5. Are there any preconditions that must be true before the fix can
   work? (e.g. accessibility identifier must be added to app, scheme
   must be reconfigured)
6. Is this test testing something that is genuinely automatable via
   XCUITest? If not, explain why and recommend removal or replacement.

## Output format
Plain prose. No code. No bullet lists. Write it as a diagnosis memo.

**Model & mode:** Opus, plan mode — root cause reasoning
```

---

## Phase 4 — Sonnet Fix from Opus Diagnosis

After Opus returns its diagnosis memo, produce a final Sonnet fix prompt:

```
## Skill
Read ~/.claude/skills/swift-uitest/SKILL.md before doing anything else.

## Diagnosis
[Paste Opus diagnosis memo in full]

## Fix task
Implement exactly what the diagnosis describes. Do not deviate from it.
If the diagnosis says the fix requires a precondition (e.g. an accessibility
identifier must be added to the app first), do that first before touching the test.

## Constraints
- Implement the diagnosis. Do not improvise.
- Touch only the files named in the diagnosis.
- Do NOT rewrite the test beyond what the diagnosis prescribes.

## Verification
- [xcodebuild command] must exit 0
- No other tests in the target must fail

**Model & mode:** Sonnet, normal mode — mechanical execution of Opus diagnosis
```

---

## Escalation ceiling — declare unautomatable

The ladder caps at one of two shapes depending on entry path:

**Standard Path (no Fast Path conditions met):**

- Attempt 1: Sonnet, targeted fix
- Attempt 2: Sonnet, second angle
- Opus diagnosis: prose memo, no code
- Final Sonnet fix: mechanical execution of the diagnosis

Four attempts total.

**Fast Path (Orchestrator hypothesis OR Same-Line Cluster heuristic):**

- Opus diagnosis: prose memo, no code (informed by the hypothesis /
  cluster summary)
- Final Sonnet fix: mechanical execution of the diagnosis

Two attempts total.

The test is **declared unautomatable** when the **final Sonnet fix
attempt** fails — irrespective of which path led to it. Do not
produce a further attempt. Do not weaken the assertion to make the
test pass. Do not switch to a less precise predicate.

The declaration trigger is one of:

- The diagnosis itself concluded the test is not genuinely automatable
  (Phase 3 answer to question 6 is "no").
- The diagnosis prescribed a fix and the final Sonnet attempt
  implemented it correctly but the test still fails — the diagnosis
  was wrong about the root cause, but the ladder has exhausted.

In either case, produce the recommendation memo below and surface it to
the calling pipeline. The pipeline replaces the test with a manual step
in the PR description and (when in Jira mode) files a story for the
underlying testability gap.

---

## Non-automatable test decision

When Phase 3 diagnosis concludes the test is not genuinely automatable,
or Phase 4 fails to make the diagnosis stick, produce this recommendation
memo:

```
## UI Test Removal Recommendation

**Test:** [ClassName.methodName]
**Reason:** [From Opus diagnosis — why this cannot be reliably automated]
**Alternatives:**
- Unit test covering [logic that can be extracted]
- Manual test plan step: [exact steps for QA]
**Action:** Remove test, add to manual regression checklist, file story for
  any underlying testability gap (missing accessibility identifier, missing
  launch argument support, etc.)
```

---

## Attempt Tracking

Maintain an attempt log across the debug session. After each attempt
completes, update this block before producing the next prompt. The
Standard Path block has four rows; the Fast Path block has two.

**Standard Path:**

```
## Debug session log — [test name] (Standard Path)

Attempt 0 (baseline):    [failure category] — [one-line failure description]
Attempt 1 (Sonnet):      [approach] — [PASSED / FAILED: one-line new failure]
Attempt 2 (Sonnet):      [approach] — [PASSED / FAILED: one-line new failure]
Opus diagnosis:          [dispatched / pending]
Final Sonnet fix:        [PASSED / FAILED / NOT YET]
```

**Fast Path:**

```
## Debug session log — [test name] (Fast Path)

Attempt 0 (baseline):    [failure category] — [one-line failure description]
Fast Path trigger:       [Orchestrator hypothesis | Same-line cluster (N tests)]
Opus diagnosis:          [dispatched / pending]
Final Sonnet fix:        [PASSED / FAILED / NOT YET]
```

Phase 3 may be entered directly via the Fast Path when an Orchestrator
hypothesis was supplied OR the Same-Line Cluster heuristic fired in
Phase 0. Otherwise (Standard Path), two failed Sonnet attempts must
precede Phase 3.

---

## What this skill does NOT do

- It does not rewrite tests from scratch (use `swift-uitest` for that).
- It does not change test architecture or add new test coverage.
- It does not file Jira tickets (use the Atlassian MCP for that).
- It does not run tests itself (use `xcodebuildmcp` or `xcodebuild`).
