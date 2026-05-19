# Focus Subsystem Checklist

Use this as the menu of possibilities when forming hypotheses. Every
hypothesis must name which subsystem owns the bug. If it doesn't fit
one of these categories, it's underspecified.

---

## How the Focus Engine finds neighbours

The engine uses a directional search based on the user's swipe. It
searches within a specific **angle/cone** in that direction. If a
focusable view is found within the cone, focus moves; otherwise it
stays put. This is why gaps and misalignment cause focus to "skip" —
nothing sits inside the search cone.

**Initial focus:** By default, the system targets the focusable view
closest to the **top-left corner** on first appearance. Override with
`preferredFocusEnvironments` to guide the user to the primary action.

**Focus Chain vs. Responder Chain:** iOS uses the Responder Chain (view
hierarchy) to route touch events. tvOS uses the Focus Chain (spatial
proximity). A fix that works on iOS by changing view hierarchy will not
fix a tvOS focus bug — the layout geometry is what matters.

---

## Focus visibility

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

---

## Focus movement

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

---

## Focus gaps — UIFocusGuide / invisible bridges

When focusable views are not aligned along the standard search cone,
the engine needs a manual bridge.

- **Symptom:** Swiping in a direction produces no movement even though
  a target logically "should" be reachable.
- **Remedy:**
  1. Define a `UIFocusGuide` (UIKit) in the empty space between source
     and target.
  2. Set its `preferredFocusEnvironments` to the intended target view.
  3. In SwiftUI, `.focusSection()` on a container achieves the same
     effect — the container's full bounds become a valid landing zone.

---

## Focus restoration

- **Symptom:** Returning to a screen lands focus on the wrong element
  or no element.
- **Suspects:**
  - `@FocusState` is local to the view and resets on every appearance.
  - `.defaultFocus($state, value)` is set but the state hasn't been
    restored from the previous visit.
  - The view is being re-created (identity change) rather than re-shown,
    losing its `@FocusState`.

---

## Navigation push / pop

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

---

## Remote input

- **Symptom:** A remote button does nothing or fires the wrong action.
- **Suspects:**
  - `.onMoveCommand` is attached but the view isn't focused, so it
    never fires.
  - Multiple views compete for `.onPlayPauseCommand`; only the focused
    one receives it.
  - Siri Remote vs Apple TV Remote differences (long-press Select).
  - In UI tests: `XCUIRemote` events sent to an element that isn't
    actually focused; events fire but go nowhere.
