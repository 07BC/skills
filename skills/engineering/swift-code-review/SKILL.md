---
name: swift-code-review
description: **Performs** a Swift code review in this session — outputs BLOCKER / WARNING / SUGGESTION findings with inline fixes. Loads swift-engineer, swift-style, swift-testing, and swift-concurrency, then applies a concrete pass/fail checklist. Use before committing, raising a PR, or verifying a feature is complete. If the user instead wants a reusable review prompt to hand off to another session, use prompt:review. Routing scope — fires for standalone Swift code review work (one-off edits, single-file reviews, quick fixes, ad-hoc questions). For full-feature work driven from a Jira ticket or a multi-task spec, defer to spec-pipeline which runs the engineer / test-writer / concurrency-auditor / task-reviewer sub-agents in a worktree.
---

# Swift Code Review

> **Source of truth for Swift code review in every context.** Other agents
> (including spec-pipeline's engineer, test-writer, concurrency-auditor, and
> task-reviewer sub-agents) read this body as authority — even when this
> skill itself does not auto-fire. Any routing scope declared elsewhere
> governs only when this skill auto-fires on a human message; it does not
> gate sub-agent referencing.

## Scope

This skill is for **standalone** Swift code review work — single-file edits, quick reviews, ad-hoc review. It is **not** the path for full-feature implementation driven from a Jira ticket or multi-task spec. For that, the `spec-pipeline` skill runs the engineer / test-writer / concurrency-auditor / task-reviewer sub-agents in a worktree and produces a PR end-to-end. Defer to `spec-pipeline` when:

- the user names a Jira ticket (e.g. NAT-1234) and asks to ship it,
- the user says "run the pipeline", "ship this", or "/jls:spec-pipeline …",
- the work spans more than one Swift file and includes design + tests + review.

If the work is one file, one function, one review pass, or a question — this skill is the right home.

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

### Documentation
- [ ] All public and internal protocol-satisfying methods have `///` documentation
- [ ] `///` format used — never `/** */` block comments
- [ ] Parameters, return values, and throws are documented where non-obvious

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
- [ ] No `DispatchQueue.main.async` — use `await MainActor.run` or `@MainActor`
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
