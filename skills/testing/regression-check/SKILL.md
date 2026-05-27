---
name: regression-check
description: Audits in-progress code changes or written plans for side effects and regressions BEFORE they are committed or implemented. Catches broken callers (blast radius), behavioural ripples through shared state, observers, KVO, NotificationCenter, scenePhase, and concurrency or threading regressions. Always use this skill when the user says "audit for regressions", "check side effects", "what could this break", "is this safe to commit", "what am I missing", or asks Claude to verify that a plan or pending change won't break anything else. Also trigger proactively right after a plan document is written and before any code is generated for it, and right before a commit when significant changes are staged.
---

# Regression Check

A focused audit pass that looks at code changes or written plans and asks one question: **what does this break that you haven't thought about?**

This is not a code review. It does not comment on style, naming, or architecture. It looks for *consequences* — the unintended reach of a change into parts of the system the author didn't touch.

## When to invoke this skill

Use this skill in four situations:

1. **Mid-edit, on demand** — user has unfinished changes and wants to know what they're about to break before going further.
2. **Pre-commit** — user is about to commit and wants a final sanity check on what the diff actually touches.
3. **Post-plan, pre-implementation** — a plan document exists (typically `docs/plans/*.md`) and the user wants the design audited before code is written against it.
4. **Explicit request** — phrases like "audit for regressions", "check side effects", "what could this break", "is this safe", "what am I missing".

The skill is most valuable for changes that look small but reach far — observers, shared state, lifecycle handlers, protocol changes, public API tweaks.

## Inputs

The skill operates on one of two input types. Detect which automatically:

- **Working tree changes** — `git status` shows modified/staged files. Default input. Use `scripts/diff-surface.sh` (see Bundled scripts below) rather than parsing raw `git diff` output by hand.
- **Plan document** — user references a path under `docs/plans/` or pastes a plan body. Read it as the change surface.

If both are present and ambiguous, ask the user which to audit.

## Bundled scripts

Three helper scripts live next to this file in `scripts/`. They are not required — the audit process works without them — but they save time on the parts that are otherwise repetitive grep work. Prefer them over re-deriving the same searches by hand. All three are read-only and side-effect-free.

- `scripts/diff-surface.sh` — lists changed files and Swift symbol declarations from the working tree (or `--base <ref>` / `--staged`). Output is a raw list; treat as a starting point for Step 1, not an exhaustive surface.
- `scripts/find-callers.sh <symbol> [<root>]` — grep-based caller search for one or more symbols, with the definition site filtered out. Uses `rg` if available, falls back to `grep -rn`. Use in Step 2 for each modified symbol.
- `scripts/scan-ripples.sh [<root-or-file>]` — categorised scan for KVO observers, Combine pipelines, NotificationCenter usage, scenePhase handlers, lifecycle methods, AppStorage/UserDefaults, singletons, and SwiftUI state. Use in Step 3 to locate the hotspots that the change might reach into.

Each script supports `-h` for usage details. They emit plain text — feed the output into your reasoning, don't quote it verbatim in the audit report unless a specific line is the evidence for a finding.

## Audit process

Work through these five steps in order. Don't skip steps — each one catches a different class of issue.

### Step 1: Map the change surface

List every symbol (function, method, property, type) that the change adds, removes, modifies, or whose semantics shift. For plans, extract this from the prose — what does the plan say will be created, deleted, or altered?

For working tree changes, run `scripts/diff-surface.sh` and use its output as a starting list. Filter mentally — the script reports every declaration on a changed line, including internal `@State` and `@Published` properties; the audit's job is to decide which of those are externally observable surfaces and which are implementation details.

Note specifically:
- Removed or renamed symbols (high blast-radius risk)
- Modified signatures (callers may break silently if types still match)
- Modified semantics with unchanged signatures (the most dangerous — compiler won't help)
- New shared state, observers, notifications, or async tasks

### Step 2: Find callers and dependents (blast radius)

For each modified symbol, search the codebase to find every site that uses it. Use `scripts/find-callers.sh <symbol>` — it handles the grep, excludes the definition site, and works whether or not `rg` is installed. Run it once per symbol of interest; collect the results before moving on. Don't trust memory — the codebase changes faster than mental models.

For each caller, ask:
- Does this caller rely on the *old* behaviour the change broke?
- If the signature changed, will the compiler catch it or does the type system allow the old call to still type-check with new semantics?
- Is this caller in a code path that runs at a different time (background thread, lifecycle handler, deinit) where breakage shows up later?

### Step 3: Trace behavioural ripples

This is the highest-value step and the one most often skipped. The change being audited may not call any new symbol, but it may *trigger* one indirectly.

Start by running `scripts/scan-ripples.sh <changed-file-or-dir>` on each file the change touches *and* on related files (the same module, the same feature folder). The script gives a categorised list of hotspots — KVO, Combine, NotificationCenter, scenePhase, lifecycle, AppStorage/UserDefaults, singletons, SwiftUI state. Read each hit and ask: could the changed code reach this, directly or indirectly?

Concretely look for:

- **KVO observers and Combine publishers** — does the change cause an observed value to fire when it didn't before? (Real example: the VOD player's `currentItem.status` observer auto-played whenever the item became `.readyToPlay`, including on background return — invisible from the immediate change site.)
- **NotificationCenter posts and observers** — does the change post a notification, or modify a value an observer reads?
- **Lifecycle handlers** — `scenePhase`, `viewWillAppear`, `applicationDidEnterBackground`, `deinit` — does the change interact with these in a new way? Are existing handlers still correct?
- **Shared mutable state** — singletons, statics, `@AppStorage`, `UserDefaults`, environment values — does the change read or write something other code relies on?
- **SwiftUI state propagation** — `@StateObject`, `@ObservedObject`, `@Environment` — does the change affect what triggers re-renders, or break the invalidation chain?
- **Protocol conformances** — does adding/removing a conformance change which extension methods get called?

**Step 3 thoroughness checklist.** Tick each item before moving on; if
any is unchecked, return to that category and read the matching
hotspots from `scan-ripples.sh`.

- [ ] KVO observers / `addObserver(_:forKeyPath:)` calls
- [ ] Combine `sink` / `assign` subscriptions
- [ ] `NotificationCenter` posts AND observers
- [ ] `scenePhase` handlers and lifecycle methods
  (`viewWillAppear`, `applicationDidEnterBackground`, `deinit`)
- [ ] Shared mutable state: singletons, `static let`, `@AppStorage`,
  `UserDefaults`, environment values
- [ ] SwiftUI state wrappers: `@State`, `@StateObject`,
  `@ObservedObject`, `@Environment`, `@Bindable`
- [ ] Protocol conformances added/removed

### Step 4: Check concurrency and threading

Specifically look for:

- **Sendable violations** — capturing non-Sendable state in a Task/closure that crosses isolation boundaries.
- **Actor isolation regressions** — calls that used to be on the main actor now happening elsewhere, or vice versa.
- **Race conditions introduced by new async work** — Tasks that mutate state without coordination, observers firing on background queues that touch UI.
- **Existing observer/callback queue context** — if the change introduces new state (especially a plain `Bool`/`Int`/property), check what queue every existing observer that reads or writes related state fires on. KVO callbacks, `AVPlayer` periodic time observers, and `NotificationCenter` observers can fire on arbitrary queues. A new unisolated property read by a main-thread method and written by a KVO callback is a race even if "no new async work" was added.
- **Deinit ordering issues** — observers or subscriptions not being released, retain cycles via captured `self`.
- **Cancellation gaps** — long-running tasks that should be cancellable but aren't.

Do not move on from this step by writing "no concurrency surface" unless you have verified — by reading the code — that every observer or callback touching adjacent state runs on the same isolation domain as the changed code. The trap to avoid is assuming "I didn't add any `async`, so concurrency is clear" when an existing KVO observer or Combine sink is doing the racing.

**Step 4 thoroughness checklist.** Tick each item before declaring
"no concurrency surface". For deeper analysis on any flagged item,
apply skill `swift-concurrency-expert` on the specific file.

- [ ] Every new closure / `Task` captured value is `Sendable` (or
  documented otherwise)
- [ ] Every cross-isolation call boundary checked against the
  isolation domain on each side
- [ ] Existing KVO callbacks, `AVPlayer` periodic time observers,
  `NotificationCenter` observers verified to fire on the expected
  queue
- [ ] No new race between a `@MainActor` reader and a non-isolated
  writer (or vice versa)
- [ ] `deinit` order safe: observers / subscriptions released
- [ ] Long-running tasks have cancellation paths

### Step 5: Cross-reference against the plan (if one exists)

If auditing against a plan document: does the change match the plan's stated scope, or has scope crept? Out-of-scope changes are themselves a regression risk — they were never reviewed.

## Output format

Use this exact structure. The severity ladder matches `swift-code-review`
(BLOCKER / WARNING / SUGGESTION) so findings cross-reference cleanly. No
emoji per the global rule.

```markdown
## Audit: <change identifier — file path, branch name, or plan title>

**Surface:** <one-line summary of what changed>

### BLOCKER
<Findings that will break something with high confidence. Must be addressed.>
- `<file>:<line>` — <what breaks, why, what to do>

### WARNING
<Findings that may break something or that depend on assumptions worth checking.>
- `<file>:<line>` — <what could break, what assumption is in play>

### SUGGESTION
<Low-confidence or low-impact observations. Worth a quick look, not worth blocking on.>
- `<file>:<line>` — <observation>

### Cleared
<Areas explicitly audited and found safe. Brief — one line each. Helps the reader trust the audit.>
- <area>: <why it's safe>
```

If a section has no findings, write `_None_` under it rather than omitting it. The structure signals what was checked.

## Calibration: what to flag, what to skip

Calibrate findings honestly. Inflating severity erodes trust in future audits.

**Flag as BLOCKER** when:
- A caller will definitely break (compile error or runtime crash on a normal path).
- A behavioural change definitely affects user-visible behaviour in a way the author likely didn't intend.

**Flag as WARNING** when:
- A caller *probably* breaks but you can't fully verify without running it.
- A behavioural ripple is plausible but depends on timing or state you can't observe statically.

**Flag as SUGGESTION** when:
- A pattern looks suspicious but you have no concrete failure case.
- Documentation, comments, or tests reference the changed area but aren't broken yet.

**Do NOT flag:**
- Style, naming, or readability issues. Use a code review skill for that.
- Test files that need trivial updates to keep compiling — note them in "Cleared" if relevant, don't fabricate severity.
- Speculative "in some future state this could break" thoughts with no current basis.

## Worked example

The output below was produced for an actual change in `Chagi/Shared/Player/VODPlayerViewModel.swift` where `handleBackground()` and `handleForeground()` were modified to track `wasPlayingBeforeBackground`. The skill's job was to spot that the fix was *incomplete* — the real culprit was an unrelated KVO observer.

```markdown
## Audit: Chagi/Shared/Player/VODPlayerViewModel.swift

**Surface:** `handleBackground()` and `handleForeground()` modified to gate resume on `wasPlayingBeforeBackground`.

### BLOCKER
- `VODPlayerViewModel.swift:155` — KVO observer on `currentItem?.status` calls `player.play()` unconditionally when the item enters `.readyToPlay`. This fires on return from background (item re-stabilises), restarting playback regardless of `wasPlayingBeforeBackground`. The new guard in `handleForeground()` is bypassed. Gate the observer on the same flag or remove the auto-play.

### WARNING
- `VODPlayerViewModel.swift:114` — `stopPlayer()` nils `viewModel.player` but `AVPlayerView.updateUIViewController` only assigns the new player when `playerController.player == nil`. The `AVPlayerViewController` retains the old AVPlayer instance after `stopPlayer()` runs. Not the current bug, but unsafe if `loadPlaybackUrl()` runs after `stopPlayer()`.

### SUGGESTION
- `Info.plist:24` declares `UIBackgroundModes = [audio]`. This grants the player permission to keep playing in background. Combined with the observer auto-play, this is what makes the timeline advance during the bug window. Worth confirming this background mode is actually required.

### Cleared
- `handleBackground()` / `handleForeground()` themselves: the `wasPlayingBeforeBackground` flag is set/cleared correctly and `player.pause()` is called on the right transitions.
- Concurrency: no new async work, no new shared state, no isolation changes.
```

This example demonstrates the value of Step 3 (behavioural ripples) — the BLOCKER finding wasn't in the diff at all.

## Why this skill exists

The reason behavioural ripples are the hardest class of bug is that they're *invisible at the change site*. A developer modifies one function and the compiler and test suite both pass, but a KVO observer or NotificationCenter chain elsewhere now behaves differently because of an indirect interaction. Code review by humans typically misses these for the same reason — reviewers look at the diff, not at what the diff implies.

The audit process above is structured to force attention onto the parts of the system that *aren't* in the diff but are reachable from it. Steps 2 and 3 are where most of the value lives.

Be honest. If you can't find anything wrong, say so plainly — `_None_` under each severity heading and a populated "Cleared" section is a more useful audit than a list of fabricated low-confidence findings.
