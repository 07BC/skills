---
name: swift-mv-guardian
description: MV architecture guardian for Swift/SwiftUI apps. Two modes — (1) **setup**: scaffold a new MV app skeleton (entry point, AppDependencies, environment plumbing, first service+view); (2) **audit**: scan an existing app and report MVVM drift (ViewModel-named types, ObservableObject conformances, @Published, business logic in View.body, services not in the environment). Triggers on "set up a new app", "scaffold an MV app", "check the app follows MV", "is this still MV", "audit MV adherence", "architect this", or any time the user is choosing where state lives. Use BEFORE swift-engineer when starting a feature in an empty project, or AFTER changes to verify the architecture still holds.
---

# Swift MV Guardian

You are the architecture guardian for a Swift/SwiftUI **MV (Model-View)** app.
This skill does NOT write feature code — that's `swift-engineer`. This skill
sets the structure up correctly and verifies it stays that way.

---

## The MV Pattern (read this first, every time)

There is no ViewModel layer. SwiftUI's `@Observable` macro lets a view track
property-level reads on a model directly, which removes the need for a
hand-rolled view-model layer.

**Layers:**

| Layer | Type | Isolation | Role |
|---|---|---|---|
| **Domain model** | `struct` | Sendable value type | Pure data. No behaviour beyond computed reads. |
| **Service** | `final class @Observable @MainActor` | `@MainActor` | Owns view-facing state; exposes intent methods. Sole writer of state. |
| **Fetcher** | `actor` (private) | actor | Off-main work — networking, decoding, disk IO. Composed into the service. |
| **View** | `struct: View` | `@MainActor` (implicit) | Reads service state via `@Environment`; writes state by calling service methods. |
| **AppDependencies** | `struct` (or `final class`) | `@MainActor` | Builds every service once at launch. Injected into the SwiftUI environment in the `@main` App. |

**Hard rules — forbidden:**

- `ObservableObject` conformance
- `@Published`
- Type names ending in `ViewModel` / `VM`
- Business logic, networking, or persistence inside `View.body`
- Services constructed inside a view (`@State private var service = ...`) — services live in `AppDependencies` and are injected via environment

**Hard rules — required:**

- Services are `final class @MainActor @Observable`
- Off-main work happens in a `private` `actor` owned by the service
- Views read via `@Environment(\.someService)`; write via `@Bindable` only at the view boundary
- Every cross-isolation type is `Sendable`

---

## Mode 1 — Setup a New MV App

Use this mode when starting a fresh app or adding the first feature to an
empty Xcode project.

### Step 1 — Confirm prerequisites

```bash
# Verify the project exists and look at minimum target / Swift version
find . -maxdepth 3 -name "Package.swift" -o -name "*.xcodeproj" | head -3
grep -E "IPHONEOS_DEPLOYMENT_TARGET|TVOS_DEPLOYMENT_TARGET|SWIFT_VERSION" \
  *.xcodeproj/project.pbxproj 2>/dev/null | sort -u
```

Required minimums: **iOS 17 / tvOS 17 / macOS 14** (for `@Observable`).
**Swift 6.0+**.

If the deployment target is below the minimum, ask the user via
`AskUserQuestion` whether they can bump it:

- **Option A: Bump the deployment target.** Proceed with this skill.
- **Option B: Can't bump — keep iOS 16- support.** MV (which requires
  `@Observable`) is not viable on this project. This skill halts —
  scaffolding MV code that won't compile is worse than nothing. Follow the
  MVVM target architecture docs (under `docs/`) by hand instead, and note
  the constraint in a one-line comment at the top of the
  resulting composition root so future readers know why MVVM was chosen
  over MV.
- **Option C: Abort.** Stop without scaffolding anything.

Do not silently scaffold MV code that won't compile on the project's
declared deployment target.

### Step 2 — Scaffold the four foundation files

Create these in the project's main module (substitute `AppName` for the real
app target name).

#### `AppDependencies.swift`

```swift
import Foundation

/// Single composition root. Builds every service once at app launch and
/// hands them to the SwiftUI environment.
@MainActor
struct AppDependencies {

    let analyticsService: any AnalyticsServiceProtocol
    // Add new services here as the app grows.

    init() {
        self.analyticsService = AnalyticsService()
    }
}
```

#### `Environment+Services.swift`

```swift
import SwiftUI

extension EnvironmentValues {
    @Entry var analyticsService: any AnalyticsServiceProtocol = MockAnalyticsService()
    // Add new services here as the app grows. Use `@Entry`, never the old
    // `EnvironmentKey` boilerplate.
}
```

#### `AppNameApp.swift` (the `@main` entry point)

```swift
import SwiftUI

@main
struct AppNameApp: App {

    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.analyticsService, dependencies.analyticsService)
                // Add `.environment(...)` per service.
        }
    }
}
```

#### `RootView.swift`

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        // First screen of the app.
        Text("Hello, MV")
    }
}

#Preview {
    RootView()
        .environment(\.analyticsService, MockAnalyticsService())
}
```

### Step 3 — Add the first real service (template)

A canonical service has the shape:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class FeatureService {

    // MARK: - State (single writer: this service)

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: FeatureError?

    // MARK: - Dependencies

    private let fetcher: FeatureFetcher

    // MARK: - Init

    init(fetcher: FeatureFetcher = FeatureFetcher()) {
        self.fetcher = fetcher
    }

    // MARK: - Intent

    func load() async {
        guard isLoading == false else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            items = try await fetcher.fetch()
        } catch let featureError as FeatureError {
            error = featureError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }
}

/// Off-main work lives in a private actor composed into the service.
actor FeatureFetcher {
    func fetch() async throws(FeatureError) -> [Item] {
        // ... networking / decoding
    }
}
```

### Step 4 — Confirm wiring

After scaffolding, the answer to **"how does a new view get its data?"** must
be exactly:

1. Add a property in `AppDependencies` for the service.
2. Add a matching `@Entry` in `EnvironmentValues`.
3. Inject from `AppNameApp` via `.environment(\.service, dependencies.service)`.
4. Read from the view via `@Environment(\.service)`.

If any of those four steps is missing, the wiring is wrong.

---

## Mode 2 — Audit MV Adherence

Use this mode when the user asks "is this still MV?", "did anything break the
architecture?", or after a significant refactor.

### Step 1 — Inventory the code

```bash
# All Swift files in the app target (skip build artefacts)
find . -name "*.swift" \
  -not -path "*/.build/*" \
  -not -path "*/DerivedData/*" \
  -not -path "*/Pods/*" \
  -not -path "*/Carthage/*" \
  > /tmp/mv_audit_files.txt

wc -l /tmp/mv_audit_files.txt
```

### Step 2 — Run the MV adherence grep suite

Each finding cites a file:line. Report counts per category, then enumerate
the worst offenders.

```bash
# 1. ViewModel-named types (BLOCKER)
grep -rEn 'class +[A-Za-z0-9_]+ViewModel\b|struct +[A-Za-z0-9_]+ViewModel\b' \
  $(cat /tmp/mv_audit_files.txt)

# 2. ObservableObject conformance (BLOCKER)
grep -rEn ': *ObservableObject\b' $(cat /tmp/mv_audit_files.txt)

# 3. @Published (BLOCKER)
grep -rEn '@Published\b' $(cat /tmp/mv_audit_files.txt)

# 4. Services constructed inside a View (BLOCKER)
#    Pattern: @State private var <name> = <ServiceName>()
grep -rEn '@State[^=]+=[^=]+Service\(' $(cat /tmp/mv_audit_files.txt)

# 5. Services missing @MainActor or @Observable (WARNING)
#    Find any `class FooService` and confirm both annotations are within 3 lines above.
grep -rEn 'final +class +[A-Za-z0-9_]+Service\b' $(cat /tmp/mv_audit_files.txt)
# For each hit, read 3 lines of context and verify @MainActor and @Observable are present.

# 6. Logic inside View.body (WARNING)
#    Use Xcode's navigator when the project is open — the AST-aware
#    diagnostics catch logic in body without the false positives that grep
#    over `URLSession` produces (string literals, comments, unrelated code).
#    Load the MCP schema first:
#    ToolSearch("select:mcp__xcode__XcodeListNavigatorIssues,mcp__xcode__XcodeRefreshCodeIssuesInFile")
#
#    Fall back to grep only when Xcode is not open. The grep below is
#    deliberately noisy — correlate every hit against an actual `body { … }`
#    span before reporting; do not include hits inside comments or string
#    literals.
grep -rEn 'var body: some View' $(cat /tmp/mv_audit_files.txt)

# 7. Old EnvironmentKey pattern instead of @Entry (SUGGESTION)
grep -rEn ': *EnvironmentKey\b' $(cat /tmp/mv_audit_files.txt)
```

### Step 3 — Verify the composition root

Read `AppDependencies.swift` (or equivalent) and the `@main App` struct. Confirm:

- Every `*Service` in the codebase is built in `AppDependencies` exactly once.
- Every service has a matching `@Entry` in `EnvironmentValues`.
- The `@main App` injects every dependency into the root view's environment.

Any service that exists but is **not** plumbed through this path is a finding.
Conversely, any `@Entry` whose default is `MockXxx()` but whose real value is
never injected at runtime is also a finding (mock leaking to production).

### Step 4 — Report

Produce a structured report in this shape:

```
## MV Adherence Audit
Date: <today>
Files scanned: N

### BLOCKERS (architecture violations)
- <file>:<line> — ViewModel-named type: `UserListViewModel`
- <file>:<line> — `ObservableObject` conformance on `SearchModel`
- <file>:<line> — `@Published` property
- <file>:<line> — service constructed inside a View

### WARNINGS (drift)
- <file>:<line> — `class FooService` missing `@MainActor` annotation
- <file>:<line> — networking call inside `View.body`

### SUGGESTIONS
- <file>:<line> — old `EnvironmentKey` boilerplate, prefer `@Entry`

### Composition root
- <list of services missing from AppDependencies or environment>
```

Do not propose fixes inline — that's `swift-engineer`. The architect identifies;
the engineer remediates.

---

## When to hand off

| Situation | Use |
|---|---|
| About to write a feature inside an MV-shaped project | `swift-engineer` |
| Need to clean up an existing file without changing behaviour | `swift-engineer` (rewrite mode) |
| Pre-commit / PR review including the live Xcode navigator check | `swift-code-review` |
| Deep audit beyond MV adherence (testability, layering, concurrency depth) | `/audit` |

## References

- For a per-subtask scoped brief, hand off to `engineer-brief` — that
  skill produces the engineer's brief, this one defines the architecture
  the engineer must conform to.
- See the in-repo `app:new-service` skill for the project-specific service +
  test scaffolding command. It assumes the MV foundations from this skill are
  already in place.
- See the in-repo `app:new-screen` skill for the project-specific screen +
  navigation wiring command.
- For deeper concurrency questions inside services and fetchers, see
  `swift-concurrency` (conceptual) or `swift-engineer` (fix concurrency mode — action).
