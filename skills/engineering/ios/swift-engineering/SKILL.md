---
name: swift-engineering
description: >
  THE entry point for writing, editing, or rewriting Swift/SwiftUI in an MV
  or MVVM app — new Swift 6.2 code, SwiftUI views, services, async work,
  AND behaviour-preserving rewrites: cleaning up messy code, refactoring for
  readability, and migrating a legacy ObservableObject/@Published type to the
  @Observable form ("convert to @Observable", "clean this up", "refactor",
  "make this readable"). Also fixes concrete Swift 6 concurrency errors, data
  races, actor-isolation warnings, and Sendable gaps in existing code. This is
  the single "Engineer" — writing any Swift 6 + SwiftUI is one job. You never
  pick a sub-skill for it: it auto-applies swift-style (always) and pulls in
  swift-concurrency (async / actor / Sendable work) and swiftui-liquid-glass
  (iOS 26+ Liquid Glass UI) automatically as the task needs them. Triggers on
  .swift files, Xcode projects, SwiftUI components, or any request to
  write/change Swift. For setting up a NEW app or auditing architecture
  adherence, use swift-mv-architecture (MV projects) or swift-mvvm-architecture
  (MVVM projects). To REVIEW code without changing it, use swift-code-review.
  To write tests, use swift-testing.
---

# Swift Engineering

Main skill for building features in a Swift/SwiftUI app. Use this skill to
write new Swift 6.2 code, SwiftUI views, services, tests, and async work
**within the architecture the project is built on**.

## Architecture selection (read before writing any code)

The project's active architecture is declared in its `CLAUDE.md` (or the
architecture authority doc it points to). Determine it before generating code:

1. Read the project `CLAUDE.md`. Look for an explicit `architecture:` line
   (`MV`, `MVVM`) or a link to `docs/MV target architecture/` or
   `docs/MVVM target architecture/`.
2. If it declares **MV** → load skill `swift-mv-architecture` and apply its rules.
3. If it declares **MVVM** → load skill `swift-mvvm-architecture` and apply its rules
   (`@Observable @MainActor` ViewModels + stateless `Sendable` Repositories).
4. If it declares **mixed / migrating**, no declaration can be found, or the
   codebase shows both shapes → **STOP. Do not guess.** Ask the user via
   `AskUserQuestion` which architecture this work targets:
   - Option A: MV (Model-View — `@Observable` services + `@Environment`)
   - Option B: MVVM (`@Observable @MainActor` ViewModels + stateless Repository)
   - Option C: Inspect first — run the `architecture-doc` detection scripts.
   Only proceed once the user picks.

The chosen architect skill is a **part of the Engineer** for this project — load
it yourself; the user does not invoke it separately.

**Common to both architectures (always forbidden):**
`ObservableObject` conformance · `@Published` · logic or networking in `View.body`

## Required Companion Skills

Before writing any Swift code, load these:

- Read skill `swift-style` — code style, quality rules, and Swift 6
  language essentials (Sendable, isolation, typed throws). Apply every
  rule in that skill when generating new code.
- Load the matching architect skill per the Architecture selection section above.
- Load `swift-testing` when writing tests, `swift-concurrency` when
  adding async / actor / Sendable work, `swiftui-liquid-glass` when
  building or adopting iOS 26+ Liquid Glass UI, and `swift-format-style`
  when formatting any value for display (numbers, currencies, dates,
  measurements, durations).

**Auto-loaded companions:**

The following skills load automatically alongside this skill as the task needs them — do not invoke separately:

- `swift-format-style` — loads when writing code that formats values for display. Enforces `.formatted()` with FormatStyle and explicitly prohibits `String(format:)`.

**Formatting rule:**

When displaying formatted values, always use `.formatted()` with the appropriate
FormatStyle — never use `String(format:)` or legacy formatters.

These companions are **parts of the Engineer**, not separate skills the user
invokes — load them yourself as the task needs them.

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

**Slow-build escape hatch.** If a clean build exceeds 60 seconds and no
incremental build can be triggered, you may accept a single SourceKit
diagnostic pass as a provisional signal — but never commit on SourceKit
alone. Re-verify with the build before declaring the task done.

## Core Principles

1. **No comments** — write no comments by default. Only add one when the WHY
   is non-obvious: a hidden constraint, a subtle invariant, a workaround for a
   specific bug, or behaviour that would surprise a reader. Never write doc
   comments (`///`). Never explain what the code does — well-named identifiers
   do that. If removing the comment wouldn't confuse a future reader, don't
   write it.
2. **No god methods** — functions over 20 lines or with more than 4
   parameters must be broken down into smaller functions with single
   responsibilities. If a function is doing too much, extract named private
   helpers, each one under 20 lines.
3. **Follow the declared architecture** — apply the rules loaded from the
   matching architect skill (see Architecture selection above). In both
   architectures: the observable layer is `@MainActor @Observable`; heavy
   work lives behind a private `actor` (MV) or flows through a stateless
   `Sendable` Repository (MVVM); no `ObservableObject`, no `@Published`.
4. **Strict concurrency by default** — all new code must compile with
   `SWIFT_STRICT_CONCURRENCY=complete`.
5. **Value semantics first** — prefer structs; use classes only for identity,
   reference semantics, or an `@Observable` service.
6. **Explicit error handling** — use typed throws where beneficial; never
   force-unwrap in production.
7. **Testability** — design for dependency injection via the environment;
   **never use singletons in production code** (no `.shared`, no
   `static let shared`, no global instances — inject dependencies via
   initialisers or `@Environment` instead); never add code just for tests
   unless in mocks.
8. **SwiftUI for UI** — use SwiftUI for all new UI work; no new UIKit unless
   the platform requires it.
9. **One type per file — hard rule.** Every `struct`, `class`, `enum`, and
   `actor` lives in its own file. The **only** exception is `extension` — a file
   may contain extensions on the file's primary type (e.g. `// MARK: - Fixtures`,
   `// MARK: - Formatting`). No secondary named types of any kind: no
   `private struct`, no nested `enum`, no supporting `struct` alongside the
   primary type. Every `View` file **must** end with a `#Preview` block. These
   rules are not negotiable — do not generate code that violates them.
10. **No global functions.** Static functions must be inside an enum or
    struct. Top-level code is forbidden.
11. **No god objects.** Services over 400 lines or with more than 10
    properties must be broken down into smaller services.

## Swift 6 Essentials

> See `swift-style` for Data Race Safety, Isolation Boundaries, and Typed Throws.

## SwiftUI Patterns

### View Architecture

The view structure depends on the declared architecture. See the matching
architect skill for canonical examples and the full wiring walkthrough.

**MV** — Views observe an `@Observable` service via `@Environment`. No ViewModel.
The service holds state; the view dispatches intent back into the service.

**MVVM** — Views own their ViewModel via `@State`. A thin Screen wrapper reads
the Repository from `@Environment` and passes it into the View's `init(repository:)`.

Quick reference:

```swift
// MV: view reads service from environment, no ViewModel
struct UserListView: View {
    @Environment(\.userListService) private var service
    var body: some View {
        List(service.users) { user in UserRow(user: user) }
            .task { await service.load() }
    }
}

// MVVM: screen passes repo → view owns ViewModel
struct UserListScreen: View {
    @Environment(\.userRepository) private var repository
    var body: some View { UserListView(repository: repository) }
}
struct UserListView: View {
    @State private var viewModel: UserListViewModel
    init(repository: any UserRepositoryProtocol) {
        _viewModel = State(initialValue: UserListViewModel(repository: repository))
    }
    var body: some View {
        List(viewModel.users) { user in UserRow(user: user) }
            .task { viewModel.load() }
    }
}
```

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

### State Management

| Wrapper                       | Use Case                                                                                                            |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `@State`                      | View-local value types (e.g. `isPresented: Bool`, search text) **or** a ViewModel owned by the view (MVVM)        |
| `@Binding`                    | Two-way connection to parent value state                                                                            |
| `@Observable`                 | Applied to **services** (MV) or **ViewModels** (MVVM). Never to Repositories.                                      |
| `@Environment(\.someService)` | How views read services (MV). How screens pass repositories to views (MVVM).                                       |
| `@Bindable`                   | Bridge to write into an `@Observable` type from a view (only at the view boundary)                                 |
| `@AppStorage`                 | UserDefaults-backed persistence **in SwiftUI views only** — never inside an `@Observable` class                     |

**Forbidden in both architectures:**

- `ObservableObject` conformance
- `@Published`
- Business logic inside `View.body`

**Forbidden in MV only** (see `swift-mv-architecture`):
- Any type named `*ViewModel`

**Forbidden in MVVM only** (see `swift-mvvm-architecture`):
- `@Observable` on a Repository
- ViewModels in `@Environment` or `AppDependencies`

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

Apply Core Principle #2 ("No god methods") to every function.

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

### Prefer enums over static constant clusters

Related constants that share a domain belong in an enum, not as a flat
list of statics. Enums enforce exhaustiveness, eliminate magic numbers at
call sites, and make invalid values impossible.

```swift
// ❌ Avoid: flat static constants with no relationship enforced
static let httpStatusOK = 200
static let httpStatusForbidden = 403
static let httpStatusNotFound = 404

// ✅ Prefer: enum scoping related constants by domain
enum HTTPStatus: Int {
    case ok = 200
    case forbidden = 403
    case notFound = 404
}
```

Use a `RawRepresentable` enum when the underlying value matters (e.g. for
comparison against an HTTP response code). Use a plain enum with static
lets only when the values are heterogeneous and cannot share a raw type.

### Bool should read like a sentence. Avoid negative conditions and double negatives.

```swift
// ❌ Avoid: negative conditions and double negatives
if !user.isAdmin {
    // ...
}
```

// ✅ Prefer: positive conditions that read like a sentence

```swift
if user.isAdmin {
    // ...
}
```

// ❌ Avoid: double negative conditions

```swift
if !user.isNotAdmin {
    // ...
}
```

// ✅ Prefer: positive conditions without double negatives

```swift
if user.isAdmin {
    // ...
}
```

// ❌ Avoid: negative variable names that lead to double negatives in conditions

```swift
let isNotAdmin = !user.isAdmin
if !isNotAdmin {
    // ...
}
```

// ✅ Prefer: positive variable names that read clearly in conditions

```swift
let isAdmin = user.isAdmin
if isAdmin {
    // ...
}
```

// ❌ Avoid: !isEmpty or !isPresented in conditions

```swift
if !items.isEmpty {
    // ...
}
if !isPresented {
    // ...
}
```

// ✅ Prefer: positive conditions using isEmpty or isPresented directly

```swift
if items.isEmpty == false {
    // ...
}
if isPresented {
    // ...
}
```

## SwiftUI View Structure

### View member ordering (top to bottom)

Members are grouped by category with **one blank line between groups** and a
lightweight `//` header on each property group — see swift-style **"Vertical
Spacing & Member Grouping"** for the full non-negotiable rule and worked example.
This grouping applies to **all types**, not only views.

Enforce this ordering in every view file:

1. `// DI` — `@Environment`, injected dependencies
2. `// Design System` — design-system wrappers (`@DSSpacing`, …)
3. `// State` — `@State`, `@Binding`, `@FocusState`, …
4. `// Private` — private stored `let` / `var`
5. `// Public` — non-private stored properties
6. computed `var` (non-view)
7. `init`
8. `body`
9. `// MARK: - Helpers` — helper / async functions

`// MARK: -` is for method / section dividers only — never for property groups.
One blank line before `body`; one blank line before and after every `// MARK: -`.

### Extract subviews into their own files

When `body` grows beyond a trivial size, extract logical sections into **separate
`View` types in their own files** — never as `private struct Foo: View` in the
parent file. Pass explicit, minimal inputs — not the entire parent state. Every
extracted view gets its own `#Preview`.

Do **not** use `@ViewBuilder` computed properties or private view-builder helpers
as a substitute for extracting a real type. They hide complexity without creating
a reviewable, testable unit.

```swift
// ✅ HeaderSection.swift — its own file, with a #Preview
struct HeaderSection: View {
    let title: String
    var body: some View { Text(title) }
}

#Preview { HeaderSection(title: "Hello") }

// ✅ ContentView.swift — references the extracted type
struct ContentView: View {
    var body: some View {
        List {
            HeaderSection(title: title)
            ResultsSection(items: items)
        }
    }
}

#Preview { ContentView() }

// ❌ Never — private View type inside another file
private struct HeaderSection: View { … }

// ❌ Never — @ViewBuilder computed helper as a substitute for extraction
private var header: some View { Text(title) }
```

### Stable view tree

Avoid `body` that returns completely different root branches via `if/else`. Prefer a single stable base with conditions inside sections/modifiers (`overlay`, `opacity`, `disabled`, `toolbar`). Root-level branch swapping causes identity churn and broader invalidation.

### Extract actions and side effects from body

Do not keep non-trivial button actions or business logic inline in `body`. Move logic into services/models and call thin private methods from the view. The `body` should read like UI, not like a view controller.

### Large-view handling

When a view file exceeds ~150 lines, split it — each extracted section becomes
its own file with its own `#Preview`. Use `private` extensions with `// MARK: -`
only for non-view helpers (actions, async functions); never for view-producing
code.

### State ownership (quick reference)

| Scenario                               | Pattern                                                 |
| -------------------------------------- | ------------------------------------------------------- |
| Local UI state owned by one view       | `@State`                                                |
| Child mutates parent-owned value state | `@Binding`                                              |
| Root-owned reference model (iOS 17+)   | `@State` with `@Observable` type                        |
| Shared app service                     | `@Environment(Type.self)`                               |
| Legacy (iOS 16 and earlier)            | `@StateObject` at root, `@ObservedObject` when injected |

### Sheets and routing

Prefer `.sheet(item:)` over `.sheet(isPresented:)` when state represents a selected model. Avoid `if let` inside a sheet body. Sheets should own their actions and call `dismiss()` internally.

Drive sheets and pushes from a **single enum of destinations** rather than a scatter of `Bool` flags — `@State private var route: Route?` with `.sheet(item: $route)` keeps presentation state in one place, makes "which screens can this view open" answerable from the type, and avoids two flags being true at once. Use `NavigationStack(path:)` + `navigationDestination(for:)` for the push stack (see the Navigation section above).

### Async state lifecycle

Model load state as an explicit enum (`loading` / `loaded` / `error`), not a tangle of `isLoading: Bool` + optional data — it makes every UI state representable and exhaustively switchable in `body`.

- Use `.task(id:)` for work that must **restart** when an input changes: when the id changes SwiftUI cancels the running task and starts a fresh one, so input-driven reloads (search, filters) need no manual cancellation.
- For user-typed input, debounce inside the task (`try await Task.sleep` *then* check `Task.isCancelled`) so a fast typer doesn't fire a request per keystroke — the `.task(id:)` cancellation makes the sleep self-cancelling.
- Long-running loops must check `Task.isCancelled` and bail; a `.task` is cancelled automatically when the view disappears.

```swift
.task(id: query) {
    guard !query.isEmpty else { state = .loaded([]); return }
    try? await Task.sleep(for: .milliseconds(300))   // debounce
    if Task.isCancelled { return }
    await search(query)
}
```

## Swift Testing

> See `swift-testing` for all unit-test authoring patterns.

## Structured Concurrency

> See `swift-concurrency` (conceptual) or the "Fix concurrency in existing code" mode below (hands-on fixes).

## Code Quality & Style

> See `swift-style` for method length, parameter count, naming, guard
> patterns, UserDefaults in `@Observable`, didSet, switch over if-else,
> overlay vs nested stacks, one-view-per-file, and all other style rules.

## Rewrite and migrate (no behaviour change)

Use this mode when asked to: "rewrite this", "clean this up", "this is hard to read", "poor structure", "refactor", "convert this ObservableObject to @Observable", "migrate this view model to @Observable".

**Hard rule: this mode does not change public API surfaces, protocol conformances, or method signatures. It does not change behaviour.**

### Process

1. Read the file in full before touching anything. Understand what it does and identify every public API surface.
2. Identify violations against the rules in `swift-style`.
3. Apply all fixes. Build. Verify zero errors and zero warnings.
4. Confirm the public API surface is identical before and after. Run tests if they exist.

### Migrating `ObservableObject` to `@Observable`

Both MV and MVVM forbid `ObservableObject` and `@Published` in new code. Converting
a legacy type to `@Observable` is a behaviour-preserving rewrite. In MV the result
is a service; in MVVM it is a ViewModel.

Mechanical steps:

1. `import Observation`.
2. Drop `: ObservableObject`; add `@Observable` macro to the type.
3. Remove every `@Published` — stored properties are tracked automatically.
4. Mark infrastructure properties `@ObservationIgnored` (task handles, cancellables, loggers, identity constants). Never blanket-annotate every `private var`.
5. Update call sites: `@StateObject` → `@State`, `@ObservedObject` → plain `let` / `@Bindable` only where a two-way binding is needed, `@EnvironmentObject` → `@Environment`.

```swift
// Before (legacy)
final class SearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [Result] = []
    private var searchTask: Task<Void, Never>?
}

// After (@Observable)
import Observation

@MainActor @Observable
final class SearchModel {
    var query = ""
    private(set) var results: [Result] = []

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?
}
```

## Fix concurrency in existing code

Use this mode when asked to fix, resolve, or remediate: Swift 6 concurrency compiler errors, data race diagnostics, actor isolation warnings, Sendable conformance gaps, or when migrating completion handlers to async/await in existing code.

### Diagnostic procedure

1. **Triage** — Capture the exact compiler diagnostics and the offending symbol(s). Check: Swift language version (6.2+), strict concurrency level, whether approachable concurrency is enabled, current actor context, whether code is UI-bound.
2. **Apply the smallest safe fix** — Preserve existing behaviour while satisfying data-race safety.
   - UI-bound types: annotate the type or relevant members with `@MainActor`.
   - Protocol conformance on `@MainActor` types: `extension Foo: @MainActor SomeProtocol`.
   - Global/static state: protect with `@MainActor` or move into an `actor`.
   - Background work: use a `@concurrent` async function or a `nonisolated` type.
   - Sendable errors: prefer immutable/value types; add `Sendable` only when correct; avoid `@unchecked Sendable` unless you can prove thread safety.
3. **Verify** — Rebuild, confirm all diagnostics resolved with no new warnings, run tests.
4. **Iterate** — If the fix surfaces new warnings, treat each as a fresh triage.

For conceptual explanations of Swift concurrency (async/await, actors, Sendable), use `swift-concurrency` instead.

## Reviewing code

This skill is for **writing, rewriting, and editing** Swift. For reviewing existing code before a commit or PR — including the full BLOCKER / WARNING / SUGGESTION pass and the live Xcode navigator check — use the `swift-code-review` skill instead. It loads this skill plus `swift-testing` and `swift-concurrency` and applies a concrete checklist.

## References

This skill applies the project's declared architecture (MV via `swift-mv-architecture`,
MVVM via `swift-mvvm-architecture`). For canonical, up-to-date API details,
query Context7 with these library IDs (use `mcp__context7__query-docs`):

| Library ID                          | Use for                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------- |
| `/websites/developer_apple_swiftui` | SwiftUI views, modifiers, navigation, environment, animations             |
| `/swiftlang/swift`                  | Swift language semantics, generics, macros, typed throws, result builders |
| `/websites/swift`                   | Swift language guide, the concurrency book, package manager               |

For topic-specific guidance, hand off to the dedicated skill:

- **Architecture setup / audit (MV)** — `swift-mv-architecture`
- **Architecture setup / audit (MVVM)** — `swift-mvvm-architecture`
- **Style & quality (write-time)** — `swift-style`
- **Rewriting / clean-up / @Observable migration** — use the "Rewrite and migrate" mode above
- **Concurrency (conceptual)** — `swift-concurrency`
- **Testing** — `swift-testing`
- **Liquid Glass** — `swiftui-liquid-glass`
