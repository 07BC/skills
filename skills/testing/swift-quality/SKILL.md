---
name: swift-quality
description: >
  Rewrites Swift code to meet Google Swift Style Guide standards and project
  architecture rules. Use when code feels hard to read, methods are too long,
  responsibilities are mixed, or structure is unclear. Triggers: "rewrite this",
  "clean this up", "this is hard to read", "poor structure", "refactor", or
  any time generated code looks like it was written to satisfy the compiler
  rather than a human reader.
---

# Swift Code Quality Skill

This skill rewrites Swift code to be clean, readable, and structurally correct
according to the Google Swift Style Guide and this project's architecture rules.
It does not change behaviour. It does not change public API surfaces or protocol
conformances. It only improves structure, naming, and readability.

---

## Authority

The Google Swift Style Guide is the primary authority:
https://google.github.io/swift/

Apple's API Design Guidelines are incorporated by reference.

Project architecture rules in `docs/target-architecture.md` and `CLAUDE.md`
take precedence over style rules where they conflict.

---

## Process — always follow in order

### Step 1 — Read before touching anything

```bash
# Read CLAUDE.md
cat CLAUDE.md

# Read the file(s) to rewrite in full
cat <target file>

# Understand what the file is supposed to do
# Identify every public API surface — these must not change
```

Do not write a single line until you have read and understood the file.

### Step 2 — Identify violations

Go through each category below. Note every violation before fixing any.

### Step 3 — Rewrite in place

Apply all fixes. Build. Verify zero errors and zero warnings.

### Step 4 — Confirm behaviour is unchanged

The public API surface (protocol conformances, method signatures, property
names) must be identical before and after. If tests exist, they must still pass.

---

## Style Rules

### Naming

**Types:** `UpperCamelCase`. Descriptive, no abbreviations unless universally
known (`URL`, `HTTP`).

**Functions and properties:** `lowerCamelCase`. Verb phrases for functions,
noun phrases for properties.

**Constants:** `lowerCamelCase`. No Hungarian notation (`k` prefix, `g` prefix,
`SCREAMING_SNAKE_CASE` — all forbidden).

```swift
// ✅
static let configBaseURL = "https://config.example.com"

// ❌
static let kConfigBaseURL = "https://config.example.com"
static let CONFIG_BASE_URL = "https://config.example.com"
```

**Parameters:** Named clearly. The call site should read like prose.

```swift
// ✅
func fetch(channel slug: String) async throws -> Channel

// ❌
func fetchChannel(s: String) async throws -> Channel
```

**Static properties returning the declaring type:** No type suffix.

```swift
// ✅
static let shared: URLSession

// ❌
static let sharedSession: URLSession
```

---

### Method length and single responsibility

A method should do one thing. If a method does URL construction, networking,
status checking, AND decoding, it must be split.

**Maximum method length:** 20 lines. If a method exceeds this, extract named
private helpers.

**The right breakdown for a network fetch:**

```swift
// ✅ — four named responsibilities
private func buildRequest(host: String, path: String, queryItems: [URLQueryItem]) throws -> URLRequest
private func execute(_ request: URLRequest) async throws -> Data
private nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
private func fetch<T: Decodable>(host: String, path: String, queryItems: [URLQueryItem]) async throws -> T

// ❌ — one method doing everything
private func request<T: Decodable>(baseURL: String, path: String, queryItems: [URLQueryItem]) async throws -> T {
    // 40 lines of URL construction + networking + status checking + decoding
}
```

---

### No inline type definitions

Types are never defined inside a method or function body. Every type lives in
its own file in the correct layer folder.

```swift
// ❌ — inline type
func fetchToken() async throws -> String {
    struct TokenResponse: Decodable {
        struct TokenData: Decodable { let token: String }
        let data: TokenData
    }
    ...
}

// ✅ — type in its own file
// MyApp/Domain/Models/TokenResponse.swift
struct TokenResponse: Sendable, Decodable {
    let data: TokenData
    struct TokenData: Sendable, Decodable { let token: String }
}
```

---

### No inline decoder instantiation

`JSONDecoder` is never created inline. Always use the shared `ModelDecoder.make()`.

```swift
// ❌
let result = try JSONDecoder().decode(Article.self, from: data)

// ✅
let result = try decode(Article.self, from: data)
```

---

### No inline URL construction

`URLRequest` is never constructed inline in a method body. Always use the
shared `buildRequest(host:path:queryItems:)` builder.

```swift
// ❌ — URL construction scattered through method body
var components = URLComponents(string: baseURL + path)
if !queryItems.isEmpty { components?.queryItems = queryItems }
guard let url = components?.url else { throw APIError.invalidURL(path) }
var urlRequest = URLRequest(url: url)
urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

// ✅ — single named builder
let request = try buildRequest(host: "api.example.com", path: path, queryItems: items)
```

---

### Force unwrapping

Force unwrapping (`!`) is forbidden in production code. Use `guard let`,
`if let`, or `throw`.

```swift
// ❌
let url = components.url!

// ✅
guard let url = components.url else {
    throw KickError.invalidURL
}
```

The one permitted exception: `HTTPURLResponse` force-cast after confirming
the response is from an HTTP URL, with a comment explaining why it is safe.

---

### Error handling

`try?` is forbidden — it silently discards errors. Use `try` and propagate,
or use `do-catch` to transform.

```swift
// ❌
let data = try? decode(Article.self, from: raw)

// ✅
let data = try decode(Article.self, from: raw)
```

### Errors must not be swallowed in services

There are two distinct `do-catch` contexts in services. Apply the correct
rule for each.

#### Context 1 — Load methods (data fetching)

A `catch` that returns without storing to `self.error` is a silent failure
equivalent to `try?`. Forbidden.

```swift
// ❌ Wrong — silent failure
private func fetchFeatured(page: Int, appending: Bool) {
    Task {
        do {
            let response = try await client.fetchFeaturedArticles(page: page, limit: 32)
            featuredArticles = response.data
        } catch {
            return  // FORBIDDEN
        }
    }
}

// ✅ Correct — error stored, loading cleared, view can react
private func fetchFeatured(page: Int, appending: Bool) {
    isLoading = true
    error = nil
    Task {
        defer { isLoading = false }
        do {
            let response = try await client.fetchFeaturedArticles(page: page, limit: 32)
            featuredArticles = response.data
            hasMoreFeatured = response.hasNextPage
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }
}
```

Required elements in every load method `do-catch`:
1. `error = nil` before the attempt — clears stale error
2. `defer { isLoading = false }` — always clears, even on failure
3. `catch` must store to `self.error` — never return silently

#### Context 2 — Event stream handlers (MessageService)

A single malformed event packet should not kill the message pipeline or set
`self.error`. Skipping is acceptable, but must be explicit and documented.

```swift
// ❌ Wrong — undocumented silent skip
} catch {
    return
}

// ✅ Correct — intentional skip with documented reason
} catch {
    // A single malformed event does not affect message pipeline health.
    // Do not surface to the view — log in debug builds only.
    #if DEBUG
    print("[MessageService] Failed to decode event payload: \(error)")
    #endif
}
```

#### The audit rule

When running `/swift-quality`, flag every `catch` block that:
- Does not store to `self.error`, AND
- Does not have a comment explaining why

A `catch` with no comment and no `self.error =` is always a violation,
regardless of context.

---

### `guard` for early exits

Use `guard` for precondition checks and early exits. Do not bury the happy
path inside nested `if` blocks.

```swift
// ✅
guard let url = components.url else {
    throw KickError.invalidURL
}
// happy path continues flush left

// ❌
if let url = components.url {
    // happy path buried in nesting
} else {
    throw KickError.invalidURL
}
```

---

### Optional property assignment — no `if let` for pass-through

When assigning an optional value to an optional property, never use `if let`
as a gate. Assign directly, or use `.map` if a transformation is required.

`if let` as a gate adds noise without adding safety — the assignment already
handles `nil` correctly.

#### Direct assignment — types match

When the source and destination are the same optional type, assign directly.

```swift
// ✅
videoData.videoTitle = content.videoTitle
videoData.videoSeries = content.videoSeries
videoData.videoCdn = content.videoCdn
playerData.viewerUserId = viewer.viewerUserId

// ❌
if let title = content.videoTitle { videoData.videoTitle = title }
if let series = content.videoSeries { videoData.videoSeries = series }
if let cdn = content.videoCdn { videoData.videoCdn = cdn }
if let userId = viewer.viewerUserId { playerData.viewerUserId = userId }
```

#### `.map` — transformation required

When the value must be transformed before assignment, use `.map` on the
optional. This returns the transformed value or `nil`, matching the
destination type without branching.

```swift
// ✅
playerData.playerVersion = appVersion.map { "\(Constants.playerVersionPrefix)\($0)" }
videoData.videoDuration = content.videoDuration.map { NSNumber(value: Int($0 * 1000)) }

// ❌
if let version = appVersion {
    playerData.playerVersion = "\(Constants.playerVersionPrefix)\(version)"
}
if let duration = content.videoDuration {
    videoData.videoDuration = NSNumber(value: Int(duration * 1000))
}
```

#### The audit rule

Flag every `if let x = optional { obj.prop = x }` block. The fix is always
one of the two forms above. Never leave a pass-through `if let` in place.

---

### Vertical whitespace — phase separation

Blank lines mark transitions between distinct phases of logic. They are not
decorative. Every phase transition gets exactly one blank line above it.

**The rule applied recursively:** the same principle applies at every nesting
level — inside `Task` closures, `do` blocks, `withTaskGroup` bodies, and
nested functions. It is not just a top-level function rule.

#### After `guard`

Every `guard` statement is followed by a blank line.

```swift
// ✅
guard let container = modelContainer else { return }

let context = ModelContext(container)

// ❌
guard let container = modelContainer else { return }
let context = ModelContext(container)
```

#### Between logically distinct `let` groups

`let` declarations that are used together stay grouped without a blank line.
A blank line separates groups that belong to different phases.

```swift
// ✅ — context and descriptor are both setup for the fetch; they stay together
let context = ModelContext(container)
let descriptor = FetchDescriptor<AuthSession>()

guard let session = try? context.fetch(descriptor).first else { return }

// ❌ — unnecessary blank line inside a coupled group
let context = ModelContext(container)

let descriptor = FetchDescriptor<AuthSession>()
```

#### Between sequential loops and mutations

Each `for` loop, `.removeAll()`, or mutation block is separated by a blank line.

```swift
// ✅
for continuation in continuations.values {
    continuation.finish()
}

for key in subscriptions.keys {
    pusher.unsubscribe(channelName(key))
}

continuations.removeAll()
subscriptions.removeAll()

// ❌
for continuation in continuations.values {
    continuation.finish()
}
for key in subscriptions.keys {
    pusher.unsubscribe(channelName(key))
}
continuations.removeAll()
subscriptions.removeAll()
```

#### Inside `Task` and `do` blocks

Phase separation applies inside closures and `do` blocks too.

```swift
// ✅
loadTask = Task { [weak self] in
    guard let self else { return }

    isLoading = true
    error = nil

    defer { isLoading = false }

    do {
        let (config, settings) = try await fetcher.fetchConfiguration()

        appConfig = config
        globalSettings = settings
    } catch { ... }
}

// ❌ — no breathing room between phases
loadTask = Task { [weak self] in
    guard let self else { return }
    isLoading = true
    error = nil
    defer { isLoading = false }
    do {
        let (config, settings) = try await fetcher.fetchConfiguration()
        appConfig = config
        globalSettings = settings
    } catch { ... }
}
```

#### Before `return`

A `return` statement that follows assignments or a loop is preceded by a
blank line.

```swift
// ✅
var results: [Subcategory] = []

for await subcategory in group {
    if let subcategory { results.append(subcategory) }
}

return results

// ❌
var results: [Subcategory] = []
for await subcategory in group {
    if let subcategory { results.append(subcategory) }
}
return results
```

#### Trailing closure bodies

Non-trivial trailing closure bodies go on new lines — never inline.

```swift
// ✅
onTermination: { [weak self] in
    if let self { await cleanupChannelContinuation(id: id) }
}

// ❌
onTermination: { [weak self] in if let self { await cleanupChannelContinuation(id: id) } }
```

---

### Array literals — one element per line

Multi-element array literals always have one element per line. Never pack
multiple elements onto a single line in a multi-line literal.

```swift
// ✅
let eventNames: [PusherEventName] = [
    .chatMessage,
    .messageDeleted,
    .subscription,
    .userBanned,
    .userUnbanned,
]

// ❌
let eventNames: [PusherEventName] = [
    .chatMessage, .messageDeleted, .subscription,
    .userBanned, .userUnbanned,
]
```

---

### Property declaration order in structs

Within a `struct`, properties are ordered:

1. `@propertyWrapper` / decorated properties (grouped together)
2. Plain `let` stored properties (grouped together)
3. Nested types and `enum CodingKeys` last

A blank line separates each group.

```swift
// ✅
private struct APIChannel: Decodable {
    @LossyDecoding<Default.False> var isLive: Bool
    @LossyDecoding<Default.Zero> var followersCount: Int

    let id: Int
    let slug: String
    let user: APIUser?
    let verified: APIVerified?

    enum CodingKeys: String, CodingKey {
        case id, slug, user, verified, isLive
        case followersCount = "followers_count"
    }
}

// ❌ — decorated and plain properties mixed together
private struct APIChannel: Decodable {
    let id: Int
    let slug: String
    @LossyDecoding<Default.False> var isLive: Bool
    @LossyDecoding<Default.Zero> var followersCount: Int
    let user: APIUser?
}
```

---

### Phase separation inside closure literals and static initialisers

The vertical whitespace rules apply inside `= { }` blocks, static computed
properties, and any closure used as an initialiser. Each configuration phase
is separated by a blank line.

```swift
// ✅
static let shared: JSONDecoder = {
    let decoder = JSONDecoder()

    decoder.keyDecodingStrategy = .useDefaultKeys
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let spaceFormatter = DateFormatter()

        spaceFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        spaceFormatter.timeZone = TimeZone(identifier: "UTC")

        if let date = spaceFormatter.date(from: string) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = iso.date(from: string) { return date }

        throw DecodingError.dataCorruptedError(...)
    }
    return decoder
}()

// ❌ — no breathing room between phases
static let shared: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .useDefaultKeys
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        let spaceFormatter = DateFormatter()
        spaceFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        spaceFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = spaceFormatter.date(from: string) { return date }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        throw DecodingError.dataCorruptedError(...)
    }
    return decoder
}()
```

**Exception to the `if let` body expansion rule:** sequential try-and-return
patterns (attempting multiple parsers in order) may use the single-line
`if let x = ... { return x }` form, provided each attempt is preceded by a
blank line.

---

### Sequential `if` blocks

Each independent `if` or `if let` block is separated by a blank line, just
like `for` loops and mutations.

```swift
// ✅
if let id = previousChatroomId {
    await pusherClient.unsubscribeFromChatroomV2(id: id)
    await pusherClient.unsubscribeFromChatroomV1(id: id)
}

if let id = previousChannelId {
    await pusherClient.unsubscribeFromChannel(id: id)
}

// ❌
if let id = previousChatroomId {
    await pusherClient.unsubscribeFromChatroomV2(id: id)
    await pusherClient.unsubscribeFromChatroomV1(id: id)
}
if let id = previousChannelId {
    await pusherClient.unsubscribeFromChannel(id: id)
}
```

---

### No `!` negation prefix — use explicit `== false`

Never negate a boolean with `!`. Always use `== false` for clarity.

```swift
// ✅
guard retryAttempted == false else { return }

// ❌
guard !retryAttempted else { return }
```

---

### Explicit type annotations on non-obvious bindings

When the return type of a `try await` call or a generic function is not
immediately readable from the call site, annotate the type explicitly on
the `let` binding. Never make the reader trace into a function signature
to know what they are holding.

```swift
// ✅
let response: PaginatedResponse<Article> = try await fetcher.fetch(page: nextPage)

// ❌
let response = try await fetcher.fetch(page: nextPage)
```

Apply this to any binding where the type is a generic, protocol-typed result,
or otherwise not self-evident from reading the right-hand side.

---

### Method chain formatting

Any chain of two or more method calls is broken so each call is on its own
line. The root object starts the chain on its own line.

```swift
// ✅
channels = raw.channels
    .sorted { $0.isLive && !$1.isLive }
    .compactMap(\.asDomainChannel)

categories = raw
    .categories
    .map(\.asDomainSubcategory)

// ❌
channels = raw.channels.sorted { $0.isLive && !$1.isLive }.compactMap(\.asDomainChannel)
categories = raw.categories.map(\.asDomainSubcategory)
```

Closure bodies passed to a chained call are always expanded — never inline:

```swift
// ✅
uniqueKeysWithValues: rows
    .enumerated()
    .map {
        ($0.element.categoryName, $0.offset)
    },

// ❌
uniqueKeysWithValues: rows.enumerated().map { ($0.element.categoryName, $0.offset) },
```

Each assignment that follows a chain is separated from the next by a blank line.

## Determinism - Swift code quality is deterministic. It produces the same output every time for the same input. It does not rely on any external state, random seeds, or non-deterministic processes. The same code will always yield the same result.

### Stored `Task` handles must be cancelled before replacement

Any `var loadTask: Task<Void, Never>?` must be cancelled before being
reassigned. Replacing without cancelling causes two concurrent tasks
mutating the same state.

```swift
// ✅
func load() {
    loadTask?.cancel()
    loadTask = Task { ... }
}

// ❌
func load() {
    loadTask = Task { ... }  // previous task still running
}
```

---

### Fire-and-forget `Task { }` requires a comment

A `Task { }` whose handle is not stored is fire-and-forget — it cannot be
cancelled and has no defined lifetime. This is sometimes correct (e.g. a
one-shot side effect), but must always be documented.

```swift
// ✅
// One-shot: fires on appear, no cancellation needed — view owns its lifetime.
Task { await analytics.trackImpression(id: channelId) }

// ❌
Task { await analytics.trackImpression(id: channelId) }
```

If you find yourself writing more than one fire-and-forget `Task { }` in a
type, reconsider whether the task lifetime should be managed explicitly.

---

### No `Task.detached` without justification

`Task.detached` inherits no actor context and no task-local values. It is
rarely correct. If you write `Task.detached`, you must add a comment
explaining why neither `Task { }` nor `async let` satisfies the requirement.

```swift
// ❌ — almost always wrong
Task.detached {
    await self.loadData()
}

// ✅ — only when you explicitly need to escape actor context, with comment
// Detached: this work must not inherit the @MainActor context of the caller
// because it performs blocking I/O on a background thread pool.
Task.detached(priority: .background) {
    await self.performBlockingExport()
}
```

---

### No `DispatchQueue` in new code

`DispatchQueue` is forbidden in new Swift code. Use structured concurrency.

```swift
// ❌
DispatchQueue.main.async { self.isLoading = false }
DispatchQueue.global().async { self.processData() }

// ✅
await MainActor.run { isLoading = false }
Task { await processData() }
```

---

### `AsyncStream` continuations must be stored and terminated

A continuation that is never finished leaks the stream and hangs any
`for await` consumer. Always store the continuation and call `finish()` in
a terminal path.

```swift
// ✅
private var continuation: AsyncStream.Continuation?

func stream() -> AsyncStream {
    AsyncStream { continuation in
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            self?.continuation = nil
        }
    }
}

func tearDown() {
    continuation?.finish()
    continuation = nil
}

// ❌ — continuation stored nowhere, stream never finishes
func stream() -> AsyncStream {
    AsyncStream { continuation in
        self.continuation = continuation  // where is finish() called?
    }
}
```

---

### `withTaskGroup` — never assume result order

`withTaskGroup` delivers child task results in completion order, not
submission order. If order matters, tag results with an index and sort
after collection.

```swift
// ✅
let results: [Result] = await withTaskGroup(of: (Int, Result).self) { group in
    for (index, id) in ids.enumerated() {
        group.addTask { (index, await fetch(id)) }
    }
    var ordered = [(Int, Result)]()
    for await pair in group { ordered.append(pair) }
    return ordered
        .sorted { $0.0 < $1.0 }
        .map(\.1)
}

// ❌ — assumes results arrive in submission order
var results: [Result] = []
await withTaskGroup(of: Result.self) { group in
    for id in ids { group.addTask { await fetch(id) } }
    for await result in group { results.append(result) }
}
```

---

### `@Observable` state mutated only from `@MainActor`

An `@MainActor @Observable` service must only have its stored properties
mutated from `@MainActor` context. Mutating from an unstructured `Task`
that re-enters the actor through a non-isolated path introduces races.

```swift
// ✅ — mutation is always on the actor
@MainActor @Observable
final class FeedService {
    private(set) var items: [Item] = []

    func load() {
        Task {
            let fetched = try await fetcher.fetchItems()
            items = fetched  // we are still on @MainActor here
        }
    }
}

// ❌ — mutation from an escaped context
Task.detached {
    let fetched = try? await self.fetcher.fetchItems()
    self.items = fetched ?? []  // race: which thread is this on?
}
```

---

### Magic numbers and magic strings

Literals with semantic meaning are never written inline. Extract to a named
`private` constant in the `// MARK: - Constants` section of the type.

```swift
// ✅
private enum Constants {
    static let minQueryLength = 3
}

guard query.count >= Constants.minQueryLength else { return }

// ❌
guard query.count >= 3 else { return }
```

---

### `Task.sleep` must be documented

Every `Task.sleep` call requires a comment explaining why the delay exists
and confirming it does not block the main thread.

```swift
// ✅
// Brief pause to allow the UI to settle before fetching — non-blocking, runs off main thread.
try? await Task.sleep(for: .milliseconds(300))

// ❌
try? await Task.sleep(for: .milliseconds(300))
```

---

### `static func` not `class func` in extensions

Use `static func` in extensions. `class func` implies subclass override
intent, which is meaningless in extensions on concrete types.

```swift
// ✅
static func animatedImage(with data: Data) -> UIImage? { ... }

// ❌
class func animatedImage(with data: Data) -> UIImage? { ... }
```

---

### `if let` with early return — expand the body

Single-line `if let { return }` is only acceptable for `guard`. For `if let`
with a `return` inside, always expand to a full block.

```swift
// ✅
if let animated = UIImage.animatedImage(with: data) {
    return animated
}

if let image = UIImage(data: data) {
    return image
}

// ❌
if let animated = UIImage.animatedImage(with: data) { return animated }
if let image = UIImage(data: data) { return image }
```

---

### No abbreviations in private helpers

Private helper names follow the same full-word naming rules as public API.
No abbreviated names even for "obvious" math utilities.

```swift
// ✅
private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int
private static func greatestCommonDivisor(for array: [Int]) -> Int

// ❌
private static func gcd(_ a: Int, _ b: Int) -> Int
private static func gcdForArray(_ array: [Int]) -> Int
```

---

### No computed property forwarding in views

Views never redeclare computed properties that simply forward to a dependency.
Use the dependency's property directly at the call site.

```swift
// ❌ — pointless indirection, bloats the view
private var featuredService: FeaturedArticlesService { home.featuredService }
private var categoryService: CategoryRowService { home.categoryService }

// Use in view body:
FeaturedArticlesView(service: featuredService)
CategoryRowView(service: categoryService)

// ✅ — use the dependency directly
FeaturedArticlesView(service: home.featuredService)
CategoryRowView(service: home.categoryService)
```

This applies regardless of how many forwarding properties exist. Ten forwarding
properties is ten times worse than one — do not accumulate them.

---

### No variable shadowing

Never reuse a name already in scope. Choose a distinct, descriptive name.

```swift
// ✅
let frameRepeatCount = delays[index] / divisor
frames.append(contentsOf: repeatElement(frame, count: frameRepeatCount))

// ❌
let count = delays[i] / divisor   // shadows the outer `count`
frames.append(contentsOf: repeatElement(frame, count: count))
```

---

### `MARK` comments and file structure

Every type with more than two logical groupings of members uses `// MARK: -`
comments to divide them. The standard order for actors and classes:

```swift
struct APIClient: APIClientProtocol {

    // MARK: - Constants
    // MARK: - State
    // MARK: - Init
    // MARK: - APIClientProtocol  (public API)
    // MARK: - Private Helpers
}
```

---

### Trailing commas

Multi-line array and function argument lists always have a trailing comma on
the last element.

```swift
// ✅
let items: [URLQueryItem] = [
    URLQueryItem(name: "page", value: "\(page)"),
    URLQueryItem(name: "limit", value: "\(limit)"),
    URLQueryItem(name: "sort", value: sort),  // trailing comma
]

// ❌
let items: [URLQueryItem] = [
    URLQueryItem(name: "page", value: "\(page)"),
    URLQueryItem(name: "limit", value: "\(limit)"),
    URLQueryItem(name: "sort", value: sort)  // missing trailing comma
]
```

---

### Access control

Explicit access control is preferred over relying on defaults. Every member
that should be private is marked `private`. Every member that should be
internal (visible within the module) is left unmodified (the default).

Protocol conformances are the public surface. Everything else is `private`.

```swift
// ✅
struct APIClient: APIClientProtocol {
    private let urlSession: URLSession

    func fetchArticle(id: String) async throws -> Article { ... }  // internal, satisfies protocol

    private func buildRequest(...) throws -> URLRequest { ... }
    private func execute(...) async throws -> Data { ... }
    private nonisolated func decode<T: Decodable>(...) throws -> T { ... }
}
```

---

### Documentation comments

Public and internal protocol-satisfying methods have documentation comments
using `///` format. Never `/** ... */`.

```swift
/// Fetches the full channel detail for the given slug.
///
/// - Parameter slug: The channel's URL slug (e.g. "whatever").
/// - Returns: A fully decoded `Channel` including playback URL and chatroom ID.
/// - Throws: `KickError.httpError` for non-2xx responses,
///   `KickError.decodingFailed` if the response cannot be decoded.
func fetchChannel(slug: String) async throws -> Channel
```

Private helpers do not require documentation comments but should have a
single-line `//` comment explaining why they exist if the name alone is
insufficient.

---

### Column limit

100 characters per line. Long function signatures are wrapped with each
parameter on its own line, indented +2:

```swift
// ✅
func fetchArticles(
    page: Int,
    limit: Int,
    sort: String = "featured",
    category: String? = nil
) async throws -> PaginatedResponse<Article>
```

---

### Attributes

Parameterized attributes on their own line. Short attributes (`private`,
`nonisolated`) on the same line as the declaration.

```swift
// ✅
@available(tvOS 17, *)
func newFeature() { ... }

private nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
```

---

## APIClient — canonical rewrite pattern

The `APIClient` struct is the primary example of what clean looks like for
this codebase. Use this as the reference pattern for any type that makes
network requests. It is a `struct` — not an `actor` — because it holds only
`let` constants and has no shared mutable state to protect.

See also: `references/api-client-canonical-example.md` for the full annotated version.

```swift
struct APIClient: APIClientProtocol {

    // MARK: - Constants

    private enum Host {
        static let api = "api.example.com"
        static let config = "config.example.com"
    }

    private static let userAgent = "MyApp/1 CFNetwork/3860 Darwin/25.0.0"

    // MARK: - State

    private let urlSession: URLSession

    // MARK: - Init

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - APIClientProtocol

    /// Fetches the app configuration used for build version gating.
    func fetchAppConfig() async throws -> AppConfig {
        try await fetch(host: Host.config, path: "/config.json")
    }

    /// Fetches global server-driven settings such as feature flags.
    func fetchGlobalSettings() async throws -> GlobalSettings {
        try await fetch(host: Host.api, path: "/api/settings/global")
    }

    /// Fetches a paginated list of articles, optionally filtered.
    ///
    /// - Parameters:
    ///   - page: The page number to fetch (1-indexed).
    ///   - limit: The number of results per page.
    ///   - sort: The sort order. Defaults to `"featured"`.
    ///   - category: An optional top-level category filter.
    func fetchArticles(
        page: Int,
        limit: Int,
        sort: String = "featured",
        category: String? = nil
    ) async throws -> PaginatedResponse<Article> {
        var items = baseQueryItems(page: page, limit: limit, sort: sort)
        if let category { items.append(URLQueryItem(name: "category", value: category)) }
        return try await fetch(host: Host.api, path: "/articles", queryItems: items)
    }

    // MARK: - Private Helpers

    private func fetch<T: Decodable>(
        host: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let request = try buildRequest(host: host, path: path, queryItems: queryItems)
        let data = try await execute(request)
        return try decode(T.self, from: data)
    }

    private func buildRequest(
        host: String,
        path: String,
        queryItems: [URLQueryItem]
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            throw APIError.mapURLError(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.httpError(statusCode: http.statusCode)
        }
        return data
    }

    private nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try ModelDecoder.make().decode(type, from: data)
        } catch {
            throw APIError.decodingFailed(context: error.localizedDescription)
        }
    }

    private func baseQueryItems(page: Int, limit: Int, sort: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sort", value: sort),
        ]
    }
}
```

---

## Verification

After every rewrite:

```bash
# Build must be clean — substitute your scheme and destination
xcodebuild build \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  2>&1 | grep -E "error:|warning:|BUILD"

# Tests must still pass
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  2>&1 | grep -E "Test.*passed|Test.*failed|error:|warning:|BUILD"
```

Zero errors. Zero warnings. All tests passing.