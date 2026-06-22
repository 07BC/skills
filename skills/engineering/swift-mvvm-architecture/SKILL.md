---
name: swift-mvvm-architecture
description: Modern @Observable MVVM architecture guardian for Swift/SwiftUI apps. Two modes — (1) **setup**: scaffold a new MVVM app skeleton (entry point, AppDependencies of repositories, environment plumbing, first Repository + ViewModel + View triad); (2) **audit**: scan an existing app and report drift from modern @Observable MVVM (legacy ObservableObject/@Published, ViewModels in the environment or AppDependencies, @Observable repositories, business logic in View.body, ViewModel calling API client directly). Triggers on "set up a new MVVM app", "scaffold MVVM", "check the app follows MVVM", "is this still MVVM", "audit MVVM adherence", "architect this" when the project declares MVVM architecture. Use BEFORE swift-engineering when starting a feature in an empty MVVM project, or AFTER changes to verify the architecture holds.
---

# Swift MVVM Architect

You are the architecture guardian for a Swift/SwiftUI **modern @Observable MVVM** app.
This is NOT legacy `ObservableObject`/`@Published` MVVM — it uses `@Observable`
ViewModels (iOS 17+, Swift 6). This skill does NOT write feature code — that's
`swift-engineering`. This skill sets the structure up correctly and verifies it stays
that way.

---

## The MVVM Pattern (read this first, every time)

The ViewModel layer is the defining feature. `@Observable` ViewModels own all
view-facing state. Repositories are stateless — they hold no state and are never
`@Observable`.

**Layers:**

| Layer | Type | Isolation | Role |
|---|---|---|---|
| **Domain model** | `struct` | Sendable value type | Pure data. No behaviour beyond computed reads. |
| **Repository** | `final class …Protocol, Sendable` | nonisolated / Sendable | **Stateless.** Sole caller of the API client + storage. Returns domain types. Never `@Observable`, never `@MainActor`. |
| **ViewModel** | `@MainActor @Observable final class` | `@MainActor` | Owns all view-facing state; exposes intent methods; holds a repository as `any …RepositoryProtocol`. The **only** `@Observable` type in user code. |
| **View** | `struct: View` | `@MainActor` (implicit) | Owns its ViewModel via `@State`; reads a repository from `@Environment` and passes it into the ViewModel's `init`. |
| **Screen wrapper** | `struct: View` | `@MainActor` | Thin: reads one or more repositories from `@Environment`, constructs the `View(repository:)`. |
| **AppDependencies** | `struct` | `@MainActor` | Builds every **repository** once at app launch. ViewModels are **never** built here. |

**Hard rules — forbidden:**

- `ObservableObject` conformance (legacy MVVM — this pattern uses `@Observable`)
- `@Published` (ditto)
- `@Observable` on a Repository (repositories are stateless; `@Observable` belongs on ViewModels only)
- Registering a ViewModel in `@Environment` / building ViewModels in `AppDependencies`
- A View constructing its own Repository (`@State private var repo = FeatureRepository()`) — repositories live in `AppDependencies` and are injected via `@Environment`
- A ViewModel calling the API client or storage layer directly — must go through a Repository
- Business logic, networking, or persistence inside `View.body`

**Hard rules — required:**

- ViewModels are `@MainActor @Observable final class`, single writer of their own state
- Views own their ViewModel via `@State private var viewModel: FeatureViewModel`, initialised in `init(repository:)` using `_viewModel = State(initialValue:)`
- Repositories are injected into ViewModels as `any FeatureRepositoryProtocol`
- One protocol → two conformers: production class + `Mock…` for tests/previews
- Every cross-isolation type is `Sendable`
- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY=complete`)

---

## Mode 1 — Setup a New MVVM App

Use this mode when starting a fresh app or adding the first feature to an empty
Xcode project.

### Step 1 — Confirm prerequisites

```bash
find . -maxdepth 3 -name "Package.swift" -o -name "*.xcodeproj" | head -3
grep -E "IPHONEOS_DEPLOYMENT_TARGET|TVOS_DEPLOYMENT_TARGET|SWIFT_VERSION" \
  *.xcodeproj/project.pbxproj 2>/dev/null | sort -u
```

Required minimums: **iOS 17 / tvOS 17 / macOS 14** (for `@Observable`). **Swift 6.0+**.

If the deployment target is below the minimum, ask the user via `AskUserQuestion`:

- **Option A: Bump the deployment target.** Proceed with this skill.
- **Option B: Can't bump — keep iOS 16- support.** Modern `@Observable` MVVM requires iOS 17. Fall back to legacy `ObservableObject`/`@Published` MVVM by hand; this skill halts. Note the constraint in the composition root.
- **Option C: Abort.** Stop without scaffolding.

### Step 2 — Scaffold the foundation files

Create these in the project's main module (substitute `AppName` for the real
app target name). The canonical templates live in `docs/MVVM target architecture/templates/`.

#### `AppDependencies.swift`

```swift
import Foundation

// Composition root. Builds every repository once at app launch.
// ViewModels are NOT constructed here.
@MainActor
struct AppDependencies {

    let featureRepository: any FeatureRepositoryProtocol
    // Add new repositories here.

    init() {
        let isTestOrPreview = ProcessInfo.processInfo.isRunningTests
            || ProcessInfo.processInfo.isRunningInPreview

        let apiClient: any APIClientProtocol = isTestOrPreview
            ? MockAPIClient()
            : APIClient()

        self.featureRepository = isTestOrPreview
            ? MockFeatureRepository()
            : FeatureRepository(client: apiClient)
    }
}
```

#### `EnvironmentRepositories.swift`

```swift
import SwiftUI

// Register one @Entry per repository.
// Default values are mocks so previews work without wiring.
// ViewModels are NOT registered here.
extension EnvironmentValues {
    @Entry var featureRepository: any FeatureRepositoryProtocol = MockFeatureRepository()
    // Add new repositories here.
}
```

#### `AppNameApp.swift`

```swift
import SwiftUI

@main
struct AppNameApp: App {

    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.featureRepository, dependencies.featureRepository)
                // One .environment() per repository.
        }
    }
}
```

#### `RootView.swift`

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        FeatureScreen()
    }
}

#Preview {
    RootView()
}
```

### Step 3 — Add the first feature triad

Every feature has three files: a Repository, a ViewModel, and a Screen+View pair.

#### Repository (stateless, Sendable)

```swift
import Foundation

final class FeatureRepository: FeatureRepositoryProtocol, Sendable {

    private let client: any APIClientProtocol

    init(client: any APIClientProtocol) {
        self.client = client
    }

    func fetch(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        try await client.fetchItems(page: page)
    }
}

protocol FeatureRepositoryProtocol: Sendable {
    func fetch(page: Int) async throws(AppError) -> PaginatedResponse<Item>
}
```

#### ViewModel (`@MainActor @Observable`, owns state)

```swift
import Foundation
import Observation

@MainActor
@Observable
final class FeatureViewModel {

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    private let repository: any FeatureRepositoryProtocol
    private var loadTask: Task<Void, Never>?

    init(repository: any FeatureRepositoryProtocol) {
        self.repository = repository
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await performLoad()
        }
    }

    private func performLoad() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            items = try await repository.fetch(page: 1).data
        } catch {
            self.error = error
        }
    }
}
```

#### Screen + View triad

```swift
import SwiftUI

// Screen — reads repository from @Environment, constructs View
struct FeatureScreen: View {
    @Environment(\.featureRepository) private var repository

    var body: some View {
        FeatureView(repository: repository)
    }
}

// View — owns its ViewModel via @State
struct FeatureView: View {

    @State private var viewModel: FeatureViewModel

    init(repository: any FeatureRepositoryProtocol) {
        _viewModel = State(initialValue: FeatureViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else {
                content
            }
        }
        .task { viewModel.load() }
    }

    private var content: some View {
        List(viewModel.items) { item in
            Text(item.title)
        }
    }
}

#Preview {
    FeatureView(repository: MockFeatureRepository())
}
```

### Step 4 — Confirm wiring

The answer to "how does a new feature get its data?" must be exactly:

1. Define a `FeatureRepositoryProtocol` + production `FeatureRepository` + `MockFeatureRepository`.
2. Add a property in `AppDependencies` for the production repository.
3. Add a matching `@Entry` in `EnvironmentValues` (default = mock).
4. Inject from `@main` via `.environment(\.featureRepository, dependencies.featureRepository)`.
5. `FeatureScreen` reads `@Environment(\.featureRepository)` and passes it into `FeatureView`.
6. `FeatureView` builds the ViewModel in its `init(repository:)` and owns it via `@State`.

If any step is missing, the wiring is wrong.

---

## Mode 2 — Audit MVVM Adherence

Use when the user asks "is this still MVVM?", "did anything break the architecture?",
or after a significant refactor.

### Step 1 — Inventory the code

```bash
find . -name "*.swift" \
  -not -path "*/.build/*" \
  -not -path "*/DerivedData/*" \
  -not -path "*/Pods/*" \
  -not -path "*/Carthage/*" \
  > /tmp/mvvm_audit_files.txt

wc -l /tmp/mvvm_audit_files.txt
```

### Step 2 — Run the MVVM adherence grep suite

```bash
# 1. Legacy ObservableObject conformance (BLOCKER — this is @Observable MVVM)
grep -rEn ': *ObservableObject\b' $(cat /tmp/mvvm_audit_files.txt)

# 2. @Published (BLOCKER)
grep -rEn '@Published\b' $(cat /tmp/mvvm_audit_files.txt)

# 3. @Observable on a Repository (BLOCKER — repos are stateless)
#    Find Repository types and verify they have NO @Observable above them.
grep -rEn 'class +[A-Za-z0-9_]+Repository\b' $(cat /tmp/mvvm_audit_files.txt)

# 4. ViewModel registered in @Environment (BLOCKER)
grep -rEn '@Entry[^=\n]*ViewModel|\.environment\(\\\.[a-zA-Z]*[Vv]iew[Mm]odel' \
  $(cat /tmp/mvvm_audit_files.txt)

# 5. ViewModel constructed in AppDependencies (BLOCKER)
#    Every ViewModel() call should be inside a View init, never AppDependencies.
grep -rEn 'ViewModel(' $(cat /tmp/mvvm_audit_files.txt)

# 6. ViewModel calling API client directly (WARNING — must go via Repository)
#    Find ViewModel types and check they hold a …RepositoryProtocol, not an APIClient.
grep -rEn 'final +class +[A-Za-z0-9_]+ViewModel\b' $(cat /tmp/mvvm_audit_files.txt)

# 7. ViewModels missing @MainActor or @Observable (WARNING)
grep -rEn 'final +class +[A-Za-z0-9_]+ViewModel\b' $(cat /tmp/mvvm_audit_files.txt)
#    For each, verify @Observable and @MainActor appear within 3 lines above.

# 8. Logic inside View.body (WARNING)
#    Prefer the Xcode navigator (AST-aware). Grep is noisy — correlate every
#    hit against an actual body {} span before reporting.
grep -rEn 'var body: some View' $(cat /tmp/mvvm_audit_files.txt)

# 9. Old EnvironmentKey pattern instead of @Entry (SUGGESTION)
grep -rEn ': *EnvironmentKey\b' $(cat /tmp/mvvm_audit_files.txt)
```

### Step 3 — Verify the composition root

Read `AppDependencies.swift` and the `@main App` struct. Confirm:

- Every `*Repository` in the codebase is built in `AppDependencies` exactly once.
- Every repository has a matching `@Entry` in `EnvironmentValues`.
- The `@main App` injects every repository into the root view's environment.
- No ViewModel appears anywhere in `AppDependencies` or `@Environment`.

### Step 4 — Report

```
## MVVM Adherence Audit
Date: <today>
Files scanned: N

### BLOCKERS (architecture violations)
- <file>:<line> — legacy `ObservableObject` conformance: `FooModel`
- <file>:<line> — `@Published` property
- <file>:<line> — `@Observable` on Repository: `FooRepository`
- <file>:<line> — ViewModel in @Environment / AppDependencies

### WARNINGS (drift)
- <file>:<line> — ViewModel missing `@MainActor` or `@Observable`
- <file>:<line> — ViewModel holds `APIClient` directly (should hold a Repository)
- <file>:<line> — networking call inside `View.body`

### SUGGESTIONS
- <file>:<line> — old `EnvironmentKey` boilerplate, prefer `@Entry`

### Composition root
- <list of repositories missing from AppDependencies or environment>
- <list of ViewModels found in AppDependencies (should be zero)>
```

Do not propose fixes inline — that's `swift-engineering`. The architect identifies;
the engineer remediates.

---

## When to hand off

| Situation | Use |
|---|---|
| About to write a feature inside an MVVM-shaped project | `swift-engineering` |
| Need to clean up an existing file without changing behaviour | `swift-engineering` (rewrite mode) |
| Pre-commit / PR review including the live Xcode navigator check | `swift-code-review` |
| Deep audit beyond MVVM adherence (testability, layering, concurrency depth) | `/audit` |

## References

- Canonical templates: `docs/MVVM target architecture/templates/` — authoritative source for code shapes.
- Architecture overview: `docs/MVVM target architecture/architecture.md`
- Coding standards: `docs/MVVM target architecture/coding-standards.md`
- Testing patterns: `docs/MVVM target architecture/testing.md`
- For a per-subtask scoped brief, hand off to `implementation-brief` — that skill produces the engineer's brief; this one defines the architecture the engineer must conform to.
- For deeper concurrency questions inside ViewModels, see `swift-concurrency` (conceptual) or `swift-engineering` (fix concurrency mode — action).
