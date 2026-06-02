# Reference: SwiftUI MV Architecture

## MV vs MVVM — the distinction that matters

In **MV (Model-View)**, the model is `@Observable` and views observe it
directly. There is no separate ViewModel layer.

```swift
// MV — model owns state and business logic
@Observable
final class SyncCoordinator {
    var isSyncing: Bool = false
    var quality: SyncMode = .full

    func start() async throws { ... }
}

// View reads model directly — no intermediary
struct SyncView: View {
    var coordinator: SyncCoordinator   // injected via environment

    var body: some View {
        Button(isSyncing ? "Stop" : "Start") {
            Task { try await coordinator.start() }
        }
    }
}
```

In **MVVM**, a ViewModel (`ObservableObject` or `@Observable`) sits between
model and view, transforming data. If you see `ViewModel` suffixed types,
the project uses MVVM, not MV — document which pattern is actually used.

## Environment Injection Patterns

### `@Entry` (iOS 18+, preferred)
```swift
extension EnvironmentValues {
    @Entry var coordinator: SyncCoordinator = .init()
}

// Root
ContentView()
    .environment(\.coordinator, coordinator)

// Consumer
@Environment(\.coordinator) private var coordinator
```

### Direct `.environment(_:)` with `@Observable`
```swift
ContentView()
    .environment(coordinator)   // no key path needed

@Environment(SyncCoordinator.self) private var coordinator
```

Document which pattern is dominant and whether both appear (mixed codebases
are a gotcha for new engineers).

## Navigation Strategy

### `NavigationStack` + enum-driven paths (preferred)
```swift
enum AppRoute: Hashable {
    case articleDetail(String)
    case settings
    case compose
}

@State private var path: [AppRoute] = []

NavigationStack(path: $path) {
    RootView()
        .navigationDestination(for: AppRoute.self) { route in
            switch route { ... }
        }
}
```

### `NavigationSplitView` (iPad / macOS)
Sidebar + detail split. Note if the app adapts between Stack and Split
based on horizontal size class.

## Module Communication Patterns

| Pattern | When used | Coupling |
|---------|-----------|---------|
| Protocol + injection | Service boundaries | Low |
| Swift enum namespace | Grouping related types | Low |
| `@Environment` | UI-to-UI feature flags / shared state | Medium |
| Direct property access | Same-module types | High (acceptable) |
| `NotificationCenter` | Legacy or cross-module events | High (avoid) |

Document which patterns appear and flag any `NotificationCenter` usage as
a potential refactor candidate.

## Reusable Component Library

Look for a `Components/`, `DesignSystem/`, or `UI/` folder. Note:
- Whether components accept generic content via `@ViewBuilder`
- Whether a design token system exists (colors, spacing as named values)
- Preview coverage (look for `#Preview` macros)
