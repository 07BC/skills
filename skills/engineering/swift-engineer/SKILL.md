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

Load `swift-testing` when writing tests, and `swift-concurrency` when
adding async / actor / Sendable work.

## Core Principles

1. **MV pattern only** — `@MainActor @Observable` services own state; views
   observe them via `@Environment`. No ViewModel layer, no `ObservableObject`,
   no `@Published`. Heavy work lives behind a private `actor` composed into
   the service.
2. **Strict concurrency by default** — All new code must compile with
   `SWIFT_STRICT_CONCURRENCY=complete`
3. **Value semantics first** — Prefer structs; use classes only for identity,
   reference semantics, or an `@Observable` service
4. **Explicit error handling** — Use typed throws where beneficial; never
   force-unwrap in production
5. **Testability** — Design for dependency injection via the environment;
   avoid singletons; never add code just for tests unless in mocks

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
extension EnvironmentValues {
  @Entry
  var timerService: TimerService? = nil

  @Entry
  var activityDetailService: ActivityDetailService? = nil

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