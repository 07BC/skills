---
name: swift-tvos
description: >
  Diagnoses tvOS navigation and focus engine bugs in SwiftUI codebases. Use
  this skill whenever the user says "focus is broken", "focus is stuck",
  "focus jumps to the wrong cell", "wrong screen pushes", "remote doesn't
  work", "the back button doesn't go back", "navigation is broken on tvOS",
  "focus engine", "this screen on Apple TV", or any variant
  involving Apple TV navigation. Also triggers on project-specific phrasing
  like "KickTV bug" — substitute your own app name. Also trigger when the user asks Claude
  Code to "look into", "investigate", "figure out why", or "debug" anything
  on tvOS, regardless of how the symptom is phrased. Always use this skill —
  do not attempt tvOS navigation diagnosis ad hoc. tvOS focus engine bugs
  are the #1 case where Claude pattern-matches symptoms to fixes without a
  grounded causal model, shuffles code around, and claims the bug is
  resolved when nothing has changed. This skill enforces the discipline
  that prevents that failure mode.
---

# Swift tvOS Diagnostic Skill

You diagnose and fix tvOS navigation and focus engine bugs in SwiftUI
codebases. The tvOS focus engine is poorly represented in training data and
its symptoms are ambiguous — "navigation is broken" can mean five different
bugs with five different root causes. Without diagnostic discipline, you
will pattern-match the symptom, invent a plausible fix, and shuffle code
without changing behaviour. This skill exists to stop that.

**Reference material** (read before forming hypotheses):

- [`references/focus-subsystems.md`](references/focus-subsystems.md) —
  search-cone model, focus categories, subsystem checklist
- [`references/diagnosis-template.md`](references/diagnosis-template.md) —
  the Phase 1 output document structure
- [`references/gotchas.md`](references/gotchas.md) —
  platform traps and counterintuitive correct behaviours
- [`references/tooling.md`](references/tooling.md) —
  `_printChanges`, LLDB commands, Quick Look, XCUIRemote

---

## Core Constraints (Non-Negotiable)

1. **Diagnosis before fix.** Phase 1 is forbidden from proposing or writing
   any code changes. The only deliverable is a written diagnosis document
   with falsifiable hypotheses. Patches are written in Phase 2 *after* the
   user has confirmed the root cause.
2. **Read real files, quote real code.** Before forming any hypothesis,
   read the files listed by the user (or the obvious candidates) and quote
   the actual code with line numbers. No reasoning from priors about how
   tvOS "usually" works.
3. **No invented symbols.** Never reference a type, property, or method
   you have not seen in the actual codebase. (Historical failure: assuming
   `ModelDecoder.kickDateFormatter` exists when it doesn't.)
4. **Name the subsystem before guessing.** Every hypothesis must name
   which focus subsystem is involved — `@FocusState`, `.focusable()`,
   `.focusSection()`, `.prefersDefaultFocus(in:)`, `FocusedValue`,
   `NavigationStack` path binding, or `XCUIRemote` event delivery. If you
   can't name the subsystem, you don't have a hypothesis — you have a guess.
5. **Falsifiable predictions only.** "I think X is the bug" is not enough.
   "If X is the bug, then Y should be observable when we do Z" is the
   minimum standard. Predictions must be cheaper to test than the fix
   would be to write.
6. **One precise symptom.** "Navigation is broken" is not a bug report.
   Pin down: which screen, which remote button, what was expected to happen,
   what actually happened, whether it's deterministic.
7. **User hypotheses are inputs, not ground truth.** If the user proposes a
   cause, treat it as Hypothesis A — read the code and either confirm it
   with quoted evidence or falsify it with quoted counter-evidence.
   Falsifying the user's hypothesis is *good*; it's the whole point of
   diagnosis. Never bend the diagnosis to fit the hypothesis the user came
   in with.
8. **Reconcile new evidence with the original symptom.** When Phase 1 is
   reopened, any new hypothesis must be consistent with the *original*
   user-reported symptom — not just with the latest log capture. If the
   new hypothesis predicts behaviour the user already said they don't see,
   the hypothesis is wrong. Direct user observation outranks log inference.
   Always restate the original symptom alongside the new evidence before
   drawing a conclusion.

---

## Step 0 — Verify the bug's framing (before reading any code)

"X is broken" implies X used to work. Before any other step, confirm the
working baseline exists. Failure to do this leads to diagnosing a phantom
regression — investigating why something stopped working that was never
working in the first place. This is the single most expensive failure mode
of this skill.

Ask the user explicitly, before doing anything else:

1. **"Is the working state you're describing something you have seen
   running on the simulator or device, or is it the intended/design
   state?"** If the user only has design mocks or Xcode previews, this is
   a feature implementation, not a bug. Stop the diagnostic workflow.

2. **"When did it last work in the simulator?"** Acceptable: "this commit
   SHA," "before this PR," "on tvOS 25." Unacceptable: "it should work,"
   "the preview shows it working." If the answer is unacceptable, treat as
   feature implementation.

3. **"Is the screenshot/state you're showing me the current behaviour,
   the previous (working) behaviour, or the desired behaviour?"** Never
   assume two screenshots are "before" and "after."

If any answer reveals the working state has never existed in the running
app, **abandon the diagnostic structure immediately**. Do not continue to
Step 1. The remaining work is:

- Confirm the desired behaviour with the user
- Identify the technical constraint
- Propose 2–3 implementation strategies
- Let the user pick one
- Skip to Phase 2 with a focused implementation prompt

The Xcode preview rendering "correctly" is not evidence of a working
baseline. A working preview only proves "the code compiles and renders
something when isolated."

---

## Step 0.5 — Reject Vague Bug Reports

Before doing anything else, confirm the symptom is precise. Acceptable
bug reports answer all of the following:

- **Screen:** Which view file? Which screen in the user-visible flow?
- **Input:** Which remote button? (Up / Down / Left / Right / Select /
  Menu / Play-Pause / Long-press Select)
- **Expected:** What was supposed to happen?
- **Actual:** What actually happened? Be specific:
  - Focus is *invisible* (no halo on any element)
  - Focus is *stuck* (halo doesn't move when you press a direction)
  - Focus *jumps to wrong element* (halo moves, but not where expected)
  - Focus *escapes the screen* (lands on tab bar or sibling section)
  - The wrong view *pushes onto the stack*
  - The view *pushes correctly* but focus inside it is wrong
  - The back button *doesn't pop*
- **Determinism:** Always? After a specific sequence? Only when navigating
  in from a particular parent screen?
- **Recently changed:** Did this work before? What was the last commit
  that touched this screen?

If any of these are missing, ask the user before reading any files.

---

## Step 1 — Map the Suspect Surface

Once the symptom is precise, identify the files that could plausibly be
involved. Read them. Do not skip this step in favour of "I think I know
where the bug is."

```bash
# The view itself and its parent
find . -name "*.swift" | xargs grep -ln "<ScreenName>"

# Any custom focus modifiers or focus state
grep -rn "@FocusState\|\.focusable\|\.focusSection\|\.prefersDefaultFocus\|FocusedValue" \
  --include="*.swift" . | grep -v ".build"

# NavigationStack and path bindings touching this screen
grep -rn "NavigationStack\|navigationDestination\|NavigationPath" \
  --include="*.swift" . | grep -v ".build"

# Custom button styles (CardButtonStyle, etc — they often own focus visuals)
grep -rn "ButtonStyle\|isFocused\|FocusState" \
  --include="*.swift" . | grep -v ".build"

# Any onMoveCommand / onPlayPauseCommand / onExitCommand handlers
grep -rn "onMoveCommand\|onPlayPauseCommand\|onExitCommand\|onLongPressGesture" \
  --include="*.swift" . | grep -v ".build"
```

Read every file you find. Quote the relevant sections in your diagnosis
document with file path and line numbers.

---

## Step 2 — Form Hypotheses

Read [`references/focus-subsystems.md`](references/focus-subsystems.md)
for the full checklist of focus categories and the search-cone model.

For every hypothesis you form:
- Name the subsystem (from the checklist)
- State the mechanism
- Write a falsifiable prediction
- Identify the cheapest experiment

Minimum three hypotheses. Resist convergence on one too early.

---

## Step 3 — Write the Diagnosis Document

Use the template in
[`references/diagnosis-template.md`](references/diagnosis-template.md).

Do not write code in this phase. The deliverable is the diagnosis
document only.

---

## Step 4 — Wait for User Confirmation

End Phase 1 here. Do not write code. Do not propose a fix. The user must:

1. Read the diagnosis.
2. Either run the recommended experiment, or push back on the hypotheses.
3. Explicitly confirm the root cause before Phase 2 begins.

This separation is the entire point of the skill. Do not collapse it.

---

## Step 5 — Phase 2: Implement the Confirmed Fix (separate session)

Phase 2 runs in a **new Claude Code session** with a new prompt. The
prompt must:

- State the confirmed root cause (one sentence).
- Reference the diagnosis document path.
- List the specific files that will change.
- Forbid scope creep ("do not refactor surrounding code").
- Require a verification step.

Verification on tvOS means one of:

- A new XCUITest that reproduces the bug and now passes (see the
  `swift-uitest` skill).
- A Swift Testing unit test on the underlying state if the bug is in a
  service or actor rather than the view.
- A reproducible manual sequence in the PR description: "Press Down on
  the Categories shelf → focus moves to the first Live tile" — with
  simulator screenshots.

If the fix can't be verified by any of these, the fix is not done.

---

## Step 6 — Phase 3: Review (separate session)

A third session reviews the diff against:

- The original diagnosis document — did the fix address the confirmed
  root cause, or did it drift?
- Project conventions — `Console` over `print()` (or your project's logging approach), one type per file,
  named constants, `nonisolated init(from:)` on models, private actor
  fetchers, actors stay actors.
- Swift 6 concurrency — no new `nonisolated(unsafe)`, no new
  `@unchecked Sendable`, actor isolation preserved.
- No invented symbols — every type/property/method referenced exists.
- Test coverage — the verification step from Phase 2 is present.

The reviewer should produce a written review, not a patch.

---

## Model & Mode Recommendations

| Phase | Model | Mode | Reason |
|---|---|---|---|
| 1 — Diagnose | Opus | Plan mode | Reasoning-heavy. Must not write code. |
| 2 — Execute | Sonnet | Normal | Mechanical patch against a confirmed root cause. |
| 3 — Review | Opus | Plan mode | Reasoning-heavy. Must not write code. |

If the bug involves UI test diagnosis (`.xcresult`, timing, accessibility
tree ambiguity), use **Opus for all three phases**. Sonnet is unreliable
here.

Always run Phase 1, 2, and 3 as **separate sessions** with **separate
prompts**. Never collapse them. The discipline is the value.

---

## Post-Diagnosis Checklist

Before declaring a tvOS navigation bug fixed, verify:

- [ ] Step 0 confirmed the bug is a regression, not a feature gap or
      design aspiration.
- [ ] Phase 1 produced a written diagnosis document with ≥3 hypotheses.
- [ ] If the user proposed a hypothesis, the diagnosis explicitly
      confirmed or falsified it with quoted code.
- [ ] At least one recommended experiment splits the hypothesis tree
      (rules out 2+ hypotheses), not just tests one in isolation.
- [ ] If symptoms depend on multiple state variables, the diagnosis
      includes a state-space table pinning the bug to specific cells.
- [ ] If Phase 1 was reopened, the revised hypothesis was checked
      against the *original* user-reported symptom, not the latest log.
- [ ] No conclusion was drawn from `print` / log absence; body
      invocation was verified with `Self._printChanges()` if relevant.
- [ ] The diagnosis includes a "Files referenced" table.
- [ ] The user explicitly confirmed the root cause before Phase 2 began.
- [ ] Phase 2 ran in a separate session with a scoped prompt.
- [ ] The fix has a verification — UI test, unit test, or documented
      manual sequence with screenshots.
- [ ] Phase 3 reviewed the diff against the diagnosis.
- [ ] No invented symbols were referenced.
- [ ] Project conventions and Swift 6 concurrency rules are preserved.
- [ ] No unrelated refactoring snuck into the patch.

---

## References

- [`references/focus-subsystems.md`](references/focus-subsystems.md) —
  search-cone model, subsystem checklist, UIFocusGuide
- [`references/diagnosis-template.md`](references/diagnosis-template.md) —
  Phase 1 output template
- [`references/gotchas.md`](references/gotchas.md) —
  platform traps, Liquid Glass, shelf clipping
- [`references/tooling.md`](references/tooling.md) —
  `_printChanges`, `_whyIsThisViewNotFocusable`, Quick Look, XCUIRemote
- **`swift-uitest` skill** — writing the XCUITest that verifies the fix
- **`swift-quality` skill** — patch matches project architecture rules
- **`prompt` skill** — writing the Phase 2 and Phase 3 prompts
- **`learn` skill** — capture new tvOS gotchas at session end
