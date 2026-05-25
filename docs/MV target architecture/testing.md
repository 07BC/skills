# Testing Guide

> Swift Testing framework only — `import Testing`. No `XCTestCase` in any unit test file.
> Source: swift-testing skill + project test conventions.

---

## Framework setup

```swift
// TestTarget/Tags.swift
import Testing

extension Tag {
    @Tag static var domain: Self
    @Tag static var network: Self
    @Tag static var services: Self
    @Tag static var auth: Self
    @Tag static var decoding: Self
    @Tag static var presentation: Self
    // Add feature-specific tags as the app grows.
}
```

```bash
xcodebuild test \
  -workspace AppName.xcworkspace \
  -scheme "AppName" \
  -destination 'platform=<Platform> Simulator,name=<Device>' \
  -only-testing:AppNameTests/TestSuiteName
```

---

## File layout

```
AppNameTests/
  Tags.swift                        ← @Tag definitions
  Helpers/
    MockURLProtocol.swift           ← URLProtocol stub for URLSession.mock
    ResponseFixtures.swift          ← JSON fixture data keyed by URL
    <Domain>TestHelpers.swift       ← Fixture builders for domain types
  Tests/
    Domain/
      Fetchers/                     ← Fetcher unit tests
      Errors/                       ← AppError encoding/mapping tests
    Infrastructure/
      <APIClient>Tests.swift        ← HTTP client endpoint tests
      StorageServiceTests.swift
      Decoding/                     ← JSON decoding + lossy-decode tests
    Services/                       ← One <Feature>ServiceTests.swift per service
    Presentation/                   ← View helper, accessibility label tests
```

---

## Concurrency contract

Swift Testing runs tests in parallel by default. Every rule in this guide exists to keep that parallelism intact. The hard-stop bans below are non-negotiable.

### Hard-stop bans

- **Never write a synchronous `@Test` function.** Always `@Test func foo() async throws`. Even if the body has no `await` today, the signature must be future-proof.
- **Never apply `@MainActor` to a `@Test` function.** It serialises every test in the suite onto the main actor and defeats parallelism. To assert on `@MainActor`-isolated state, use `await MainActor.run { #expect(...) }` for the assertion only.
- **Never apply `.serialized` to a suite or test.** The only legitimate reason is a true process singleton you cannot inject around — which is almost always a production code bug. If you think you need `.serialized` to fix a race, you have a shared-state bug. Find it.
- **Never use `Task.sleep` to wait for state to settle.** Flaky by construction. Use `confirmation { }` for callback/notification APIs, `withCheckedContinuation` for completion handlers, or `await` the actor/service method directly.
- **Never declare a mock as `class Mock: @unchecked Sendable`.** Never use `NSLock`, `Mutex`, or any lock inside a mock. If the mock holds mutable state, it is an `actor`. Full stop.
- **Never silence Swift 6 concurrency warnings in test targets.** `@preconcurrency import`, `@unchecked Sendable`, and `nonisolated(unsafe)` in test code are the bug, not the fix.
- **Never touch process-global Apple singletons.** See "Process-global state" below.

---

## Helpers

### `URLSession.mock`

```swift
// Helpers/MockURLProtocol.swift
extension URLSession {
    static func mock(
        handler: @escaping (URLRequest) async throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        MockURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
```

### Fixture builders

Define `.fixture(...)` static methods directly on production types in `#if DEBUG` blocks, not in the test target:

```swift
// Domain/Models/Item.swift
#if DEBUG
extension Item {
    static func fixture(
        id: String = "fixture-id",
        title: String = "Fixture Item",
        createdAt: Date = Date()
    ) -> Item {
        Item(id: id, title: title, createdAt: createdAt)
    }
}
#endif
```

---

## Mock taxonomy

The shape of a mock depends on what it stands in for. Picking the wrong shape is the root cause of most test races.

| Mock stands in for | Shape | Why |
|---|---|---|
| Shared mutable system state (UserDefaults, Keychain, FileManager, NotificationCenter, in-memory caches) | `actor` | Read/modify/write needs serialisation across calls. Locks (`Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore`) are not approved and force synchronous call sites that clash with `async` test bodies. |
| Pure call recorder / argument captor with no read-after-write semantics | `final class` with `let` properties, or closure-captured state via `@Sendable` callback | If callers only ever write (e.g. recording the last endpoint hit), an actor is overkill. |
| `URLSession` and HTTP-layer mocking | `URLProtocol` subclass registered per-test | Supported Apple extension point. The system handles request isolation. |
| `Date`, `UUID`, `Locale`, `Calendar`, clocks | `@TaskLocal` provider, or constructor-injected closure (`() -> Date`) | Tests scope the value to a single test via `$now.withValue(...) { ... }`. No shared mutable state across tests. |
| `@Observable` SwiftUI service (`@MainActor`-isolated) | The real type, exercised via `await` | Don't mock your own `@Observable` services. Construct them with mocked dependencies and `await` their methods. |

### Worked example: `actor MockAPIClient`

```swift
// Infrastructure/Mocks/MockAPIClient.swift
#if DEBUG
actor MockAPIClient: APIClientProtocol {

    // MARK: - Configuration

    var fetchItemsResult: Result<PaginatedResponse<Item>, AppError> = .success(.fixture())
    var fetchDelay: Duration?

    // MARK: - Recorded calls

    private(set) var fetchItemsCallCount = 0

    // MARK: - APIClientProtocol

    func fetchItems(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        fetchItemsCallCount += 1
        if let delay = fetchDelay {
            try? await Task.sleep(for: delay)
        }
        return try fetchItemsResult.get()
    }
}

extension PaginatedResponse where T == Item {
    static func fixture(
        data: [Item] = [.fixture()],
        currentPage: Int = 1,
        hasNextPage: Bool = false
    ) -> PaginatedResponse<Item> {
        PaginatedResponse(data: data, currentPage: currentPage, hasNextPage: hasNextPage)
    }
}
#endif
```

### Production mocks

All mocks live in `Infrastructure/Mocks/` and are available via `@testable import AppName`. Compile with `#if DEBUG` guards — never ship mock conformers in a release build.

| Mock | Protocol |
|------|----------|
| `MockAPIClient` | `APIClientProtocol` |
| `MockAuthTokenProvider` | `AuthTokenProviding` |
| `MockStorageService` | `StorageServiceProtocol` |
| `MockAnalyticsAdapter` | `AnalyticsAdapter` |
| `MockNowProvider` | `NowProviding` |
| `MockUUIDProvider` | `UUIDProviding` |

Each mock is an `actor`. Mutable state (result stubs, call counts) is actor-isolated and `await`-ed in tests.

---

## Process-global state

**Unit tests must never read from or write to a process-global Apple singleton.** They are shared mutable state across the test process, leak between suites, and cause flaky CI under parallel scheduling. Note: `.serialized` only serialises tests within the suite that declares it — it does **not** protect against two suites racing on the same singleton.

**Banned in unit tests:**
- `UserDefaults.standard`
- `FileManager.default`
- `NotificationCenter.default`
- `URLSession.shared`
- `UIPasteboard.general`
- `NSUbiquitousKeyValueStore.default`
- `Bundle.main` (mutating accessors)
- `HTTPCookieStorage.shared`, `URLCache.shared`
- Any other `.shared` / `.default` / `.standard` Apple accessor

Always inject the dependency. If the production code reaches for a singleton directly, the production code is the bug — refactor to accept the dependency via initialiser before writing the test.

---

## Patterns

### Testing `@MainActor`-isolated services

A `@MainActor @Observable` service is the correct design for a SwiftUI domain service. Testing it does **not** require putting `@MainActor` on the test function.

**Pattern 1 — Construct in-body, `await` the methods**

The SUT is not stored as a suite property — `@MainActor` types are not safely stored on a nonisolated `Sendable` struct. Construct per-test in the body.

```swift
@Suite(.tags(.home))
struct HomeServiceTests {

    @Test("Loads channels on activation")
    func loadsOnActivation() async throws {
        let mockAPI = MockChannelAPI()           // actor
        let sut = await HomeService(api: mockAPI) // @MainActor init

        await sut.activate()

        let endpoints = await mockAPI.recordedEndpoints
        #expect(endpoints == ["/channels/featured"])
    }
}
```

**Pattern 2 — `await MainActor.run` for synchronous property reads**

When the SUT exposes synchronous `@MainActor`-isolated properties, reading them from a nonisolated test requires a hop. Wrap only the assertion's property read — not the whole test body.

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

### Suite `init()` for per-test setup

Swift Testing calls `init()` once **per test**, not once for the whole suite. Each test gets a fresh set of collaborators — no cleanup needed.

```swift
@Suite(.tags(.preferences))
struct PreferencesServiceTests {
    let store: MockUserDefaults  // actor

    init() async throws {
        store = MockUserDefaults()
        await store.set("rtmp://default", forKey: "server_url")
    }

    @Test("Reads pre-populated value from store")
    func readsFromStore() async throws {
        let sut = PreferencesService(store: store)
        let url = await sut.serverURL
        #expect(url == "rtmp://default")
    }
}
```

Do not store `@MainActor`-isolated SUTs as suite properties — construct them per-test in the body instead.

### Service test

```swift
@Suite("FeatureService", .tags(.services))
struct FeatureServiceTests {

    @Test("Items is empty before load")
    func itemsEmptyBeforeLoad() async throws {
        let mockAPI = MockAPIClient()
        let sut = await FeatureService(client: mockAPI)
        let items = await MainActor.run { sut.items }
        let isLoading = await MainActor.run { sut.isLoading }
        #expect(items.isEmpty)
        #expect(isLoading == false)
    }

    @Test("Load populates items on success")
    func loadPopulatesItems() async throws {
        let mockAPI = MockAPIClient()
        await mockAPI.stub(.success([.fixture(), .fixture()]))
        let sut = await FeatureService(client: mockAPI)

        await sut.load()

        let items = await MainActor.run { sut.items }
        #expect(items.count == 2)
    }

    @Test("Load sets error on failure")
    func loadSetsErrorOnFailure() async throws {
        let mockAPI = MockAPIClient()
        await mockAPI.stub(.failure(.network(URLError(.notConnectedToInternet))))
        let sut = await FeatureService(client: mockAPI)

        await sut.load()

        let error = await MainActor.run { sut.error }
        let items = await MainActor.run { sut.items }
        #expect(error != nil)
        #expect(items.isEmpty)
    }
}
```

Key rules:
- One assertion focus per test. No multi-scenario tests.
- Construct fresh instances per test — never `.shared`.
- No `@MainActor` on `@Test` functions. Use `await MainActor.run { }` for isolated property reads.

### Bridging async callbacks

When the SUT calls a closure or posts a notification, use `confirmation { }` — never `Task.sleep`.

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

For legacy completion-handler APIs, bridge with `withCheckedContinuation`:

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

### `@TaskLocal` for clocks and UUID providers

Inject time and UUID providers via `@TaskLocal` to scope overrides to a single test with no shared mutable state.

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

### HTTP client / fetcher test

```swift
@Suite("APIClient — fetchItems", .tags(.network))
struct APIClientFetchItemsTests {

    private func makeClient(data: Data, statusCode: Int = 200) -> APIClient {
        APIClient(
            urlSession: .mock { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, data)
            },
            tokenProvider: MockAuthTokenProvider()
        )
    }

    @Test("fetchItems returns decoded items")
    func fetchItemsReturnsDecodedItems() async throws {
        let client = makeClient(data: ResponseFixtures.items())
        let result = try await client.fetchItems(page: 1)
        #expect(result.data.count == 1)
    }

    @Test("fetchItems throws on non-200")
    func fetchItemsThrowsOnNon200() async throws {
        let client = makeClient(data: Data(), statusCode: 500)
        #expect(throws: AppError.self) {
            _ = try await client.fetchItems(page: 1)
        }
    }
}
```

No `@MainActor` needed — pure async fetcher tests run off-main.

### Decoding test

```swift
@Suite("Item decoding", .tags(.decoding))
struct ItemDecodingTests {

    @Test("Decodes id and title")
    func decodesIdAndTitle() async throws {
        let json = Data(#"{"id":"abc","title":"Hello","created_at":"2024-01-01T00:00:00Z"}"#.utf8)
        let dto = try ModelDecoder.shared.decode(APIItem.self, from: json)
        let item = Item(api: dto)
        #expect(item.id == "abc")
        #expect(item.title == "Hello")
    }

    @Test("Throws AppError on bad JSON")
    func throwsOnBadJSON() async throws {
        #expect(throws: AppError.self) {
            _ = try ModelDecoder.decode(APIItem.self, from: Data("not json".utf8))
        }
    }
}
```

### Mock concurrency test

```swift
@Suite("MockAPIClient concurrency", .tags(.network))
struct MockAPIClientConcurrencyTests {

    @Test("Concurrent calls succeed without data race")
    func concurrentCallsSucceed() async throws {
        let client = MockAPIClient()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    _ = try? await client.fetchItems(page: 1)
                }
            }
        }

        let callCount = await client.fetchItemsCallCount
        #expect(callCount == 50)
    }
}
```

---

## Anti-patterns

### Parallel-setup test

A test that constructs its own collaborators, mutates them, then asserts on its own mutations. The test passes — but it tests the collaborator, not the SUT. Diagnostic question: "If I deleted the SUT's implementation, would this test still pass?" If yes, rewrite it.

### Weaker-after-crash

When a test traps at runtime, never weaken the assertion to make the suite go green. That is silent coverage loss. If you cannot fix the trap while keeping the assertion contract intact in 5 minutes, stop and escalate.

### Testing compiler-enforced behaviour

```swift
// BAD — synthesised Hashable; verifies the compiler, not your code
@Test("Route cases are distinct")
func routeCasesAreDistinct() async throws {
    #expect(Route.loanInput != Route.comparison)
}

// BAD — if it didn't conform, the file wouldn't compile
@Test("Service conforms to protocol")
func conformsToProtocol() async throws {
    #expect(sut is ScenarioServicing)
}
```

Only test behaviour the compiler cannot catch: decoding from external input, switch dispatch side effects, custom `Equatable`/`Hashable` implementations.

### Tautological setter/getter tests

```swift
// BAD — always passes, tests nothing
@Test("Stores value")
func storesValue() async throws {
    var value = ""
    value = "test"
    #expect(value == "test")
}

// GOOD — verify the value reached the collaborator with the correct key
@Test("Persists value to store with correct key")
func persistsToStore() async throws {
    let store = MockUserDefaults()   // actor
    let sut = PreferencesService(store: store)

    await sut.setServerURL("rtmp://test.com")

    let stored = await store.string(forKey: "server_url")
    #expect(stored == "rtmp://test.com")
}
```

---

## What is NOT unit-tested

- SwiftUI layout, view hierarchy, or visual rendering.
- Focus engine routing (`prefersDefaultFocus`, `focusedValue`).
- `AVPlayer` / `AVFoundation` runtime behaviour.
- Animation and transition timing.
- Xcode preview rendering.
- Apple framework internals.
- Exhaustive `switch` over enums with no associated-value logic — compiler-enforced.
- `Codable` round-trips for types with no custom coding — compiler-synthesised.
- Type conformances — if it didn't conform, the file wouldn't compile.
- Simple property getters/setters with no collaborator interaction.

Before writing any test, ask: **what regression would this test catch?** If the honest answer is "the Swift compiler stopped working", do not write the test.

---

## SwiftData

Use `ModelContainer` with an in-memory configuration for all storage tests. Never use a persistent store in a unit test — it leaks state across tests and requires cleanup.

```swift
@Suite(.tags(.services))
struct ItemStorageServiceTests {

    @Test("Saves and fetches item")
    func savesAndFetchesItem() async throws {
        let container = try ModelContainer(
            for: Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let sut = ItemStorageService(modelContainer: container)

        let item = Item.fixture()
        try await sut.save(item)

        let fetched = try await sut.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == item.id)
    }
}
```

Never share a `ModelContainer` across tests via a `static` property or singleton — each test must construct its own in-memory container.
