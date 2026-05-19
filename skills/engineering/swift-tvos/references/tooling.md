# tvOS Diagnostic Tooling

Tools for gathering evidence during Phase 1. Prefer these over `print`.

---

## `Self._printChanges()` — body invocation logging

Place unconditionally at the top of a view's `body`. Logs to the console
every time SwiftUI invokes the body and what changed to cause it (state,
environment, parent re-render).

```swift
var body: some View {
    let _ = Self._printChanges()
    // ...
}
```

**Warning:** `print` / `Console.log` absence is NOT proof of body
non-invocation. SwiftUI elides redundant re-evaluations and may batch
transitions. Drawing conclusions from log absence is unsound. Use
`Self._printChanges()` first.

**Normal:** View-body quiescence is the steady state. Bodies run when
inputs or environment change; once those stabilise, the body stops
running. "I don't see further logs after the transition" is expected
behaviour, not evidence of freezing.

**Reconcile log evidence with visible symptoms.** If logs suggest one
thing (e.g. body never re-runs) and the user's visible symptom
contradicts it (e.g. focus halo flashes), the visible symptom wins.
The log is being misread.

---

## `_whyIsThisViewNotFocusable` — LLDB focus eligibility

A private Objective-C method that returns a detailed text explanation
of why a specific view cannot receive focus (e.g. "view is hidden" or
"`userInteractionEnabled` is false").

```objectivec
po [yourViewVariable _whyIsThisViewNotFocusable]
```

Run this in the LLDB console while paused at a breakpoint, passing the
UIKit view instance you suspect is un-focusable.

**Critical:** This is a private API, strictly for debugging. Never ship
it in production code — App Store will reject any binary that calls it.

---

## `UIFocusUpdateContext` Quick Look — visual search-path map

Lets you see exactly what the Focus Engine "sees" when it performs a
directional search.

1. Set a breakpoint inside `didUpdateFocusInContext(_:withAnimationCoordinator:)`.
2. When the breakpoint hits, select the `UIFocusUpdateContext` instance
   in the Xcode debugger variables pane.
3. Click the **Quick Look (eye icon)**.
4. Xcode renders an image overlay showing the search path and potential
   focus targets.

Use this when a hypothesis involves "the engine can't see the target"
or "the wrong neighbour is winning the search."

---

## XCUIRemote — UI test event delivery

```swift
XCUIRemote.shared.press(.select)
XCUIRemote.shared.press(.up)
XCUIRemote.shared.press(.menu)
```

Always confirm the target element is focused before sending remote
events in UI tests. An event sent to an unfocused element fires but
goes nowhere — this looks like "the remote doesn't work" when the real
issue is focus state.
