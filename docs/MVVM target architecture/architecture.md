# MVVM Architecture Reference

> Swift 6.2 · SwiftUI · MVVM (Model-View-ViewModel) with `@Observable`
> Platform-agnostic template. Substitute your target OS (iOS 17+, tvOS 17+, macOS 14+).

---

## Table of Contents

1. [Layer Map](#1-layer-map)
2. [App Entry & Composition Root](#2-app-entry--composition-root)
3. [Domain Layer](#3-domain-layer)
4. [Infrastructure Layer](#4-infrastructure-layer)
5. [Repositories Layer](#5-repositories-layer)
6. [ViewModels Layer](#6-viewmodels-layer)
7. [Presentation Layer](#7-presentation-layer)
8. [Data & Persistence](#8-data--persistence)
9. [Concurrency Model](#9-concurrency-model)
10. [Navigation](#10-navigation)
11. [Configuration & Secrets](#11-configuration--secrets)

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
├── Repositories/           ← Sendable final class. FLAT — no subfolders.
├── Services/               ← @MainActor @Observable. App-scoped shared state (auth, prefs, flags).
├── Presentation/
│   ├── <Feature>/
│   │   ├── <Feature>Screen.swift     ← Reads @Environment, passes repo to View
│   │   ├── <Feature>View.swift       ← Owns ViewModel via @State
│   │   └── <Feature>ViewModel.swift  ← @MainActor @Observable — all view state here
│   └── Shared/
│       ├── Components/     ← Stateless, reusable views
│       └── UIConstants/    ← Design tokens (Padding, Spacing, CornerRadius, FontSize…)
└── Resources/              ← Assets.xcassets, Fonts, Localizable.xcstrings
```

### Layer dependency rules

```
Presentation (View + ViewModel)  →  Repositories  →  Domain  ←  Infrastructure
```

- `Domain` imports nothing project-internal.
- `Infrastructure` implements `Domain/Protocols` — never imports `Presentation`.
- `Repositories` import `Domain` and `Infrastructure` protocols — never import `Presentation`.
- `ViewModels` depend on `Domain/Protocols` (repository protocols) — never construct a repository.
- `Services` are `@MainActor @Observable`, hold cross-cutting app state, and are built once in `AppDependencies` then injected via `@Environment` — like repositories, but stateful and observed. Views bind into them with `@Bindable`.
- Views read their ViewModel via `@State`. They receive repositories (and services) from `@Environment` and pass repositories into the ViewModel's `init`.

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
            RootScreen()
                .environment(\.featureRepository, dependencies.featureRepository)
                .environment(\.authRepository, dependencies.authRepository)
                // One .environment() call per repository.
        }
    }
}
```

### `AppDependencies` — composition root

```swift
// App/AppDependencies.swift
@MainActor
struct AppDependencies {
    let authRepository: any AuthRepositoryProtocol
    let featureRepository: any FeatureRepositoryProtocol
    // ...

    init() {
        let apiClient = APIClient()
        self.authRepository = AuthRepository(client: apiClient)
        self.featureRepository = FeatureRepository(client: apiClient)
    }
}
```

Rules for `AppDependencies`:

- **Pure wiring only** — no business logic.
- Every repository constructed **exactly once**.
- `@Observable` **Services** (auth, preferences, feature flags) are constructed here once too, like repositories, and injected via `@Environment`.
- ViewModels are **never** constructed here — they are per-screen and owned by their View.
- Mock infrastructure swapped in DEBUG via `ProcessInfo` check:

```swift
private var isTestOrPreview: Bool {
    ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
        || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
}
```

### `EnvironmentValues` entries

```swift
// App/EnvironmentRepositories.swift
extension EnvironmentValues {
    @Entry var authRepository: any AuthRepositoryProtocol = MockAuthRepository()
    @Entry var featureRepository: any FeatureRepositoryProtocol = MockFeatureRepository()
    // One @Entry per repository. Default value is always a mock.
}
```

Use `@Entry` (Swift 5.9+). Never use the old `EnvironmentKey` boilerplate.
ViewModels are **never** registered as `@Entry` values. `@Observable` Services
**are** — the same way repositories are.

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
- Computed properties are fine; mutating methods are not (ViewModels mutate their own state).

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

// Domain/Protocols/FeatureRepositoryProtocol.swift
protocol FeatureRepositoryProtocol: Sendable {
    func fetch(page: Int) async throws(AppError) -> PaginatedResponse<Item>
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
    private(set) var lastFetchedPage: Int?

    // MARK: - APIClientProtocol

    func fetchItems(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        fetchItemsCallCount += 1
        lastFetchedPage = page
        if let delay = fetchDelay {
            try? await Task.sleep(for: delay)
        }
        return try fetchItemsResult.get()
    }
}
#endif
```

---

## 5. Repositories Layer

All repositories live in `Repositories/` (flat — no subfolders).

Repositories are **stateless** — no `@Observable`, no `@MainActor`. They translate between infrastructure and domain, delegating to the API client or storage. All view-facing state lives in ViewModels.

### Canonical repository

```swift
// Repositories/FeatureRepository.swift
final class FeatureRepository: FeatureRepositoryProtocol, Sendable {

    // MARK: - Init

    private let client: any APIClientProtocol

    init(client: any APIClientProtocol) {
        self.client = client
    }

    // MARK: - FeatureRepositoryProtocol

    func fetch(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        try await client.fetchItems(page: page)
    }
}
```

Rules:
- `final class … Sendable` — no actor annotation, no `@Observable`.
- No stored view state (`items`, `isLoading`, `error` belong in the ViewModel).
- Dependencies as `any Protocol` injected via `init`.
- Methods are `async throws(AppError)` — typed throws propagated from the API client.

### Repository mock

```swift
// Infrastructure/Mocks/MockFeatureRepository.swift
#if DEBUG
actor MockFeatureRepository: FeatureRepositoryProtocol {

    var fetchResult: Result<PaginatedResponse<Item>, AppError> = .success(.fixture())
    var fetchDelay: Duration?
    private(set) var fetchCallCount = 0

    func fetch(page: Int) async throws(AppError) -> PaginatedResponse<Item> {
        fetchCallCount += 1
        if let delay = fetchDelay {
            try? await Task.sleep(for: delay)
        }
        return try fetchResult.get()
    }

    func stub(_ result: Result<PaginatedResponse<Item>, AppError>) {
        fetchResult = result
    }
}
#endif
```

---

## 6. ViewModels Layer

ViewModels live inside `Presentation/<Feature>/` alongside their View.

ViewModels hold **all** observable state for a screen. They are the primary unit-testing target in MVVM — they contain business logic and state transitions with no SwiftUI dependency.

### Canonical ViewModel

```swift
// Presentation/Feature/FeatureViewModel.swift
@MainActor
@Observable
final class FeatureViewModel {

    // MARK: - State

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: AppError?
    private(set) var hasMore = true

    // MARK: - Private

    private let repository: any FeatureRepositoryProtocol
    private var currentPage = 1
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    init(repository: any FeatureRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Intent

    func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await performLoad(page: 1, reset: true)
        }
    }

    func loadNextPage() {
        guard hasMore, !isLoading else { return }
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await performLoad(page: currentPage + 1, reset: false)
        }
    }

    func loadNextPageIfNeeded() async {
        guard hasMore, !isLoading else { return }
        loadTask?.cancel()
        await performLoad(page: currentPage + 1, reset: false)
    }

    func refresh() async {
        loadTask?.cancel()
        await performLoad(page: 1, reset: true)
    }

    // MARK: - Private

    private func performLoad(page: Int, reset: Bool) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await repository.fetch(page: page)
            if reset {
                items = response.data
                currentPage = 1
            } else {
                items.append(contentsOf: response.data)
                currentPage = page
            }
            hasMore = response.hasNextPage
        } catch {
            self.error = error
            Console.error(error)
        }
    }
}
```

Rules:
- `@MainActor @Observable final class` — always these three together.
- `private(set) var` for observable state. Only this ViewModel writes it.
- `private var` for internal bookkeeping (page, in-flight task).
- Repository as `any Protocol` injected via `init`.
- Cancel in-flight task before starting a new one.
- `[weak self]` in every `Task { }` block that outlives the ViewModel's scope.
- No `import SwiftUI` — ViewModels are UI-framework-agnostic, which is what makes them unit-testable.
- All errors → `Console.error()` then surfaced via `self.error`.

---

## 6a. Services Layer (cross-cutting state)

Some state is not per-screen: the auth session, user preferences, feature flags.
It lives in an `@Observable` **Service** — same shape as a ViewModel, but built
once in `AppDependencies`, injected via `@Environment`, and observed by many
screens. A view binds into it with `@Bindable`.

```swift
// Services/PreferencesService.swift
@MainActor
@Observable
final class PreferencesService: PreferencesServiceProtocol {

    // MARK: - State

    private(set) var prefersReducedMotion = false

    // MARK: - Private

    private let storage: any StorageServiceProtocol

    // MARK: - Init

    init(storage: any StorageServiceProtocol) {
        self.storage = storage
    }

    // MARK: - Intent

    func setPrefersReducedMotion(_ on: Bool) async {
        prefersReducedMotion = on
        try? await storage.set(on, for: .prefersReducedMotion, mode: .standard)  // persist
    }
}
```

Rules:
- `@MainActor @Observable final class` — same as a ViewModel.
- App-scoped and shared: built once in `AppDependencies`, injected via `@Environment`. Never owned by a single View's `@State`.
- One protocol → two conformers (production + mock), like every other injected dependency.
- Persist through `StorageService` — never raw `UserDefaults` in the service beyond a change-observer bridge for external writes.
- **Not** a substitute for a ViewModel: per-screen state stays in the ViewModel. Reach for a Service only for genuinely cross-cutting, app-lifetime state.

---

## 7. Presentation Layer

### Screen and View anatomy

Each feature has two types:

- **`FeatureScreen`** — reads repositories from `@Environment`, constructs the View. Has no `@State` of its own.
- **`FeatureView`** — owns the ViewModel via `@State`, reads only from `viewModel.*`.

```swift
// Presentation/Feature/FeatureScreen.swift
struct FeatureScreen: View {
    @Environment(\.featureRepository) private var repository

    var body: some View {
        FeatureView(repository: repository)
    }
}

// Presentation/Feature/FeatureView.swift
struct FeatureView: View {
    @State private var viewModel: FeatureViewModel

    init(repository: any FeatureRepositoryProtocol) {
        _viewModel = State(initialValue: FeatureViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else if let error = viewModel.error, viewModel.items.isEmpty {
                ErrorView(error: error)
            } else {
                itemList
            }
        }
        .task { viewModel.load() }
    }

    private var itemList: some View {
        List(viewModel.items) { item in
            ItemRow(item: item)
        }
    }
}

#Preview {
    FeatureView(repository: MockFeatureRepository())
}
```

Rules:
- One file per type; file name matches type name.
- `FeatureView` receives its repository via `init` — never reads from `@Environment` directly.
- `@State private var viewModel` — the View owns the ViewModel lifetime.
- Local `@State` only for transient UI state (focus, sheet presentation, text field input).
- No business logic, networking, or persistence in `View.body`.
- `#Preview` passes `MockFeatureRepository()` directly — no environment plumbing needed.
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

## 8. Data & Persistence

### Persistence verdict

| Concern | Implementation |
|---------|---------------|
| Key-value (non-secret) | `UserDefaults.standard` via `StorageService(mode: .standard)` |
| Secrets (tokens, keys) | Keychain via `StorageService(mode: .private)` |
| Image cache | In-process dictionary, scoped to relevant repository |
| Relational data | Not used — prefer server-authoritative state |

**No SwiftData, no Core Data, no raw `UserDefaults` in business logic.**

### Auth token flow

1. On login success: `storageRepository.setString(token, for: .accessToken, mode: .private)`
2. On launch: `storageRepository.getString(.accessToken, mode: .private)`
3. On every HTTP request: `await tokenProvider.currentToken` (via `AuthTokenProvider`)
4. On logout: `storageRepository.remove(.accessToken, mode: .private)`

---

## 9. Concurrency Model

### Strategy

| Isolation | When |
|-----------|------|
| `@MainActor @Observable` | All ViewModels and Services |
| `actor` | Off-main infrastructure with concurrent callers (e.g. WebSocket client, device fingerprint, token cache) |
| `Sendable struct` | All domain models |
| `final class … Sendable` | Stateless repositories and HTTP clients — `async` methods run off-main by default |

Lock primitives (`Mutex`, `NSLock`, `os_unfair_lock`, `OSAllocatedUnfairLock`, `DispatchSemaphore`, `@synchronized`) are not part of this table. Cross-isolation mutable state is always an `actor`; there is no "actor would be overkill" tier.

### Actor usage

Reserve `actor` for infrastructure types whose work has no UI relevance and would otherwise serialise behind `@MainActor`. Examples: WebSocket client, offline cache, device ID resolver.

```swift
actor WebSocketClient: WebSocketClientProtocol {
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

```swift
actor TokenCache {
    private var token: Token?

    func currentToken() -> Token? { token }
    func store(_ token: Token) { self.token = token }
    func clear() { token = nil }
}
```

Callers `await tokenCache.currentToken()`. There is no synchronous variant.

### Task lifecycle

```swift
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

## 10. Navigation

### Single typed enum

```swift
// Presentation/Shared/NavigationRoute.swift
enum NavigationRoute: Hashable {
    case detail(Item)
    case settings
    case profile(userId: String)
}
```

### `NavigationViewModel`

```swift
@MainActor
@Observable
final class NavigationViewModel {
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

If navigation is scoped to a single feature, the `NavigationViewModel` is owned by the root screen via `@State`. If it is app-wide, register it in `@Environment`.

### Root view wiring

```swift
struct RootScreen: View {
    @State private var navigation = NavigationViewModel()

    var body: some View {
        NavigationStack(path: Binding(get: { navigation.path }, set: { navigation.path = $0 })) {
            HomeScreen()
                .navigationDestination(for: NavigationRoute.self) { route in
                    switch route {
                    case .detail(let item): ItemDetailScreen(item: item)
                    case .settings: SettingsScreen()
                    case .profile(let id): ProfileScreen(userId: id)
                    }
                }
        }
    }
}
```

---

## 11. Configuration & Secrets

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
│ Repositories              │    │ Presentation                    │
│ Sendable, stateless       │◄───│ Screen reads @Environment repo  │
└───────────┬──────────────┘    │ View owns ViewModel via @State  │
            │ depends on        └────────────────────────────────┘
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

ViewModels live in `Presentation/` and depend on `Domain/Protocols/` (repository protocols) only.
Repositories are the boundary between Infrastructure and ViewModels.

## Appendix B — MVVM adherence audit grep suite

Run after any significant refactor:

```bash
find . -name "*.swift" \
  -not -path "*/.build/*" -not -path "*/DerivedData/*" > /tmp/files.txt

# BLOCKERS
# @Observable on a Repository — state belongs in a ViewModel or a Service, never a repo
grep -rEn '@Observable' $(cat /tmp/files.txt) | grep -v 'ViewModel\|Service\|Preview\|Mock'
# Remaining hits should be empty or a deliberate app-scoped *Service; a @Observable *Repository is a BLOCKER.

# Repository with @MainActor — repos are Sendable, not UI-bound
grep -rEn '@MainActor.*Repository\b' $(cat /tmp/files.txt)

# ViewModel constructed inside a View without @State
grep -rEn '@StateObject.*ViewModel\|@ObservedObject.*ViewModel' $(cat /tmp/files.txt)

# ObservableObject / @Published — banned, use @Observable
grep -rEn ': *ObservableObject\b|@Published\b' $(cat /tmp/files.txt)

# WARNINGS
# Verify each @Observable class is a ViewModel or a Service (never a repository)
grep -rEn '@Observable' $(cat /tmp/files.txt)
# Each hit should be a *ViewModel or a *Service type. A @Observable *Repository is a BLOCKER.

# ViewModel importing SwiftUI — breaks testability
grep -rEn 'import SwiftUI' $(cat /tmp/files.txt) | grep 'ViewModel'

# SUGGESTIONS
grep -rEn ': *EnvironmentKey\b' $(cat /tmp/files.txt)
# ViewModel registered in EnvironmentValues — VMs belong in @State, not @Environment
grep -rEn '@Entry.*ViewModel' $(cat /tmp/files.txt)
```
