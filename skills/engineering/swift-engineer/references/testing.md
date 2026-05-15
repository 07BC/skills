# Swift Testing Reference

## Migration from XCTest

| XCTest | Swift Testing |
|--------|---------------|
| `XCTestCase` class | `struct` with `@Test` methods |
| `func testX()` | `@Test func x()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `setUpWithError()` | `init() throws` |
| `tearDown()` | `deinit` (for classes) |
| `XCTSkip` | `throw Skip()` or `.enabled(if:)` |

## Assertions

### Basic Expectations

```swift
// Equality
#expect(result == expected)
#expect(array.count == 3)

// Boolean
#expect(user.isActive)
#expect(!list.isEmpty)

// Optional
#expect(value != nil)
let unwrapped = try #require(optionalValue)  // Unwrap or fail

// Comparisons
#expect(score > 90)
#expect(date < .now)

// Type checking
#expect(animal is Dog)
```

### Error Expectations

```swift
// Expect any error
await #expect(throws: (any Error).self) {
    try await dangerousOperation()
}

// Expect specific error type
await #expect(throws: NetworkError.self) {
    try await fetchData()
}

// Expect specific error value
await #expect(throws: ValidationError.invalidEmail) {
    try validate(email: "bad")
}

// Expect no error (explicit)
#expect(throws: Never.self) {
    try safeOperation()
}
```

### Custom Failure Messages

```swift
#expect(
    user.permissions.contains(.admin),
    "User \(user.id) should have admin permissions for this test"
)
```

## Test Organization

### Suites

```swift
@Suite("User Management")
struct UserTests {
    @Suite("Registration")
    struct RegistrationTests {
        @Test func validEmail() { ... }
        @Test func invalidEmail() { ... }
    }
    
    @Suite("Authentication")
    struct AuthTests {
        @Test func login() { ... }
        @Test func logout() { ... }
    }
}
```

### Tags

```swift
extension Tag {
    @Tag static var networking: Self
    @Tag static var database: Self
    @Tag static var slow: Self
    @Tag static var flaky: Self
}

@Test(.tags(.networking, .slow))
func downloadLargeFile() async { ... }

// Run specific tags: swift test --filter .tags:networking
```

### Traits

```swift
// Time limits
@Test(.timeLimit(.minutes(2)))
func longRunningOperation() async { ... }

// Bug references
@Test(.bug("PROJ-123", "Intermittent failure on CI"))
func flakyTest() { ... }

// Conditional execution
@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] != nil))
func ciOnlyTest() { ... }

@Test(.disabled("Pending backend deployment"))
func pendingFeature() { ... }

// Serial execution (no parallelism)
@Suite(.serialized)
struct DatabaseTests { ... }
```

## Setup and Teardown

### Using Init

```swift
struct ServiceTests {
    let sut: UserService
    let mockDB: MockDatabase
    let mockNetwork: MockNetworkClient
    
    init() async throws {
        mockDB = MockDatabase()
        mockNetwork = MockNetworkClient()
        sut = UserService(database: mockDB, network: mockNetwork)
        
        // Async setup
        try await mockDB.seed(with: testData)
    }
    
    @Test func fetchUser() async throws {
        let user = try await sut.fetchUser(id: "123")
        #expect(user.name == "Test User")
    }
}
```

### Shared State with Actor

```swift
actor TestFixture {
    static let shared = TestFixture()
    
    private var isSetUp = false
    private var testDatabase: TestDatabase?
    
    func setUp() async throws -> TestDatabase {
        if !isSetUp {
            testDatabase = try await TestDatabase.create()
            try await testDatabase?.migrate()
            isSetUp = true
        }
        return testDatabase!
    }
}

struct IntegrationTests {
    let db: TestDatabase
    
    init() async throws {
        db = try await TestFixture.shared.setUp()
    }
}
```

## Parameterized Tests

### Basic Parameters

```swift
@Test(arguments: [1, 2, 3, 4, 5])
func isPositive(number: Int) {
    #expect(number > 0)
}

@Test(arguments: ["hello", "world", "swift"])
func stringNotEmpty(value: String) {
    #expect(!value.isEmpty)
}
```

### Multiple Parameter Sets

```swift
@Test(arguments: [
    (input: "test@example.com", valid: true),
    (input: "invalid", valid: false),
    (input: "", valid: false),
    (input: "a@b.c", valid: true)
])
func emailValidation(input: String, valid: Bool) {
    #expect(EmailValidator.isValid(input) == valid)
}
```

### Cartesian Product

```swift
@Test(arguments: [1, 2, 3], ["a", "b"])
func combinations(number: Int, letter: String) {
    // Runs 6 times: (1,"a"), (1,"b"), (2,"a"), (2,"b"), (3,"a"), (3,"b")
    #expect(!"\(number)\(letter)".isEmpty)
}
```

### Zip (Parallel Iteration)

```swift
@Test(arguments: zip([1, 2, 3], ["one", "two", "three"]))
func numberNames(number: Int, name: String) {
    // Runs 3 times: (1,"one"), (2,"two"), (3,"three")
}
```

## Async Testing

### Confirmation

```swift
// Single confirmation
@Test func delegateCalled() async {
    await confirmation { confirm in
        let delegate = TestDelegate(onComplete: confirm)
        let sut = Processor(delegate: delegate)
        await sut.process()
    }
}

// Expected count
@Test func multipleEvents() async {
    await confirmation(expectedCount: 3) { confirm in
        let observer = Observer(onEvent: { _ in confirm() })
        await eventSource.emit(events: [.a, .b, .c])
    }
}

// Optional (0 or more)
@Test func maybeNotified() async {
    await confirmation(expectedCount: 0...5) { confirm in
        // ...
    }
}
```

### Timeout Handling

```swift
@Test(.timeLimit(.seconds(5)))
func networkRequest() async throws {
    let result = try await api.fetch()
    #expect(result.isValid)
}
```

## Mocking Patterns

### Protocol-Based Mocks

```swift
protocol APIClient: Sendable {
    func fetch<T: Decodable>(from endpoint: String) async throws -> T
}

final class MockAPIClient: APIClient, @unchecked Sendable {
    var responses: [String: Any] = [:]
    var errors: [String: Error] = [:]
    private(set) var requestedEndpoints: [String] = []
    
    func fetch<T: Decodable>(from endpoint: String) async throws -> T {
        requestedEndpoints.append(endpoint)
        
        if let error = errors[endpoint] {
            throw error
        }
        
        guard let response = responses[endpoint] as? T else {
            throw MockError.noResponse
        }
        
        return response
    }
    
    func stub<T>(_ endpoint: String, response: T) {
        responses[endpoint] = response
    }
    
    func stubError(_ endpoint: String, error: Error) {
        errors[endpoint] = error
    }
}
```

### Spy Pattern

```swift
actor CallSpy<T: Sendable> {
    private(set) var calls: [T] = []
    
    func record(_ call: T) {
        calls.append(call)
    }
    
    var callCount: Int { calls.count }
    var lastCall: T? { calls.last }
}

// Usage
struct AnalyticsTests {
    let spy = CallSpy<AnalyticsEvent>()
    
    @Test func tracksPageView() async {
        let analytics = Analytics { event in
            await spy.record(event)
        }
        
        analytics.trackPageView("home")
        
        let calls = await spy.calls
        #expect(calls.count == 1)
        #expect(calls[0] == .pageView("home"))
    }
}
```

## Snapshot Testing Pattern

```swift
@Test func viewSnapshot() throws {
    let view = ProfileView(user: .mock)
    let rendered = view.render()
    
    let snapshotPath = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("__Snapshots__/profile.txt")
    
    if ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil {
        try rendered.write(to: snapshotPath, atomically: true, encoding: .utf8)
    } else {
        let expected = try String(contentsOf: snapshotPath)
        #expect(rendered == expected)
    }
}
```

## Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter UserTests/fetchUser

# Run by tag
swift test --filter .tags:networking

# Parallel execution (default)
swift test --parallel

# Serial execution
swift test --no-parallel

# With code coverage
swift test --enable-code-coverage
```
