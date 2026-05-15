# Swift Concurrency Reference

## Actor Isolation Deep Dive

### Global Actors

```swift
// Define custom global actor
@globalActor
actor DatabaseActor {
    static let shared = DatabaseActor()
}

// Use on types or functions
@DatabaseActor
final class DatabaseManager {
    func query(_ sql: String) -> [Row] { ... }
}

@DatabaseActor
func performMigration() async { ... }
```

### Isolation Inheritance

```swift
actor BankAccount {
    var balance: Decimal = 0
    
    // Isolated to self by default
    func deposit(_ amount: Decimal) {
        balance += amount
    }
    
    // nonisolated - can be called synchronously from anywhere
    nonisolated func accountNumber() -> String {
        // Can only access immutable/Sendable state
        return _accountNumber
    }
    
    // Assume isolation when you know caller context
    nonisolated(unsafe) func unsafeAccess() {
        // Use sparingly - bypasses safety checks
    }
}
```

### Sendable Conformance Strategies

```swift
// 1. Value types with Sendable members - automatic
struct Point: Sendable {
    let x: Double
    let y: Double
}

// 2. Immutable reference types
final class Config: Sendable {
    let apiKey: String
    let baseURL: URL
    
    init(apiKey: String, baseURL: URL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
}

// 3. Internally synchronized types
final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]
    
    func get(_ key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }
}

// 4. Sendable closures
func process(completion: @Sendable () -> Void) { ... }
```

## Task Management

### Detached Tasks

```swift
// Unstructured - use sparingly
Task.detached(priority: .background) {
    // No parent task, not cancelled when caller cancels
    await performBackgroundSync()
}

// Prefer structured concurrency
func loadData() async throws {
    // Child task inherits cancellation
    async let result = fetchFromNetwork()
    return try await result
}
```

### Task Priorities

```swift
Task(priority: .userInitiated) { ... }  // User waiting
Task(priority: .utility) { ... }        // Long-running, not urgent
Task(priority: .background) { ... }     // Maintenance, sync

// Inherit from current context (default)
Task { ... }
```

### Task Local Values

```swift
enum RequestContext {
    @TaskLocal static var requestID: String?
    @TaskLocal static var userID: UUID?
}

// Set for duration of task
await RequestContext.$requestID.withValue("req-123") {
    await handleRequest()  // requestID available here
}
```

## AsyncSequence Patterns

### Built-in Sequences

```swift
// NotificationCenter
for await notification in NotificationCenter.default.notifications(named: .userDidLogin) {
    handleLogin(notification)
}

// URLSession bytes
let (bytes, response) = try await URLSession.shared.bytes(from: url)
for try await byte in bytes {
    process(byte)
}

// FileHandle
for try await line in FileHandle.standardInput.bytes.lines {
    print("Input: \(line)")
}
```

### AsyncStream

```swift
// Continuation-based stream
let stream = AsyncStream<Int> { continuation in
    for i in 1...10 {
        continuation.yield(i)
        try? await Task.sleep(for: .seconds(1))
    }
    continuation.finish()
}

// With buffering policy
let bufferedStream = AsyncStream<Event>(bufferingPolicy: .bufferingNewest(10)) { continuation in
    eventSource.onEvent = { continuation.yield($0) }
    eventSource.onComplete = { continuation.finish() }
}

// Throwing version
let throwingStream = AsyncThrowingStream<Data, Error> { continuation in
    networkClient.onData = { continuation.yield($0) }
    networkClient.onError = { continuation.finish(throwing: $0) }
    networkClient.onComplete = { continuation.finish() }
}
```

### Combining AsyncSequences

```swift
// Process multiple streams
func monitor() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            for await event in networkEvents {
                handle(event)
            }
        }
        group.addTask {
            for await event in userEvents {
                handle(event)
            }
        }
    }
}
```

## Continuations

### Wrapping Callback APIs

```swift
// Basic continuation
func fetchUser(id: String) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        legacyAPI.fetchUser(id: id) { result in
            switch result {
            case .success(let user):
                continuation.resume(returning: user)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}

// Unsafe (faster) when you guarantee single resume
func fetchUserUnsafe(id: String) async throws -> User {
    try await withUnsafeThrowingContinuation { continuation in
        // Same pattern, no runtime checks
    }
}
```

### Continuation Rules

1. **Resume exactly once** — Multiple resumes crash (checked) or undefined behavior (unsafe)
2. **Always resume** — Failing to resume leaks the task forever
3. **Thread-safe** — Can resume from any thread/queue

```swift
// ❌ WRONG - might resume twice
func bad() async -> Int {
    await withCheckedContinuation { cont in
        if condition {
            cont.resume(returning: 1)
        }
        cont.resume(returning: 0)  // Crash if condition was true
    }
}

// ✅ CORRECT
func good() async -> Int {
    await withCheckedContinuation { cont in
        if condition {
            cont.resume(returning: 1)
        } else {
            cont.resume(returning: 0)
        }
    }
}
```

## MainActor Patterns

### View Models

```swift
@MainActor
@Observable
final class ContentViewModel {
    var items: [Item] = []
    var isLoading = false
    var error: Error?
    
    private let service: ItemService
    
    init(service: ItemService) {
        self.service = service
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await service.fetchItems()
        } catch {
            self.error = error
        }
    }
}
```

### Escaping MainActor for Heavy Work

```swift
@MainActor
final class ImageProcessor {
    func processImage(_ image: UIImage) async -> UIImage {
        // Heavy work off main actor
        let processed = await Task.detached(priority: .userInitiated) {
            await self.applyFilters(image)
        }.value
        
        // Back on MainActor for UI update
        return processed
    }
    
    nonisolated func applyFilters(_ image: UIImage) async -> UIImage {
        // CPU-intensive work here
    }
}
```

## Common Pitfalls

### Actor Reentrancy

```swift
actor Counter {
    var value = 0
    
    // ⚠️ Reentrancy hazard
    func incrementTwice() async {
        value += 1
        await somethingAsync()  // Other code can run here!
        value += 1              // value might not be what you expect
    }
    
    // ✅ Capture state before suspension
    func safeIncrement() async {
        let current = value
        await somethingAsync()
        value = current + 2
    }
}
```

### Sendable Closure Captures

```swift
class ViewController: UIViewController {
    var data: [String] = []
    
    func loadData() {
        // ❌ Captures non-Sendable self
        Task {
            self.data = await fetchData()
        }
        
        // ✅ Explicitly handle on MainActor
        Task { @MainActor in
            self.data = await fetchData()
        }
    }
}
```
