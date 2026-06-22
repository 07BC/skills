# Concurrency Bug Patterns — failure catalogue

Real failure modes, each with the symptom, the cause, and the fix. Use alongside
`hotspots.md` (which tells you *where* to look). When a review or a flaky test smells
of concurrency, match the symptom here first.

## Actor reentrancy: check-then-act across an `await`

**Symptom:** state mutated twice, a guard that "can't" fail does, duplicated network calls.

**Cause:** an actor's execution can be interleaved at every `await`. A value read before
the suspension may be stale after it, because another call ran on the actor in between.

```swift
actor ImageLoader {
    var cache: [URL: Image] = [:]
    var inFlight: Set<URL> = []

    func load(_ url: URL) async throws -> Image {
        if let img = cache[url] { return img }
        // ❌ two concurrent callers both pass this guard before either inserts
        let img = try await download(url)   // suspension — reentrancy window
        cache[url] = img
        return img
    }
}
```

**Fix:** record the in-flight work *before* the `await` and dedupe on it (store a `Task`
per key and await that), or re-check the invariant after the suspension. Never assume an
actor's state is unchanged across an `await`.

## Continuation resumed zero or twice

**Symptom:** a call hangs forever (zero), or the app traps with "continuation resumed
more than once" (twice).

**Cause:** a `withCheckedContinuation` whose resume isn't matched 1:1 with every exit
path — an early `return`, a delegate that fires again, an error branch that forgets to
resume.

**Fix:** ensure exactly one resume on every path. Guard against double-fire with a
captured flag if the underlying callback is not single-shot. Use the **checked**
variants in debug — they trap on misuse instead of corrupting silently.

## Unbounded `AsyncStream`

**Symptom:** memory climbs under load; consumer falls behind producer.

**Cause:** default unbounded buffering plus a producer faster than the consumer, or a
continuation that is never `finish()`ed so the stream — and everything it captures —
never deallocates.

**Fix:** set an explicit buffering policy (`.bufferingNewest(n)`), and `finish()` the
continuation on every teardown path (`onTermination`, cancellation, deinit of the owner).

## Swallowed errors / unobserved work in `Task {}`

**Symptom:** a failure disappears; "it just didn't happen" with no log.

**Cause:** a fire-and-forget `Task {}` whose thrown error is never awaited, so it's
dropped on the floor. Also loses structured cancellation — the task outlives its logical
parent.

**Fix:** prefer structured concurrency (`async let`, task groups) so errors propagate. If
an unstructured `Task` is genuinely needed, handle its error inside the closure and store
the handle so it can be cancelled.

## Blocking the main actor with synchronous work

**Symptom:** UI hitches; a "background" operation freezes the screen.

**Cause:** heavy synchronous work inside a `@MainActor` context, or an `async` function
that — under Swift 6.2 caller-stays-on-actor defaults — never actually leaves the main
actor because nothing marked it `@concurrent`.

**Fix:** mark the genuinely-offloadable function `@concurrent`, or move the heavy work
into a `nonisolated` async function. Do not assume an `async` function hops off the
caller's executor — under `NonisolatedNonsendingByDefault` it doesn't unless told to.

## `@MainActor`-as-a-fix

**Symptom:** isolation errors vanish but races move elsewhere; everything serialises.

**Cause:** annotating a type `@MainActor` to silence a diagnostic rather than because the
state is truly UI-bound. It makes the compiler happy and hides the real ownership
question.

**Fix:** identify the real isolation owner. Shared mutable state that isn't UI-bound
wants its own `actor`, not the main one.
