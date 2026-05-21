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
    let sut: MyFeature

    init() {
        sut = MyFeature()
    }

    @Test("Description of what is being tested")
    func behaviourUnderTest() {
        // Given
        let input = "test"

        // When
        let result = sut.process(input)

        // Then
        #expect(result == "expected")
    }
}
```

## Core Syntax

| XCTest | Swift Testing |
|--------|---------------|
| `class FooTests: XCTestCase` | `@Suite struct FooTests` |
| `func testFoo()` | `@Test func foo()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `setUpWithError()` | `init() throws` |
| `tearDown()` | `deinit` |

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
func registersDefault() {
    UserDefaults.standard.removeObject(forKey: "server_url")
    sut.registerDefaults()
    #expect(UserDefaults.standard.string(forKey: "server_url") == "rtmp://default")
}

// GOOD — mock store passed in, no global state
@Test("Registers default when key absent")
func registersDefault() {
    let store = MockUserDefaults()  // in-memory dictionary
    let sut = PreferencesService(store: store)
    sut.registerDefaults()
    #expect(store.string(forKey: "server_url") == "rtmp://default")
}
```

**`.serialized` is not a workaround.** If you find yourself adding `.serialized` to avoid a UserDefaults race, stop — inject a mock instead. `.serialized` will still flake when a *different* suite touches the same singleton.

**If the production code reaches for a singleton directly,** the production code is the bug — refactor it to accept the store via initialiser before writing the test. Do not work around it by mutating the singleton in `init()` / `deinit`.

## Avoid Tautological Tests

**Never write tests that only verify what was just set.** These tests always pass and verify nothing:

```swift
// BAD: Tautological - always passes, tests nothing
@Test("Stores value")
func storesValue() {
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
func persistsToStore() {
    let store = MockUserDefaults()

    @UserDefault(.serverUrl, store: store)
    var server: String

    server = "rtmp://test.com"

    // Verify the store directly - not via the wrapper
    #expect(store.string(forKey: "server_url") == "rtmp://test.com")
}
```

### Testing Getters - Pre-populate the store
```swift
// GOOD: Pre-populate store, then verify wrapper reads it correctly
@Test("Reads value from pre-populated store")
func readsFromStore() {
    let store = MockUserDefaults()
    store.set("rtmp://existing.com", forKey: "server_url")  // Arrange first

    @UserDefault(.serverUrl, store: store)
    var server: String

    #expect(server == "rtmp://existing.com")  // Verify getter works
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
func invalidInput() throws {
    #expect(throws: ValidationError.self) {
        try sut.validate("")
    }
}
```

### Testing with mocks
```swift
@Test("Calls API with correct parameters")
func callsAPI() async {
    await sut.loadData()
    #expect(mockAPI.lastEndpoint == "/data")
    #expect(mockAPI.callCount == 1)
}
```

### Parameterised tests
```swift
@Test("Validates email formats", arguments: [
    ("valid@example.com", true),
    ("invalid", false),
    ("@missing.com", false)
])
func emailValidation(email: String, expected: Bool) {
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

- See `references/assertions.md` for complete assertion reference
- See `references/tags.md` for tag organisation patterns

### Context7 References

Query Context7 with `mcp__context7__query-docs` for current API details:

| Library ID | Use for |
|---|---|
| `/swiftlang/swift` | Swift Testing library source, trait/expectation semantics |
| `/websites/swift` | Swift Testing documentation on swift.org |
