---
name: swift-uitest-debug
description: >
  Diagnoses and fixes failing XCUITest UI tests using a structured two-attempt
  Sonnet escalation to Opus. Use when a UI test is failing after being written
  or after a code change, when xcodebuild reports XCUITest failures, when a test
  passes locally but fails on CI, or when the swift-uitest-pipeline debug phase
  is invoked. Triggers on: "this test is failing", "fix this UI test", "debug
  uitest", "uitest is broken", "XCUITest failure", or any failing xcresult output
  shared in chat. Always use this skill — do not attempt to diagnose UI test
  failures ad hoc.
---

# Swift UI Test Debug Skill

You diagnose and fix failing XCUITest tests. You operate under a strict
escalation budget: two Sonnet attempts before Opus takes over diagnosis.
Never exceed this budget — escalating costs less than spinning in place.

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

---

## Phase 1 — Attempt 1 (Sonnet, normal mode)

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

## Phase 2 — Attempt 2 (Sonnet, normal mode)

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

## Phase 3 — Opus Diagnosis (if attempt 2 fails)

Do not produce another fix prompt. Produce a diagnosis-only prompt for Opus.

```
## Skill
Read ~/.claude/skills/swift-uitest/SKILL.md before doing anything else.

## Situation
Two Sonnet attempts have failed to fix this XCUITest. Your job is DIAGNOSIS
ONLY. Do not write code. Do not produce a fix. Produce a written root cause
analysis only.

## Original failure
[failure output from attempt 0]

## Attempt 1
Approach taken: [summary]
Result: [failure output after attempt 1]

## Attempt 2
Approach taken: [summary]
Result: [failure output after attempt 2]

## Diagnosis task
Answer each of the following in writing:

1. What is the precise line and condition that is failing?
2. Why did the Sonnet attempts not fix it? (Identify the gap in their reasoning.)
3. What is the true root cause? (Name the iOS API behaviour, simulator condition,
   or architectural issue — not the symptom.)
4. What is the minimal correct fix? Describe it in plain English. Do not write code.
5. Are there any preconditions that must be true before the fix can work?
   (e.g. accessibility identifier must be added to app, scheme must be reconfigured)
6. Is this test testing something that is genuinely automatable via XCUITest?
   If not, explain why and recommend removal or replacement.

## Output format
Plain prose. No code. No bullet lists. Write it as a diagnosis memo.

**Model & mode:** Opus, plan mode — root cause reasoning after two failed attempts
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

The ladder caps at:

- Attempt 1: Sonnet, targeted fix
- Attempt 2: Sonnet, second angle
- Opus diagnosis: prose memo, no code
- Attempt 3: Sonnet, mechanical execution of the diagnosis

If **Attempt 3 still fails**, the test is **declared unautomatable**.
Do not produce a fifth attempt. Do not weaken the assertion to make the
test pass. Do not switch to a less precise predicate.

The declaration trigger is one of:

- The diagnosis itself concluded the test is not genuinely automatable
  (Phase 3 answer to question 6 is "no").
- The diagnosis prescribed a fix and Attempt 3 implemented it correctly
  but the test still fails — the diagnosis was wrong about the root
  cause, but the ladder has exhausted.

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

Maintain an attempt log across the debug session. After each attempt completes,
update this block before producing the next prompt:

```
## Debug session log — [test name]

Attempt 0 (baseline): [failure category] — [one-line failure description]
Attempt 1 (Sonnet):   [approach] — [PASSED / FAILED: one-line new failure]
Attempt 2 (Sonnet):   [approach] — [PASSED / FAILED: one-line new failure]
Opus diagnosis:       [dispatched / pending]
Attempt 3 (Sonnet):   [PASSED / FAILED / NOT YET]
```

Never produce a Phase 3 (Opus diagnosis) prompt without a completed log
showing two failed Sonnet attempts.

---

## What this skill does NOT do

- It does not rewrite tests from scratch (use `swift-uitest` for that).
- It does not change test architecture or add new test coverage.
- It does not file Jira tickets (use the Atlassian MCP for that).
- It does not run tests itself (use `xcodebuildmcp` or `xcodebuild`).
