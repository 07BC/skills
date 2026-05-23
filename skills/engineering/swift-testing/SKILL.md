---
name: swift-testing
description: Generate unit tests using Apple's Swift Testing framework. Use when asked to write tests, check test coverage, or create test files for Swift code. Triggers on requests like "write unit tests for {file}", "test this code", "add tests for my changes", or any Swift testing task. NOT for XCTest - this skill uses Swift Testing (@Test, @Suite, #expect).
---

# Swift Testing

> **Source of truth for Swift Testing patterns in every context.** Other agents
> (including spec-pipeline's engineer, test-writer, concurrency-auditor, and
> task-reviewer sub-agents) read this body as authority — even when this skill
> itself does not auto-fire. Any routing scope declared elsewhere governs only
> when this skill auto-fires on a human message; it does not gate sub-agent
> referencing.

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
- **Never declare a mock as `class Mock: @unchecked Sendable`.** Never use `NSLock`, `os_unfair_lock`, or `Mutex` inside a mock to "make it thread-safe." If the mock holds mutable state, the mock is an `actor`. Full stop. See "Mock taxonomy" below.
- **Never use `nonisolated(unsafe) static var` for shared test fixtures.** Each test creates its own mocks. There is no such thing as a shared fixture in a parallel test suite — that is just a race waiting to happen.
- **Never use `Task.sleep` (or `try await Task.sleep`) to wait for state to settle.** It is flaky by construction. Use `confirmation { }` for callback APIs, `withCheckedContinuation` for completion handlers, or `await` the actor directly. See `references/concurrency.md`.
- **Never silence Swift 6 concurrency warnings in test targets.** `@preconcurrency import`, `@unchecked Sendable`, and `nonisolated(unsafe)` in test code are not workarounds — they are the bug.
- **Crash budget: 5 minutes.** If a test traps at runtime and you cannot fix it without changing the SUT's assertion contract within 5 minutes, **stop and escalate**. Do not rewrite the test to a weaker assertion that sidesteps the crash. That is silent coverage loss. See `references/anti-patterns.md` ("weaker-after-crash").
- **Never assert on test-built state.** A test that constructs its own collaborators, mutates them, then asserts on its own mutations is testing the collaborator, not the SUT. The test must observe state **through the SUT's own returned instance or its own context**. See `references/anti-patterns.md` ("parallel-setup tests").

### Diagnostic workflow when a test is flaky

Before reaching for `.serialized` or `@MainActor`:

1. Run the suite with repetitions: `swift test --filter MyFeatureTests --num-workers 8 --repetitions 50` (or the Xcode equivalent — Product → Perform Action → Test Repeatedly).
2. If only one test in N runs fails, you have a race. If every run fails, you have a logic bug.
3. For races, list every piece of state shared across tests: `static` properties, singleton accesses, captured `Task { }` blocks without `await`, `@TaskLocal` values set in `init()` that bleed across tests, file-system paths, port numbers, notification names.
4. Eliminate the sharing. Do not serialise around it.

## Mock taxonomy

The shape of a mock depends on what it stands in for. **Picking the wrong shape is the root cause of most test races.**

| Mock stands in for | Mock shape | Why |
|---|---|---|
| Shared mutable system state (UserDefaults, Keychain, FileManager, NotificationCenter, in-memory caches) | `actor` | Read/modify/write needs serialisation across calls. An actor is the only correct primitive — `Mutex` works but forces synchronous call sites that clash with `async` test bodies. |
| Pure call recorder / argument captor with no read-after-write semantics | `final class` with `let` properties, OR closure-captured state via `@Sendable` callback | If callers only ever write (e.g. recording the last endpoint hit), an actor is overkill. Use a `Sendable` final class or capture state in a closure the SUT calls. |
| `URLSession` and HTTP-layer mocking | `URLProtocol` subclass registered per-test | `URLProtocol` is the supported Apple extension point. The system handles request isolation; do not wrap in an actor. |
| `Date`, `UUID`, `Locale`, `Calendar`, clocks | `@TaskLocal` provider, or constructor-injected closure (`() -> Date`) | Tests scope the value to a single test via `$now.withValue(...) { ... }`. No shared mutable state across tests. |
| `@Observable` SwiftUI service (`@MainActor`-isolated) | The real type, exercised from the test with `await` | Don't mock your own `@Observable` services. Construct them with mocked dependencies and `await` their methods. See `references/concurrency.md`. |

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
    #expect(UserDefaults.standard.string(forKey: "server_url") == "rtmp://default")
}

// GOOD — mock store passed in, no global state
@Test("Registers default when key absent")
func registersDefault() async throws {
    let store = MockUserDefaults()  // actor wrapping in-memory dictionary
    let sut = PreferencesService(store: store)
    await sut.registerDefaults()
    let stored = await store.string(forKey: "server_url")
    #expect(stored == "rtmp://default")
}
```

**`.serialized` is not a workaround.** If you find yourself adding `.serialized` to avoid a UserDefaults race, stop — inject a mock instead. `.serialized` will still flake when a *different* suite touches the same singleton.

**If the production code reaches for a singleton directly,** the production code is the bug — refactor it to accept the store via initialiser before writing the test. Do not work around it by mutating the singleton in `init()` / `deinit`.

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

    await sut.setServerURL("rtmp://test.com")

    // Verify the store directly - not via the wrapper
    let stored = await store.string(forKey: "server_url")
    #expect(stored == "rtmp://test.com")
}
```

### Testing Getters - Pre-populate the store
```swift
// GOOD: Pre-populate store, then verify wrapper reads it correctly
@Test("Reads value from pre-populated store")
func readsFromStore() async throws {
    let store = MockUserDefaults()
    await store.set("rtmp://existing.com", forKey: "server_url")  // Arrange first

    let sut = PreferencesService(store: store)

    let server = await sut.serverURL
    #expect(server == "rtmp://existing.com")
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
   Use `mcp__xcode__RunSomeTests` for the specific test class, then `mcp__xcode__XcodeListNavigatorIssues` to confirm no new issues. Fall back to `swift-test-all` skill if Xcode is not open.
8. **Review: Could any new tests be consolidated with existing ones?**

## References

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
