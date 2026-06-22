---
name: swift-code-review
description: >
  REVIEWS existing Swift/SwiftUI code — outputs BLOCKER / WARNING / SUGGESTION
  findings with inline fixes. Two modes: (1) standard in-session diff review
  before commit/PR; (2) adversarial deep mode — a ruthless senior pre-PR pass
  against target architecture, third-party SDK contracts, lifecycle/cleanup, and
  test coverage, producing a prioritised Critical/High/Medium/Low findings doc
  for high-stakes branches (new SDK, infra, lifecycle changes). Loads
  swift-engineering, swift-style, swift-testing, swift-concurrency. Do NOT use for
  writing or rewriting code — use swift-engineering. For a whole-codebase
  architecture audit, use /audit. For a reusable hand-off review
  prompt, use prompt:review.
---

# Swift Code Review

Required dependency skills (must be present in ~/.claude/skills/):
- `swift-engineering`
- `swift-style`
- `swift-testing`
- `swift-concurrency`

Load these skills first, then apply every checklist item below:

- Read skill swift-engineering
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
- [ ] No `///` doc comments — well-named identifiers replace them (per `swift-engineering` Core Principle #1)
- [ ] No `/** */` block comments
- [ ] No inline `//` comments unless the WHY is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug)
- [ ] `MARK: -` sections used for types with more than two logical groupings

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

---

## Deep / Adversarial Mode

Use deep mode for **high-stakes branches**: a new third-party SDK, infrastructure layer code, lifecycle/cleanup changes, or any branch where you need a ruthless second pass before raising the PR.

**When to use deep mode:** "deep PR review", "senior PR review", "ruthless review", "pre-PR audit", "audit my PR", "find every defect", or when the branch introduces a new SDK / infra / lifecycle changes.

**Output:** a prioritised findings document written to:
```
${HOME}/Developer/obsidian/$(basename $(git rev-parse --show-toplevel))/plans/<slug>-pr-review-findings.md
```

Standard BLOCKER/WARNING/SUGGESTION still applies for the diff; deep mode adds the adversarial checklist below and produces a Critical/High/Medium/Low classification.

### Step 0 — Pre-flight

```bash
BASE="${BASE:-main}"
git fetch origin "$BASE" --quiet 2>/dev/null || true
git diff --name-only "origin/${BASE}...HEAD" > /tmp/pre-pr-files.txt
git diff "origin/${BASE}...HEAD" > /tmp/pre-pr-diff.patch
```

Read every touched file AND every authority doc (`docs/MV target architecture/*.md`, `docs/MVVM target architecture/*.md`, `docs/adr/*.md`, `CLAUDE.md`, `CONTEXT.md`) before writing any finding.

For every new external SDK: fetch the SDK's integration guide via Context7 MCP; read the framework headers in DerivedData to confirm property names, init signatures, and threading contracts.

Call `advisor()` once with your touched-file list, authority docs read, and SDK contracts — let the advisor validate your architectural interpretation before producing findings.

### Adversarial checklist

**1. Third-party SDK correctness** — required fields populated, property names vs init param names confirmed against headers, unit/encoding correctness, lifecycle ordering, identifier reuse, threading contracts.

**2. Layer/architecture alignment** — no domain protocol returning infrastructure types, no infrastructure importing presentation, mocks `#if DEBUG`-gated, `@Entry` used for environment values, composition root correct, new `@Observable` types `@MainActor`. The observable layer matches the project's declared architecture: services (MV, per `swift-mv-architecture`) or ViewModels + stateless Repositories (MVVM, per `swift-mvvm-architecture`); no `ObservableObject`/`@Published`; no ViewModels in `@Environment` (MVVM); no ViewModel-named types (MV).

**3. Concurrency and Sendable** — types crossing isolation boundaries have explicit `Sendable`, mutable shared state actor-isolated or `@MainActor`, `dispatchPrecondition` not called from background Task, strict concurrency compiles clean.

**4. Session and lifecycle completeness** — enumerate every code path where the session must end (user exit, view dismissal, error, network failure, deinit, app backgrounding); verify cleanup at each; idempotent stop/cancel; bounded dictionary growth.

**5. Edge cases not covered by tests** — empty/nil inputs, all-nil metadata, background→foreground mid-session, rapid repeated state changes, orphaned session id, operation after deallocation, two concurrent sessions.

**6. Test quality** — mocks in correct location, Swift Testing used, descriptive `@Test` strings, `@Suite` tags, no tautological tests, call sequence asserted not just call count.

**7. Configuration and operational gaps** — env vars set in all CI workflows, SDK keys differ across dev/staging/prod, new engineers can onboard from docs alone.

**8. Code quality (if not already flagged by standard pass)** — default params that silently restore deleted behaviour, `class` where `struct` suffices, long-lived services holding strong view references.

### Findings document structure

```markdown
# <Project/Ticket> — Senior Pre-PR Review

## Context
Verdict: <DO NOT MERGE / MERGE WITH FOLLOW-UPS / READY TO MERGE>

## Critical (must fix before merge)
### [C1] Title
**File:** path:lines — **Issue:** one sentence — **Impact:** production consequence — **Fix:** exact fix

## High / Medium / Low ...

## Missing tests (required before merge)

## Things the existing implementation gets right
```

**Rules:** every finding cites file + line range; severity reflects production impact, not taste; be exhaustive.
