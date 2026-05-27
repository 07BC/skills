---
name: swift-code-review
description: **Performs** a Swift code review in this session — outputs BLOCKER / WARNING / SUGGESTION findings with inline fixes. Loads swift-engineer, swift-style, swift-testing, and swift-concurrency, then applies a concrete pass/fail checklist. Use before committing, raising a PR, or verifying a feature is complete. If the user instead wants a reusable review prompt to hand off to another session, use prompt:review.
---

# Swift Code Review

Required dependency skills (must be present in ~/.claude/skills/):
- `swift-engineer`
- `swift-style`
- `swift-testing`
- `swift-concurrency`

Load these skills first, then apply every checklist item below:

- Read skill swift-engineer
- Read skill swift-style
- Read skill swift-testing
- Read skill swift-concurrency

Output a numbered list of issues rated **BLOCKER**, **WARNING**, or **SUGGESTION**. Include the file path and line number for each. Provide an inline fix for every BLOCKER.

---

## Severity mapping

Apply this mapping when grading a finding:

- **BLOCKER** — every item in *Correctness* and *Concurrency*, plus any
  Xcode navigator error surfaced via `mcp__xcode__XcodeListNavigatorIssues`.
- **WARNING** — *Code Quality*, *Naming*, *Structure and Organisation*, and
  *SwiftUI* violations that don't trip a Correctness rule.
- **SUGGESTION** — *Comments*, *Testing-coverage gaps*, and
  *Platform-compatibility* hints that don't overlap a higher rule.

A single finding may match more than one category; grade it at the highest
severity it matches.

---

## Checklist

### Correctness
- [ ] No force unwraps (`!`) in production code without a documented invariant
- [ ] No `try?` — errors must propagate or be explicitly caught and stored
- [ ] No `catch` block that silently returns without storing to an error property or logging
- [ ] No `fatalError` in production code
- [ ] Async operations handle cancellation (`Task.checkCancellation()` in long loops)

### Code Quality
- [ ] Every method is ≤ 20 lines. Longer methods must be extracted into named helpers
- [ ] Every function has ≤ 3 parameters. More parameters require a dedicated parameter type
- [ ] No boolean flag parameters that toggle behaviour — use separate functions or an enum
- [ ] No copy-pasted logic appearing more than twice — extract a named helper (DRY)
- [ ] Each function does one thing at one level of abstraction (single responsibility)
- [ ] Lines ≤ 100 characters. Long signatures wrapped with each parameter on its own line

### Naming (Google Swift Style Guide + API Design Guidelines)
- [ ] Types in `UpperCamelCase`; functions and properties in `lowerCamelCase`
- [ ] No Hungarian notation (`k` prefix, `g` prefix, `SCREAMING_SNAKE_CASE`)
- [ ] Boolean properties read as assertions: `isEmpty`, `isValid`, `isLoading`
- [ ] Mutating/nonmutating pairs follow verb / adjective convention: `sort()` / `sorted()`
- [ ] Call site reads as natural English: `remove(at: index)` not `remove(index)`
- [ ] No unnecessary type information in names: `userArray` → `users`, `sharedSession` → `shared`
- [ ] No boolean flag parameters that toggle between two modes

### Structure and Organisation
- [ ] `// MARK: - ` sections used for types with more than two logical groupings
- [ ] Standard MARK order: Constants → State → Init → Protocol conformance → Private Helpers
- [ ] Trailing commas on all multi-line array/dictionary/argument literals
- [ ] Explicit access control: `private` for everything not satisfying a protocol
- [ ] No inline type definitions inside function bodies
- [ ] One SwiftUI view per file — no `private struct` subviews or computed property views

### Comments and documentation
- [ ] No `///` doc comments — well-named identifiers replace them (per `swift-engineer` Core Principle #1)
- [ ] No `/** */` block comments
- [ ] No inline `//` comments unless the WHY is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug)
- [ ] `MARK: -` sections used per `swift-quality` for types with more than two logical groupings

### SwiftUI
- [ ] Views are small and focused (body ≤ 50 lines preferred)
- [ ] Logic belongs in services, not in view body
- [ ] `overlay` / `background` used instead of nested `ZStack` / `VStack` / `HStack` for layering
- [ ] `@Entry` macro used for custom environment values (iOS 18+), not the old `EnvironmentKey` pattern
- [ ] No `didSet` with side effects — use explicit setter methods instead
- [ ] All new SwiftUI components include a `#Preview`

### Concurrency (Swift 6)
- [ ] Compiles with `SWIFT_STRICT_CONCURRENCY=complete`
- [ ] `@MainActor` applied to all UI-bound types and methods
- [ ] Actors used for shared mutable state
- [ ] `Sendable` conformance on types that cross isolation boundaries
- [ ] No `DispatchQueue.main.async` — use `@MainActor`, or `await MainActor.run` only when called from a `nonisolated` context
- [ ] **BLOCKER** — `MainActor.run` inside a `Task { }` created on a `@MainActor` type. The task inherits isolation; the explicit hop is a no-op and signals a misunderstanding of Swift concurrency
- [ ] Unstructured `Task { }` used only when structured concurrency is not possible

### Testing
- [ ] Swift Testing used for all new tests (`import Testing`, `@Test`, `#expect`)
- [ ] Every `@Test` has a description string
- [ ] Every `@Suite` has a tag
- [ ] Tests follow Given / When / Then structure
- [ ] All external dependencies mocked — no real network, persistence, or hardware in unit tests
- [ ] No tautological tests (tests that always pass regardless of implementation)
- [ ] No duplicate tests covering the same code path

### iOS / Platform Compatibility
- [ ] No APIs below the project's minimum deployment target used without availability guards
- [ ] Review for both iOS 18 and iOS 26 where applicable

---

## Live Xcode Diagnostics

Before declaring PASS, call `mcp__xcode__XcodeListNavigatorIssues` to surface any errors or warnings currently visible in the Xcode navigator. These are deferred tools — load the schema first:

```
ToolSearch("select:mcp__xcode__XcodeListNavigatorIssues,mcp__xcode__XcodeRefreshCodeIssuesInFile")
```

Call `mcp__xcode__XcodeRefreshCodeIssuesInFile` on any file you edited to force a fresh diagnostic pass, then call `mcp__xcode__XcodeListNavigatorIssues` to retrieve the full issue list.

Fold any issues found into the BLOCKER / WARNING / SUGGESTION output — a navigator error is always a **BLOCKER**.
