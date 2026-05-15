---
name: swift-tvos
description: >
  Diagnoses tvOS navigation and focus engine bugs in SwiftUI codebases. Use
  this skill whenever the user says "focus is broken", "focus is stuck",
  "focus jumps to the wrong cell", "wrong screen pushes", "remote doesn't
  work", "the back button doesn't go back", "navigation is broken on tvOS",
  "focus engine", "this screen on Apple TV", "KickTV bug", or any variant
  involving Apple TV navigation. Also trigger when the user asks Claude
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
   cause ("I think it's local state drifting from the service"), treat it
   as Hypothesis A — read the code and either confirm it with quoted
   evidence or falsify it with quoted counter-evidence. Falsifying the
   user's hypothesis is *good*; it's the whole point of diagnosis. Never
   bend the diagnosis to fit the hypothesis the user came in with.
8. **Reconcile new evidence with the original symptom.** When a Phase 2
   attempt fails and Phase 1 is reopened, any new hypothesis must be
   consistent with the *original* user-reported symptom — not just with
   the latest log capture. If the new hypothesis predicts behaviour the
   user already said they don't see (e.g. "the body is frozen, so the
   focus halo would persist" vs the user's "it flashes"), the new
   hypothesis is wrong. Direct user observation outranks log inference.
   Always restate the original symptom alongside the new evidence before
   drawing a conclusion.

---

## Step 0 — Verify the bug's framing (before reading any code)

"X is broken" implies X used to work. Before any other step, confirm
the working baseline exists. Failure to do this leads to diagnosing a
phantom regression — investigating why something stopped working that
was never working in the first place. This has happened. It is the
single most expensive failure mode of this skill, more expensive than
any focus-engine misdiagnosis, because every subsequent step builds on
the assumption of a regression that doesn't exist.

Ask the user, explicitly, before doing anything else:

1. **"Is the working state you're describing something you have seen
   running on the simulator or device, or is it the intended/design
   state?"** If the user only has design mocks, brand guidelines, or
   Xcode previews showing the working state, **this is a feature
   implementation, not a bug**. Stop the diagnostic workflow. Switch
   to feature-implementation mode: design the highlight strategy,
   propose options, get user buy-in, then implement.

2. **"When did it last work in the simulator?"** Acceptable answers:
   "this commit SHA," "before this PR," "on tvOS 25." Unacceptable:
   "it should work," "the preview shows it working," "based on the
   design." If the answer is unacceptable, treat as feature
   implementation.

3. **"Is the screenshot/state you're showing me the current behaviour,
   the previous (working) behaviour, or the desired behaviour?"** If
   the user uploads images, ask which is which. Never assume two
   screenshots are "before" and "after" — they might both be "desired"
   and "actual," in which case the question is design, not debug.

If any of these answers reveal that the working state has never
existed in the running app, **abandon the diagnostic structure
immediately**. Do not continue to Step 1. Do not produce hypotheses
about why X broke. There is no X to have broken. The remaining work is:

- Confirm the desired behaviour with the user
- Identify the technical constraint (e.g. "Liquid Glass desaturates
  foreground tints")
- Propose 2–3 implementation strategies
- Let the user pick one
- Skip to Phase 2 with a focused implementation prompt

The Xcode preview rendering "correctly" is not evidence of a working
baseline. Previews routinely omit material containers, environment
values, and parent view modifiers that change behaviour at runtime.
A working preview only proves "the code compiles and renders something
when isolated."

---

## Step 0.5 — Reject Vague Bug Reports

Before doing anything else, confirm the symptom is precise. If the user's
description is vague, stop and ask. Acceptable bug reports answer all of
the following:

- **Screen:** Which view file? Which screen in the user-visible flow?
- **Input:** Which remote button? (Up / Down / Left / Right / Select /
  Menu / Play-Pause / Long-press Select)
- **Expected:** What was supposed to happen?
- **Actual:** What actually happened? Be specific —
  - Focus is *invisible* (no halo on any element)
  - Focus is *stuck* (halo doesn't move when you press a direction)
  - Focus *jumps to wrong element* (halo moves, but not where expected)
  - Focus *escapes the screen* (lands on a tab bar or sibling section)
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
find . -name "*.swift" -path "*KickTV*" | xargs grep -ln "<ScreenName>"

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

## Step 2 — The Focus Subsystem Checklist

For every hypothesis, you must name which subsystem owns the bug. Use this
checklist as the menu of possibilities. If your hypothesis doesn't fit
into one of these, it's underspecified.

### Focus visibility

- **Symptom:** No focus halo visible anywhere on screen.
- **Suspects:**
  - A parent view has `.focusable(false)` and nothing inside can claim
    focus.
  - The focusable element is inside a `ScrollView` or `LazyVStack` that
    hasn't yet rendered.
  - A custom `ButtonStyle` is missing the `.focused` visual treatment.
  - `FocusState` binding is `nil` and never gets set.
  - The view is presented as a `.sheet` or `.fullScreenCover` and focus
    is trapped on the presenter behind it.

### Focus movement

- **Symptom:** Halo moves, but to the wrong place.
- **Suspects:**
  - Missing `.focusSection()` boundaries — the focus engine groups
    elements geometrically; without sections, it picks the nearest
    neighbour by screen position, which may not be the intended one.
  - `.prefersDefaultFocus(_:in:)` is pointing at the wrong element or
    isn't being respected (the namespace must match).
  - Hidden / zero-size focusable elements are absorbing focus
    (`.frame(width: 0, height: 0)` plus `.focusable()` is a classic
    invisible trap).
  - `accessibilitySortPriority` conflicts with geometric layout.

### Focus restoration

- **Symptom:** Returning to a screen lands focus on the wrong element
  (or no element).
- **Suspects:**
  - `@FocusState` is local to the view and gets reset on every appearance.
  - `.defaultFocus($state, value)` is set but the state hasn't been
    restored from the previous visit.
  - The view is being re-created (identity change) rather than re-shown,
    losing its `@FocusState`.

### Navigation push / pop

- **Symptom:** Wrong screen pushes, or back doesn't pop.
- **Suspects:**
  - `NavigationPath` is being mutated from a non-main actor.
  - `navigationDestination(for:)` is registered on the wrong view
    (must be inside the `NavigationStack`, not on a child).
  - A `Button` action is firing twice (double-tap or gesture conflict).
  - `.onExitCommand` is overridden somewhere upstream and swallowing
    the Menu button.
  - The path binding is to `@State` instead of `@Bindable` /
    `@Binding`, so mutations don't propagate.

### Remote input

- **Symptom:** A remote button does nothing or fires the wrong action.
- **Suspects:**
  - `.onMoveCommand` is attached but the view isn't focused, so it
    never fires.
  - Multiple views compete for `.onPlayPauseCommand`; only the focused
    one receives it.
  - Siri Remote vs Apple TV Remote differences (long-press Select).
  - In UI tests: `XCUIRemote` events sent to an element that isn't
    actually focused; events fire but go nowhere.

---

## Step 3 — Write the Diagnosis Document

Output a single Markdown document with this structure. Do not write code
in this phase.

```markdown
# Diagnosis: <ScreenName> — <one-line symptom>

## Confirmed Symptom

- Screen: <file path>
- Input: <remote button>
- Expected: <what should happen>
- Actual: <what happens>
- Deterministic: <yes / yes-after-sequence / intermittent>
- Last working: <commit SHA or "unknown">

## User's hypothesis — confirmed / falsified

(Include this section only if the user came in with a stated hypothesis.)

State the user's hypothesis verbatim. Then either:

- **Confirmed:** Quote the code that supports it. It becomes Hypothesis A.
- **Falsified:** Quote the code that contradicts it. Move on — do not
  spend the rest of the document arguing against it.

If falsified, briefly state what the symptom must therefore *actually*
be caused by, then proceed to hypotheses against that reframed problem.

## How navigation is supposed to flow through this screen

One paragraph. Cite file paths and line numbers. Quote the relevant code
verbatim where ambiguity exists.

## State-space table (when symptoms depend on multiple state variables)

If the bug is conditional on the cross-product of multiple state
variables (e.g. `isSelected × isFocused`, or `isExpanded × hasFocus ×
isPlaying`), enumerate the full table and pin the bug to specific
cells. This makes the bug surface unambiguous and prevents reasoning
errors. Example:

| `isSelected` | `isFocused` | Expected | Actual |
|---|---|---|---|
| true | true | green | green ✓ |
| true | false | green | **white ✗** ← the bug lives here |
| false | true | green | green ✓ |
| false | false | white | white ✓ |

Skip this section if the symptom is single-variable or non-conditional.

## Hypotheses

### Hypothesis A — <Subsystem>: <one-line description>

- Subsystem: <one of the checklist categories above>
- Mechanism: <why this would cause the symptom>
- Falsifiable prediction: <if A is true, then X should be observable>
- Cheapest experiment: <smallest change that would confirm or refute>
- Confidence: <low / medium / high> and why

### Hypothesis B — ...

### Hypothesis C — ...

(Minimum three hypotheses. Resist the urge to converge on one too early.
Where possible, design **one experiment that distinguishes between
multiple hypotheses** — a single log line or a single removed modifier
that splits the hypothesis tree in two. Note which hypotheses each
experiment would confirm or refute.)

## Recommended next step

Which experiment to run first, and why it's the cheapest distinguisher.
Prefer experiments that split the hypothesis tree (rule out 2+ hypotheses
in one observation) over experiments that test a single hypothesis. This
is a *diagnostic* experiment, not a fix.

State exactly what observable outcome maps to which hypothesis:
- "If X is observed → Hypothesis A or C is the cause; next step is …"
- "If Y is observed → Hypothesis B or D is the cause; next step is …"

## Open questions for the user

Anything you need confirmed before Phase 2 can begin.

## Files referenced in this diagnosis

| File | Key lines | Why it matters |
|------|-----------|----------------|
| `<path>` | `<line ranges>` | <one line> |

(Every file you read and quoted from. Makes the diagnosis greppable and
reviewable; lets Phase 2 and Phase 3 confirm scope.)
```

Save the document to `docs/diagnostics/<screen>-<date>.md` in the repo
(or output to stdout if no repo is available).

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
- Require a verification step that demonstrates the fix.

Verification on tvOS means one of:

- A new XCUITest that reproduces the bug and now passes (see the
  `swift-uitest` skill).
- A Swift Testing unit test on the underlying state if the bug is in a
  service or actor rather than the view.
- A reproducible manual sequence captured in the PR description: "Press
  Down on the Categories shelf → focus moves to the first Live tile" —
  with simulator screenshots.

If the fix can't be verified by any of these, the fix is not done.

---

## Step 6 — Phase 3: Review (separate session)

A third session reviews the diff against:

- The original diagnosis document — did the fix address the confirmed
  root cause, or did it drift?
- KickTV conventions — `Console` over `print()`, one type per file,
  named constants, `nonisolated init(from:)` on models, private actor
  fetchers, actors stay actors (never converted to `@MainActor final
  class`).
- Swift 6 concurrency — no new `nonisolated(unsafe)`, no new
  `@unchecked Sendable`, actor isolation preserved.
- No invented symbols — every type/property/method referenced exists.
- Test coverage — the verification step from Phase 2 is present.

The reviewer should produce a written review, not a patch.

---

## tvOS-Specific Gotchas Worth Memorising

- `XCUIRemote.shared.press(.select)` only works if the element you expect
  to receive it is actually focused. Send a screenshot before pressing
  to confirm focus state.
- `accessibilityIdentifier` on tvOS must be set on the focusable element
  itself, not its parent — the focus engine and the accessibility tree
  use the same identifiers.
- `.focusSection()` is geometric, not logical. Two sections at the same
  Y-coordinate will compete for horizontal navigation.
- `Button` actions on tvOS fire on Select (centre press), not on tap.
  A `TapGesture` will not fire.
- `NavigationStack` on tvOS works, but presenting modally
  (`.fullScreenCover`) traps focus inside the modal — this is correct
  behaviour, not a bug.
- The Siri Remote's Menu button maps to `.onExitCommand`. If a parent
  view registers `onExitCommand`, the child can't override it without
  re-registering and conditionally forwarding.
- **Liquid Glass + `.foregroundColor` / `.foregroundStyle`:** content
  inside `GlassEffectContainer` and `.glassEffect(...)` runs through a
  vibrancy pass that can desaturate or override foreground tints on
  unfocused content. The Xcode preview will often render the correct
  colour because previews typically omit the glass wrapper. Symptoms:
  selected-but-not-focused items render white/neutral despite the
  foreground modifier setting `.accentColor`. Possible fixes: apply
  the highlight as a background fill (composes above the material
  rather than under it), use `.tint(_:)` on the Button (routes through
  the system tint channel), or — last resort — remove the glass for
  the affected content. Diagnosis must distinguish between "foreground
  is suppressed" and "API was swapped to one that vibrancy treats
  differently" via a background-fill experiment.

## SwiftUI Diagnostic Tooling (use these, not `print`)

- **`let _ = Self._printChanges()`** — placed unconditionally at the top
  of a view's `body`, logs to the console every time SwiftUI invokes
  the body and *what* changed to cause it (state, environment, parent
  re-render). This is the canonical "did my body re-run?" tool.
- **`print` / `Console.log` absence is NOT proof of body non-invocation.**
  SwiftUI elides redundant re-evaluations, may batch transitions, and
  may not invoke side effects on every body call. Drawing conclusions
  from log *absence* is unsound. Use `Self._printChanges()` first.
- **View-body quiescence is the steady state, not a bug.** Bodies run
  when inputs or environment change; once those stabilise, the body
  stops running. "I don't see further logs after the transition" is
  expected behaviour, not evidence of freezing.
- **Reconcile log evidence with visible symptoms.** If logs suggest one
  thing (e.g. body never re-runs) and the user's visible symptom
  contradicts it (e.g. focus halo flashes), the visible symptom wins.
  The log is being misread.

---

## Model & Mode Recommendations

| Phase | Model | Mode | Reason |
|---|---|---|---|
| 1 — Diagnose | Opus | Plan mode | Reasoning-heavy. Must not write code. Plan mode enforces this. |
| 2 — Execute | Sonnet | Normal | Mechanical patch implementation against a confirmed root cause. |
| 3 — Review | Opus | Plan mode | Reasoning-heavy. Must not write code. Reviews diff against diagnosis. |

If the bug involves UI test diagnosis (interpreting `.xcresult`, timing,
accessibility tree ambiguity), use **Opus for all three phases**. Sonnet
is unreliable here.

Always run Phase 1, 2, and 3 as **separate sessions** with **separate
prompts**. Never collapse them. The discipline is the value.

---

## Post-Diagnosis Checklist

Before declaring a tvOS navigation bug fixed, verify:

- [ ] Step 0 confirmed the bug is a regression (working state existed
      in the running app), not a feature gap or design aspiration.
- [ ] Phase 1 produced a written diagnosis document with ≥3 hypotheses.
- [ ] If the user proposed a hypothesis, the diagnosis explicitly
      confirmed or falsified it with quoted code.
- [ ] At least one recommended experiment splits the hypothesis tree
      (rules out 2+ hypotheses), not just tests one in isolation.
- [ ] If symptoms depend on multiple state variables, the diagnosis
      includes a state-space table pinning the bug to specific cells.
- [ ] If Phase 1 was reopened, the revised hypothesis was checked
      against the *original* user-reported symptom, not just the latest
      log capture.
- [ ] No conclusion was drawn from `print` / log *absence*; body
      invocation was verified with `Self._printChanges()` if relevant.
- [ ] The diagnosis includes a "Files referenced" table.
- [ ] The user explicitly confirmed the root cause before Phase 2 began.
- [ ] Phase 2 ran in a separate session with a scoped prompt.
- [ ] The fix has a verification — UI test, unit test, or documented
      manual sequence with screenshots.
- [ ] Phase 3 reviewed the diff against the diagnosis.
- [ ] No invented symbols were referenced.
- [ ] KickTV conventions and Swift 6 concurrency rules are preserved.
- [ ] No unrelated refactoring snuck into the patch.

---

## References

- **`swift-uitest` skill** — For writing the XCUITest that verifies the
  fix in Phase 2.
- **`swift-quality` skill** — For ensuring the patch matches Google
  Swift Style Guide and KickTV architecture rules.
- **`prompt` skill** — For writing the Phase 2 execute-phase prompt and
  the Phase 3 review prompt.
- **`pr-preflight` skill** — Before opening a PR with the fix.
- **`learn` skill** — At session end, capture any new tvOS gotchas
  uncovered during diagnosis.
