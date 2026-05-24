# Sendable

Type safety patterns for sharing data across concurrency boundaries.

## What is Sendable?

`Sendable` indicates a type is safe to share across isolation domains (actors, tasks, threads). The compiler verifies thread-safety at compile time.

```swift
public protocol Sendable {}
```

Empty protocol, but triggers compiler verification of thread-safety.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.1: Explaining the concept of Sendable in Swift](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Isolation Domains

Three types of isolation in Swift Concurrency:

### 1. Nonisolated (default)

No concurrency restrictions, but can't modify isolated state:

```swift
func computeValue(a: Int, b: Int) -> Int {
    return a + b
}
```

### 2. Actor-isolated

Dedicated isolation domain with serialized access:

```swift
actor Library {
    var books: [String] = []
    
    func addBook(_ title: String) {
        books.append(title)
    }
}

// External access requires await
await library.addBook("Swift Concurrency")
```

### 3. Global actor-isolated

Shared isolation domain across types:

```swift
@MainActor
func updateUI() {
    // Runs on main thread
}
```

## Data Races vs Race Conditions

### Data Race

Multiple threads access shared mutable state, at least one writes, without synchronization:

```swift
// ⚠️ Data race
var counter = 0
DispatchQueue.global().async { counter += 1 }
DispatchQueue.global().async { counter += 1 }
```

**Detection**: Enable Thread Sanitizer in scheme settings.

**Prevention**: Use actors or Sendable types:

```swift
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1
    }
}
```

### Race Condition

Timing-dependent behavior leading to unpredictable results:

```swift
let counter = Counter()

for _ in 1...10 {
    Task { await counter.increment() }
}

// May print inconsistent values
print(await counter.getValue())
```

**Key difference**: Swift Concurrency prevents data races but not race conditions. You must still ensure proper sequencing.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.2: Understanding Data Races vs. Race Conditions: Key Differences Explained](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Value Types (Structs, Enums)

### Implicit conformance

Non-public structs/enums with Sendable members:

```swift
// Implicitly Sendable
struct Person {
    var name: String
}
```

### Explicit conformance required

Public types need explicit declaration:

```swift
public struct Person: Sendable {
    var name: String
}
```

**Why**: Compiler can't verify internal details of public types across modules.

### Frozen types

Public frozen types can be implicitly Sendable:

```swift
@frozen
public struct Point: Sendable {
    public var x: Double
    public var y: Double
}
```

### All members must be Sendable

```swift
public struct Person: Sendable {
    var name: String
    var hometown: Location // Must also be Sendable
}

public struct Location: Sendable {
    var name: String
}
```

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.3: Conforming your code to the Sendable protocol](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

### Copy-on-write makes mutability safe

```swift
public struct Person: Sendable {
    var name: String // Mutable but safe due to COW
}
```

Each mutation creates a copy, preventing concurrent access to same instance.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.4: Sendable and Value Types](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Reference Types (Classes)

### Requirements for Sendable classes

Must be:
1. `final` (no inheritance)
2. Immutable stored properties only
3. All properties Sendable
4. No superclass or `NSObject` only

```swift
final class User: Sendable {
    let name: String
    let id: Int
    
    init(name: String, id: Int) {
        self.name = name
        self.id = id
    }
}
```

### Why non-final classes can't be Sendable

Child classes could introduce unsafe mutability:

```swift
// Can't be Sendable
class Purchaser {
    func purchase() { }
}

// Could introduce data races
class GamePurchaser: Purchaser {
    var credits: Int = 0 // Mutable!
}
```

### Actor isolation makes classes Sendable

```swift
@MainActor
class ViewModel {
    var data: [Item] = [] // Safe due to actor isolation
}
// Implicitly Sendable
```

### Composition over inheritance

```swift
final class Purchaser: Sendable {
    func purchase() { }
}

final class GamePurchaser {
    let purchaser: Purchaser = Purchaser()
    // Handle credits separately
}
```

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.5: Sendable and Reference Types](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Functions and Closures (@Sendable)

Mark functions/closures that cross isolation domains:

```swift
actor ContactsStore {
    func removeAll(_ shouldRemove: @Sendable (Contact) -> Bool) async {
        contacts.removeAll { shouldRemove($0) }
    }
}
```

### Captured values must be Sendable

```swift
let query = "search"

// ✅ Immutable capture
store.filter { contact in
    contact.name.contains(query)
}

var query = "search"

// ❌ Mutable capture
store.filter { contact in
    contact.name.contains(query) // Error
}
```

### Capture lists for mutable values

```swift
var query = "search"

// ✅ Capture immutable snapshot
store.filter { [query] contact in
    contact.name.contains(query)
}
```

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.6: Using @Sendable with closures](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## @unchecked Sendable

**Reach for an actor first.** `@unchecked Sendable` exists as an escape hatch for the small number of classes you genuinely cannot make into an actor — typically wrappers around third-party non-Sendable types you don't own, or types constrained to be a `class` by an external protocol.

### The default: actor

For anything with mutating shared state, the answer is an actor:

```swift
actor Cache {
    private var items: [String: Data] = [:]

    var count: Int { items.count }

    func get(_ key: String) -> Data? { items[key] }

    func set(_ key: String, value: Data) { items[key] = value }
}
```

### The escape hatch

Only when the class shape is forced on you and you cannot adopt an actor, wrap the underlying non-Sendable object in a single serial `DispatchQueue`-free actor adapter, or — if you truly cannot — keep it as a class and serialise through an internal actor:

```swift
final class ThirdPartyClientWrapper: @unchecked Sendable {
    private let inbox = MessageInbox() // actor, defined elsewhere

    func send(_ message: Message) async {
        await inbox.enqueue(message)
    }
}

actor MessageInbox {
    private var pending: [Message] = []
    func enqueue(_ message: Message) { pending.append(message) }
}
```

### Risks of using @unchecked without an actor underneath

If you keep `@unchecked Sendable` without an actor doing the serialisation, you've turned off the compiler's only check. It is easy to forget a synchronisation step on a new code path and silently introduce a data race. Always run the actor; reserve `@unchecked Sendable` for the outer shape only.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.7: Using @unchecked Sendable](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Region-Based Isolation

Compiler allows non-Sendable types in same scope:

```swift
class Article {
    var title: String
    init(title: String) { self.title = title }
}

func check() {
    let article = Article(title: "Swift")
    
    Task {
        print(article.title) // ✅ OK - same region
    }
}
```

**Why**: No mutation after transfer, so no data race risk.

### Breaks when accessed after transfer

```swift
func check() {
    let article = Article(title: "Swift")
    
    Task {
        print(article.title)
    }
    
    print(article.title) // ❌ Error - accessed after transfer
}
```

## The sending Keyword

Enforces ownership transfer for non-Sendable types:

### Parameter values

```swift
actor Logger {
    func log(article: Article) {
        print(article.title)
    }
}

func printTitle(article: sending Article) async {
    let logger = Logger()
    await logger.log(article: article)
}

// Usage
let article = Article(title: "Swift")
await printTitle(article: article)
// article no longer accessible here
```

### Return values

```swift
@SomeActor
func createArticle(title: String) -> sending Article {
    return Article(title: title)
}
```

Transfers ownership to caller's region.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.8: Understanding region-based isolation and the sending keyword](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Global Variables

Must be concurrency-safe since accessible from any context.

### Problem

```swift
class ImageCache {
    static var shared = ImageCache() // ⚠️ Not concurrency-safe
}
```

### Solution 1: Actor isolation

```swift
@MainActor
class ImageCache {
    static var shared = ImageCache()
}
```

### Solution 2: Immutable + Sendable

```swift
final class ImageCache: Sendable {
    static let shared = ImageCache()
}
```

### Solution 3: nonisolated(unsafe)

**Last resort** - you guarantee safety:

```swift
struct APIProvider: Sendable {
    nonisolated(unsafe) static private(set) var shared: APIProvider!
    
    static func configure(apiURL: URL) {
        shared = APIProvider(apiURL: apiURL)
    }
}
```

Use `private(set)` to limit mutation points.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.9: Concurrency-safe global variables](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Migrating Lock-Based Legacy Code

You will inherit code that uses `NSLock`, `os_unfair_lock`, or `DispatchSemaphore` to guard mutable state. The target shape is always an actor.

### Before — legacy class with a lock

```swift
final class BankAccount: @unchecked Sendable {
    private var balance: Int = 0
    private let lock = NSLock()

    func deposit(amount: Int) {
        lock.lock()
        balance += amount
        lock.unlock()
    }

    func getBalance() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return balance
    }
}
```

> Prefer an actor — the lock + `@unchecked Sendable` combination has no compile-time guarantee that every accessor takes the lock.

### After — actor

```swift
actor BankAccount {
    private var balance: Int = 0

    func deposit(amount: Int) { balance += amount }

    func getBalance() -> Int { balance }
}
```

### Migration order

1. **New code**: always an actor. Locks are not on the menu.
2. **Existing code, small scope**: migrate to actor in the same PR.
3. **Existing code, widely used**: keep the class temporarily, but route its state-touching methods through an internal actor (see "The escape hatch" above). File a follow-up to remove the outer class.

> **Course Deep Dive**: This topic is covered in detail in [Lesson 4.10: Combining Sendable with custom Locks](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference)

## Decision Tree

```
Need to share type across isolation domains?
├─ Value type (struct/enum)?
│  ├─ Public? → Add explicit Sendable
│  └─ Internal? → Implicit Sendable (if members Sendable)
│
├─ Reference type (class)?
│  ├─ Can be final + immutable? → Sendable
│  ├─ Needs mutation?
│  │  ├─ UI-bound? → @MainActor
│  │  ├─ Can be an actor? → Yes — make it an actor (automatic Sendable)
│  │  └─ Class shape forced by external constraint? → @unchecked Sendable wrapping an internal actor
│  └─ Can be struct instead? → Refactor to struct
│
└─ Function/closure? → @Sendable attribute
```

## Common Patterns

### Restructure to avoid non-Sendable dependencies

```swift
// Instead of storing non-Sendable type
public struct Person: Sendable {
    var hometown: String // Just the name
    
    init(hometown: Location) {
        self.hometown = hometown.name
    }
}
```

### Prefer actors for mutable state

```swift
// Instead of @unchecked Sendable with locks
actor Cache {
    private var items: [String: Data] = [:]
    
    func get(_ key: String) -> Data? {
        items[key]
    }
}
```

### Use @MainActor for UI-bound types

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```

## Best Practices

1. **Prefer value types** - structs/enums are easier to make Sendable
2. **Use actors for mutable state** - automatic thread-safety
3. **Avoid @unchecked Sendable** - use only for proven thread-safe code
4. **Mark public types explicitly** - don't rely on implicit conformance
5. **Ensure all members Sendable** - one non-Sendable breaks the chain
6. **Use @MainActor for UI types** - simple isolation for view models
7. **Capture immutably** - use capture lists for mutable variables
8. **Test with Thread Sanitizer** - catches runtime data races
9. **File migration tickets** - track @unchecked Sendable usage

## Further Learning

For migration strategies, real-world examples, and actor patterns, see [Swift Concurrency Course](https://www.swiftconcurrencycourse.com).

