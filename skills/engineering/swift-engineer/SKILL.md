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

### Data Race Safety

```swift
// ✅ Sendable conformance for cross-isolation transfer
struct UserData: Sendable {
    let id: UUID
    let name: String
}

// ✅ Actor for mutable shared state
actor CacheManager {
    private var cache: [String: Data] = [:]
    
    func get(_ key: String) -> Data? { cache[key] }
    func set(_ key: String, value: Data) { cache[key] = value }
}
```

### Isolation Boundaries

```swift
// ✅ MainActor @Observable service owns view-facing state
@MainActor
@Observable
final class FeatureService {
    private(set) var items: [Item] = []

    private let fetcher: ItemFetcher    // private actor for off-main work

    init(fetcher: ItemFetcher) {
        self.fetcher = fetcher
    }

    func load() async throws {
        items = try await fetcher.fetchItems()
    }
}

// ✅ nonisolated for sync access to immutable data
actor DataStore {
    nonisolated let identifier: String
    private var data: [String: Any] = [:]
    
    init(identifier: String) {
        self.identifier = identifier
    }
}
```

### Typed Throws (Swift 6)

```swift
enum NetworkError: Error {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed
}

func fetchUser(id: UUID) throws(NetworkError) -> User {
    guard let url = URL(string: "...") else {
        throw .invalidURL
    }
    // ...
}
```

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
| `@AppStorage` | UserDefaults-backed persistence |

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

## Swift Testing Framework

Use Swift Testing (`import Testing`) for all new tests. Migrate XCTest only when modifying existing test files.

### Basic Structure

```swift
import Testing
@testable import MyApp

struct UserServiceTests {
    let sut: UserService
    let mockAPI: MockAPIClient
    
    init() {
        mockAPI = MockAPIClient()
        sut = UserService(api: mockAPI)
    }
    
    @Test("fetches user by ID")
    func fetchUser() async throws {
        mockAPI.stubResponse(User(id: "123", name: "Alice"))
        
        let user = try await sut.fetchUser(id: "123")
        
        #expect(user.name == "Alice")
        #expect(mockAPI.requestCount == 1)
    }
    
    @Test("throws on invalid ID")
    func fetchUserInvalidID() async {
        mockAPI.stubError(APIError.notFound)
        
        await #expect(throws: APIError.notFound) {
            try await sut.fetchUser(id: "invalid")
        }
    }
}
```

### Parameterized Tests

```swift
@Test("validates email format", arguments: [
    ("test@example.com", true),
    ("invalid", false),
    ("@missing.local", false),
    ("spaces in@email.com", false)
])
func validateEmail(email: String, isValid: Bool) {
    #expect(EmailValidator.isValid(email) == isValid)
}
```

### Traits and Organization

```swift
@Suite("Authentication", .tags(.auth))
struct AuthTests {
    @Test("login succeeds with valid credentials")
    func loginSuccess() async throws { ... }
    
    @Test("login fails with invalid password", .bug("APP-123", "Flaky on CI"))
    func loginFailure() async throws { ... }
    
    @Test("refresh token", .timeLimit(.minutes(1)))
    func refreshToken() async throws { ... }
    
    @Test("biometric auth", .enabled(if: BiometricAuth.isAvailable))
    func biometricAuth() async throws { ... }
}
```

### Confirmation for Async Expectations

```swift
@Test("notifies delegate on completion")
func delegateNotification() async {
    await confirmation("delegate called") { confirm in
        let delegate = MockDelegate(onComplete: { confirm() })
        let sut = Downloader(delegate: delegate)
        await sut.download(url: testURL)
    }
}
```

## Structured Concurrency

> For comprehensive concurrency guidance including migration, diagnostics, and advanced patterns, see the `swift-concurrency` skill.

### Task Hierarchies

```swift
// ✅ Parallel fetch with automatic cancellation
func loadDashboard() async throws -> Dashboard {
    async let user = fetchUser()
    async let stats = fetchStats()
    async let notifications = fetchNotifications()
    
    return try await Dashboard(
        user: user,
        stats: stats,
        notifications: notifications
    )
}

// ✅ TaskGroup for dynamic concurrency
func fetchAllImages(urls: [URL]) async throws -> [UIImage] {
    try await withThrowingTaskGroup(of: (Int, UIImage).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    throw ImageError.invalidData
                }
                return (index, image)
            }
        }
        
        var results = [Int: UIImage]()
        for try await (index, image) in group {
            results[index] = image
        }
        return urls.indices.compactMap { results[$0] }
    }
}
```

### Cancellation Handling

```swift
func processLargeDataset(_ items: [Item]) async throws -> [Result] {
    var results: [Result] = []
    
    for item in items {
        try Task.checkCancellation() // Check before expensive work
        let result = try await process(item)
        results.append(result)
    }
    
    return results
}

// Using withTaskCancellationHandler for cleanup
func streamData() async throws {
    let connection = await openConnection()
    
    try await withTaskCancellationHandler {
        for try await chunk in connection.stream {
            process(chunk)
        }
    } onCancel: {
        Task { await connection.close() }
    }
}
```

### AsyncSequence

```swift
// ✅ Custom AsyncSequence for paginated API
struct PaginatedResults<T: Decodable>: AsyncSequence {
    typealias Element = [T]
    let initialURL: URL
    
    func makeAsyncIterator() -> Iterator {
        Iterator(nextURL: initialURL)
    }
    
    struct Iterator: AsyncIteratorProtocol {
        var nextURL: URL?
        
        mutating func next() async throws -> [T]? {
            guard let url = nextURL else { return nil }
            let (data, _) = try await URLSession.shared.data(from: url)
            let page = try JSONDecoder().decode(Page<T>.self, from: data)
            nextURL = page.nextURL
            return page.items.isEmpty ? nil : page.items
        }
    }
}
```

## Code Quality

### Method Length

20 lines maximum per method. If a method exceeds this, extract named private helpers with descriptive names.

```swift
// ❌ Avoid: One method doing everything
func submit() async throws {
    // URL construction
    // validation
    // networking
    // decoding
    // state update
    // analytics
}

// ✅ Prefer: Named responsibilities
func submit() async throws {
    try validate()
    let request = try buildRequest()
    let data = try await execute(request)
    let result = try decode(data)
    apply(result)
}
```

### Parameter Count

Maximum 3 parameters. Beyond 3, introduce a dedicated parameter type.

```swift
// ❌ Avoid
func fetch(page: Int, limit: Int, sort: String, category: String?, subcategory: String?) async throws -> [Item]

// ✅ Prefer
struct FetchOptions {
    let page: Int
    let limit: Int
    let sort: String
    var category: String?
    var subcategory: String?
}

func fetch(_ options: FetchOptions) async throws -> [Item]
```

### No Boolean Flag Parameters

Boolean parameters that toggle behaviour belong in separate functions or an enum.

```swift
// ❌ Avoid
func load(forceRefresh: Bool)

// ✅ Prefer
func load()
func reload()
```

### Single Responsibility

Every function does one thing at one level of abstraction. If you need the word "and" to describe what it does, split it.

### DRY — Extract Repeated Logic

Identify any pattern appearing more than twice and extract it into a named helper. Apply generics and closures to capture variation; keep call sites readable.

```swift
// ❌ Avoid: Copy-pasted loop body
for item in listA { item.cancel() }
for item in listB { item.cancel() }
for item in listC { item.cancel() }

// ✅ Prefer: Named helper
[listA, listB, listC].forEach { $0.forEach { $0.cancel() } }
// or a dedicated named method when the operation is complex
```

### Naming — Clarity at Call Site

Design names for clarity at the point of use, not at the declaration site. The call site should read as natural English.

```swift
// ❌ Avoid: Abbreviated or ambiguous
func remove(_ x: Int)
func fetch(_ s: String) async throws

// ✅ Prefer: Reads as prose
func remove(at index: Int)
func fetch(channel slug: String) async throws
```

**Boolean properties read as assertions:**

```swift
// ❌
var empty: Bool
var valid: Bool

// ✅
var isEmpty: Bool
var isValid: Bool
```

**Mutating/nonmutating pairs follow the verb/adjective convention:**

```swift
// Mutating: imperative verb
mutating func sort()
mutating func append(_ item: Item)

// Nonmutating: adjective or past participle
func sorted() -> [Item]
func appending(_ item: Item) -> [Item]
```

### Documentation Comments

All public and internal protocol-satisfying methods require `///` documentation. Private helpers do not unless the name alone is insufficient.

```swift
/// Fetches the full channel detail for the given slug.
///
/// - Parameter slug: The channel's URL slug (e.g. "whatever").
/// - Returns: A fully decoded `Channel` including playback URL.
/// - Throws: `NetworkError.httpError` for non-2xx responses.
func fetchChannel(slug: String) async throws -> Channel
```

Never use `/** */` block comments.

### Column Limit

100 characters per line. Wrap long signatures with each parameter on its own line, indented +2:

```swift
func fetchLivestreams(
  page: Int,
  limit: Int,
  sort: String = "featured",
  category: String? = nil
) async throws -> PaginatedResponse<Stream>
```

---

## Code Style

### Avoid didSet with Side Effects

Never use `didSet` property observers for side effects like persistence, networking, or analytics. Use explicit setter methods instead:

```swift
// ❌ Avoid: didSet with side effects
@Observable
final class SettingsService {
    var volume: Double = 0.5 {
        didSet {
            guard volume != oldValue else { return }
            Task { await saveVolume(volume) }  // Hidden side effect!
        }
    }
}

// ✅ Prefer: Explicit setter methods
@Observable
final class SettingsService {
    private(set) var volume: Double = 0.5

    func setVolume(_ value: Double) async {
        guard value != volume else { return }
        volume = value
        await settings.saveVolume(value)
        analytics.log(.volumeChanged(value))
    }
}
```

For SwiftUI bindings with `@Observable`, create custom bindings in the View:

```swift
struct SettingsView: View {
    var service: SettingsService

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { service.volume },
            set: { newValue in Task { await service.setVolume(newValue) } }
        )
    }

    var body: some View {
        Slider(value: volumeBinding, in: 0...1)
    }
}
```

**Why avoid didSet side effects:**
- Creates implicit dependencies that are hard to trace
- `Task { }` in didSet creates detached tasks that can race
- Difficult to test since side effects happen automatically
- Mixes concerns (state change + persistence + analytics)

### Early Returns

Prefer early returns over nested if-else blocks. Invert conditions and return early to reduce nesting:

```swift
// ❌ Avoid: Nested conditionals
func process() {
    if isValid {
        // long block of valid logic
    } else {
        // handle invalid
    }
}

// ✅ Prefer: Early return
func process() {
    guard isValid else {
        // handle invalid
        return
    }
    // valid logic at top level
}
```

### Prefer Switch Over If-Else Chains

Use `switch` statements instead of long if-else chains for better readability and exhaustiveness checking:

```swift
// ❌ Avoid: Long if-else chains
if keyPath == \.resolution {
    // ...
} else if keyPath == \.bitrate {
    // ...
} else if keyPath == \.framerate {
    // ...
} else {
    return
}

// ✅ Prefer: Switch statement
switch keyPath {
case \.resolution:
    // ...
case \.bitrate:
    // ...
case \.framerate:
    // ...
default:
    return
}
```

This applies to KeyPath matching, enum cases, and any branching with 3+ conditions.

### Prefer Overlay Over Nested Stacks

Use `overlay` and `background` modifiers instead of deeply nested VStacks, HStacks, and ZStacks for layering content:

```swift
// ❌ Avoid: Nested stacks for layering
ZStack {
    VStack {
        HStack {
            Spacer()
            closeButton
        }
        Spacer()
    }

    contentView

    VStack {
        Spacer()
        bottomBar
    }
}

// ✅ Prefer: Overlay modifiers
contentView
    .overlay(alignment: .topTrailing) {
        closeButton
    }
    .overlay(alignment: .bottom) {
        bottomBar
    }

// ✅ Prefer: safeAreaInset for edge-pinned content
contentView
    .safeAreaInset(edge: .bottom) {
        bottomBar
    }
```

**Why prefer overlay:**
- Clearer intent — each layer is explicitly positioned
- Fewer nested braces and indentation levels
- Better performance — SwiftUI can optimise layout more efficiently
- Alignment is explicit rather than relying on Spacer hacks
- `safeAreaInset` properly adjusts scrollable content

**When to use ZStack:**
- Truly stacked content where all children contribute to sizing
- Complex layering with more than 2-3 overlapping elements
- When children need to share the same coordinate space for animations

### One View Per File

Every SwiftUI view must be in its own file. Never use `private struct` views, computed properties, or functions to create subviews within a parent view file.

```swift
// ❌ Avoid: Private subviews in same file
struct AboutView: View {
    var body: some View {
        VStack {
            ProfilePhotoSection()
            AboutTextSection()
        }
    }
}

private struct ProfilePhotoSection: View { ... }  // ❌ Wrong file

// ❌ Avoid: Computed property subviews
struct AboutView: View {
    private var profilePhotoSection: some View { ... }  // ❌ Never do this
}

// ✅ Correct: Separate files
// ProfilePhotoSection.swift
struct ProfilePhotoSection: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue, .pink], ...)
            Image("ProfilePhoto")
                .clipShape(Circle())
        }
    }
}

#Preview {
    ProfilePhotoSection()
}

// AboutTextSection.swift
struct AboutTextSection: View {
    var body: some View {
        Text("About content here")
    }
}

#Preview {
    AboutTextSection()
}

// AboutView.swift
struct AboutView: View {
    var body: some View {
        VStack {
            ProfilePhotoSection()
            AboutTextSection()
        }
    }
}

#Preview {
    AboutView()
}
```

**Why one view per file:**
- Each view has its own `#Preview` for rapid iteration
- Clearer file organisation and smaller files
- Easier to locate and modify components
- Better git history and code review
- Forces proper separation of concerns
- No exceptions — consistency is more valuable than saving a file

## Reviewing code

This skill is for **writing** new Swift. For reviewing existing code before a
commit or PR — including the full BLOCKER / WARNING / SUGGESTION pass and the
live Xcode navigator check — use the `swift-code-review` skill instead. It
loads this skill plus `swift-testing` and `swift-concurrency` and applies a
concrete checklist.

## References

- **Swift Concurrency**: See the `swift-concurrency` skill for comprehensive guidance on async/await, actors, Sendable, Swift 6 migration, and data race safety
- **Testing patterns**: See [references/testing.md](references/testing.md)
- **SwiftUI components**: See [references/swiftui.md](references/swiftui.md)
- **Apple Liquid glass**: See [references/liquidglass.md](references/liquidglass.md)