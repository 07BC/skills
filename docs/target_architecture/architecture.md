# MV Architecture Reference

> Swift 6.2 · SwiftUI · MV (Model-View) — no MVVM
> Platform-agnostic template. Substitute your target OS (iOS 17+, tvOS 17+, macOS 14+).

---

## Table of Contents

1. [Layer Map](#1-layer-map)
2. [App Entry & Composition Root](#2-app-entry--composition-root)
3. [Domain Layer](#3-domain-layer)
4. [Infrastructure Layer](#4-infrastructure-layer)
5. [Services Layer](#5-services-layer)
6. [Presentation Layer](#6-presentation-layer)
7. [Data & Persistence](#7-data--persistence)
8. [Concurrency Model](#8-concurrency-model)
9. [Navigation](#9-navigation)
10. [Configuration & Secrets](#10-configuration--secrets)

---

## 1. Layer Map

```
AppName/
├── App/                    ← @main, composition root, configuration bootstrap
├── Domain/
│   ├── Models/             ← Pure Sendable structs/enums. No SwiftUI, no networking.
│   ├── Protocols/          ← Cross-layer contracts. One protocol → always two conformers.
│   ├── Errors/             ← Typed error enums. Conforms to Error + Sendable.
│   └── Fetchers/           ← Stateless structs. Depend on protocols, not concrete types.
├── Infrastructure/
│   ├── API/                ← HTTP client, DTO types (APIFoo), request builders
│   ├── Storage/            ← UserDefaults + Keychain adapter
│   ├── Decoding/           ← Shared JSONDecoder, lossy-decode wrappers
│   ├── Logging/            ← Console / analytics sink
│   └── Mocks/              ← DEBUG-only mock conformers (actor-based)
├── Services/               ← @MainActor @Observable final class. FLAT — no subfolders.
├── Presentation/
│   ├── <Feature>/          ← One folder per feature. No cross-feature imports.
│   └── Shared/
│       ├── Components/     ← Stateless, reusable views
│       └── UIConstants/    ← Design tokens (Padding, Spacing, CornerRadius, FontSize…)
└── Resources/              ← Assets.xcassets, Fonts, Localizable.xcstrings
```

### Layer dependency rules

```
Presentation  →  Services  →  Domain  ←  Infrastructure
```

- `Domain` imports nothing project-internal.
- `Infrastructure` implements `Domain/Protocols` — never imports `Presentation`.
- `Services` import `Domain` and `Infrastructure` protocols — never import `Presentation`.
- `Presentation` reads services via `@Environment`. Never constructs a service inline.

---

## 2. App Entry & Composition Root

### `@main` App struct

```swift
// App/AppNameApp.swift
@main
struct AppNameApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.featureService, dependencies.featureService)
                .environment(\.authService, dependencies.authService)
                // One .environment() call per service.
        }
    }
}
```

### `AppDependencies` — composition root

```swift
// App/AppDependencies.swift
@MainActor
struct AppDependencies {
    let authService: AuthService
    let featureService: FeatureService
    // ...

    init() {
        let apiClient = APIClient()
        self.authService = AuthService(client: apiClient)
        self.featureService = FeatureService(client: apiClient)
    }
}
```

Rules for `AppDependencies`:

- **Pure wiring only** — no business logic.
- Every service constructed **exactly once**.
- Mock infrastructure swapped in DEBUG via `ProcessInfo` check:

```swift
private var isTestOrPreview: Bool {
    ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
        || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
}
```

### `EnvironmentValues` entries

```swift
// App/Environment+Services.swift
extension EnvironmentValues {
    @Entry var authService: any AuthServiceProtocol = MockAuthService()
    @Entry var featureService: any FeatureServiceProtocol = MockFeatureService()
    // One @Entry per service. Default value is always a mock.
}
```

Use `@Entry` (Swift 5.9+). Never use the old `EnvironmentKey` boilerplate.

---

## 3. Domain Layer

### Models

```swift
// Domain/Models/Item.swift
struct Item: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
}
```

Rules:
- Pure `struct` or `enum` — no classes, no `@Observable`.
- `Sendable` by default.
- No `import SwiftUI`, `import UIKit`, `import Combine`.
- Computed properties are fine; mutating methods are not (services mutate state).

### Domain errors

```swift
// Domain/Errors/AppError.swift
enum AppError: Error, Sendable {
    case network(URLError)
    case decoding(String)
    case notFound
    case unknown(String)
}
```

### Protocols

```swift
// Domain/Protocols/APIClientProtocol.swift
protocol APIClientProtocol: Sendable {
    func fetchItems(page: Int) async throws(AppError) -> PaginatedResponse<Item>
}
```

Rules:
- Every protocol has **exactly two conformers**: production type + mock.
- Single-conformer protocols are banned.
- Cross-layer protocols live here. Internal protocols stay inside their layer.

### Fetchers

```swift
// Domain/Fetchers/ItemFetcher.swift
struct ItemFetcher {
    private let client: any APIClientProtocol

    init(client: any APIClientProtocol) {
        self.client = client
    }

    func fetch(page: Int) async throws(AppError) -> [Item] {
        let response = try await client.fetchItems(page: page)
        return response.data
    }
}
```

Rules:
- `struct`, no stored state.
- Dependencies injected via `init` as `any Protocol`.
- No `@MainActor` — runs off-main by default.

---

## 4. Infrastructure Layer

### HTTP client

```swift
// Infrastructure/API/APIClient.swift
final class APIClient: APIClientProtocol, Sendable {
    private let urlSession: URLSession
    private let tokenProvider: any AuthTokenProviding

    init(urlSession: URLSession = .shared, tokenProvider: any AuthTokenProviding) {
        self.urlSession = urlSession
        self.tokenProvider = tokenProvider
    }

    // Runs off-main — no actor annotation needed on Sendable final class
    func fetchItems(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        let request = try buildRequest(path: "/items", queryItems: [.init(name: "page", value: "\(page)")])
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.network(URLError(.badServerResponse))
        }
        return try ModelDecoder.decode(PaginatedResponse<APIItem>.self, from: data).toDomain()
    }

    private func buildRequest(path: String, queryItems: [URLQueryItem] = []) throws(AppError) -> URLRequest {
        // Build URLRequest with auth headers.
    }
}
```

Rules:
- `Sendable` but **not** `actor` — stateless.
- No actor annotation needed — `async` methods on a `Sendable final class` run on the cooperative thread pool by default.
- All mutable state in mocks is actor-isolated (mocks are `actor` types, not `@unchecked Sendable` classes).

### DTOs

```swift
// Infrastructure/API/APIItem.swift
struct APIItem: Decodable, Sendable {
    let id: String
    let title: String
    let created_at: Date
}

extension Item {
    init(api: APIItem) {
        self.id = api.id
        self.title = api.title
        self.createdAt = api.created_at
    }
}
```

Pattern: `APIFoo` (DTO) → `Foo.init(api:)` (domain). Never make domain models `Decodable` directly.

### Shared decoder

```swift
// Infrastructure/Decoding/ModelDecoder.swift
enum ModelDecoder {
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(AppError) -> T {
        do {
            return try shared.decode(type, from: data)
        } catch {
            throw AppError.decoding(error.localizedDescription)
        }
    }
}
```

### Storage

```swift
// Infrastructure/Storage/StorageService.swift
final class StorageService: StorageServiceProtocol {
    enum Mode { case standard, private }

    func getString(_ key: StorageKey, mode: Mode) async throws -> String? { ... }
    func setString(_ value: String, for key: StorageKey, mode: Mode) async throws { ... }
    func remove(_ key: StorageKey, mode: Mode) async throws { ... }
}

// Infrastructure/Storage/StorageKey.swift
enum StorageKey: String {
    case accessToken
    case userPreference
    // One case per persisted value.
}
```

### Logging

```swift
// Infrastructure/Logging/Console.swift
enum Console {
    static func log(_ message: String, file: String = #file) {
        #if DEBUG
        let prefix = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        print("[\(prefix)] \(message)")
        #endif
    }

    static func error(_ error: Error, file: String = #file) {
        let prefix = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        // Forward to analytics service.
        analyticsSink?(error)
        #if DEBUG
        print("[\(prefix)] ERROR: \(error)")
        #endif
    }

    static var analyticsSink: ((Error) -> Void)?
}
```

### Mocks (DEBUG-only)

```swift
// Infrastructure/Mocks/MockAPIClient.swift
#if DEBUG
actor MockAPIClient: APIClientProtocol {

    // MARK: - Configuration

    var fetchItemsResult: Result<PaginatedResponse<Item>, AppError> = .success(.fixture())
    var fetchDelay: Duration?

    // MARK: - Recorded calls

    private(set) var fetchItemsCallCount = 0

    // MARK: - APIClientProtocol

    func fetchItems(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        fetchItemsCallCount += 1
        if let delay = fetchDelay {
            try? await Task.sleep(for: delay)
        }
        return try fetchItemsResult.get()
    }
}
#endif
```

---

## 5. Services Layer

All services live in `Services/` (flat — no subfolders).

### Canonical service

```swift
// Services/FeatureService.swift
@MainActor
@Observable
final class FeatureService {

    // MARK: - State

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    // MARK: - Private

    private let fetcher: ItemFetcher
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    init(client: any APIClientProtocol) {
        self.fetcher = ItemFetcher(client: client)
    }

    // MARK: - Intent

    func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            isLoading = true
            error = nil
            defer { isLoading = false }

            do {
                items = try await fetcher.fetch(page: 1)
            } catch {
                // fetcher.fetch throws(AppError) — single catch branch is exhaustive
                self.error = error
                Console.error(error)
            }
        }
    }

    func refresh() async {
        loadTask?.cancel()
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await fetcher.fetch(page: 1)
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }
}
```

Rules:
- `@MainActor @Observable final class` — always these three together.
- `private(set) var` for observable state. Only this service writes it.
- `private var` for internal bookkeeping (page, in-flight task).
- Dependencies as `any Protocol` injected via `init`.
- Cancel in-flight task before starting a new one.
- `[weak self]` in every `Task { }` block that outlives the service's scope.
- All errors → `Console.error()` then surfaced via `self.error`.

### Scoped environment containers

When a feature needs 3+ co-owned services, wrap them:

```swift
@MainActor
@Observable
final class FeatureEnvironment {
    let listService: ItemListService
    let detailService: ItemDetailService
    let filterService: FilterService

    init(client: any APIClientProtocol) {
        listService = ItemListService(client: client)
        detailService = ItemDetailService(client: client)
        filterService = FilterService()
    }
}
```

Inject as one `@Environment` value rather than three.

---

## 6. Presentation Layer

### View anatomy

```swift
// Presentation/Feature/FeatureView.swift
struct FeatureView: View {
    @Environment(\.featureService) private var service

    var body: some View {
        Group {
            if service.isLoading {
                ProgressView()
            } else if let error = service.error {
                ErrorView(error: error)
            } else {
                itemList
            }
        }
        .task { service.load() }
    }

    private var itemList: some View {
        List(service.items) { item in
            ItemRow(item: item)
        }
    }
}

#Preview {
    FeatureView()
        .environment(\.featureService, MockFeatureService())
}
```

Rules:
- One view per file; file name matches type name.
- `@Environment` to read services. Never `@EnvironmentObject`, `@StateObject`, or `@ObservedObject`.
- Local `@State` only for transient UI state (focus, sheet presentation, text field input).
- No business logic, networking, or persistence in `View.body`.
- `#Preview` always uses mock services.
- Extract complex compositions into private `@ViewBuilder` properties.

### Design token system

```swift
// Presentation/Shared/UIConstants/UIConstants.swift
enum UIConstants {
    enum Padding {
        static let screen: CGFloat = 40
        static let card: CGFloat = 16
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 32
    }

    enum CornerRadius {
        static let card: CGFloat = 12
        static let pill: CGFloat = 24
    }

    enum FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let title: CGFloat = 24
        static let hero: CGFloat = 40
    }
}
```

No raw `CGFloat` literals in view files — always a token.

---

## 7. Data & Persistence

### Persistence verdict

| Concern | Implementation |
|---------|---------------|
| Key-value (non-secret) | `UserDefaults.standard` via `StorageService(mode: .standard)` |
| Secrets (tokens, keys) | Keychain via `StorageService(mode: .private)` |
| Image cache | In-process dictionary, scoped to relevant service |
| Relational data | Not used — prefer server-authoritative state |

**No SwiftData, no Core Data, no raw `UserDefaults` in business logic.**

### Auth token flow

1. On login success: `storageService.setString(token, for: .accessToken, mode: .private)`
2. On launch: `storageService.getString(.accessToken, mode: .private)`
3. On every HTTP request: `await tokenProvider.currentToken` (via `AuthTokenProvider`)
4. On logout: `storageService.remove(.accessToken, mode: .private)`

---

## 8. Concurrency Model

### Strategy

| Isolation | When |
|-----------|------|
| `@MainActor @Observable` | All services and UI-facing state |
| `actor` | Off-main infrastructure with concurrent callers (e.g. WebSocket client, device fingerprint, token cache) |
| `Sendable struct` | All domain models |
| `final class … Sendable` | Stateless HTTP clients — `async` methods run off-main by default |

Lock primitives (`Mutex`, `NSLock`, `os_unfair_lock`, `OSAllocatedUnfairLock`, `DispatchSemaphore`, `@synchronized`) are not part of this table. Cross-isolation mutable state is always an `actor`; there is no "actor would be overkill" tier.

### Actor usage

Reserve `actor` for infrastructure types whose work has no UI relevance and would otherwise serialise behind `@MainActor`. Examples: WebSocket client, offline cache, device ID resolver.

```swift
actor WebSocketClient: WebSocketClientProtocol {
    // connection is set once at init and never mutated — nonisolated let is safe
    nonisolated let connection: URLSessionWebSocketTask

    private var continuations: [String: AsyncStream<Event>.Continuation] = [:]

    func subscribe(to channel: String) -> AsyncStream<Event> {
        AsyncStream { continuation in
            continuations[channel] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.unsubscribe(from: channel) }
            }
        }
    }

    func unsubscribe(from channel: String) {
        continuations[channel]?.finish()
        continuations.removeValue(forKey: channel)
    }
}
```

### Token cache pattern

A token cache is the canonical "small piece of cross-isolation mutable state" — the temptation to reach for a lock here is high. The answer is an actor with a small, focused API:

```swift
actor TokenCache {
    private var token: Token?

    func currentToken() -> Token? { token }

    func store(_ token: Token) { self.token = token }

    func clear() { token = nil }
}
```

Callers `await tokenCache.currentToken()`. There is no synchronous variant; if a call site needs one, that call site is what changes — not the cache.

### Task lifecycle

```swift
// Cancel before starting — prevents double-load.
private var loadTask: Task<Void, Never>?

func load() {
    loadTask?.cancel()
    loadTask = Task { [weak self] in
        // ...
    }
}
```

- `Task.detached` — **never** in production (requires explicit comment if used).
- `[weak self]` — always in `Task { }` blocks that may outlive the owner.
- `async/await` only — no completion handlers in new code.

---

## 9. Navigation

### Single typed enum

```swift
// Services/NavigationRoute.swift
enum NavigationRoute: Hashable {
    case detail(Item)
    case settings
    case profile(userId: String)
}
```

### `NavigationService`

```swift
@MainActor
@Observable
final class NavigationService {
    private(set) var path = NavigationPath()

    func push(_ route: NavigationRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
```

### Root view wiring

```swift
struct RootView: View {
    @Environment(\.navigationService) private var nav

    var body: some View {
        NavigationStack(path: Binding(get: { nav.path }, set: { nav.path = $0 })) {
            HomeView()
                .navigationDestination(for: NavigationRoute.self) { route in
                    switch route {
                    case .detail(let item): ItemDetailView(item: item)
                    case .settings: SettingsView()
                    case .profile(let id): ProfileView(userId: id)
                    }
                }
        }
    }
}
```

---

## 10. Configuration & Secrets

### Pattern

- Secrets come from environment variables at build time (CI) or a local `.env` file (dev).
- A code-generation script writes `Configuration.swift` into the source tree.
- `Configuration.swift` is **gitignored**. Never committed.
- `.env.example` is committed with placeholder values.

```swift
// App/Configuration.swift — GENERATED, DO NOT EDIT, gitignored
// periphery:ignore:all
enum Configuration {
    static let apiBaseURL = "https://api.example.com"
    static let analyticsToken = "<ANALYTICS_TOKEN>"
    static let appStoreID = "<APP_STORE_ID>"
}
```

### `ProcessInfo` guard for test/preview

```swift
extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestBundlePath"] != nil
    }

    var isRunningInPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
    }
}
```

---

## Appendix A — Layer dependency diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Composition (AppDependencies)                                    │
└───────────┬─────────────────────────────────────────────────────┘
            │ constructs
┌───────────▼──────────────┐    ┌────────────────────────────────┐
│ Services                 │    │ Presentation                    │
│ @MainActor @Observable   │◄───│ reads via @Environment          │
└───────────┬──────────────┘    └────────────────────────────────┘
            │ depends on
┌───────────▼──────────────────────────────────────────────────┐
│ Domain                                                        │
│  Models (Sendable struct)  Protocols  Fetchers  Errors        │
└───────────────┬───────────────────────────────────────────────┘
                │ implemented by
┌───────────────▼──────────────────────────────────────────────┐
│ Infrastructure                                                │
│  APIClient (Sendable)  Actors  Storage  Logging  Mocks        │
└───────────────────────────────────────────────────────────────┘
```

Arrows point inward toward Domain. Infrastructure never imports Presentation.

## Appendix B — MV adherence audit grep suite

Run after any significant refactor:

```bash
find . -name "*.swift" \
  -not -path "*/.build/*" -not -path "*/DerivedData/*" > /tmp/files.txt

# BLOCKERS
grep -rEn 'class +[A-Za-z0-9_]+ViewModel\b' $(cat /tmp/files.txt)
grep -rEn ': *ObservableObject\b' $(cat /tmp/files.txt)
grep -rEn '@Published\b' $(cat /tmp/files.txt)
grep -rEn '@State[^=]+=[^=]+Service\(' $(cat /tmp/files.txt)

# WARNINGS
grep -rEn 'final +class +[A-Za-z0-9_]+Service\b' $(cat /tmp/files.txt)
# Verify each hit has both @MainActor and @Observable in the 3 lines above.

# SUGGESTIONS
grep -rEn ': *EnvironmentKey\b' $(cat /tmp/files.txt)
```
