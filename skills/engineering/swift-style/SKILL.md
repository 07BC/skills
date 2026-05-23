---
name: swift-style
description: >
  Code style, quality rules, and Swift 6 language essentials for writing
  clean Swift and SwiftUI from the first line. Loaded automatically by
  swift-engineer whenever new code is being generated, and by
  swift-code-review during review. Covers: method length, parameter count,
  naming conventions, guard / early-return patterns, switch over if-else
  chains, overlay over nested stacks, one-view-per-file, UserDefaults in
  @Observable (access / withMutation), didSet side effects, Sendable
  conformance, typed throws, and data race safety. For auditing or
  rewriting existing messy code, use swift-quality instead.
---

# Swift Style

> **Source of truth for Swift style and Swift 6 language essentials in every
> context.** Other agents (including spec-pipeline's engineer, test-writer,
> concurrency-auditor, and task-reviewer sub-agents) read this body as
> authority — even when this skill itself does not auto-fire. Any routing
> scope declared elsewhere governs only when this skill auto-fires on a human
> message; it does not gate sub-agent referencing.

Write-time rules companion to `swift-engineer`. Every rule here applies
to **new** Swift and SwiftUI code as it is being generated. For rewriting
existing messy code in place, use `swift-quality`. For reviewing code
before commit or PR, use `swift-code-review`.

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

### UserDefaults in @Observable — use `access` / `withMutation`

`@AppStorage` is a SwiftUI property wrapper. It **cannot** be applied to stored
properties inside an `@Observable` class — the compiler will reject it with:

> *Property wrapper cannot be applied to a stored property declared in a
> '@Observable' class*

Instead, back UserDefaults-persisted properties using the two observation
primitives the `@Observable` macro exposes: `access` and `withMutation`.

```swift
// ✅ Correct: UserDefaults in an @Observable service
@MainActor
@Observable
final class SettingsService {
  private let defaults = UserDefaults.standard

  var isNotificationsEnabled: Bool {
    get {
      access(keyPath: \.isNotificationsEnabled)
      return defaults.bool(forKey: Keys.isNotificationsEnabled)
    }
    set {
      withMutation(keyPath: \.isNotificationsEnabled) {
        defaults.set(newValue, forKey: Keys.isNotificationsEnabled)
      }
    }
  }
}

private extension SettingsService {
  enum Keys {
    static let isNotificationsEnabled = "isNotificationsEnabled"
  }
}
```

`access` registers the read with the observation graph so SwiftUI knows which
views depend on this property. `withMutation` fires the change notification so
those views invalidate. The result is identical tracking behaviour to a plain
stored property.

`@AppStorage` is correct and idiomatic in a SwiftUI `View` for simple,
view-local preferences that do not need to be shared across services:

```swift
// ✅ Correct: @AppStorage in a view
struct AppearanceView: View {
  @AppStorage("useDarkMode") private var useDarkMode = false

  var body: some View {
    Toggle("Dark mode", isOn: $useDarkMode)
  }
}
```

**One owner per key.** A service property and a view `@AppStorage` for the same
key will both compile but will not stay in sync — changes through one will not
update the other. Decide on a single owner and stick to it.

| Scenario | Pattern |
|---|---|
| Preference used by multiple views or has business logic | `access`/`withMutation` in service |
| Simple view-local toggle with no logic | `@AppStorage` in the view |

**Keys must always be named constants** — never inline string literals:

```swift
// ❌ Avoid
defaults.bool(forKey: "isNotificationsEnabled")

// ✅ Prefer
defaults.bool(forKey: Keys.isNotificationsEnabled)
```

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

## See Also

| Skill | Purpose |
|---|---|
| `swift-engineer` | Main feature-building skill (loads this one as a companion) |
| `swift-quality` | Rewrite existing messy code in place |
| `swift-code-review` | BLOCKER / WARNING / SUGGESTION review pass |
| `swift-concurrency` | Concurrency concepts and patterns |
| `swift-testing` | Unit-test authoring |
