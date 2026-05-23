# Swift Testing — concurrency patterns

How to test `@MainActor`-isolated services, bridge async-callback APIs without `Task.sleep`, scope clocks and UUID providers per-test with `@TaskLocal`, and handle async cleanup when `deinit` cannot.

Read this **after** the "Concurrency contract" section in `SKILL.md`. The hard-stop bans in `SKILL.md` are the law; this file is the toolkit for staying within them.

## Testing `@MainActor`-isolated services

A `@MainActor @Observable` service is the right design for a SwiftUI domain service. Testing it does **not** require putting `@MainActor` on the test function — see the hard-stop ban. Use one of these three patterns instead:

### Pattern 1 — Construct in-body, `await` the methods

Easiest when the SUT is `@MainActor`-isolated. The test stays nonisolated; the `await` on each SUT method hops to the main actor and back.

```swift
@Suite(.tags(.home))
struct HomeServiceTests {

    @Test("Loads channels on first activation")
    func loadsOnActivation() async throws {
        let mockAPI = MockChannelAPI()           // actor
        let sut = await HomeService(api: mockAPI) // @MainActor init

        await sut.activate()

        let endpoints = await mockAPI.recordedEndpoints
        #expect(endpoints == ["/channels/featured"])
    }
}
```

The SUT is not stored as a suite property — it cannot be, because `@MainActor` types are not safely stored on a nonisolated `Sendable` struct. Construct per-test in the body.

### Pattern 2 — `await MainActor.run` for synchronous property reads

When the SUT exposes synchronous `@MainActor`-isolated properties (typical for `@Observable` services), reading them from a nonisolated test requires hopping. `await MainActor.run` does this without making the whole test main-actor-isolated:

```swift
@Test("Surfaces error state when API fails")
func surfacesError() async throws {
    let mockAPI = MockChannelAPI()
    await mockAPI.stub(.failure(APIError.network))

    let sut = await HomeService(api: mockAPI)
    await sut.activate()

    let state = await MainActor.run { sut.loadState }
    #expect(state == .failed)
}
```

This is the only legitimate use of `MainActor.run` in a test — wrapping the assertion's property read. Do not wrap the whole test body in `MainActor.run`; that defeats parallelism just like `@MainActor` on the function would.

### Pattern 3 — `MainActor.assumeIsolated` is not for tests

`MainActor.assumeIsolated` exists for synchronous call sites that are already known by the runtime to be on the main actor (e.g. a SwiftUI `View` body calling a `@MainActor` factory). **Inside a Swift Testing `@Test` closure, the runtime cannot make that guarantee** even when `@MainActor` is applied to the test function — see `references/isolation.md` for the underlying mechanism.

If your production code uses `nonisolated + MainActor.assumeIsolated` in a factory (a common workaround for `@Entry` defaults), do not test the factory by calling it from a `@Test` function. Test the *thing the factory produces* by injecting an already-constructed instance, or test the factory in a `@MainActor`-isolated context the runtime trusts (e.g. by driving it through a `View`-rendered preview, not directly).

## Bridging async-callback APIs

`Task.sleep` is banned (see `SKILL.md`). Real callback APIs need real bridging.

### `confirmation` for delegate / notification callbacks

Use `confirmation` when the SUT will call a closure or post a notification a known number of times within the test:

```swift
@Test("Posts didUpdate notification when channel loads")
func postsDidUpdate() async throws {
    await confirmation("didUpdate fires exactly once") { confirm in
        let mockAPI = MockChannelAPI()
        let sut = await HomeService(api: mockAPI)

        let observer = NotificationObserver(for: .didUpdate) {
            confirm()
        }
        defer { observer.cancel() }

        await sut.activate()
    }
}
```

`confirmation` accepts an `expectedCount:` parameter for known repetitions; it fails if the count doesn't match. No timeouts, no sleeps — the test driver waits for the expected count or the body to return.

### `withCheckedContinuation` for legacy completion handlers

When the API takes a completion closure and you need to await its result, bridge with `withCheckedContinuation`:

```swift
@Test("Auth token completes with refreshed value")
func refreshesToken() async throws {
    let sut = AuthService(api: MockAuthAPI())

    let token = await withCheckedContinuation { continuation in
        sut.refreshToken { result in
            continuation.resume(returning: result)
        }
    }

    #expect(token.value == "refreshed")
}
```

`withCheckedThrowingContinuation` for completions that pass a `Result` or can throw. Always `resume` exactly once — Swift's runtime traps on double-resume and on never-resume.

### `AsyncStream` for sequences of events

When the SUT emits a sequence of events (e.g. WebSocket messages, scrubbing updates), bridge to an `AsyncStream` and iterate:

```swift
@Test("Emits three progress updates during sync")
func emitsProgress() async throws {
    let sut = SyncService()
    var updates: [SyncProgress] = []

    let stream = await sut.progressStream()
    for await update in stream {
        updates.append(update)
        if updates.count == 3 { break }
    }

    #expect(updates.map(\.percentage) == [0.33, 0.66, 1.0])
}
```

If the stream might never produce, wrap the iteration in a `withTimeout`-style helper. Do **not** use `Task.sleep` to "give it time."

## `@TaskLocal` for clocks, UUIDs, and locales

Mocking `Date.now`, `UUID()`, or `Locale.current` by injecting a closure into every type that needs them is invasive. `@TaskLocal` scopes the value to a single test:

```swift
enum TestClock {
    @TaskLocal static var now: () -> Date = { Date() }
}

@Test("Stamps record with current time")
func stampsRecord() async throws {
    let fixed = Date(timeIntervalSince1970: 1_700_000_000)
    try await TestClock.$now.withValue({ fixed }) {
        let sut = RecordService()
        let record = await sut.makeRecord()
        #expect(record.createdAt == fixed)
    }
}
```

Production code reads from `TestClock.now()` (or a similarly-named domain provider). The `@TaskLocal` machinery scopes the override to the structured task tree the test runs in — no leakage across tests, no shared mutable state, no `static var` race.

The same pattern works for `UUID` providers, locale, calendar, time zone, and feature-flag overrides.

## Async cleanup

Swift Testing maps `tearDown()` to `deinit`, but `deinit` cannot `await`. In a Swift 6 world that means **you cannot do async cleanup in `deinit`**. Two correct alternatives:

### Per-test instances + no cleanup needed

The simplest path: construct mocks per-test in the function body, let them go out of scope at the end. Actors and `Sendable` value types deallocate without any explicit cleanup. **Do this by default.**

### Explicit cleanup at end of test

When the test sets up something with a real teardown cost (a temporary directory, a registered `URLProtocol`, an `AsyncStream` continuation), do the cleanup at the end of the test:

```swift
@Test("Writes export file to staging directory")
func writesExport() async throws {
    let tempDir = try FileManager.default.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let sut = ExportService(stagingDirectory: tempDir)
    try await sut.exportChannels()

    let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
}
```

`defer` runs even if `#expect` fails or the test throws. For async cleanup, wrap in `Task { await ... }` inside `defer`, but be aware the task is not awaited — only use this when the cleanup is best-effort.

### Suite-level `deinit` for non-async cleanup

If you do have a `Sendable` resource that needs synchronous cleanup, `deinit` on the suite struct still works:

```swift
@Suite(.tags(.networking))
struct URLProtocolTests {
    init() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    deinit {
        URLProtocol.unregisterClass(MockURLProtocol.self)
    }
}
```

This is the rare legitimate case. For anything `async`, do it in the test body.

## When `init()` must be `async throws`

Swift Testing supports `init() async throws` on a `@Suite` struct. Use it when:

- The suite needs to construct a `@MainActor`-isolated SUT once and store it
- The setup involves awaiting an actor (e.g. seeding a mock store)

```swift
@Suite(.tags(.preferences))
struct PreferencesServiceTests {
    let sut: PreferencesService
    let store: MockUserDefaults

    init() async throws {
        store = MockUserDefaults()
        await store.set("rtmp://default", forKey: "server_url")
        sut = PreferencesService(store: store)
    }
}
```

The suite runs `init()` before every test (not once for the suite — once *per test*). Each test gets a fresh `store` and `sut`. No shared mutable state, no cleanup needed.

If the SUT is `@MainActor`-isolated, do **not** store it — see "Testing `@MainActor`-isolated services" above.

## Diagnostic checklist when a test races

1. Run the suite under repetition: `swift test --num-workers 8 --repetitions 50 --filter MySuite`.
2. If a test fails 1-in-N rather than every run, you have a race.
3. Inspect what's shared across tests:
   - `static var` (any non-`let` static)
   - Singletons accessed via `.shared` / `.default` / `.standard`
   - `@TaskLocal` set in `init()` (does not bleed across tests, but check for leaks into helpers)
   - File-system paths, port numbers, notification names
   - Captured `Task { }` blocks that the test does not `await`
4. Eliminate the sharing. **Do not** add `.serialized`. **Do not** add `@MainActor` to the test.

If after eliminating sharing the test still races, the SUT itself has a concurrency bug — the test is doing its job. Escalate.
