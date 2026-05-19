# Diagnosis Document Template

Output this structure at the end of Phase 1. No code in this phase.

Save to `docs/diagnostics/<screen>-<date>.md` in the repo, or stdout
if no repo is available.

---

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

(Include only if the user came in with a stated hypothesis.)

State the user's hypothesis verbatim. Then either:

- **Confirmed:** Quote the code that supports it. It becomes Hypothesis A.
- **Falsified:** Quote the code that contradicts it. Move on — do not
  spend the rest of the document arguing against it.

If falsified, briefly state what the symptom must therefore actually
be caused by, then proceed to hypotheses against that reframed problem.

## How navigation is supposed to flow through this screen

One paragraph. Cite file paths and line numbers. Quote the relevant code
verbatim where ambiguity exists.

## State-space table (when symptoms depend on multiple state variables)

If the bug is conditional on the cross-product of multiple state
variables (e.g. `isSelected × isFocused`, or `isExpanded × hasFocus ×
isPlaying`), enumerate the full table and pin the bug to specific cells.

| `isSelected` | `isFocused` | Expected | Actual |
|---|---|---|---|
| true | true | green | green ✓ |
| true | false | green | **white ✗** ← the bug lives here |
| false | true | green | green ✓ |
| false | false | white | white ✓ |

Skip this section if the symptom is single-variable or non-conditional.

## Hypotheses

### Hypothesis A — <Subsystem>: <one-line description>

- Subsystem: <category from focus-subsystems.md>
- Mechanism: <why this would cause the symptom>
- Falsifiable prediction: <if A is true, then X should be observable>
- Cheapest experiment: <smallest change that would confirm or refute>
- Confidence: <low / medium / high> and why

### Hypothesis B — ...

### Hypothesis C — ...

Minimum three hypotheses. Resist the urge to converge on one too early.
Where possible, design one experiment that distinguishes between multiple
hypotheses — a single log line or a single removed modifier that splits
the hypothesis tree in two. Note which hypotheses each experiment would
confirm or refute.

## Recommended next step

Which experiment to run first, and why it's the cheapest distinguisher.
Prefer experiments that split the hypothesis tree (rule out 2+ hypotheses
in one observation) over experiments that test a single hypothesis. This
is a diagnostic experiment, not a fix.

State exactly what observable outcome maps to which hypothesis:
- "If X is observed → Hypothesis A or C is the cause; next step is …"
- "If Y is observed → Hypothesis B or D is the cause; next step is …"

## Open questions for the user

Anything you need confirmed before Phase 2 can begin.

## Files referenced in this diagnosis

| File | Key lines | Why it matters |
|------|-----------|----------------|
| `<path>` | `<line ranges>` | <one line> |

Every file you read and quoted from. Makes the diagnosis greppable and
reviewable; lets Phase 2 and Phase 3 confirm scope.
```
