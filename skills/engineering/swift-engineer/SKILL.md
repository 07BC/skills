---
name: swift-engineer
description: Main skill for building features in a Swift/SwiftUI MV (Model-View) app — writes new Swift 6.2 code, SwiftUI views, services, tests, and async work. Use when implementing new features, screens, services, or test suites. For setting up a new app or auditing an existing app for MV-pattern adherence, use swift-architect. For reviewing code before commit/PR, use swift-code-review. For rewriting existing code without behaviour changes, use swift-quality. Triggers on Swift files (.swift), Xcode projects, SwiftUI components, or questions about Swift best practices.
---

# Swift Engineering

Main skill for building features in a Swift/SwiftUI app. Use this skill to
write new Swift 6.2 code, SwiftUI views, services, tests, and async work
**within the MV (Model-View) architecture** the project is built on.

> The architectural law for these projects: **MV, not MVVM.** Services are
> `@MainActor @Observable` and views observe them directly via
> `@Environment` / `@Bindable`. No `ObservableObject`, no `@Published`,
> no `*ViewModel` types. For app setup or MV-adherence audits, hand off to
> `swift-architect`.

## Required Companion Skills

Before writing any Swift code, load this skill:

- Read skill `swift-style` — code style, quality rules, and Swift 6
  language essentials (Sendable, isolation, typed throws). Apply every
  rule in that skill when generating new code.
- Read skill `swift-mv-guardian` -- MV architecture rules and anti-patterns. Apply every rule when
  generating new code.
- Load `swift-testing` when writing tests, and `swift-concurrency` when
adding async / actor / Sendable work.

## Build vs SourceKit — truth source

When editing Swift files, `<new-diagnostics>` system reminders may surface
SourceKit IDE diagnostics like:

- `Cannot find type X in scope`
- `Cannot find Y`
- `No exact matches in call to initializer`
- `No such module 'Testing'`
- `Generic parameter 'SelectionValue' could not be inferred`

If these fire **within 30 seconds of any file edit** and reference symbols,
types, or modules that exist in the project (you've grepped or just edited
the surrounding code), treat them as suspected SourceKit indexing lag, not
real failures. The IDE-side index can lag behind the compiler.

**Resolution:** a clean `xcodebuild build` (exit 0, zero errors, zero
warnings) is the authoritative answer. Trust it. Do not re-spawn an agent or
roll back changes on the SourceKit diagnostic alone.

When suppressed, emit one acknowledgement line:
`SourceKit indexing lag suppressed — build clean.` and continue.

**This rule does NOT apply to:**

- Diagnostics that persist after a clean build.
- Diagnostics on a file you have not recently edited — those may indicate a
  real regression you introduced indirectly (e.g. a removed type used
  elsewhere).
- Compiler errors surfaced inside `xcodebuild` output itself — those are
  always real.

The asymmetry: SourceKit can lie about the build state, but the build
itself cannot. Always re-verify with the build before acting on a
diagnostic.

## Core Principles

1. **No comments** — write no comments by default. Only add one when the WHY
   is non-obvious: a hidden constraint, a subtle invariant, a workaround for a
   specific bug, or behaviour that would surprise a reader. Never write doc
   comments (`///`). Never explain what the code does — well-named identifiers
   do that. If removing the comment wouldn't confuse a future reader, don't
   write it.
3. **MV pattern only** — `@MainActor @Observable` services own state; views
   observe them via `@Environment`. No ViewModel layer, no `ObservableObject`,
   no `@Published`. Heavy work lives behind a private `actor` composed into
   the service.
4. **Strict concurrency by default** — All new code must compile with
   `SWIFT_STRICT_CONCURRENCY=complete`
5. **Value semantics first** — Prefer structs; use classes only for identity,
   reference semantics, or an `@Observable` service
6. **Explicit error handling** — Use typed throws where beneficial; never
   force-unwrap in production
7. **Testability** — Design for dependency injection via the environment;
   **never use singletons in production code** (no `.shared`, no `static let shared`, no global instances — inject dependencies via initialisers or `@Environment` instead); never add code just for tests unless in mocks
8. **SwiftUI for UI** — Use SwiftUI for all new UI work; no new UIKit unless
9. **One view per file** — Keep views small and focused; one view per file is the standard convention
10. No global functions. Static functions **must** be inside an enum or struct. Top-level code is forbidden.
11. NO GOD OBJECTS. Services over 400 lines or with more than 10 properties must be broken down into smaller services.

## Swift 6 Essentials
> See `swift-style` for Data Race Safety, Isolation Boundaries, and Typed Throws.

## SwiftUI Patterns

### View Architecture (MV)

Views **observe** an `@Observable` service via `@Environment`. They never
own a `ViewModel`. The service holds state; the view renders it and dispatches
intent back into the service.

```swift
// ✅ Small, focused views — one view per file
// View observes a service from the environment; no ViewModel.

// UserListView.swift
struct UserListView: View {
    @Environment(\.userListService) private var service

    var body: some View {
        List(service.users) { user in
            UserRow(user: user)
        }
        .task { await service.load() }
        .refreshable { await service.refresh() }
    }
}

// UserRow.swift (separate file)
struct UserRow: View {
    let user: User

    var body: some View {
        HStack {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            Text(user.name)
        }
    }
}

#Preview {
    UserRow(user: .preview)
}
```

### State Management (MV pattern)

| Wrapper | Use Case |
|---------|----------|
| `@State` | View-local value types only (e.g. `isPresented: Bool`, search text) |
| `@Binding` | Two-way connection to parent value state |
| `@Observable` | Applied to **services** (reference types). Never to ViewModels — there are no ViewModels |
| `@Environment(\.someService)` | How views read services. This is the default injection mechanism |
| `@Bindable` | Bridge to write into an `@Observable` service from a view (only at the view boundary, never the property of choice) |
| `@AppStorage` | UserDefaults-backed persistence **in SwiftUI views only** — never inside an `@Observable` class |

**Forbidden in this codebase:**
- `ObservableObject` conformance
- `@Published`
- Any type named `*ViewModel`
- Business logic inside `View.body`

### Environment Values

Use the `@Entry` macro for custom environment values (iOS 18+, macOS 15+):

```swift
// ❌ Avoid: Old EnvironmentKey pattern
private struct TimerServiceKey: EnvironmentKey {
    static let defaultValue: TimerService? = nil
}

extension EnvironmentValues {
    var timerService: TimerService? {
        get { self[TimerServiceKey.self] }
        set { self[TimerServiceKey.self] = newValue }
    }
}

// ✅ Prefer: @Entry macro — one place for every injected service
// No Service should be Optional

extension EnvironmentValues {
  @Entry
  var timerService: TimerService = TimerService()

  @Entry
  var activityDetailService: ActivityDetailService = ActivityDetailService()

  @Entry
  var settingsService: SettingsService = SettingsService()

  @Entry
  var analyticsService: any AnalyticsServiceProtocol = MockAnalyticsService()
}
```

**Benefits of @Entry:**
- Less boilerplate — no separate key type needed
- Cleaner syntax — default value inline with property
- Grouped definitions — all environment values in one place
- Type-safe — compiler-generated key management

**Usage in views:**
```swift
struct TimerView: View {
    @Environment(\.timerService) private var service

    var body: some View {
        // Use service
    }
}
```

### Navigation (iOS 16+)

```swift
// ✅ Type-safe navigation with NavigationStack
struct ContentView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: User.self) { user in
                    UserDetailView(user: user)
                }
                .navigationDestination(for: Settings.self) { _ in
                    SettingsView()
                }
        }
    }
}
```

### Functions

// ❌ — NEVER GOD Method. Functions over 20 lines or with more than 4 parameters must be broken down into smaller functions with single responsibilities. If a function is doing too much, break it down into helper functions.
```swift
// ❌ — one method doing validation, derivation, loop iteration, and result assembly
func processOrder() throws -> [OrderLine] {
    guard !items.isEmpty else { return [] }
    let baseRate = pricing.rate(for: customer.tier)
    if baseRate == nil { return [] }                       // silent failure on nil
    let discountedRate = baseRate! * (1 - customer.discountFactor)  // force-unwrap
    let maxAttempts = max(items.count * 2, items.count + 10)
    var results: [OrderLine] = []
    results.reserveCapacity(items.count)
    for i in 0..<maxAttempts {                             // single-letter loop var
        if i >= items.count { break }
        let item = items[i]
        var lineTotal = item.quantity * item.unitPrice * discountedRate
        var tax = lineTotal * taxRate
        var taxRounded = Decimal()
        NSDecimalRound(&taxRounded, &tax, 2, .bankers)
        if lineTotal + taxRounded > spendingCap {
            lineTotal = spendingCap - taxRounded
        }
        if let voucher, voucher.appliesTo == item.id {
            if voucher.amount > lineTotal { throw OrderError.voucherExceedsLineTotal }
            lineTotal -= voucher.amount
        }
        results.append(OrderLine(itemID: item.id, total: lineTotal, tax: taxRounded))
    }
    return results
}

// ✅ — four named responsibilities, each under 20 lines
func processOrder() throws -> [OrderLine] {
    guard !items.isEmpty else { return [] }
    let effectiveRate = try deriveEffectiveRate()
    return try buildOrderLines(effectiveRate: effectiveRate)
}

private func deriveEffectiveRate() throws -> Decimal {
    guard let baseRate = pricing.rate(for: customer.tier) else {
        throw OrderError.noRateForTier(customer.tier)      // thrown, not silenced
    }
    return baseRate * (1 - customer.discountFactor)
}

private func buildOrderLines(effectiveRate: Decimal) throws -> [OrderLine] {
    var results: [OrderLine] = []
    results.reserveCapacity(items.count)
    for item in items {                                    // iterate the collection directly
        let line = try buildLine(item: item, effectiveRate: effectiveRate)
        results.append(line)
    }
    return results
}

private func buildLine(item: Item, effectiveRate: Decimal) throws -> OrderLine {
    var lineTotal = min(item.quantity * item.unitPrice * effectiveRate, spendingCap)
    let tax = rounded(lineTotal * taxRate)
    if let voucher, voucher.appliesTo == item.id {
        guard voucher.amount <= lineTotal else { throw OrderError.voucherExceedsLineTotal }
        lineTotal -= voucher.amount
    }
    return OrderLine(itemID: item.id, total: lineTotal, tax: tax)
}

private nonisolated func rounded(_ value: Decimal) -> Decimal {
    var raw = value
    var result = Decimal()
    NSDecimalRound(&result, &raw, 2, .bankers)
    return result
}
```

// ❌ Avoid: Global functions or static functions on classes
```swift
func formatDate(_ date: Date) -> String {
    // ...
}   

// ✅ Prefer: Static functions on structs or enums
enum DateFormatter {
    static func format(_ date: Date) -> String {
        // ...
    }
}
``` 

// ❌ Avoid: Functions with more than 4 parameters
```swift
func createUser(name: String, email: String, age: Int, isAdmin: Bool, avatarURL: URL) -> User {
    // ...
}   

// ✅ Prefer: Parameter objects for complex data
struct CreateUserRequest {
    let name: String
    let email: String
    let age: Int
    let isAdmin: Bool
    let avatarURL: URL
}

func createUser(request: CreateUserRequest) -> User {
    // ...
}
```

### Variables

// ❌ Avoid: Missing types when they can't be inferred, or when they improve readability
```swift
let user = functionThatReturnsAUser() // Type of 'user' is not clear   
```

// ✅ Prefer: Explicit types for clarity
```swift
let user: User = functionThatReturnsAUser() // Clear that 'user' is of type User
```


### Optionals

// ❌ NEVER: Force-unwrapping optionals in production code
```swift 
let httpResponse = response as! HTTPURLResponse // swiftlint:disable:this force_cast
```
// ✅ Always: Use safe unwrapping with guard or if-let, and handle nil cases explicitly
```swift
guard let httpResponse = response as? HTTPURLResponse else {
    throw NetworkError.invalidResponse
}
```

## Swift Testing
> See `swift-testing` for all unit-test authoring patterns.

## Structured Concurrency
> See `swift-concurrency` (concepts) or `swift-concurrency-expert` (fixes).

## Code Quality & Style
> See `swift-style` for method length, parameter count, naming, guard
> patterns, UserDefaults in `@Observable`, didSet, switch over if-else,
> overlay vs nested stacks, one-view-per-file, and all other style rules.

## Reviewing code

This skill is for **writing** new Swift. For reviewing existing code before a
commit or PR — including the full BLOCKER / WARNING / SUGGESTION pass and the
live Xcode navigator check — use the `swift-code-review` skill instead. It
loads this skill plus `swift-testing` and `swift-concurrency` and applies a
concrete checklist.

## References

This skill teaches the MV pattern. For canonical, up-to-date API details,
query Context7 with these library IDs (use `mcp__context7__query-docs`):

| Library ID | Use for |
|---|---|
| `/websites/developer_apple_swiftui` | SwiftUI views, modifiers, navigation, environment, animations |
| `/swiftlang/swift` | Swift language semantics, generics, macros, typed throws, result builders |
| `/websites/swift` | Swift language guide, the concurrency book, package manager |

For topic-specific guidance, hand off to the dedicated skill:

- **Style & quality (write-time)** — `swift-style`
- **Rewriting / clean-up** — `swift-quality`
- **Concurrency** — `swift-concurrency` (conceptual) or `swift-concurrency-expert` (hands-on fixes)
- **Testing** — `swift-testing`
- **Liquid Glass** — `swiftui-liquid-glass`