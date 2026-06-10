# Swift Testing — isolation

The single most expensive trap in this skill is the `@Test + @MainActor + MainActor.assumeIsolated` interaction. This doc documents what Swift Testing actually does at the runtime level, when `MainActor.assumeIsolated` is safe to call from a test, and why "Swift 6 checks task isolation, not thread identity" is the diagnostic phrase that makes it click.

Read this **after** `references/concurrency.md`. That doc covers the patterns you should reach for; this doc covers the trap you must avoid.

## The Swift Testing concurrency model

`@Test` is a macro. It generates a `@Sendable` outer closure that the test driver schedules on the cooperative thread pool. **That outer closure is not main-actor-isolated.** The driver does not establish a `MainActor`-isolated task context unless you do so explicitly.

Annotating the `@Test` function with `@MainActor` makes the **function body** main-actor-isolated. It does not change the macro-generated outer closure, and — crucially under Swift 6 — it does not change the task-level isolation that `MainActor.assumeIsolated` checks.

```swift
@Test                      // outer closure: @Sendable, not main-actor-isolated
@MainActor                 // function body: main-actor-isolated
func test() async throws { // task at this point: ???
    MainActor.assumeIsolated { /* may trap */ }
}
```

The question mark in the third comment is the bug.

## "Swift 6 checks task isolation, not thread identity"

In Swift 5's concurrency model, `MainActor.assumeIsolated` checked whether the current thread was the main thread. If you happened to be on the main thread, the precondition held, and the closure ran.

In Swift 6's strict model, `MainActor.assumeIsolated` checks the **task's declared isolation**. Even if the current code is executing on the main thread, the precondition fails if the surrounding task is not main-actor-isolated.

This is the breaking change that makes `@Test @MainActor` insufficient. The test function's body is annotated `@MainActor`, but the task the driver scheduled for the test does not carry main-actor isolation. So when production code (called transitively from the test) reaches a `MainActor.assumeIsolated { }`, the runtime checks the task isolation, sees it isn't `@MainActor`, and traps.

## When `MainActor.assumeIsolated` is safe to call from a test

**Safe:**

```swift
// 1. Direct call from a @MainActor test body to an isolated context.
// This is rare and usually unnecessary — if you're already on the main actor,
// you don't need assumeIsolated.

// 2. Called from a SwiftUI View body that the test renders via a preview-driver
// helper. The View's body has a runtime-guaranteed main-actor context.
```

**Unsafe (will trap under Swift 6):**

```swift
// ❌ Calling a `nonisolated` factory whose body is MainActor.assumeIsolated
// from inside a @Test function, regardless of @MainActor on the function.

nonisolated static var preview: ArticleService {
    MainActor.assumeIsolated {
        ArticleService(...)
    }
}

@Test @MainActor func test() async throws {
    let service = ArticleService.preview   // TRAPS HERE under Swift 6
}
```

The trap fires because the call site's task does not carry main-actor isolation, even though the function body is `@MainActor`-annotated. The macro-generated outer closure is the boundary.

## Why `@Entry` forces this pattern (and what to do about it)

`@Entry` synthesises a **nonisolated** `defaultValue` property on `EnvironmentValues`. The default expression must be evaluable from a nonisolated context. If your default is a `@MainActor`-isolated factory, the common workaround is:

```swift
extension EnvironmentValues {
    @Entry var articleService: ArticleService = .preview
}

extension ArticleService {
    nonisolated static var preview: ArticleService {
        MainActor.assumeIsolated {
            ArticleService(...)
        }
    }
}
```

This works in production because SwiftUI evaluates the default inside a `View` body, which carries a main-actor-isolated task context the runtime trusts. It does **not** work in a Swift Testing `@Test` function, where the task context is whatever the driver scheduled.

### Mitigations

1. **Don't test the factory directly.** Test the thing the factory produces by constructing it explicitly in the test:

   ```swift
   @Test("Service seeds expected rows")
   func seedsRows() async throws {
       let container = try ModelStack.makePreviewContainer()
       let sut = await ArticleService(modelContainer: container)
       await sut.seedDefaults()

       let lists = try await sut.fetchArticleLists()
       #expect(lists.count == 1)
   }
   ```

   This avoids `assumeIsolated` entirely. The test exercises the seeding contract, not the factory's isolation gymnastics.

2. **If you must test the factory**, drive it through a `View` that the test renders, so the runtime can establish main-actor isolation:

   ```swift
   @Test("Preview factory produces a usable service")
   func previewFactory() async throws {
       try await MainActor.run {
           let service = ArticleService.preview  // safe: rendered context
           #expect(service.modelContext != nil)
       }
   }
   ```

   `MainActor.run` does establish the isolation `assumeIsolated` needs. This is the one case where wrapping a whole test body in `MainActor.run` is justified.

3. **Refactor the production code.** If `@Entry` is forcing a `nonisolated` default that papers over a real isolation mismatch, the design is the bug. Hoist the service construction into the composition root (`AppDependencies`) where `@MainActor` is honest, and pass the service through `.environment(\.articleService, ...)` instead of relying on the `@Entry` default.

## Case study: the Story 01b debug spiral

The setup:
- `ArticleService.preview` was `nonisolated static var preview` with `MainActor.assumeIsolated { ... }` inside.
- The test was `@Test @MainActor func test() async throws { ... }`.
- The test called `ArticleService.preview` and `ModelStack.makePreviewContainer()` (also `@MainActor`) in the same body.
- The test trapped at `MainActor.assumeIsolated`.

The engineer assumed `@MainActor` on the test was sufficient — it isn't. The task driving the test did not carry main-actor isolation. Two hours of debugging eventually produced a "fix": rewrite the test to call `.preview` twice and assert `first !== second`, which is a property most factories satisfy trivially. **The original acceptance criterion (factory seeds 1 ArticleList + 2 Articles) was no longer tested.**

The correct fix was Mitigation 1 above — construct the service explicitly in the test, do not go through `.preview` at all, and assert on the seeded rows directly. This would have taken ten minutes and produced a test that actually verified the spec.

## Compiler limitation: task group + `@MainActor` child + `AsyncPublisher.values`

A specific shape trips the region-based isolation checker and fails to compile with `pattern that the region-based isolation checker does not understand how to check. Please file a bug`:

```swift
// ❌ Trips the region-based isolation checker.
try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { @MainActor in
        for await _ in cache.objectWillChange.values where isSettled() { return }
    }
    group.addTask { try await Task.sleep(for: .seconds(2)); throw TimeoutError() }
    try await group.next(); group.cancelAll()
}
```

It is a compiler limitation, not a real data race — but you cannot ship code that doesn't compile. Don't fight it with annotations; use the simpler `AsyncStream` + Combine `.sink` continuation gate instead (see `references/concurrency.md`, "Subscribe-then-recheck"), and rely on a `.timeLimit(.minutes(1))` suite trait for the hang backstop rather than a hand-rolled timeout child task:

```swift
// ✅ No task group, no AsyncPublisher.values — compiles, and is simpler.
if isSettled() { return }
let (stream, continuation) = AsyncStream<Void>.makeStream()
let token = cache.objectWillChange.sink { _ in continuation.yield() }
defer { token.cancel() }
if isSettled() { return }
for await _ in stream where isSettled() { return }
```

## Diagnostic phrases

When a Swift Testing trap mentions `assumeIsolated`, the diagnostic phrase is **"Swift 6 checks task isolation, not thread identity."** Once that phrase is in your head, the fix path becomes obvious:

1. The trap is about the task, not the thread.
2. The task's isolation comes from the macro-generated closure, not the `@MainActor` on the function.
3. Either avoid `assumeIsolated` in code reachable from tests, or establish main-actor isolation explicitly via `MainActor.run`.

**Crash budget reminder:** if you can't fix an isolation trap in five minutes, stop and escalate (see SKILL.md). Do not rewrite the test to a weaker assertion — that loses the coverage and hides the bug.
