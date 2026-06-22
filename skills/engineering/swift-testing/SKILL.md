---
name: swift-testing
description: Generate unit tests using Apple's Swift Testing framework. Use when asked to write tests, check test coverage, or create test files for Swift code. Triggers on requests like "write unit tests for {file}", "test this code", "add tests for my changes", or any Swift testing task. NOT for XCTest - this skill uses Swift Testing (@Test, @Suite, #expect).
---

# Swift Testing

Generate unit tests using Apple's Swift Testing framework (not XCTest).

## Quick Reference

```swift
import Testing

@Suite(.tags(.feature))
struct MyFeatureTests {

    @Test("Description of what is being tested")
    func behaviourUnderTest() async throws {
        // Given
        let sut = MyFeature()
        let input = "test"

        // When
        let result = try await sut.process(input)

        // Then
        #expect(result == "expected")
    }
}
```

**Every `@Test` function is `async throws`.** Swift Testing runs tests in parallel by default; `async throws` is the contract that keeps parallel execution safe and lets you `await` mocks, `try #require` optionals, and bridge async APIs without changing the signature later. Synchronous tests are not an optimisation — they are a regression that paints the test into a corner the moment a collaborator becomes an actor.

## Core Syntax

| XCTest | Swift Testing |
|--------|---------------|
| `class FooTests: XCTestCase` | `@Suite struct FooTests` |
| `func testFoo()` | `@Test func foo() async throws` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `setUpWithError()` | `init() async throws` |
| `tearDown()` | per-test cleanup in body (see `references/concurrency.md`) |

## Test Structure

### Every test file MUST have:
1. `@Suite` with a tag: `@Suite(.tags(.featureName))`
2. `@Test` with a description: `@Test("User can log in with valid credentials")`
3. Given/When/Then structure in test body

### Use `init()` to reduce duplication:
```swift
@Suite(.tags(.auth))
struct AuthServiceTests {
    let sut: AuthService
    let mockAPI: MockAPIClient

    init() {
        mockAPI = MockAPIClient()
        sut = AuthService(api: mockAPI)
    }
}
```

Stored properties on a `@Suite` struct must be `Sendable`. If your SUT is not `Sendable` (e.g. it is `@MainActor`-isolated or holds non-`Sendable` collaborators), do not store it as a property — construct it inside the test body instead. See `references/concurrency.md` for the `@MainActor` patterns.

## Concurrency contract

Swift Testing runs tests in parallel by default. The whole point of the framework is that the test runner uses the cooperative thread pool, scheduling tests concurrently within a process. **Every rule below exists to keep that parallelism intact.** Reaching for `.serialized`, `@MainActor`, or locks is the testing equivalent of converting an `actor` to a `@MainActor class` — it makes the compiler happy and hides the bug.

### Hard-stop bans

If you find yourself typing any of these, stop and re-read this section:

- **Never write a synchronous `@Test` function.** No `@Test func foo()` — always `@Test func foo() async throws`. Even if the body has no `await` today, the signature must be future-proof.
- **Never apply `.serialized` to a test or suite.** Not at the `@Test` level, not at the `@Suite(.serialized)` level. The only legitimate reasons for `.serialized` are (a) the suite tests a true process singleton you cannot inject around (rare — usually means a production bug), or (b) the suite drives an ordering-dependent integration scenario explicitly. Neither applies to a unit test. If you think you need `.serialized` to fix a race, you have a shared-state bug — find it.
- **Never apply `@MainActor` to a `@Test` function.** It serialises every test in the suite onto the main actor and defeats parallelism. To assert on `@MainActor`-isolated state, use `await MainActor.run { #expect(...) }` for the assertion only, or `await` the SUT's method normally and let isolation inference handle the hop. See `references/concurrency.md`.
- **Never declare a mock as `class Mock: @unchecked Sendable`.** Never use `NSLock`, `os_unfair_lock`, or `Mutex` inside a mock to "make it thread-safe." If the mock holds mutable state, the mock is an `actor`. If the mock holds no mutable state (pure stub or closure-injected callback), it can be a struct or `final class` conforming to `Sendable` — no actor needed. See "Mock taxonomy" below.
- **Never use `nonisolated(unsafe) static var` for shared test fixtures.** Each test creates its own mocks. There is no such thing as a shared fixture in a parallel test suite — that is just a race waiting to happen.
- **Never use `Task.sleep` (or `try await Task.sleep`) to wait for state to settle.** It is flaky by construction. Use `confirmation { }` for callback APIs, `withCheckedContinuation` for completion handlers, or `await` the actor directly. See `references/concurrency.md`.
- **Never use a polling helper (`waitUntil`, `pollUntil`, manual `Task.yield()` retry loops) to wait for a SUT method's own work to finish.** If the SUT method launches a `Task` and returns synchronously, the test cannot deterministically know when the work completes — that is a SUT design bug, not a testing problem. Refactor the SUT method to `async` and `await` it from the test. Polling is acceptable ONLY when waiting on genuinely uncontrolled async — Timer-driven loops, KVO `publisher(for:).values`, WebSocket message streams, NotificationCenter posts — and even then, prefer `for await … in .values { }` over polling. A common smell: `vm.doSomething()` followed by `await waitUntil { await mock.callCount == 1 }` — that's a hint that `doSomething` should be `async`. See "Fire-and-forget Tasks are a test smell" in `references/concurrency.md` and the case study below.
- **Never silence Swift 6 concurrency warnings in test targets.** `@preconcurrency import`, `@unchecked Sendable`, and `nonisolated(unsafe)` in test code are not workarounds — they are the bug.
- **Crash budget: 5 minutes.** If a test traps at runtime and you cannot fix it without changing the SUT's assertion contract within 5 minutes, **stop and escalate**. Do not rewrite the test to a weaker assertion that sidesteps the crash. That is silent coverage loss. See `references/anti-patterns.md` ("weaker-after-crash").
- **Never assert on test-built state.** A test that constructs its own collaborators, mutates them, then asserts on its own mutations is testing the collaborator, not the SUT. The test must observe state **through the SUT's own returned instance or its own context**. See `references/anti-patterns.md` ("parallel-setup tests").
- **Never assert on a value the mock was configured to return.** If the mock is stubbed to return `X` and the SUT passes `X` straight through, `#expect(result == X)` tests the stub, not the SUT — delete the SUT's logic and it still passes. Observe production behaviour **through the consumer**: assert the SUT's *transformation/derivation* of the mock's output, or assert (on a call-recorder `actor`) that the SUT **called the dependency with the right inputs**. See `references/anti-patterns.md` ("pass-through-mock").

  ```swift
  // ❌ pass-through: stub returns the model, profile(for:) forwards it unchanged.
  //    The assertion checks the stub's own fixture, not any ProfileService logic.
  let stub = StubProfileAPI(profile: .fixture(name: "Ada"))
  let sut = ProfileService(api: stub)
  #expect(await sut.profile(for: "1")?.name == "Ada")

  // ✅ assert the SUT's own transformation
  let stub = StubProfileAPI(profile: .fixture(first: "Ada", last: "Lovelace"))
  let sut = ProfileService(api: stub)
  #expect(await sut.displayName(for: "1") == "Ada Lovelace")   // tests ProfileService's formatting

  // ✅ or assert the call the SUT made (recorder actor)
  let api = MockProfileAPI()                 // actor recording requests
  let sut = ProfileService(api: api)
  await sut.refresh(id: "42")
  #expect(await api.requestedIDs == ["42"])  // tests that the SUT asked correctly
  ```
- **No unit test runs longer than 1 second.** A slow unit test is almost always a `Task.sleep`/timeout/wall-clock wait in disguise — fix it deterministically (above), don't tune the duration. `.timeLimit` **cannot** enforce this: its granularity is a 1-minute minimum, so `.timeLimit(.seconds(1))` is illegal. Use `.timeLimit(.minutes(1))` only as a runaway-*hang* backstop on async suites; the real fix is removing the wait. See `references/concurrency.md`.

### Diagnostic workflow when a test is flaky

Before reaching for `.serialized` or `@MainActor`:

1. Run the suite with repetitions: `swift test --filter MyFeatureTests --num-workers 8 --repetitions 50` (or the Xcode equivalent — Product → Perform Action → Test Repeatedly).
2. If only one test in N runs fails, you have a race. If every run fails, you have a logic bug.
3. For races, list every piece of state shared across tests: `static` properties, singleton accesses, captured `Task { }` blocks without `await`, `@TaskLocal` values set in `init()` that bleed across tests, file-system paths, port numbers, notification names.
4. Eliminate the sharing. Do not serialise around it.

## Mock taxonomy

The shape of a mock depends on what it stands in for. **Picking the wrong shape is the root cause of most test races.**

**Decision rule — ask two questions before picking a shape:**

1. **Does this mock hold mutable state?** (Records calls, captures arguments, stores a value for the test to read back.) → Yes: `actor`. No: struct or `final class` conforming to `Sendable`.
2. **Does the production protocol have `async` methods?** → Mock method `async`-ness follows the production protocol. If protocol methods are synchronous, mock methods are synchronous. A stateful mock (`actor`) requires the protocol to have `async` methods so the test can `await` the actor's accessors — if the protocol is synchronous and you need a stateful mock, update the protocol first.

| Mock stands in for | Mock shape | Why |
|---|---|---|
| Shared mutable system state (UserDefaults, Keychain, FileManager, NotificationCenter, in-memory caches) | `actor` | Read/modify/write needs serialisation across calls. Actor is the only correct primitive — locks (`Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore`) are not approved and force synchronous call sites that clash with `async` test bodies. |
| Pure stub — returns fixed values, holds no mutable state | `struct` conforming to `Sendable` | No state changes → no actor needed. Mock method `async`-ness matches the protocol. If the protocol is sync, the stub is sync. |
| Call recorder / argument captor — test reads back what was called | `actor` | Mutable stored state (`var recordedEndpoints: [String]`, `var callCount: Int`) requires actor isolation. Protocol methods must be `async` so the test can `await` the actor's accessors. |
| `URLSession` and HTTP-layer mocking | `URLProtocol` subclass registered per-test | `URLProtocol` is the supported Apple extension point. The system handles request isolation; do not wrap in an actor. |
| `Date`, `UUID`, `Locale`, `Calendar`, clocks | `@TaskLocal` provider, or constructor-injected closure (`() -> Date`) | Tests scope the value to a single test via `$now.withValue(...) { ... }`. No shared mutable state across tests. |
| `@Observable` SwiftUI service or ViewModel (`@MainActor`-isolated) | The real type, exercised from the test with `await` | Don't mock your own `@Observable` services (MV) or ViewModels (MVVM). Construct the real type with mocked dependencies (MV: mocked fetcher actor; MVVM: `MockRepository`) and `await` its methods. See `references/concurrency.md`. |

### Worked example: `actor MockUserDefaults`

This is the exact shape Sonnet should generate when a test needs a `UserDefaults` substitute:

```swift
actor MockUserDefaults: KeyValueStore {
    private var storage: [String: Any] = [:]

    func string(forKey key: String) -> String? {
        storage[key] as? String
    }

    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
    }

    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}
```

The production code depends on a `KeyValueStore` protocol (with `async` methods), and the real implementation wraps `UserDefaults.standard`. The mock and the real type both conform. Tests construct `MockUserDefaults()` per-test and `await` its methods — no locks, no `@unchecked Sendable`, no `.serialized`.

If you cannot make the protocol's methods `async` because the call site is synchronous, the production code is the bug — preferences access from a synchronous context inside `@MainActor` code is a sign that the property should be hoisted to an `@Observable` service that loads it once at startup.

### Worked example: `struct StubChannelAPI` (stateless)

When the SUT only reads from a dependency (no state change), the mock is a plain struct. No actor, no `await` on mock accesses:

```swift
// Production protocol — sync, no state changes needed from callers
protocol ChannelAPIProtocol: Sendable {
    func fetchFeatured() async throws -> [Channel]
}

// Stub — fixed return value, no stored mutable state
struct StubChannelAPI: ChannelAPIProtocol {
    let channels: [Channel]

    func fetchFeatured() async throws -> [Channel] { channels }
}

// Test — no actor, no await on the stub itself
@Test("Displays channels returned by the API")
func displaysChannels() async throws {
    let stub = StubChannelAPI(channels: [.fixture(id: "A"), .fixture(id: "B")])
    let sut = await HomeService(api: stub)

    await sut.activate()

    let state = await MainActor.run { sut.loadState }
    #expect(state == .loaded(count: 2))
}
```

The stub method is `async` because the protocol method is `async` (the SUT `await`s it). The *stub itself* is not an actor — there is nothing to isolate.

## When NOT to write a test

Before writing anything, ask: **what regression would this test catch?** If the honest answer is "the Swift compiler stopped working" or "Apple's framework stopped working", do not write the test. Categories that typically need no test:

- **Exhaustive `switch` over an enum with no associated-value logic.** Compiler-enforced.
- **SwiftUI `View` bodies with no `@State` interaction.** Structural; the type checker is the test.
- **`@main App` struct bodies.** Opaque return types make the modifier chain unobservable from a test. Verify the composition root *constructs* (a smoke test) — do not try to assert the modifier graph.
- **Pure value types whose only members are `let` properties.** Construction is the test.
- **`Hashable` / `Equatable` conformances on enums.** Compiler-synthesised. `#expect(Route.a != Route.b)` verifies the compiler, not your code.
- **`Codable` round-trips for types with no custom coding.** Compiler-synthesised.
- **Type conformance** (`#expect(sut is SomeProtocol)`). If it didn't conform, the file wouldn't compile.

When you decide a unit of work needs no test, **state which existing test (or compile-time guarantee) covers each acceptance criterion**. Reporting "no test needed" without naming the existing coverage is the same as not checking.

The only behaviours worth testing on enums and value types are the ones the compiler *cannot* catch:
- Decoding the right case from external input (JSON, URL, raw value)
- `switch` dispatch side effects (the right branch ran, with the right output)
- Custom `Equatable`/`Hashable` implementations (anything not synthesised)

## What to Test

**DO test:**
- Guard clauses and early exits
- State changes from method calls
- Correct collaborator interactions
- Error handling paths
- Edge cases and boundary conditions

**DO NOT test:**
- **Process-global Apple singletons** — see "Never touch process-global state" below
- Apple frameworks (UIKit, SwiftUI, Foundation internals)
- Simple property getters/setters
- Private implementation details
- Third-party library internals

## Raising coverage

When the task is "increase coverage" rather than "test this change", treat it as a yield problem, not a sweep. Full playbook in `references/coverage.md`; the essentials:

- **Measure, don't infer** — `xcodebuild test … -enableCodeCoverage YES` then `xcrun xccov view --report`. Re-measure after each batch and record the delta.
- **Chase logic, not view bodies** — line coverage counts SwiftUI `View` bodies that unit tests don't cover by design. A low app % is usually "logic well-covered, view layer 0%". Stop climbing a file when the rest is `body`/logging/`#Preview`.
- **Prioritise by `uncovered lines × blast radius`** — grade blast radius with `gitnexus_impact` (`references/tooling.md`). Attack pure-logic types first (parameterise — cheapest %), then decode/error/nil/empty branches, then ViewModel edge branches.
- **Fix the seam first** — if you can't inject a stub, the injection point is the bug. Make it injectable (impact-gated; stop on HIGH/CRITICAL) before writing the test. Never reach for a singleton or real network to "make it testable".

Every new test must answer *what regression does this catch?* — a coverage number that rises while regression-catching power stays flat is false confidence.

## Never touch process-global state

**Unit tests must never read from or write to a process-global Apple singleton.** They are shared mutable state across the test process, leak between suites, and cause flaky CI under parallel scheduling.

**Banned in unit tests:**
- `UserDefaults.standard` (and any default-initialised `UserDefaults(suiteName:)` shared with the app)
- `FileManager.default`
- `NotificationCenter.default`
- `URLSession.shared`
- `UIPasteboard.general`
- `NSUbiquitousKeyValueStore.default`
- `Bundle.main` (mutating accessors)
- `HTTPCookieStorage.shared`, `URLCache.shared`
- Any other `.shared` / `.default` / `.standard` Apple accessor in `Foundation`, `UIKit`, `AppKit`, `WatchKit`, or `TVUIKit`

**Why:** Swift Testing runs suites in parallel by default. `.serialized` only serialises tests **within** the suite that declares it — it does **not** serialise across suites. Two suites both writing to `UserDefaults.standard` will race, and the race only appears on the CI scheduler. This is exactly how previously-green tests start failing on Apple TV 4K but pass locally.

**Always inject the dependency.** Production code must take the store as a parameter (constructor injection or initialiser default), and the test must pass a mock or in-memory implementation.

```swift
// BAD — touches UserDefaults.standard, races across suites
@Test("Registers default when key absent")
func registersDefault() async throws {
    UserDefaults.standard.removeObject(forKey: "server_url")
    sut.registerDefaults()
    #expect(UserDefaults.standard.string(forKey: "server_url") == "https://api.example.com")
}

// GOOD — mock store passed in, no global state
@Test("Registers default when key absent")
func registersDefault() async throws {
    let store = MockUserDefaults()  // actor wrapping in-memory dictionary
    let sut = PreferencesService(store: store)
    await sut.registerDefaults()
    let stored = await store.string(forKey: "server_url")
    #expect(stored == "https://api.example.com")
}
```

**`.serialized` is not a workaround.** If you find yourself adding `.serialized` to avoid a UserDefaults race, stop — inject a mock instead. `.serialized` will still flake when a *different* suite touches the same singleton.

**If the production code reaches for a singleton directly,** the production code is the bug — refactor it to accept the store via initialiser before writing the test. Do not work around it by mutating the singleton in `init()` / `deinit`.

### When refactor is genuinely out of scope

If the production code reaches for a global singleton and refactoring it
sits outside the current subtask's scope (e.g. you are adding a test next
to legacy code you must not touch), follow this order:

1. **Document the dependency.** Write a one-line TODO at the top of the
   test file naming the singleton and linking to a follow-up ticket.
2. **Write against an injected fake anyway.** If the SUT has a seam — an
   init parameter, a protocol, an optional override — use it. Sometimes
   the seam exists but isn't obvious; read the SUT before assuming there
   is none.
3. **If no seam exists, surface as a BLOCKER.** Report the missing
   injection point as a finding — do not write the test. Writing a test
   that touches the singleton and hoping CI doesn't notice is silent
   coverage loss that flakes on another developer's machine.

Never reach for `.serialized` to paper over this. `.serialized` does not
serialise across suites and will still race against any other test that
touches the same singleton.

## Avoid Tautological Tests

**Never write tests that only verify what was just set.** These tests always pass and verify nothing:

```swift
// BAD: Tautological - always passes, tests nothing
@Test("Stores value")
func storesValue() async throws {
    var value = ""
    value = "test"
    #expect(value == "test")  // Always true!
}
```

**Instead, verify observable side effects on collaborators:**

### Testing Setters - Check the store directly
```swift
// GOOD: Verifies the value reached the store with correct key
@Test("Persists value to store with correct key")
func persistsToStore() async throws {
    let store = MockUserDefaults()
    let sut = PreferencesService(store: store)

    await sut.setServerURL("https://test.example.com")

    // Verify the store directly - not via the wrapper
    let stored = await store.string(forKey: "server_url")
    #expect(stored == "https://test.example.com")
}
```

### Testing Getters - Pre-populate the store
```swift
// GOOD: Pre-populate store, then verify wrapper reads it correctly
@Test("Reads value from pre-populated store")
func readsFromStore() async throws {
    let store = MockUserDefaults()
    await store.set("https://existing.example.com", forKey: "server_url")  // Arrange first

    let sut = PreferencesService(store: store)

    let server = await sut.serverURL
    #expect(server == "https://existing.example.com")
}
```

### Key principle
The test should fail if the implementation is broken. Ask: "If I deleted the implementation, would this test fail?"

## Avoid Duplicate Tests

**Before writing tests, always check existing tests in the file to avoid duplication.**

### Types of duplication to avoid:

1. **Same code path, different data** - If two tests exercise identical code with different enum cases or values, keep only one:
```swift
// BAD: Both test the same RawRepresentable<Int> extension
@Test("Reads Resolution from store")
func readsResolution() { ... }

@Test("Reads FrameRate from store")  // DELETE - same code path
func readsFrameRate() { ... }

// GOOD: One test is sufficient
@Test("Reads enum from pre-populated store")
func readsEnumFromStore() { ... }
```

2. **Testing framework behaviour** - Don't test that Apple's frameworks work:
```swift
// BAD: Tests AppStorage/UserDefaults behaviour, not your code
@Test("Different keys use separate storage")
func keysUseSeparateStorage() { ... }  // DELETE
```

3. **Redundant edge cases** - One representative test per edge case type:
```swift
// BAD: Testing same "invalid input" logic twice
@Test("Returns default for invalid Resolution")
@Test("Returns default for invalid FrameRate")  // DELETE

// GOOD: One test covers the behaviour
@Test("Returns default when stored value does not match enum case")
```

### Checklist before adding tests:
- [ ] Read existing tests in the file first
- [ ] Does a test already cover this code path?
- [ ] Am I testing my code or Apple's framework?
- [ ] Does this test touch `UserDefaults.standard`, `FileManager.default`, `NotificationCenter.default`, or any other process-global singleton? (If yes, inject a mock instead — see "Never touch process-global state")
- [ ] Would removing this test reduce confidence in the code?

## Common Patterns

### Testing async code
```swift
@Test("Fetches user data successfully")
func fetchUser() async throws {
    let user = try await sut.fetchUser(id: "123")
    #expect(user.name == "Test User")
}
```

### Testing errors
```swift
@Test("Throws error for invalid input")
func invalidInput() async throws {
    #expect(throws: ValidationError.self) {
        try sut.validate("")
    }
}
```

### Testing with mocks
```swift
@Test("Calls API with correct parameters")
func callsAPI() async throws {
    let mockAPI = MockAPIClient()  // actor
    let sut = DataService(api: mockAPI)

    await sut.loadData()

    let lastEndpoint = await mockAPI.lastEndpoint
    let callCount = await mockAPI.callCount
    #expect(lastEndpoint == "/data")
    #expect(callCount == 1)
}
```

### Fire-and-forget Tasks are a test smell

If you're tempted to poll a mock's call count after invoking a SUT method, the SUT method is the problem — not the test.

**Wrong** (SUT method launches an internal `Task` and returns synchronously, forcing the test to poll):

```swift
// Production:
@MainActor @Observable final class ArticleViewModel {
    func openArticle(_ article: Article) {                       // sync
        Task { @MainActor in                                      // fire-and-forget
            let source = try? await repo.fetch(article)
            self.selectedArticle = source.map(SelectedArticle.init)
        }
    }
}

// Test (forced to poll because there's no awaitable handle):
@Test func opensArticle() async throws {
    let mock = MockRepo()
    let sut = await ArticleViewModel(repo: mock)
    sut.openArticle(article)
    await waitUntil { await mock.fetchCallCount == 1 }   // flaky
    let count = await mock.fetchCallCount
    #expect(count == 1)
}
```

**Right** (SUT method is `async`; test `await`s and reads state immediately afterwards):

```swift
// Production:
@MainActor @Observable final class ArticleViewModel {
    func openArticle(_ article: Article) async {                  // async
        let source = try? await repo.fetch(article)
        self.selectedArticle = source.map(SelectedArticle.init)
    }
}

// Test (deterministic, no polling):
@Test func opensArticle() async throws {
    let mock = MockRepo()
    let sut = await ArticleViewModel(repo: mock)
    await sut.openArticle(article)
    let count = await mock.fetchCallCount
    #expect(count == 1)
}
```

The polling version compiles fine but is flaky AND silently breaks the day someone refactors `openArticle` to `async` — the test then has a "missing `await`" compile error that's easy to miss in a rebase. Always prefer making the SUT method `async`.

**When polling IS acceptable**: only for genuinely uncontrolled async — Timer-driven loops inside the SUT (e.g. a `liveTime` ticker), KVO `publisher(for:).values` consumers, WebSocket message streams, NotificationCenter handlers. In those cases the SUT cannot expose an awaitable handle because the source itself is push-driven. Even then, prefer `for await event in stream.values { ... }` inside the test where possible — only fall back to `waitUntil`-style polling as a last resort.

**Case study — PROJ-1868 rebase (May 2026):** A characterisation test wrote `vm.openArticle(article, categoryId: 42)` against a sync `openArticle` API and then `await waitUntil { mock.callCount == 1 }`. When main was rebased in with `openArticle` refactored to `@MainActor async`, the test compiled at first (the sync call site still looked OK), but on CI it failed with `expression is 'async' but is not marked with 'await'`. Had the test been written to `await vm.openArticle(...)` from day one, the refactor on main would have been transparent.

### Parameterised tests
```swift
@Test("Validates email formats", arguments: [
    ("valid@example.com", true),
    ("invalid", false),
    ("@missing.com", false)
])
func emailValidation(email: String, expected: Bool) async throws {
    #expect(sut.isValidEmail(email) == expected)
}
```

**Pair inputs with a tuple, not `zip`.** Two `arguments:` collections produce the **Cartesian product** (every combination), which is usually what you want for a matrix. To pair element-by-element instead, pass **one** collection of tuples (as above) — do **not** reach for `zip(a, b)`:

- `zip` **silently truncates** to the shorter collection, so a typo that drops a case quietly shrinks coverage with no failure.
- `zip(Enum.allCases, expected)` is **order-fragile** — reordering the enum re-pairs every case against the wrong expectation.

If you genuinely need the product of two axes, pass both collections (`arguments: rows, columns`) and let Swift Testing form the pairs — it is clearer than a nested loop and each pair is an independently-reported, independently-retryable case.

### Regression-guard: prove the fix is load-bearing

When you write a test for a bug fix or a tolerance/workaround, prove the test would actually catch the regression: assert the **raw/unfixed input fails** *and* the **fixed path succeeds**. A test that only checks the fixed path can't tell you the fix is doing anything.

```swift
// The production decoder tolerates a field the backend sometimes sends as a JSON-encoded string.
@Test("string-encoded metadata decodes after the repair")
func repairedDecodes() throws {
    let fixed = Repair.fixStringEncodedJSON(in: rawWithStringMetadata)
    #expect(throws: Never.self) { try JSONDecoder().decode(Response.self, from: fixed) }
}

@Test("raw string-encoded metadata fails to decode without the repair")  // the guard
func rawFails() {
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(Response.self, from: rawWithStringMetadata)
    }
}
```

The second test is what makes the first meaningful — it shows the repair is the reason decoding succeeds.

### Characterisation: pin behaviour whose "correct" policy you don't know

When you must cover code but don't know the intended policy (legacy logic, a gating rule with no spec), assert what it does **today** so any future change is caught. Say so in the description — it signals the assertion documents current behaviour, not a specification.

```swift
@Test("characterisation: over-18 gate hides mature streams for an under-18 viewer (current behaviour)")
func maturalGateCurrentBehaviour() async throws {
    let sut = await PlayerViewModel(viewer: .fixture(isOver18: false), repo: stub)
    await sut.load(matureStream)
    #expect(await MainActor.run { sut.viewState } == .blocked)
}
```

Do not invent the "right" policy — lock in the observed one and flag it for the owner if it looks wrong.

## Swift 6.2 additions

Reach for these when they fit — verify the exact signature against Context7 (`/swiftlang/swift-testing`) if unsure, the APIs are recent.

### Exit tests — cover `precondition` / `fatalError` / `exit` paths

A trap or process exit cannot be caught by `#expect(throws:)` — it kills the test process. `#expect(processExitsWith:)` runs the closure in a **child process** and asserts how it terminates, so a deliberate `precondition` failure becomes testable instead of un-coverable:

```swift
@Test func rejectsNegativeBalance() async {
    await #expect(processExitsWith: .failure) {
        _ = Account(balance: -1)   // hits a precondition
    }
}
```

Use sparingly — a trap path that *should* be a thrown error is a production bug; only pin genuine programmer-error preconditions this way.

### Range-based confirmations — events that fire an unknown number of times

`confirmation` already takes a fixed `expectedCount:`. For push-driven sources where the exact count is non-deterministic, pass a **range** instead of fixing a brittle number:

```swift
await confirmation(expectedCount: 1...) { handled in        // at least once
    subject.onEvent = { _ in handled() }
    await subject.run()
}
```

Any range works (`0..<1000`, `2...5`). This is the deterministic alternative to "fire some events then `Task.sleep`".

### `#expect(throws:)` returns the error — assert on its payload

The thrown error is returned, so a second assertion can inspect it instead of a bare type check:

```swift
let error = #expect(throws: ValidationError.self) { try sut.validate("") }
#expect(error?.field == .email)
```

(Returns `nil` if nothing — or the wrong error — was thrown.) Prefer this over the older two-closure form.

### Attachments — capture diagnostics on failure

Attach a value (conforming to `Attachable`) to the test record so a CI failure carries the offending payload, not just a line number:

```swift
Attachment.record(decodedResponse, named: "response.json")
```

### Custom scoping traits over shared `init()`

When several suites need the same per-test setup (a `@TaskLocal` clock, a temp directory), a custom trait conforming to `TestScoping` wraps each test in `provideScope(for:testCase:performing:)` — cleaner and more reusable than copying `init()` across suites. Verify the protocol shape against current docs before writing one.

### Raw identifiers for readable names (optional)

Swift 6.2 allows backtick-delimited function names, which can replace the `@Test("…")` display string:

```swift
@Test func `rejects an empty username`() async throws { … }
```

Suggest it where it reads better; do not mass-rewrite existing `@Test("…")` tests for it.

## Where test doubles live

A double used by **one** suite stays in that test file. A double shared across targets (e.g. a `MockRepository` several feature test targets need) belongs in a dedicated test-support target or an `…-Interface` module behind `#if DEBUG`, so every test target links the same definition instead of re-declaring drifting copies. Do not expose doubles from the production target's release build.

## Workflow: Writing Tests for a File

1. Read the source file to understand public interface
2. Identify testable behaviours (not implementation)
3. **Check for existing test file and read ALL existing tests**
4. **Identify which behaviours are already tested - do not duplicate**
5. Create/update test suite with appropriate tag
6. Write tests following Given/When/Then (only for untested behaviours)
7. Run tests to verify they pass — prefer Xcode MCP tools when Xcode is open:
   ```
   ToolSearch("select:mcp__xcode__RunSomeTests,mcp__xcode__RunAllTests,mcp__xcode__XcodeListNavigatorIssues")
   ```
   Use `mcp__xcode__RunSomeTests` for the specific test class, then `mcp__xcode__XcodeListNavigatorIssues` to confirm no new issues. Fall back to `swift-test-all` skill if Xcode is not open. `xcodebuild` is the build/test truth — SourceKit "No such module" on a file you just edited is indexing lag, not a failure. Run serially when verifying. See `references/tooling.md`.
8. **Review: Could any new tests be consolidated with existing ones?**

## References

- `references/coverage.md` — raising coverage: measure with `xccov`, the view-body denominator trap, prioritise by uncovered × blast-radius, fix untestable seams first
- `references/tooling.md` — the full toolkit: gitnexus/codegraph (consumers, blast radius, pre-change impact), `xccov`, `xcodebuild`-is-truth (SourceKit lag, run serially, SPM platform conflicts), context7, Xcode MCP, gate-commit-on-green
- `references/assertions.md` — complete assertion reference (`#expect`, `#require`, error matching)
- `references/tags.md` — tag organisation patterns
- `references/concurrency.md` — testing `@MainActor`-isolated services, bridging async callbacks (`confirmation`, `withCheckedContinuation`), `@TaskLocal` clocks/UUID providers, async cleanup
- `references/isolation.md` — Swift Testing's concurrency model, when `MainActor.assumeIsolated` is safe inside `@Test`, and the `@Test + @MainActor` ≠ "test body runs main-actor-isolated" trap
- `references/anti-patterns.md` — parallel-setup tests, weaker-after-crash, compiler-already-enforced assertions, `Decimal` float-literal trap

### Context7 References

Query Context7 with `mcp__context7__query-docs` for current API details:

| Library ID | Use for |
|---|---|
| `/swiftlang/swift` | Swift Testing library source, trait/expectation semantics |
| `/websites/swift` | Swift Testing documentation on swift.org |
