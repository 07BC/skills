# Coding Standards

> Swift 6.2 · SwiftUI MVVM · enforced — not suggestions.
> Source: swift-mvvm-architect, swift-engineer, swift-style skills + project SwiftLint config.

---

## Architecture rules

**MVVM pattern — `@Observable` ViewModels, stateless repositories.**
Views bind to a `@State`-owned ViewModel. No `ObservableObject`, no `@Published`, no `@StateObject` for ViewModels. Per-screen transient state goes in `@State`. All view-driving state goes in the ViewModel.

**ViewModels: `@MainActor @Observable final class`.**
One ViewModel per screen, named `<Feature>ViewModel`. Constructed by the View via `@State`, repository injected via `init`. Never constructed in `AppDependencies`. Never registered in `@Environment`.

**Repositories: `Sendable final class`, stateless.**
No `@Observable`, no `@MainActor`. Methods return values — they hold no state. One repository per domain responsibility. Constructed once in `AppDependencies`. Injected via `@Environment`. Named `<Feature>Repository`.

**Domain layer: protocol-injected structs.**
Fetchers are stateless `struct` types. Domain models are `Sendable` structs/enums. Domain never imports `SwiftUI`, `UIKit`, or `Combine`.

**ViewModels do not import SwiftUI.**
ViewModels contain no view code. This is what makes them unit-testable.

**One type per file; filename matches type name exactly.**
Exception: a tightly-coupled `private` helper type may share the file with its owner.

**Protocols only when two conformers exist.**
Production type + test mock. Single-conformer protocols are banned.

**Cross-layer protocols live in `Domain/Protocols/`.**
The domain consumer depends on the protocol; the Infrastructure type conforms to it.

**Composition root is `AppDependencies`.**
No business logic there — pure wiring only. ViewModels are not constructed here.

---

## Prohibited patterns

| Banned | Use instead |
|--------|-------------|
| `SomeType.shared` in business logic | `@Environment` injection |
| `@EnvironmentObject` | `@Environment` with `@Entry` |
| `ObservableObject` + `@Published` | `@Observable` |
| `@StateObject` for ViewModels | `@State private var vm: FeatureViewModel` |
| `XCTestCase` for unit tests | Swift Testing (`@Test`, `@Suite`, `#expect`) |
| `class` for value types | `struct` or `enum` |
| `@Observable` on a repository | Move state into a ViewModel |
| ViewModel registered in `@Environment` | `@State` in the owning View |
| Business logic in `View.body` | ViewModel method |
| Concrete types in View inits | Repository protocol via `any FeatureRepositoryProtocol` |
| `import SwiftUI` in a ViewModel | Move UI concerns to the View |
| `import SwiftUI` in Domain or Repositories | Move UI concerns up |
| `import UIKit` in ViewModel, Domain, or Repositories | Move UI concerns up |
| `Combine` anywhere | `@Observable` |
| `DispatchQueue` | `async/await` + actors |
| Force-unwrap (`!`) in production | `guard let` / `if let` / `throws` |
| `Task.detached` without a comment | Scoped `Task { }` |
| `fatalError` | `throws` + structured errors |
| `TODO` / `FIXME` in shipped code | Jira ticket |
| Raw `CGFloat` literals in views | `UIConstants.*` tokens |

---

## Swift 6 concurrency rules

**All new code must compile with `SWIFT_STRICT_CONCURRENCY=complete`.**

**`Sendable` by default.** Every type you introduce should be `Sendable`. If it cannot be, reconsider the design before reaching for `@unchecked Sendable`.

**`@unchecked Sendable` requires a same-line justification comment.**
Use only for production types whose isolation is genuinely outside the type — for example, a thin wrapper over an SDK that owns its own threading. Mocks must never use `@unchecked Sendable` — mocks with mutable state must be `actor` types.
```swift
// Wrapper around vendor SDK that documents its own thread safety
final class AnalyticsSDKWrapper: @unchecked Sendable {}
```

**`nonisolated(unsafe)` requires a same-line justification comment.**
```swift
nonisolated(unsafe) var socket: URLSessionWebSocketTask  // SDK owns its own thread safety
```

**Actors for cross-isolation mutable state.** Any type with mutating shared state must be an `actor` (or `@MainActor` if UI-bound). Lock primitives — `Mutex`, `NSLock`, `NSRecursiveLock`, `os_unfair_lock`, `OSAllocatedUnfairLock`, `DispatchSemaphore`, `@synchronized` — are not approved in this project. If a call site is synchronous and tempts you toward a lock, refactor the call site to `await`, not the state to a lock.

**ViewModels are `@MainActor`, actors are for infrastructure.** Do not isolate a ViewModel to a non-main actor. Do not use `DispatchQueue.main`.

**`[weak self]` in every `Task { }` that outlives its owner.**

**Cancel before re-triggering.** ViewModels that paginate or reload must cancel the in-flight task before starting a new one.

---

## Async patterns

```swift
// ✅ async/await only
func load() async throws -> [Item] { ... }

// ❌ no completion handlers in new code
func load(completion: @escaping (Result<[Item], Error>) -> Void) { ... }

// ✅ withCheckedContinuation — correct bridge for legacy completion-handler APIs
```

---

## Style

**Indentation:** 4 spaces (adjust to project `.swift-format` config).

**Line length:** 100 characters (swift-style skill default). This project overrides to 150 max (SwiftLint warning at 130, error at 160) to accommodate SwiftUI modifier chains — update `.swiftlint.yml` accordingly.

**Type body length:** 350 lines warning / 400 lines error.

**File length:** 800 lines warning / 1200 lines error.

**Function body:** 50 lines warning / 80 lines error. Break into private helpers.

**Comments:** Add only when the *why* is non-obvious — hidden constraint, subtle invariant, workaround for a specific bug. Never describe *what* the code does.

**`MARK: -` sections** — use consistently:
```swift
// MARK: - State
// MARK: - Init
// MARK: - Intent
// MARK: - Private
```

**Closures and `Task` bodies: content always on its own line.**
```swift
// Wrong
Task { [weak self] in await self?.reload() }

// Correct
Task { [weak self] in
    await self?.reload()
}
```

**Sibling closure calls: separated by a blank line.**
```swift
connection.onEvent { [weak self] event in
    self?.handle(event)
}

connection.onError { [weak self] error in
    self?.handle(error)
}
```

**Force cast / force try:** prohibited in production. Allowed in `#Preview` and `@Test` functions.

---

## Logging

**`Console.log(…)` / `Console.error(…)` always — never `print()`.**
Enforced by SwiftLint custom rule `no_print`. `Console` routes through the analytics sink so all output is observable.

```swift
// ✅
Console.log("Session restored")
Console.error(error)

// ❌
print("Session restored")
debugPrint(error)
```

---

## Testing rules

See `testing.md` for full patterns.

- Swift Testing only — never `XCTestCase` for unit tests.
- Tags required on every `@Suite`.
- `@Test` descriptions are backtick-quoted natural-language sentences.
- Fresh mock instances per test — never `.shared` singletons.
- No `Task.sleep` — use `confirmation { }` for callback/notification APIs, `withCheckedContinuation` for legacy completion handlers, or `await` the ViewModel method directly.
- Never test Apple APIs or framework internals.
- Never test `UserDefaults` or `AppStorage` directly (parallel-test race conditions).
- **Primary unit-test target is the ViewModel** — it contains all business logic and is SwiftUI-free.

---

## Storage rules

- All persistence through `StorageService` or `StorageServiceProtocol`.
- No raw `UserDefaults` access in ViewModels, repositories, or domain code.
- No SwiftData, no Core Data, no `NSCoding` archival.
- Secrets → `StorageMode.private` (Keychain). Non-secret prefs → `StorageMode.standard`.

---

## Git

- Branch naming: `<owner>/<ticket>-<feature>` (lowercase, hyphens).
- Commits: plain imperative, one change per commit, no AI-attribution trailers.
- Do not auto-commit. Do not auto-push.
