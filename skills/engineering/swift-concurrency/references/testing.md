# Testing Concurrent Code

Best practices for testing Swift Concurrency with Swift Testing (recommended) and XCTest.

## Recommendation: Use Swift Testing

**Swift Testing is strongly recommended** for new projects and tests. It provides:
- Modern Swift syntax with macros
- Better concurrency support
- Cleaner test structure
- More flexible test organization

XCTest patterns are included for legacy codebases.

## Swift Testing Basics

### Simple async test

```swift
@Test
@MainActor
func emptyQuery() async {
    let searcher = ArticleSearcher()
    await searcher.search("")
    #expect(searcher.results == ArticleSearcher.allArticles)
}
```

**Key differences from XCTest**:
- `@Test` macro instead of `XCTestCase`
- `#expect` instead of `XCTAssert`
- Structs preferred over classes
- No `test` prefix required

### Testing with actors

```swift
@Test
@MainActor
func searchReturnsResults() async {
    let searcher = ArticleSearcher()
    await searcher.search("swift")
    #expect(!searcher.results.isEmpty)
}
```

Mark test with actor if system under test requires it.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 11.2: Testing concurrent code using Swift Testing](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Testing Tasks

Every `Task.sleep` in a test is a sign that the production code's async boundary isn't surfaced in a testable way. The following patterns eliminate arbitrary sleeps.

### Pattern 1: Direct `await` (preferred)

When the model exposes `async` functions — which it should — tests simply await them. No timing, no flakiness, fully deterministic.

```swift
@Observable
@MainActor
final class ItemListModel {
    private(set) var items: [Item] = []
    private let service: ItemServiceProtocol

    func load() async {
        items = await service.fetchAll()
    }
}

@Test
@MainActor
func itemsLoadFromService() async {
    let model = ItemListModel(service: MockItemService())
    await model.load()
    #expect(model.items.count == 5)
}
```

**This is the goal state.** If your test cannot directly `await` production code, the production code's async boundary needs restructuring — see Pattern 2 for when you cannot change it.

### Pattern 2: `confirmation()` for fire-and-forget Tasks

When production code spawns an unstructured `Task { }` internally and you cannot change it, use `confirmation()` to wait for side effects instead of sleeping:

```swift
// Production code you cannot modify
@Observable
@MainActor
final class ProfileModel {
    private(set) var profile: UserProfile?
    private let service: ProfileServiceProtocol

    func load() {
        Task { profile = await service.fetch() }
    }
}

// Test
@Test
@MainActor
func profileFetchesOnLoad() async {
    await confirmation { confirm in
        let service = MockProfileService(onFetch: {
            confirm()
            return .mock
        })
        let model = ProfileModel(service: service)
        model.load()  // fires a Task internally
    }
}
```

`confirmation()` waits (with a configurable timeout) for `confirm()` to be called. No arbitrary sleep.

**Critical**: Must trigger the async work inside the `confirmation` block. The block exits once `confirm()` fires or the timeout expires.

### Pattern 3: Injected `Clock` for time-dependent logic

When production code involves delays (polling, debounce, retry), inject a `Clock` so tests control time:

```swift
@Observable
@MainActor
final class PollingModel {
    private(set) var data: [Item] = []
    private let service: DataServiceProtocol
    private let clock: any Clock<Duration>

    init(
        service: DataServiceProtocol,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.service = service
        self.clock = clock
    }

    func startPolling() async {
        while !Task.isCancelled {
            data = await service.fetch()
            try? await clock.sleep(for: .seconds(30))
        }
    }
}
```

In tests, use a manual/test clock (e.g. from `swift-clocks`) to advance time instantly — no real 30-second wait.

### Pattern 4: Test cancellation behaviour

Verify that stored Tasks respect cancellation:

```swift
@Test
@MainActor
func cancelStopsLoading() async throws {
    let service = MockProfileService(delay: .seconds(10))
    let model = ProfileModel(service: service)

    model.load()
    model.cancelLoad()

    // Brief yield for cancellation to propagate — acceptable
    try await Task.sleep(for: .milliseconds(50))
    #expect(model.profile == nil)
}
```

> **Note:** A very short sleep (~50ms) for cancellation propagation is acceptable.
> Multi-second sleeps waiting for work to complete are the anti-pattern.

### Pattern 5: Test Task cancellation with `CancellationError`

For Tasks that throw on cancellation:

```swift
@Test
func cancellationThrows() async throws {
    let processor = DataProcessor()

    let task = Task {
        try await processor.processLargeDataset()
    }

    task.cancel()

    do {
        try await task.value
        Issue.record("Should have thrown cancellation error")
    } catch is CancellationError {
        // Expected
    }
}
```

### Decision: Which pattern to use?

| Production code shape | Test pattern |
|---|---|
| `func load() async` — async function | **Direct `await`** — always preferred |
| `func load()` with internal `Task { }` you cannot change | **`confirmation()`** via mock callback |
| Code with `Task.sleep` / polling / debounce | **Injected `Clock`** |
| Stored `Task` with `cancelLoad()` | **Cancellation test** |
| `Task` that `throws` on cancel | **`CancellationError` assertion** |

## Awaiting Async Callbacks

### Using continuations

When testing observation of unstructured tasks:

```swift
@Test
@MainActor
func searchTaskCompletes() async {
    let searcher = ArticleSearcher()

    await withCheckedContinuation { continuation in
        _ = withObservationTracking {
            searcher.results
        } onChange: {
            continuation.resume()
        }

        searcher.startSearchTask("swift")
    }

    #expect(searcher.results.count > 0)
}
```

**Use when**: Testing code that spawns unstructured tasks and you need to observe `@Observable` state changes.

### Using confirmations

For structured async code:

```swift
@Test
@MainActor
func searchTriggersObservation() async {
    let searcher = ArticleSearcher()

    await confirmation { confirm in
        _ = withObservationTracking {
            searcher.results
        } onChange: {
            confirm()
        }

        // Must await here for confirmation to work
        await searcher.search("swift")
    }

    #expect(!searcher.results.isEmpty)
}
```

**Critical**: Must `await` async work for confirmation to validate.

## Setup and Teardown

### Using init/deinit

```swift
@MainActor
final class DatabaseTests {
    let database: Database

    init() async throws {
        database = Database()
        await database.prepare()
    }

    deinit {
        // Synchronous cleanup only
    }

    @Test
    func insertsData() async throws {
        try await database.insert(item)
        #expect(await database.count() == 1)
    }
}
```

**Limitation**: `deinit` cannot call async methods.

### Test Scoping Traits

For async teardown:

```swift
@MainActor
struct DatabaseTrait: SuiteTrait, TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: () async throws -> Void
    ) async throws {
        let database = Database()

        try await Environment.$database.withValue(database) {
            await database.prepare()
            try await function()
            await database.cleanup() // Async teardown
        }
    }
}

// Environment for task-local storage
@MainActor
struct Environment {
    @TaskLocal static var database = Database()
}

// Apply to suite
@Suite(DatabaseTrait())
@MainActor
final class DatabaseTests {
    @Test
    func insertsData() async throws {
        try await Environment.database.insert(item)
    }
}

// Or apply to individual test
@Test(DatabaseTrait())
func specificTest() async throws {
    // Test code
}
```

**Use when**: Need async cleanup after each test.

## Handling Flaky Tests

### Problem: Race conditions

```swift
@Test
@MainActor
func isLoadingState() async throws {
    let fetcher = ImageFetcher()

    let task = Task { try await fetcher.fetch(url) }

    // ❌ Flaky - may pass or fail
    #expect(fetcher.isLoading == true)

    try await task.value
    #expect(fetcher.isLoading == false)
}
```

**Issue**: Task may complete before we check `isLoading`.

### Solution: Swift Concurrency Extras

```swift
import ConcurrencyExtras

@Test
@MainActor
func isLoadingState() async throws {
    try await withMainSerialExecutor {
        let fetcher = ImageFetcher { url in
            await Task.yield() // Allow test to check state
            return Data()
        }

        let task = Task { try await fetcher.fetch(url) }

        await Task.yield() // Switch to task

        #expect(fetcher.isLoading == true) // ✅ Reliable

        try await task.value
        #expect(fetcher.isLoading == false)
    }
}
```

**Add package**: `https://github.com/pointfreeco/swift-concurrency-extras.git`

> **Course Deep Dive**: This topic is covered in detail in [Lesson 11.3: Using Swift Concurrency Extras by Point-Free](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

### Serial execution required

```swift
@Suite(.serialized)
@MainActor
final class ImageFetcherTests {
    // Tests run serially when using withMainSerialExecutor
}
```

**Critical**: Main serial executor doesn't work with parallel test execution.

## XCTest Patterns (Legacy)

### Basic async test

```swift
final class ArticleSearcherTests: XCTestCase {
    @MainActor
    func testEmptyQuery() async {
        let searcher = ArticleSearcher()
        await searcher.search("")
        XCTAssertEqual(searcher.results, ArticleSearcher.allArticles)
    }
}
```

### Using expectations

```swift
@MainActor
func testSearchTask() async {
    let searcher = ArticleSearcher()
    let expectation = expectation(description: "Search complete")

    _ = withObservationTracking {
        searcher.results
    } onChange: {
        expectation.fulfill()
    }

    searcher.startSearchTask("swift")

    // Use fulfillment, not wait
    await fulfillment(of: [expectation], timeout: 10)

    XCTAssertEqual(searcher.results.count, 1)
}
```

**Critical**: Use `await fulfillment(of:)`, not `wait(for:)` to avoid deadlocks.

### Setup and teardown

```swift
final class DatabaseTests: XCTestCase {
    override func setUp() async throws {
        // Async setup
    }

    override func tearDown() async throws {
        // Async teardown
    }
}
```

Mark as `async throws` to call async methods.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 11.1: Testing concurrent code using XCTest](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

### Main serial executor for all tests

```swift
final class MyTests: XCTestCase {
    override func invokeTest() {
        withMainSerialExecutor {
            super.invokeTest()
        }
    }
}
```

## Common Patterns

### Testing @MainActor code

```swift
@Test
@MainActor
func viewModelUpdates() async {
    let viewModel = ViewModel()
    await viewModel.loadData()
    #expect(viewModel.items.count > 0)
}
```

### Testing actors

```swift
@Test
func actorIsolation() async {
    let store = DataStore()
    await store.insert(item)
    let count = await store.count()
    #expect(count == 1)
}
```

### Testing with delays (injected Clock preferred)

When you cannot inject a Clock, use `withMainSerialExecutor` to control execution:

```swift
@Test
func debouncedSearch() async throws {
    try await withMainSerialExecutor {
        let searcher = DebouncedSearcher()

        searcher.search("a")
        await Task.yield()

        searcher.search("ab")
        await Task.yield()

        searcher.search("abc")

        // Wait for debounce
        try await Task.sleep(for: .milliseconds(600))

        #expect(searcher.searchCount == 1) // Only last search executed
    }
}
```

**Prefer**: Injecting a `Clock` into production code so the test can advance time instantly without any real sleep.

### Testing task groups

```swift
@Test
func taskGroupProcessesAll() async throws {
    let processor = BatchProcessor()

    let results = await withTaskGroup(of: Int.self) { group in
        for i in 1...5 {
            group.addTask { await processor.process(i) }
        }

        var collected: [Int] = []
        for await result in group {
            collected.append(result)
        }
        return collected
    }

    #expect(results.count == 5)
}
```

## Testing Memory Management

### Verify deallocation

```swift
@Test
func viewModelDeallocates() async {
    var viewModel: ViewModel? = ViewModel()
    weak var weakViewModel = viewModel

    viewModel?.startWork()
    viewModel = nil

    try? await Task.sleep(for: .milliseconds(100))

    #expect(weakViewModel == nil)
}
```

### Detect retain cycles

```swift
@Test
func noRetainCycle() async {
    var manager: Manager? = Manager()
    weak var weakManager = manager

    manager?.startLongRunningTask()
    manager = nil

    #expect(weakManager == nil)
}
```

## Best Practices

1. **Prefer `async` functions in production** so tests can directly `await` — no sleep needed
2. **Use Swift Testing for new code** — modern, better concurrency support
3. **Use `confirmation()` over `Task.sleep`** when testing fire-and-forget Tasks
4. **Inject a `Clock`** for time-dependent code (polling, debounce, retry)
5. **Mark tests with correct isolation** — `@MainActor` when needed
6. **Serialize tests with main serial executor** — avoid flaky tests
7. **Test cancellation explicitly** — ensure proper cleanup
8. **Verify deallocation** — catch retain cycles early
9. **Use `Task.yield()` strategically** — control execution in tests
10. **Keep tests deterministic** — eliminate timing dependencies

## Migration from XCTest

### XCTest → Swift Testing

```swift
// XCTest
final class MyTests: XCTestCase {
    func testExample() async {
        XCTAssertEqual(value, expected)
    }
}

// Swift Testing
@Suite
struct MyTests {
    @Test
    func example() async {
        #expect(value == expected)
    }
}
```

### Expectations → Confirmations

```swift
// XCTest
let expectation = expectation(description: "Done")
doWork { expectation.fulfill() }
await fulfillment(of: [expectation])

// Swift Testing
await confirmation { confirm in
    await doWork { confirm() }
}
```

### Setup/Teardown → Traits

```swift
// XCTest
override func setUp() async throws {
    await prepare()
}

// Swift Testing
struct SetupTrait: TestTrait, TestScoping {
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: () async throws -> Void
    ) async throws {
        await prepare()
        try await function()
    }
}
```

## Troubleshooting

### Test hangs

**Cause**: Waiting for expectation that never fulfills.

**Solution**: Add timeout, verify observation tracking.

### Flaky test

**Cause**: Race condition in unstructured task.

**Solution**: Use main serial executor + Task.yield().

### Deadlock

**Cause**: Using `wait(for:)` in async context.

**Solution**: Use `await fulfillment(of:)` instead.

### Confirmation fails

**Cause**: Not awaiting async work in confirmation block.

**Solution**: Add `await` before async calls.

### Actor isolation error

**Cause**: Test not marked with required actor.

**Solution**: Add `@MainActor` or appropriate actor to test.

### Multi-second `Task.sleep` in tests

**Cause**: Production code's async boundary isn't testable.

**Solution**: Restructure production code to expose `async` functions. If not possible, use `confirmation()`. If time-dependent, inject a `Clock`.

## Testing Checklist

- [ ] Production functions are `async` so tests can directly `await`
- [ ] No `Task.sleep(.seconds(N))` in tests — using `confirmation()` or injected `Clock` instead
- [ ] Tests marked with correct isolation
- [ ] Using Swift Testing (recommended)
- [ ] Async methods properly awaited
- [ ] Cancellation tested for stored Tasks
- [ ] Memory leaks checked
- [ ] Race conditions handled
- [ ] Timeouts appropriate
- [ ] Flaky tests fixed with serial executor
- [ ] Actor isolation verified
- [ ] Cleanup in traits (not deinit)

## Further Learning

For advanced testing patterns, real-world examples, and migration strategies:
- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [Swift Concurrency Extras](https://github.com/pointfreeco/swift-concurrency-extras)
- [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)