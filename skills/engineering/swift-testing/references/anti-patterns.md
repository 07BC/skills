# Swift Testing — anti-patterns

Patterns that compile, often pass, and verify nothing useful. Each one has fired in real KickTV / Escape work; the fix in every case is to write a test that would actually fail if the implementation was broken.

Read this alongside the "Avoid Tautological Tests" section in `SKILL.md`. That section covers tests that assert what was just set. This file covers four further patterns the skill body does not address.

## Anti-pattern: parallel-setup tests

A test that builds its own copy of the SUT's collaborators, mutates them, then asserts on its own mutations. The test passes — but it tests the *collaborator*, not the SUT.

### Example (real, from Story 01b)

The spec said: "preview factory seeds one `LoanDetails` and two `Scenario` rows."

The test that "covered" it:

```swift
// ❌ Tests SwiftData, not ScenarioService.preview
@Test("Preview factory seeds expected rows")
func previewFactorySeedsExpectedRows() async throws {
    let container = try ModelStack.makePreviewContainer()
    container.mainContext.insert(LoanDetails(...))   // test's own insert
    container.mainContext.insert(Scenario(...))      // test's own insert
    container.mainContext.insert(Scenario(...))      // test's own insert

    let loans = try container.mainContext.fetch(FetchDescriptor<LoanDetails>())
    #expect(loans.count == 1)
}
```

The test passes. The `ScenarioService.preview` seeding code path is **never exercised**. If the production seeding broke, the test would still pass.

### The fix

Fetch from the SUT's own state:

```swift
// ✅ Tests the factory's actual seed code path
@Test("Preview factory seeds expected rows")
func previewFactorySeedsExpectedRows() async throws {
    let service = await ScenarioService.previewForTesting()  // explicit construction
    let loans = try await service.fetchLoanDetails()
    let scenarios = try await service.fetchScenarios()
    #expect(loans.count == 1)
    #expect(scenarios.count == 2)
}
```

The test now exercises the production seeding code. If the seed contract changes, the test fails.

### The diagnostic question

Before committing a test, ask: **"If I deleted the SUT's implementation and left only its public surface, would this test still pass?"** If yes, the test is parallel-setup. Rewrite it so the SUT's implementation is on the path the test exercises.

## Anti-pattern: weaker-after-crash

When a test traps at runtime and the engineer "fixes" it by rewriting the assertion to something the SUT trivially satisfies, the test passes but the original contract is no longer tested. This is **silent coverage loss** — the test file still has a green check next to the relevant `@Test`, but the acceptance criterion it claimed to cover is unverified.

### Example (real, from Story 01b)

Original test, mapping to acceptance criterion A7 ("preview factory seeds 1 `LoanDetails` + 2 `Scenarios`"):

```swift
// Original — traps with MainActor.assumeIsolated under Swift 6
@Test("Preview service seeds the expected rows")
func previewServiceSeeds() async throws {
    let service = ScenarioService.preview   // TRAP
    let loans = try service.modelContext.fetch(FetchDescriptor<LoanDetails>())
    #expect(loans.count == 1)
}
```

After 1 hour 55 minutes of debugging, "fixed" to:

```swift
// ❌ Compiles, passes, asserts nothing useful
@Test("Preview service seeds the expected rows")
func previewServiceSeeds() async throws {
    let first = ScenarioService.preview
    let second = ScenarioService.preview
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
    #expect(Route.loanInput != Route.comparison)
    #expect(Route.scenario(slot: .a) != Route.scenario(slot: .b))
}

// ❌ Exhaustive switch is compiler-enforced. If a case were missing, the file
//    would not compile.
@Test("Route exhaustively handles all cases")
func routeHandlesAllCases() async throws {
    for route in [Route.loanInput, .comparison, .scenario(slot: .a)] {
        let view = RouteView(route: route)
        #expect(view != nil)  // construction never fails for these types
    }
}

// ❌ Type conformance. If it didn't conform, the file would not compile.
@Test("Service conforms to ScenarioServicing")
func conformsToProtocol() async throws {
    let sut = ScenarioService(...)
    #expect(sut is ScenarioServicing)
}
```

### When testing enums and conformances is actually justified

Only test behaviour the compiler **cannot** catch:

```swift
// ✅ Decoding from external input — the JSON shape is not compiler-checked.
@Test("Route decodes from URL path")
func decodesFromURL() async throws {
    let route = try Route(url: URL(string: "/scenario/a")!)
    #expect(route == .scenario(slot: .a))
}

// ✅ Switch dispatch side effects — the right branch ran, with the right output.
@Test("Router navigates to ScenarioView for .scenario route")
func navigatesToScenario() async throws {
    let router = MockRouter()  // actor
    let coordinator = Coordinator(router: router)

    await coordinator.handle(.scenario(slot: .a))

    let pushed = await router.lastPushedView
    #expect(pushed == .scenarioView(slot: .a))
}

// ✅ Custom Equatable/Hashable (not synthesised).
@Test("Money equality ignores currency formatting")
func moneyEquality() async throws {
    #expect(Money(amount: "10.00", currency: .aud) == Money(amount: "10.0", currency: .aud))
}
```

The signal is: **the test would fail if the implementation regressed**. If you can delete the implementation and the test still passes (because the compiler enforces the property), the test is not earning its keep.

## Anti-pattern: `Decimal` float literal

`Decimal` conforms to `ExpressibleByFloatLiteral` via `Double`. A literal like `let x: Decimal = 0.0625` silently routes through `Double`, which violates the "no `Double` in monetary code" rule and introduces floating-point representation errors.

### Examples

```swift
// ❌ Routes through Double — representation error, violates "no Double" rule.
let rate: Decimal = 0.0625
let loan = LoanDetails(annualRate: 0.0625)   // same trap

// ✅ String initialiser — exact representation, compiler-checked.
let rate: Decimal = Decimal(string: "0.0625") ?? 0
let loan = LoanDetails(annualRate: Decimal(string: "0.0625") ?? 0)

// ✅ Integer-based construction when applicable.
let rate = Decimal(625) / Decimal(10_000)
```

### Why this lands in the testing skill

Tests for monetary code routinely set up fixtures with literal rates and amounts. The `Decimal = 0.0625` form will:

1. Pass compilation.
2. Produce a `Decimal` whose representation matches `Double(0.0625)` — not the exact decimal `0.0625`.
3. Cause arithmetic comparisons in the test to fail in unexpected places (`#expect(result == 0.1875)` when the result is `0.1875000000000001`).
4. Or worse — pass, but only because both sides of the comparison share the same `Double`-routed error.

The fix is `Decimal(string:)` in both production and test code. The test fixture should match the production constructor; if production uses `Decimal(string:)`, the test must use `Decimal(string:)`.

### Detecting this in review

Search the test diff for `Decimal\s*=\s*\d+\.\d+` or `annualRate:\s*\d+\.\d+` (where the parameter type is `Decimal`). Both are smells.
