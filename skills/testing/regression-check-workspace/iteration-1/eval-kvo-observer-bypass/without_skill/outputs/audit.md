# Audit: `handleBackground()` / `handleForeground()` fix in `VideoPlayerViewModel.swift`

## Summary verdict

**The fix is incomplete.** The new `wasPlayingBeforeBackground` flag correctly guards the explicit `player.play()` call inside `handleForeground()`, but it does **not** stop the player from resuming on its own through a separate code path: the KVO observer on `currentItem?.status` installed by `observePlayerStatus(_:)`. There is a realistic scenario in which a user-paused VOD will still auto-resume on return from background. There are also several adjacent concerns (`Sendable`/captures in the KVO closure, double-pause races, missing reset of the flag, and `pause(showPauseIcon:)` semantics) that the change interacts with.

The remainder of this report walks through each concrete regression / side effect.

---

## 1. BLOCKER — KVO observer on `currentItem?.status` bypasses the new guard

File: `VideoPlayerViewModel.swift`, lines 155–167.

```swift
player.observe(keyPath: \.currentItem?.status) { oldValue, newValue in
    Console.log("AVPlayerItem.status ... ")
    switch newValue {
    case .none:
        player.pause()
    case .readyToPlay:
        player.play()        // <-- unconditional
    case .failed: break
    case .unknown: break
    @unknown default:
        break
    }
}
.store(in: &observations)
```

### Why this defeats the fix

`handleForeground()` only protects one of *two* places where the player can be started. The KVO closure above also calls `player.play()` unconditionally whenever `currentItem.status` transitions to `.readyToPlay`. After the app returns from background, AVFoundation routinely re-evaluates the `AVPlayerItem`:

- On iOS/tvOS, when the app is backgrounded an `AVPlayerItem` whose asset is a network HLS stream is often torn down or its status flipped back to `.unknown` (especially for VODs without `usesExternalPlaybackWhileExternalScreenIsActive`, or when AirPlay/Now Playing reclaims the session).
- On foreground, the item is re-prepared and the status transitions back through `.unknown` → `.readyToPlay`.
- That transition fires the KVO observer, which unconditionally calls `player.play()` — completely bypassing `wasPlayingBeforeBackground`.

### Reproducer (logical)

1. User opens a VOD.
2. `observePlayerStatus(_:)` installs the `.readyToPlay → player.play()` observer.
3. User pauses with the pause button. `pause()` sets `hidePauseImage` and calls `player.pause()`. `isPaused` becomes `true` via the second observer.
4. User backgrounds the app. `handleBackground()` records `wasPlayingBeforeBackground = false` (player was paused) and calls `player.pause()` (no-op).
5. App is suspended; AVFoundation drops/reclaims the player item. `currentItem.status` is no longer `.readyToPlay`.
6. User foregrounds. `handleForeground()` correctly returns early because `wasPlayingBeforeBackground == false`. **Good.**
7. AVFoundation re-prepares the item. Status goes `.unknown → .readyToPlay`.
8. KVO observer fires → `player.play()`. **The bug returns.**

This is the exact bug the ticket describes. The fix is not robust to it.

### Suggested fix

Either:

- Track an explicit "user paused" intent on the view model (e.g. a `userPaused: Bool` flag set in `pause(showPauseIcon:)` and cleared on user-initiated play / new item load), and consult it in the KVO closure before calling `player.play()`; or
- Tear down the `.readyToPlay → play()` auto-play behaviour entirely after the first ready-to-play (it really only exists to start initial playback), or
- In `handleBackground()` / `handleForeground()`, temporarily remove or suppress the status observer and re-install it after `wasPlayingBeforeBackground` has been honoured.

The cleanest is the first: a single source of truth for user intent. The KVO observer should never override an explicit user pause.

---

## 2. BLOCKER — `wasPlayingBeforeBackground` is never reset

`wasPlayingBeforeBackground` is set in `handleBackground()` and read in `handleForeground()`, but it is **never cleared**. Concrete consequences:

- `handleForeground()` reads `true`, calls `player.play()`. The flag stays `true`. If the user then *pauses inside the app* (foreground) and the app is killed/relaunched without going through `handleBackground()` again (e.g. scene phase glitch, dev hot-reload, certain tvOS lifecycle paths), a subsequent `handleForeground()` would still see `true` and re-play.
- More realistically: if `handleForeground()` is called multiple times for one `handleBackground()` (this *does* happen on iOS/tvOS — `scenePhase` can deliver `.active` more than once for a single resume cycle, e.g. when a system alert dismisses, when AirPlay route changes, when an interruption ends), the second call will still `play()` even if the user paused between the two callbacks.

### Suggested fix

Set `wasPlayingBeforeBackground = false` at the end of `handleForeground()` (or right after capturing the decision), so it strictly represents "state captured on the most recent background transition".

```swift
func handleForeground() {
    guard let player else { Console.warning("No Player"); return }
    defer { wasPlayingBeforeBackground = false }
    guard wasPlayingBeforeBackground else { return }
    player.play()
}
```

---

## 3. WARNING — `timeControlStatus == .playing` is not the same as "user wanted to be playing"

`handleBackground()` snapshots `player.timeControlStatus == .playing`. That value is not necessarily what the user intended:

- `.waitingToPlayAtSpecifiedRate` (buffering) is a very common state on cellular / poor networks. A user who hit Play 200 ms ago and is buffering when the app is backgrounded will be recorded as "not playing" and **will not resume** on return from background. That is a behaviour regression vs. the pre-fix code, which would always resume.
- Conversely, `.playing` can be true momentarily during seek scrubs / ad transitions even if the user is mid-interaction.

The right signal is the user's pause intent (see §1), not the live transport state.

### Suggested fix

Track intent at the call sites that change it (`pause()`, the play button, the first auto-play on `.readyToPlay`) rather than sampling `timeControlStatus` at background time.

---

## 4. WARNING — `hidePauseImage` / pause overlay UI is now inconsistent after foreground

`pause(showPauseIcon:)` sets `hidePauseImage`, and the `timeControlStatus` observer resets `hidePauseImage = false` when transitioning *into* a non-paused state.

After the fix:

- User pauses (`hidePauseImage` becomes whatever `!showPauseIcon` is — usually `false`, so the overlay is shown).
- Background → foreground. `wasPlayingBeforeBackground` is `false`, so `player.play()` is not called. Good.
- But if the KVO status observer fires (see §1) and starts playback, the `timeControlStatus` observer will then flip `isPaused = false` and `hidePauseImage = false`. The UI will now silently mark itself as "playing" while the user expects "paused". The visible state diverges from user intent.

Even without §1, if any of the auto-paths re-start the player, the pause overlay state is wrong. This couples the bug in §1 to UI correctness; fixing §1 fixes this too.

---

## 5. WARNING — Race / double-mutation with `loadPlaybackUrl`'s resolution callback

`loadPlaybackUrl(_:)` schedules an async `getResolutions` callback (lines 96–111) that:

- On success: calls `player.replaceCurrentItem(with: ...)`. Replacing the current item causes the status observer to fire `.unknown → .readyToPlay`, which calls `player.play()`.
- On failure: directly calls `self?.player?.play()`.

This callback can complete *after* the app has been backgrounded or while the app is being backgrounded. Sequence:

1. `load(...)` is called.
2. User backgrounds before resolutions resolve. `handleBackground()` records `wasPlayingBeforeBackground = false` (player was paused or .unknown) and pauses.
3. Resolutions callback fires; replaces item → `.readyToPlay` → `player.play()`. Or in the `.failure` branch, `player.play()` is called directly.
4. App is still backgrounded (or transitioning). Playback resumes audio-only, fighting the AV session.

The new flag does not protect against this either. This is not introduced by the fix, but the fix does not address it and a regression test that covers "pause + background during initial load" will fail.

---

## 6. WARNING — `player.observe(...)` capture semantics

Lines 155 and 170:

```swift
player.observe(keyPath: \.currentItem?.status) { oldValue, newValue in
    ...
    player.pause()   // <-- captures `player` strongly
}
```

```swift
player.observe(keyPath: \.timeControlStatus) { [weak self] oldValue, newValue in
    ...
}
```

The first closure captures `player` strongly and is stored on `self.observations`. `self` retains `observations`, which retains the cancellable, which retains the closure, which retains `player`. `self.player` also retains the player. As long as `self.observations` is alive, the player cannot be deallocated even if `stopPlayer()` nils `self.player`. Not directly related to the background bug, but worth flagging as it interacts with `deinit { removeObservers(); stopPlayer() }` ordering — if `removeObservers()` runs before `stopPlayer()` (it does), the observer-captured player reference can outlive `self.player = nil` only inside the closure itself, but `observations.removeAll()` should release them. Still, the strong capture is inconsistent with the `[weak self]` capture below and is fragile.

### Suggested fix

Use `[weak player]` or rely on the KVO callback parameter (the observer provides `oldValue`/`newValue`; the player itself can be re-derived from `self`).

---

## 7. WARNING — `handleBackground()` always calls `player.pause()`, even if already paused

Minor, but: when the user has already paused, `handleBackground()` still calls `player.pause()`. That re-fires `timeControlStatus` observers? In practice `.paused → .paused` is filtered by `guard oldValue != newValue else { return }`, so it's safe. No bug, just noise.

More importantly, the snapshot is taken *before* the pause, which is correct.

---

## 8. SUGGESTION — Threading / `@MainActor` discipline

`VODPlayerViewModel` is an `ObservableObject` driving SwiftUI. `handleBackground()`, `handleForeground()`, the KVO closures, and the resolutions callback all mutate `@Published` state. None of them are explicitly `@MainActor`. The KVO callbacks from `AVPlayer.observe(keyPath:)` are delivered on an arbitrary queue (the helper used here is custom — `Utilities` — and may or may not hop to main). If `wasPlayingBeforeBackground` is read on main and written from a KVO queue, you have a TSan-flaggable race.

`wasPlayingBeforeBackground` is a plain `Bool` on a class. There is no isolation. The fix should either:

- Move the flag onto the main actor (annotate the type or the methods), or
- Document that `handleBackground()` and `handleForeground()` are only ever called from the main actor (they are — they're invoked from `scenePhase` handlers in the view).

The latter is fine, but the KVO closure that auto-plays (§1) is not on the main actor, so any cross-talk between them is racy.

---

## 9. SUGGESTION — Missing tests

The fix is exactly the kind of change that should land with a regression test. Suggested cases:

1. User pauses → background → foreground → assert `player.play()` is not called.
2. User playing → background → foreground → assert `player.play()` is called.
3. User pauses → background → foreground → status observer fires `.readyToPlay` → assert `player.play()` is **not** called. *(This is the test that catches §1.)*
4. Multiple foregrounds for a single background → assert `play()` only fires once and only if intended.
5. Background during initial resolutions load → assert no `play()` during background.

A `MockAPIClient` and a stubbed `AVPlayer` (or a thin protocol seam) would make these tests cheap.

---

## 10. SUGGESTION — Naming

`wasPlayingBeforeBackground` is fine but conflates state-at-snapshot with user intent. If the underlying signal is changed to "did the user intend to be playing" (per §1, §3), rename to `userIntendsPlayback` or `shouldResumeOnForeground`. This makes the KVO bypass in §1 obvious during review.

---

## Recommended minimum changes before merge

1. Reset `wasPlayingBeforeBackground = false` at the end of `handleForeground()`. (§2 — one line, no downside.)
2. Make the `.readyToPlay → player.play()` KVO branch respect a user-intent flag, or convert it to a one-shot that only auto-plays the *first* ready-to-play after `loadPlaybackUrl`. (§1 — this is the actual fix for the original bug.)
3. Add at least the test in §9.3.

Without (2), the original bug is still reachable through realistic AVFoundation lifecycle on iOS/tvOS, even though the simple "pause → background → foreground" path is now covered.
