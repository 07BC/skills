# Swift Testing — anti-patterns

Patterns that compile, often pass, and verify nothing useful. Each one has fired in real-world Swift projects; the fix in every case is to write a test that would actually fail if the implementation was broken.

Read this alongside the "Avoid Tautological Tests" section in `SKILL.md`. That section covers tests that assert what was just set. This file covers several further patterns the skill body does not address.

## Anti-pattern: parallel-setup tests

A test that builds its own copy of the SUT's collaborators, mutates them, then asserts on its own mutations. The test passes — but it tests the *collaborator*, not the SUT.

### Example (real, from Story 01b)

The spec said: "preview factory seeds one `ArticleList` and two `Article` rows."

The test that "covered" it:

```swift
// ❌ Tests SwiftData, not ArticleService.preview
@Test("Preview factory seeds expected rows")
func previewFactorySeedsExpectedRows() async throws {
    let container = try ModelStack.makePreviewContainer()
    container.mainContext.insert(ArticleList(...))   // test's own insert
    container.mainContext.insert(Article(...))       // test's own insert
    container.mainContext.insert(Article(...))       // test's own insert

    let lists = try container.mainContext.fetch(FetchDescriptor<ArticleList>())
    #expect(lists.count == 1)
}
```

The test passes. The `ArticleService.preview` seeding code path is **never exercised**. If the production seeding broke, the test would still pass.

### The fix

Fetch from the SUT's own state:

```swift
// ✅ Tests the factory's actual seed code path
@Test("Preview factory seeds expected rows")
func previewFactorySeedsExpectedRows() async throws {
    let service = await ArticleService.previewForTesting()  // explicit construction
    let lists = try await service.fetchArticleLists()
    let articles = try await service.fetchArticles()
    #expect(lists.count == 1)
    #expect(articles.count == 2)
}
```

The test now exercises the production seeding code. If the seed contract changes, the test fails.

### The diagnostic question

Before committing a test, ask: **"If I deleted the SUT's implementation and left only its public surface, would this test still pass?"** If yes, the test is parallel-setup. Rewrite it so the SUT's implementation is on the path the test exercises.

## Anti-pattern: weaker-after-crash

When a test traps at runtime and the engineer "fixes" it by rewriting the assertion to something the SUT trivially satisfies, the test passes but the original contract is no longer tested. This is **silent coverage loss** — the test file still has a green check next to the relevant `@Test`, but the acceptance criterion it claimed to cover is unverified.

### Example (real, from Story 01b)

Original test, mapping to acceptance criterion A7 ("preview factory seeds 1 `ArticleList` + 2 `Articles`"):

```swift
// Original — traps with MainActor.assumeIsolated under Swift 6
@Test("Preview service seeds the expected rows")
func previewServiceSeeds() async throws {
    let service = ArticleService.preview   // TRAP
    let lists = try service.modelContext.fetch(FetchDescriptor<ArticleList>())
    #expect(lists.count == 1)
}
```

After 1 hour 55 minutes of debugging, "fixed" to:

```swift
// ❌ Compiles, passes, asserts nothing useful
@Test("Preview service seeds the expected rows")
func previewServiceSeeds() async throws {
    let first = ArticleService.preview
    let second = ArticleService.preview
    #expect(first !== second)   // most factories satisfy this trivially
}
```

The test passes. A7 is no longer tested.

### The fix

If a test traps, the response is **one of two things**:

1. Change the test setup so the trap doesn't fire, while keeping the same assertion contract (see `references/isolation.md` for the `MainActor.assumeIsolated` case specifically).
2. Escalate. The SUT may need to change to be testable, or the spec may need clarification.

**Do not weaken the assertion.** A test that asserts a trivial property no longer maps to the acceptance criterion it claims to cover.

### The crash budget rule

`SKILL.md` enforces a 5-minute crash budget. If you cannot fix the trap while keeping the assertion contract intact in 5 minutes, **stop and escalate** with the failing trace. Do not commit a weaker assertion to make the suite go green.

## Anti-pattern: testing compiler-enforced behaviour

If the type system already enforces a property, a runtime test adds no signal — it just verifies the compiler.

### Examples

```swift
// ❌ Hashable conformance is compiler-synthesised. This test verifies the compiler.
@Test("Route cases are distinct")
func routeCasesAreDistinct() async throws {
    #expect(Route.home != Route.search)
    #expect(Route.articleDetail(id: "a") != Route.articleDetail(id: "b"))
}

// ❌ Exhaustive switch is compiler-enforced. If a case were missing, the file
//    would not compile.
@Test("Route exhaustively handles all cases")
func routeHandlesAllCases() async throws {
    for route in [Route.home, .search, .articleDetail(id: "x")] {
        let view = RouteView(route: route)
        #expect(view != nil)  // construction never fails for these types
    }
}

// ❌ Type conformance. If it didn't conform, the file would not compile.
@Test("Service conforms to ArticleServicing")
func conformsToProtocol() async throws {
    let sut = ArticleService(...)
    #expect(sut is ArticleServicing)
}
```

### When testing enums and conformances is actually justified

Only test behaviour the compiler **cannot** catch:

```swift
// ✅ Decoding from external input — the JSON shape is not compiler-checked.
@Test("Route decodes from URL path")
func decodesFromURL() async throws {
    let route = try Route(url: URL(string: "/articles/abc123")!)
    #expect(route == .articleDetail(id: "abc123"))
}

// ✅ Switch dispatch side effects — the right branch ran, with the right output.
@Test("Router navigates to ArticleDetailView for .articleDetail route")
func navigatesToArticleDetail() async throws {
    let router = MockRouter()  // actor
    let coordinator = Coordinator(router: router)

    await coordinator.handle(.articleDetail(id: "abc123"))

    let pushed = await router.lastPushedView
    #expect(pushed == .articleDetailView(id: "abc123"))
}

// ✅ Custom Equatable/Hashable (not synthesised).
@Test("Price equality ignores currency formatting")
func priceEquality() async throws {
    #expect(Price(amount: "10.00", currency: .aud) == Price(amount: "10.0", currency: .aud))
}
```

The signal is: **the test would fail if the implementation regressed**. If you can delete the implementation and the test still passes (because the compiler enforces the property), the test is not earning its keep.

## Anti-pattern: `Decimal` float literal

`Decimal` conforms to `ExpressibleByFloatLiteral` via `Double`. A literal like `let x: Decimal = 0.0625` silently routes through `Double`, which introduces floating-point representation errors and breaks exact-decimal arithmetic.

### Examples

```swift
// ❌ Routes through Double — representation error.
let rate: Decimal = 0.0625
let product = Product(price: 0.0625)   // same trap

// ✅ String initialiser — exact representation, compiler-checked.
let rate: Decimal = Decimal(string: "0.0625") ?? 0
let product = Product(price: Decimal(string: "0.0625") ?? 0)

// ✅ Integer-based construction when applicable.
let rate = Decimal(625) / Decimal(10_000)
```

### Why this lands in the testing skill

Tests for code using `Decimal` routinely set up fixtures with literal values. The `Decimal = 0.0625` form will:

1. Pass compilation.
2. Produce a `Decimal` whose representation matches `Double(0.0625)` — not the exact decimal `0.0625`.
3. Cause arithmetic comparisons in the test to fail in unexpected places (`#expect(result == 0.1875)` when the result is `0.1875000000000001`).
4. Or worse — pass, but only because both sides of the comparison share the same `Double`-routed error.

The fix is `Decimal(string:)` in both production and test code. The test fixture should match the production constructor; if production uses `Decimal(string:)`, the test must use `Decimal(string:)`.

### Detecting this in review

Search the test diff for `Decimal\s*=\s*\d+\.\d+` or any `Decimal`-typed parameter receiving a float literal. Both are smells.

## Anti-pattern: pass-through-mock (mock-asserts-mock)

The subtler sibling of parallel-setup. Here the test *does* go through the SUT — but it asserts a value the mock was configured to return and that the SUT forwards unchanged. The SUT runs; it just does nothing observable to the value, so the assertion verifies the stub's fixture.

```swift
// ❌ The stub returns a Profile; profile(for:) forwards it. The assertion checks
//    the fixture you wrote two lines up, not any ProfileService behaviour.
@Test("returns the profile")
func returnsProfile() async throws {
    let stub = StubProfileAPI(profile: .fixture(name: "Ada"))
    let sut = ProfileService(api: stub)
    #expect(await sut.profile(for: "1")?.name == "Ada")
}
```

### The fix

Assert something the SUT *does*, not something it *relays*:

```swift
// ✅ Assert the SUT's own transformation of the dependency's output.
@Test("composes display name from profile parts")
func composesDisplayName() async throws {
    let stub = StubProfileAPI(profile: .fixture(first: "Ada", last: "Lovelace"))
    let sut = ProfileService(api: stub)
    #expect(await sut.displayName(for: "1") == "Ada Lovelace")
}

// ✅ Or assert the call the SUT made — what it asked the dependency for.
@Test("requests the profile by the supplied id")
func requestsByID() async throws {
    let api = MockProfileAPI()          // actor recording requestedIDs
    let sut = ProfileService(api: api)
    await sut.refresh(id: "42")
    #expect(await api.requestedIDs == ["42"])
}
```

### The diagnostic question

Same as parallel-setup, sharpened: **"If I replaced the SUT method body with `return <the mock's configured value>` (or `return nil`), would this test still pass?"** If yes, you are testing the stub. Either the SUT has a transformation worth asserting, or the interesting behaviour is *which call it made* — assert that on a recorder actor.

This is a hard-stop ban in `SKILL.md`. Stateless stubs are still the right mock shape (see "Mock taxonomy"); the ban is about the *assertion*, not the mock.

## Anti-pattern: disjunctive assertion

An assertion with an `||` that includes the "not yet populated" state passes whenever the real path didn't run.

```swift
// ❌ Passes whenever videoSeries is nil — i.e. exactly when the code under test
//    failed to populate it. Asserts nothing on the path that matters.
#expect(dimensions.videoSeries == nil || dimensions.videoSeries == expectedSeries)
```

### The fix

Assert the specific value. If `nil` is a legitimate separate case, give it its own test with its own input — don't fold it into an `||`.

```swift
// ✅ Forces the populated path.
#expect(dimensions.videoSeries == expectedSeries)
```

If the strengthened assertion goes red, you've learned something real: either the production code doesn't populate the field, or the test's premise about *what* the value should be is wrong. Investigate — do not retreat to the disjunction.

## Anti-pattern: over-wide `throws: Error.self`

`#expect(throws: Error.self) { ... }` (and `#expect(throws: (any Error).self)`) passes for *any* thrown error — including one thrown for a completely different reason than the test intends (a force-unwrap trap, a precondition, an unrelated decode failure). It is the error-path equivalent of `!= nil`.

```swift
// ❌ Green even if the code throws the wrong error for the wrong reason.
#expect(throws: Error.self) { try decoder.decode(Foo.self, from: data) }

// ✅ Match the specific error type (or case) the behaviour should produce.
#expect(throws: DecodingError.self) { try decoder.decode(Foo.self, from: data) }
#expect(throws: ValidationError.empty) { try sut.validate("") }
```

`throws: Error.self` is acceptable only when the contract genuinely is "throws *something*" and the specific type is an implementation detail outside the SUT's control — rare. Default to the specific type; see `references/assertions.md`.
