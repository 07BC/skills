# Actors

Data isolation patterns and thread-safe state management in Swift.

## What is an Actor?

Actors protect mutable state by ensuring only one task accesses it at a time. They're reference types with automatic synchronization.

```swift
actor Counter {
    var value = 0
    
    func increment() {
        value += 1
    }
}
```

**Key guarantee**: Only one task can access mutable state at a time (serialized access).

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.1: Understanding actors in Swift Concurrency](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Actor Isolation

### Enforced by compiler

```swift
actor BankAccount {
    var balance: Int = 0
    
    func deposit(_ amount: Int) {
        balance += amount
    }
}

let account = BankAccount()
account.balance += 1 // ❌ Error: can't mutate from outside
await account.deposit(1) // ✅ Must use actor's methods
```

### Reading properties

```swift
let account = BankAccount()
await account.deposit(100)
print(await account.balance) // Must await reads too
```

Always use `await` when accessing actor properties/methods—you don't know if another task is inside.

## Actors vs Classes

### Similarities

- Reference types (copies share same instance)
- Can have properties, methods, initializers
- Can conform to protocols

### Differences

- **No inheritance** (except `NSObject` for Objective-C interop)
- **Automatic isolation** (no manual locks needed)
- **Implicit Sendable** conformance

```swift
// ❌ Can't inherit from actors
actor Base {}
actor Child: Base {} // Error

// ✅ NSObject exception
actor Example: NSObject {} // OK for Objective-C
```

## Global Actors

Shared isolation domain across types, functions, and properties.

### @MainActor

Ensures execution on main thread:

```swift
@MainActor
final class ViewModel {
    var items: [Item] = []
}

@MainActor
func updateUI() {
    // Always runs on main thread
}

@MainActor
var title: String = ""
```

### Custom global actors

```swift
@globalActor
actor ImageProcessing {
    static let shared = ImageProcessing()
    private init() {} // Prevent duplicate instances
}

@ImageProcessing
final class ImageCache {
    var images: [URL: Data] = [:]
}

@ImageProcessing
func applyFilter(_ image: UIImage) -> UIImage {
    // All image processing serialized
}
```

**Use private init** to prevent creating multiple executors.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.2: An introduction to Global Actors](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## @MainActor Best Practices

### When to use

UI-related code that must run on main thread:

```swift
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```

### Replacing DispatchQueue.main

```swift
// Old way
DispatchQueue.main.async {
    // Update UI
}

// Modern way
await MainActor.run {
    // Update UI
}

// Better: Use attribute
@MainActor
func updateUI() {
    // Automatically on main thread
}
```

### MainActor.assumeIsolated

**Use sparingly** - assumes you're on main thread, crashes if not:

```swift
func methodB() {
    assert(Thread.isMainThread) // Validate assumption
    
    MainActor.assumeIsolated {
        someMainActorMethod()
    }
}
```

**Prefer**: Explicit `@MainActor` or `await MainActor.run` over `assumeIsolated`.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.3: When and how to use @MainActor](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Isolated vs Nonisolated

### Default: Isolated

Actor methods are isolated by default:

```swift
actor BankAccount {
    var balance: Double
    
    // Implicitly isolated
    func deposit(_ amount: Double) {
        balance += amount
    }
}
```

### Isolated parameters

Reduce suspension points by inheriting caller's isolation:

```swift
struct Charger {
    static func charge(
        amount: Double,
        from account: isolated BankAccount
    ) async throws -> Double {
        // No await needed - we're isolated to account
        try account.withdraw(amount: amount)
        return account.balance
    }
}
```

### Isolated closures

```swift
actor Database {
    func transaction<T>(
        _ operation: @Sendable (_ db: isolated Database) throws -> T
    ) throws -> T {
        beginTransaction()
        let result = try operation(self)
        commitTransaction()
        return result
    }
}

// Usage: Multiple operations, one await
try await database.transaction { db in
    db.insert(item1)
    db.insert(item2)
    db.insert(item3)
}
```

### Generic isolated extension

```swift
extension Actor {
    func performInIsolation<T: Sendable>(
        _ block: @Sendable (_ actor: isolated Self) throws -> T
    ) async rethrows -> T {
        try block(self)
    }
}

// Usage
try await bankAccount.performInIsolation { account in
    try account.withdraw(amount: 20)
    print("Balance: \(account.balance)")
}
```

### Nonisolated

Opt out of isolation for immutable data:

```swift
actor BankAccount {
    let accountHolder: String
    
    nonisolated var details: String {
        "Account: \(accountHolder)"
    }
}

// No await needed
print(account.details)
```

### Protocol conformance

```swift
extension BankAccount: CustomStringConvertible {
    nonisolated var description: String {
        "Account: \(accountHolder)"
    }
}
```

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.4: Isolated vs. non-isolated access in actors](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Isolated Deinit (Swift 6.2+)

Clean up actor state on deallocation:

```swift
actor FileDownloader {
    var downloadTask: Task<Void, Error>?
    
    isolated deinit {
        downloadTask?.cancel() // Can call isolated methods
    }
}
```

**Requires**: iOS 18.4+, macOS 15.4+

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.5: Using Isolated synchronous deinit](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Global Actor Isolated Conformance (Swift 6.2+)

Protocol conformance respecting actor isolation:

```swift
@MainActor
final class PersonViewModel {
    let id: UUID
    var name: String
}

extension PersonViewModel: @MainActor Equatable {
    static func == (lhs: PersonViewModel, rhs: PersonViewModel) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
```

**Enable**: `InferIsolatedConformances` upcoming feature.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.6: Adding isolated conformance to protocols](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Actor Reentrancy

**Critical**: State can change between suspension points.

```swift
actor BankAccount {
    var balance: Double
    
    func deposit(amount: Double) async {
        balance += amount
        
        // ⚠️ Actor unlocked during await
        await logActivity("Deposited \(amount)")
        
        // ⚠️ Balance may have changed!
        print("Balance: \(balance)")
    }
}
```

### Problem

```swift
async let _ = account.deposit(50)
async let _ = account.deposit(50)
async let _ = account.deposit(50)

// May print same balance three times:
// Balance: 150
// Balance: 150
// Balance: 150
```

### Solution

Complete actor work before suspending:

```swift
func deposit(amount: Double) async {
    balance += amount
    print("Balance: \(balance)") // Before suspension
    
    await logActivity("Deposited \(amount)")
}
```

**Rule**: Don't assume state is unchanged after `await`.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.7: Understanding actor reentrancy](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## #isolation Macro

Inherit caller's isolation for generic code:

```swift
extension Collection where Element: Sendable {
    func sequentialMap<Result: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        transform: (Element) async -> Result
    ) async -> [Result] {
        var results: [Result] = []
        for element in self {
            results.append(await transform(element))
        }
        return results
    }
}

// Usage from @MainActor context
Task { @MainActor in
    let names = ["Alice", "Bob"]
    let results = await names.sequentialMap { name in
        await process(name) // Inherits @MainActor
    }
}
```

**Benefits**: Avoids unnecessary suspensions, allows non-Sendable data.

### Task Closures and Isolation Inheritance

When spawning unstructured `Task` closures that need to work with `non-Sendable` types, you must capture the isolation parameter to inherit the caller's isolation context.

**Problem**: `Task` closures are `@Sendable`, which prevents capturing `non-Sendable` types:

```swift
func process(delegate: NonSendableDelegate) {
  Task {
    delegate.doWork() // ❌ Error: capturing non-Sendable type
  }
}
```

**Solution**: Use `#isolation` parameter and capture it inside the `Task`:

```swift
func process(
  delegate: NonSendableDelegate,
  isolation: isolated (any Actor)? = #isolation
) {
  Task {
    _ = isolation  // Forces capture, Task inherits caller's isolation
    delegate.doWork()  // ✅ Safe - running on caller's actor
  }
}
```

**Why `_ = isolation` is required**: Per [SE-0420](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md), `Task` closures only inherit isolation when "a non-optional binding of an isolated parameter is captured by the closure." The `_ = isolation` statement forces this capture. The capture list syntax `[isolation]` should work but currently does not.

**When to use this pattern**:
- Spawning `Task`s that work with `non-Sendable` delegate objects
- Fire-and-forget async work that needs access to caller's state
- Bridging callback-based APIs to async streams while keeping delegates alive

**Note**: This pattern keeps the `non-Sendable` value alive and accessible within the `Task`. The `Task` runs on the caller's isolation domain, so no cross-isolation "sending" occurs.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.8: Inheritance of actor isolation using the #isolation macro](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Custom Actor Executors

**Advanced**: Control how actor schedules work.

### Serial executor

```swift
final class DispatchQueueExecutor: SerialExecutor {
    private let queue: DispatchQueue
    
    init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        
        queue.async {
            unownedJob.runSynchronously(on: executor)
        }
    }
}

actor LoggingActor {
    private let executor: DispatchQueueExecutor
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    init(queue: DispatchQueue) {
        executor = DispatchQueueExecutor(queue: queue)
    }
}
```

### When to use

- Integration with legacy DispatchQueue-based code
- Specific thread requirements (e.g., C++ interop)
- Custom scheduling logic

**Default executor is usually sufficient.**

> **Course Deep Dive**: This topic is covered in detail in [Lesson 5.9: Using a custom actor executor](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Why not `Mutex`?

`Mutex` from `Swift.Synchronization` is a synchronous lock. You will see it in older codebases and in some Apple sample code. It is not an approved primitive in this project. Anything with mutating shared state must be an actor.

### The counter, done properly

```swift
actor Counter {
    private(set) var currentCount = 0
    func increment() { currentCount += 1 }
}
```

### Sharing a non-Sendable object across tasks

A `Mutex`-wrapped non-Sendable object (e.g. `NSBezierPath`) tempts you into a class with a synchronous API. The actor equivalent keeps the non-Sendable state inside the isolation domain and exposes only `Sendable` operations:

```swift
actor TouchesCapturer {
    private let path = NSBezierPath()

    func storeTouch(_ point: NSPoint) {
        path.move(to: point)
    }
}
```

### Errors out of an actor

`throws` works identically inside an actor — no special wrapper needed:

```swift
actor Counter {
    enum Error: Swift.Error { case reachedZero }
    private var count = 0

    func decrement() throws {
        guard count > 0 else { throw Error.reachedZero }
        count -= 1
    }
}
```

### Why an actor and not a lock?

- **Compile-time isolation.** The compiler enforces that every accessor goes through the actor's serialised queue. A lock guards only the call sites that remember to take it.
- **Composes with async/await.** Callers `await` the actor; no `withLock` closure, no risk of holding a lock across a suspension point.
- **One mental model.** Engineers reading the code only need to understand actors. `Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore` are not vocabulary the rest of the codebase uses.

If you find yourself wanting `Mutex` because the call site is synchronous, the call site is the thing to refactor, not the state.

## Common Patterns

### View model with @MainActor

```swift
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    func loadItems() async {
        items = try await api.fetchItems()
    }
}
```

### Background processing with custom actor

```swift
@ImageProcessing
final class ImageProcessor {
    func process(_ images: [UIImage]) async -> [UIImage] {
        images.map { applyFilters($0) }
    }
}
```

### Mixed isolation

```swift
actor DataStore {
    private var items: [Item] = []
    
    func add(_ item: Item) {
        items.append(item)
    }
    
    nonisolated func itemCount() -> Int {
        // ❌ Can't access items
        return 0
    }
}
```

### Transaction pattern

```swift
actor Database {
    func transaction<T>(
        _ operation: @Sendable (_ db: isolated Database) throws -> T
    ) throws -> T {
        beginTransaction()
        defer { commitTransaction() }
        return try operation(self)
    }
}
```

## Best Practices

1. **Actors over any lock primitive** — `Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore` are not approved.
2. **Use @MainActor for UI** — all view models and UI updates.
3. **Minimise work in actors** — keep critical sections short.
4. **Watch for reentrancy** — don't assume state is unchanged after an `await`.
5. **Use `nonisolated` sparingly** — only for truly immutable data.
6. **Avoid `assumeIsolated`** — prefer explicit isolation.
7. **Custom executors are rare** — the default is usually best.
8. **Refactor sync call sites, don't lock the state** — a synchronous-feeling API around mutable state belongs in an actor.
9. **Complete actor work before suspending** — prevent reentrancy bugs.
10. **Use isolated parameters** — reduce suspension points.

## Decision Tree

```
Need thread-safe mutable state?
├─ UI-related? → @MainActor
├─ Single shared instance? → Actor (or Global Actor if process-wide)
└─ Synchronous call site forced on you?
   └─ Refactor the call site to `await`, then use an Actor.
       Locks (`Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore`)
       are not approved primitives — see "Why not Mutex?" above.
```

## Further Learning

For migration strategies, advanced patterns, and real-world examples, see [Swift Concurrency Course](https://www.swiftconcurrencycourse.com).

