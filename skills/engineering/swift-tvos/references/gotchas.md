# tvOS-Specific Gotchas

Platform behaviours that are correct but counterintuitive, or traps that
produce symptoms that look like bugs.

---

## Remote and input

- `XCUIRemote.shared.press(.select)` only works if the element you
  expect to receive it is actually focused. Send a screenshot before
  pressing to confirm focus state.
- `Button` actions on tvOS fire on Select (centre press), not on tap.
  A `TapGesture` will not fire.
- Siri Remote's Menu button maps to `.onExitCommand`. If a parent view
  registers `onExitCommand`, a child can't override it without
  re-registering and conditionally forwarding.

---

## Focus geometry

- `.focusSection()` is geometric, not logical. Two sections at the same
  Y-coordinate will compete for horizontal navigation.
- `accessibilityIdentifier` on tvOS must be set on the focusable element
  itself, not its parent — the focus engine and the accessibility tree
  use the same identifiers.
- The focus engine searches within a directional cone, not along an axis.
  If a target sits just outside the cone (e.g. slightly off-diagonal),
  focus won't reach it even if it's visually "next" in the direction of
  the swipe.

---

## Navigation

- `NavigationStack` on tvOS works, but presenting modally
  (`.fullScreenCover`) traps focus inside the modal — this is correct
  behaviour, not a bug.

---

## Liquid Glass + foreground colour

Content inside `GlassEffectContainer` and `.glassEffect(...)` runs
through a vibrancy pass that can desaturate or override foreground tints
on unfocused content. Symptoms: selected-but-not-focused items render
white/neutral despite the foreground modifier setting `.accentColor`.

The Xcode preview will often render the correct colour because previews
typically omit the glass wrapper.

Possible fixes:
- Apply the highlight as a background fill (composes above the material
  rather than under it).
- Use `.tint(_:)` on the Button (routes through the system tint channel).
- Last resort: remove the glass for the affected content.

Diagnosis must distinguish between "foreground is suppressed" and "API
was swapped to one that vibrancy treats differently" via a background-fill
experiment.

---

## SwiftUI content shelves

- Scroll clipping must be disabled on horizontal shelf containers.
  If clipping is enabled, a focused item that scales up will be cropped
  by the container's bounds.
- `containerRelativeFrame` is the correct way to size lockup items;
  it ensures alignment with safe area insets regardless of item count.
