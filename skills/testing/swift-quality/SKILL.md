---
name: swift-quality
description: >
  Rewrites Swift code to meet the project's Swift Style Guide standards and project
  architecture rules. Use when code feels hard to read, methods are too long,
  responsibilities are mixed, or structure is unclear. Triggers: "rewrite this",
  "clean this up", "this is hard to read", "poor structure", "refactor", or
  any time generated code looks like it was written to satisfy the compiler
  rather than a human reader.

  Scope — fires for standalone Swift refactoring work (one-off edits,
  single-file reviews, quick fixes, ad-hoc questions). For full-feature
  work driven from a Jira ticket or a multi-task spec, defer to
  spec-pipeline which runs the engineer / test-writer /
  concurrency-auditor / task-reviewer sub-agents in a worktree.
---

# Swift Code Quality Skill

> **Source of truth for Swift refactoring and quality rewriting in every
> context.** Other agents (including spec-pipeline's engineer, test-writer,
> concurrency-auditor, and task-reviewer sub-agents) read this body as
> authority — even when this skill itself does not auto-fire. Any routing
> scope declared elsewhere governs only when this skill auto-fires on a human
> message; it does not gate sub-agent referencing.

## Scope

This skill is for **standalone** Swift refactoring work — single-file edits, quick reviews, ad-hoc rewrite. It is **not** the path for full-feature implementation driven from a Jira ticket or multi-task spec. For that, the `spec-pipeline` skill runs the engineer / test-writer / concurrency-auditor / task-reviewer sub-agents in a worktree and produces a PR end-to-end. Defer to `spec-pipeline` when:

- the user names a Jira ticket (e.g. NAT-1234) and asks to ship it,
- the user says "run the pipeline", "ship this", or "/jls:spec-pipeline …",
- the work spans more than one Swift file and includes design + tests + review.

If the work is one file, one function, one review pass, or a question — this skill is the right home.

This skill rewrites Swift code to be clean, readable, and structurally correct
according to the Google Swift Style Guide and this project's architecture rules.
It does not change behaviour. It does not change public API surfaces or protocol
conformances. It only improves structure, naming, and readability.

**Scope boundary.** This skill *rewrites* — it does not flag issues or output
severities. If you need diagnosis (BLOCKER / WARNING / SUGGESTION findings
with file:line citations), use `swift-code-review` instead. If you need an
exhaustive multi-section report, use `swift-audit`.

---

## Authority

The Google Swift Style Guide is the primary authority:
https://google.github.io/swift/

Apple's API Design Guidelines are incorporated by reference.

Project architecture rules in any `docs/` architecture doc and `CLAUDE.md`
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
static let appConfigBaseURL = "https://kick-app-config.kick.com"

// ❌
static let kAppConfigBaseURL = "https://kick-app-config.kick.com"
static let APP_CONFIG_BASE_URL = "https://kick-app-config.kick.com"
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
// KickTV/Domain/Models/TokenResponse.swift
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
let result = try JSONDecoder().decode(Stream.self, from: data)

// ✅
let result = try decode(Stream.self, from: data)
```

---

### No inline URL construction

`URLRequest` is never constructed inline in a method body. Always use the
shared `buildRequest(host:path:queryItems:)` builder.

```swift
// ❌ — URL construction scattered through method body
var components = URLComponents(string: baseURL + path)
if !queryItems.isEmpty { components?.queryItems = queryItems }
guard let url = components?.url else { throw KickError.invalidURL(path) }
var urlRequest = URLRequest(url: url)
urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

// ✅ — single named builder
let request = try buildRequest(host: "kick.com", path: path, queryItems: items)
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
let data = try? decode(Stream.self, from: raw)

// ✅
let data = try decode(Stream.self, from: raw)
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
            let response = try await client.fetchFeaturedLivestreams(page: page, limit: 32)
            featuredStreams = response.data
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
            let response = try await client.fetchFeaturedLivestreams(page: page, limit: 32)
            featuredStreams = response.data
            hasMoreFeatured = response.hasNextPage
        } catch let kickError as KickError {
            error = kickError
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

#### Context 2 — Event stream handlers (ChatService)

A single malformed event packet should not kill the stream or set
`self.error`. Skipping is acceptable, but must be explicit and documented.

```swift
// ❌ Wrong — undocumented silent skip
} catch {
    return
}

// ✅ Correct — intentional skip with documented reason
} catch {
    // A single malformed event does not affect stream health.
    // Do not surface to the view — log in debug builds only.
    #if DEBUG
    print("[ChatService] Failed to decode event payload: \(error)")
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
let response: PaginatedResponse<Stream> = try await fetcher.fetch(page: nextPage)

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
private var featuredService: HomeFeaturedStreamsService { home.featuredService }
private var valorantService: HomeSubcategoryRowService { home.valorantService }

// Use in view body:
HomeFeaturedView(service: featuredService)
HomeSubcategoryRowView(service: valorantService)

// ✅ — use the dependency directly
HomeFeaturedView(service: home.featuredService)
HomeSubcategoryRowView(service: home.valorantService)
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
comments to divide them. The standard order for structs and classes:

```swift
struct KickAPIClient: KickAPIClientProtocol {

    // MARK: - Constants
    // MARK: - State
    // MARK: - Init
    // MARK: - KickAPIClientProtocol  (public API)
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
struct KickAPIClient: KickAPIClientProtocol {
    private let urlSession: URLSession

    func fetchChannel(slug: String) async throws -> Channel { ... }  // internal, satisfies protocol

    private func buildRequest(...) throws -> URLRequest { ... }
    private func execute(...) async throws -> Data { ... }
    private func decode<T: Decodable>(...) throws -> T { ... }
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
func fetchLivestreams(
    page: Int,
    limit: Int,
    sort: String = "featured",
    category: String? = nil,
    subcategory: String? = nil
) async throws -> PaginatedResponse<Stream>
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

## Canonical API client shape

For any type that performs network requests, follow this shape:

- A `struct` (not an `actor`) when the type holds only immutable `let` state.
  `async` functions already hop off the main thread; an actor would add
  serialisation without protecting any mutable state.
- One small responsibility per private helper: build the request, execute it,
  decode the response. Each helper stays under ~20 lines.
- No inline `URLRequest` construction, no inline `JSONDecoder()` — both go
  through shared, named helpers.
- Errors propagate as a typed error enum; never `try?`, never silent catches.
- MARK ordering: `Constants → State → Init → Protocol conformance → Private Helpers`.

For a full worked example, see
[`references/kick-canonical-example.md`](references/kick-canonical-example.md)
(Kick tvOS project). Apply the **shape**, not the specific type names, when
working in other projects.

---

## Verification

After every rewrite, build and run the test suite. Read the workspace,
scheme, and destination from the project's `CLAUDE.md` (or fall back to
`xcodebuild -list` and `xcrun simctl list devices available`):

```bash
# Build must be clean — substitute <workspace>, <scheme>, <destination>
xcodebuild build \
  -workspace <workspace> \
  -scheme <scheme> \
  -destination '<destination>' \
  2>&1 | grep -E "error:|warning:|BUILD"

# Tests must still pass
xcodebuild test \
  -workspace <workspace> \
  -scheme <scheme> \
  -destination '<destination>' \
  2>&1 | grep -E "Test.*passed|Test.*failed|error:|warning:|BUILD"
```

Prefer the `swift-test-all` skill — it already resolves the workspace,
scheme, and destination from `CLAUDE.md` and skips UI test targets safely.

Zero errors. Zero warnings. All tests passing.