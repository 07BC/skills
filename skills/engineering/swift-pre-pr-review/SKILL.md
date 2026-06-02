---
name: swift-pre-pr-review
description: >
  Performs a ruthless senior-engineer pre-PR review of a Swift/SwiftUI branch
  against the project's target architecture, any third-party SDK contracts the
  branch touches, concurrency rules, and test coverage — then writes a
  prioritised findings document (Critical / High / Medium / Low). Use BEFORE
  raising a PR when the branch (a) introduces a new third-party SDK, (b) adds
  infrastructure layer code, (c) changes lifecycle / cleanup semantics, or (d)
  is otherwise high-stakes and needs an adversarial second pass. Triggers on
  "deep PR review", "senior PR review", "ruthless review", "pre-PR audit",
  "audit my PR", "find every defect", "swift-pre-pr-review". Distinct from
  swift-code-review (inline BLOCKER/WARNING/SUGGESTION on a diff),
  swift-pr-gate (mechanical build/tests/scope gates), and swift-deep-audit
  (whole-codebase architecture audit).
---

# Swift Pre-PR Review

Adversarial second-pass review of a branch before the PR is raised. Your job
is not to approve — your job is to find every defect, gap, and risk that a
reviewer or production would catch later.

**Output:** a prioritised findings document at
`${HOME}/Developer/obsidian/$(basename $(git rev-parse --show-toplevel))/plans/<ticket-or-branch-slug>-pr-review-findings.md`.

**Not in scope:**
- Writing or applying fixes — this skill identifies; the engineer fixes.
- Mechanical gates (build, tests, scope, branch name, PR body) — use
  `swift-pr-gate` for those.
- Inline per-diff comments — use `swift-code-review` for those.
- Whole-codebase architecture audit — use `swift-deep-audit` for that.

---

## Step 0 — Pre-flight

Confirm the active repository:

```bash
git remote -v
git branch --show-current
```

If the user has not specified a base branch, default to `main`. If the
project's `CLAUDE.md` declares a different base, prefer that.

Generate the diff and the touched-file list:

```bash
BASE="${BASE:-main}"
git fetch origin "$BASE" --quiet 2>/dev/null || true
git diff --name-only "origin/${BASE}...HEAD" > /tmp/pre-pr-files.txt
git diff "origin/${BASE}...HEAD" > /tmp/pre-pr-diff.patch
wc -l /tmp/pre-pr-files.txt
```

If the diff is empty, halt — there is nothing to review.

---

## Step 1 — Inventory the inputs

Before any analysis, build three lists. State them at the top of the run so
the user can correct them before review starts.

1. **Touched files** — every entry in `/tmp/pre-pr-files.txt`.
2. **Authority docs** — must read all of these before writing any finding:
   - `docs/target_architecture/*.md` (or whatever the project's architecture
     doc set is called — look for `architecture.md`, `testing.md`, `coding-standards.md`)
   - `docs/adr/*.md` (every ADR — they are accepted decisions that must not
     be silently violated)
   - `CLAUDE.md` (project conventions and guardrails)
   - `CONTEXT.md` / `CONTEXT-MAP.md` if present
3. **Third-party SDK contracts** — for every external SDK newly imported or
   newly used in the diff:
   - Fetch the SDK's integration guide via Context7 MCP (preferred) or
     WebFetch.
   - Read the SDK's framework headers in `~/Library/Developer/Xcode/DerivedData/*/Build/Products/*/<SDK>.framework/Headers/`
     to verify property names, init signatures, and threading contracts. Do
     not assume — the public API may differ from a blog post or stale doc.
   - Note the resolved SDK version (`Package.resolved` for SwiftPM, podfile
     lockfiles for CocoaPods).

Read every file in the touched-files list AND every authority doc before
writing any finding. Do not paginate speculatively — `grep` for the symbol
you need if a file exceeds the read window.

---

## Step 2 — Validate with advisor

Call `advisor()` once with your understanding so far. Provide:
- The touched-files list
- The authority docs you have read
- The SDK contracts you have read (with versions)
- The architectural patterns you intend to assert against

The advisor sees your full transcript and validates whether your
interpretation of the architecture rules and SDK usage is correct before you
commit to findings. If the advisor identifies a misread of the architecture
docs or the SDK headers, fix the interpretation before producing findings.

---

## Step 3 — Apply the review checklist

For every finding, state:
- **File:** path + line range
- **Issue:** what is wrong (one sentence)
- **Impact:** why it matters (one or two sentences — operational consequence
  in production, not just "violates rule X")
- **Fix:** exact remediation, with code if applicable (compileable Swift, not
  pseudo-code)

### 1. Third-party SDK correctness

For every new or changed SDK call site:

- Are all **required** fields of the SDK's data structures populated? Check
  the SDK headers — do not rely on the framework letting nil fields slip
  through. Common omissions: `playerSoftwareName`, `playerSoftwareVersion`,
  `viewerUserId`, `viewSessionId`, `appVersion`, `userId`.
- Property name vs init parameter name: many Objective-C SDKs use one name
  in `initWith...` and a different name on the readable property
  (e.g. `videoData:` init param exposed as `customerVideoData` getter).
  Confirm against the framework header, not against the init signature.
- Unit and encoding correctness: durations (seconds vs milliseconds), bytes
  vs bits, NSNumber boxing of bools (`NSNumber(value: true)` vs
  `NSNumber(booleanLiteral: true)`).
- Lifecycle ordering: if the SDK requires `destroyPlayer()` before
  re-`monitor`-ing the same identifier, is that ordering preserved across
  every stop/start cycle?
- Identifier reuse: does the SDK require unique-per-session ids? If we
  reuse a session id after `stop`, do we corrupt the SDK's internal map?
- ABR / item-swap semantics: does the SDK handle `replaceCurrentItem(with:)`
  automatically, or does it require an explicit content-changed call?
- Are all SDK API calls made on the documented thread? Threading is rarely
  declared in headers — check the SDK's integration guide.

### 2. Layer / architecture alignment

- Does the diff introduce a Domain protocol that returns or accepts a
  type defined in Infrastructure? That is a layer inversion.
- Does Infrastructure import Presentation, or does a Service import
  Presentation? Both are forbidden by the standard layer rules.
- Are new types compiled into the production target that should be
  test-only (mocks, recording spies, `Noop`-named conformers)? Mocks must
  be `#if DEBUG`-gated or live in the test target.
- Are new environment values declared with `@Entry` (Swift 5.9+), or with
  the deprecated `EnvironmentKey` boilerplate?
- Composition root: does `App.init()` construct concrete Infrastructure
  types, or does it route through the documented `AppDependencies` /
  composition layer?
- Are all new `@Observable` types `@MainActor` if they own UI-bound state?

### 3. Concurrency and Sendable

- Every new type that crosses an isolation boundary must have an explicit
  `Sendable` conformance (or be a value type with all-`Sendable` stored
  properties).
- Every type that holds mutable shared state and is not actor-isolated must
  declare `@MainActor` (or be an `actor`). A `final class` with mutable
  `var` properties and no isolation is a latent data race.
- `dispatchPrecondition(.onQueue(.main))` traps in release. Every call site
  must either be on a `@MainActor` type or wrapped in `await MainActor.run`.
  A call from a background `Task { }` on a non-isolated type will crash.
- Swift 6 strict concurrency: do all new types compile under
  `SWIFT_STRICT_CONCURRENCY=complete`? Watch for implicit `Sendable`
  synthesis that hides races.
- `@unchecked Sendable` is a debt marker — every instance must have a
  comment explaining the main-thread or actor invariant it relies on.

### 4. Session and lifecycle completeness

For any new monitor / session / subscription / observer:

- Enumerate **every** code path where the session must end: explicit user
  exit, view dismissal (`onDisappear`, `onViewDestroy`), error throws,
  network failure, deinit, app backgrounding (tvOS / iOS scene phase),
  force-quit. For each path missing a corresponding cleanup call, state
  the path and the required fix.
- App backgrounding: does any new VM observe `scenePhase` or
  `UIApplication.didEnterBackgroundNotification` to release resources? If
  not, what is the consequence (perpetual live sessions, leaked Combine
  subscriptions, orphaned timers)?
- `deinit` safety: if the type is `@MainActor`, can `deinit` safely call
  back into the main-thread-only SDK? If not, is there an explicit
  pre-deinit cleanup hook documented and wired up at every callsite?
- Idempotency: does the second `stop()` / `cancel()` / `flush()` call no-op
  cleanly, or does it crash / double-fire?
- Bounded growth: any `[Key: State]` dictionary that holds session state
  must be cleared on stop. If a stop is ever missed, sessions accumulate.

### 5. Edge cases not covered by tests

For each of the following, state whether a test exists. If not, provide a
test stub (Swift Testing — `@Test`, `#expect`, `@Suite`).

- Empty / nil critical inputs (`videoId: ""`, `userId: nil`, empty config key)
- All-nil optional metadata
- Background → foreground round-trip mid-session
- Rapid repeated state changes (5 `contentChanged()` calls in succession)
- Operation on an orphaned / unknown session id
- Operation after the underlying resource has been deallocated (player
  released, network connection dropped)
- Two concurrent sessions on the same shared resource (e.g. re-mounted view)
- Failure paths returning typed errors — verify no monitor / analytics
  calls are emitted on the failure branch

### 6. Test quality

- Are mocks / fakes / recording spies in `MyAppTests/SwiftTesting/Mocks/`
  (or the project's equivalent location), or are they defined inline in
  a test file (not reusable)?
- Do tests use Swift Testing (`@Test`, `#expect`, `@Suite`) or legacy
  XCTest? New tests should use Swift Testing.
- Every `@Test` should have a descriptive string. Every `@Suite` should
  carry a tag.
- No tautological tests (a test that always passes regardless of
  implementation).
- Tests must pattern-match exactly — `if case .X(_, let y)` patterns
  break silently when the enum case gains a new associated value. Where
  the case payload is checked, verify every payload field is exercised.
- Integration tests should assert call **sequence** (`[.start, .stop, .start]`),
  not just call **count**.

### 7. Configuration and operational gaps

- Does any new environment variable / secret have to be set for the SDK to
  function? If the variable is unset, does the app fail loudly or silently
  no-op? Silent no-ops in release are a footgun.
- Does CI set every required env var across every workflow that produces
  a build artefact (PR check, nightly, release)? Missing a var in one
  workflow means that build will silently disable the integration.
- Is the SDK key / env identifier different across dev / staging / prod?
  Using a single key pollutes production telemetry with test traffic.
- README / CONTRIBUTING coverage — can a new engineer onboard onto this
  branch by reading the docs alone?

### 8. Code quality (only if not already flagged by swift-code-review)

- Default function parameter values that re-introduce a deleted type
  (`= NoopFoo()` after `NoopFoo` was renamed / split).
- New parameters added with a default value that silently restore the
  pre-change behaviour — defaults can be a backwards-compat trap.
- `class` where `struct` would do (no reference identity needed, no
  inheritance).
- Strong references held by long-lived services that prevent timely
  deallocation of view models / players / network sessions.
- New SwiftUI view extracted from an existing one — verify every
  modifier (`.onAppear`, `.onDisappear`, `.onChange`, `.task`, env reads)
  is preserved verbatim.

---

## Step 4 — Output document

Write the findings to:

```
${HOME}/Developer/obsidian/$(basename $(git rev-parse --show-toplevel))/plans/<slug>-pr-review-findings.md
```

Where `<slug>` is the ticket id (e.g. `proj-123`) if extractable from the
branch name, otherwise the branch name itself.

Use this structure:

```markdown
# <Project / Ticket> — Senior Pre-PR Review

## Context

Ruthless senior-engineer review of branch `<branch>` against:
- <architecture doc path>
- <SDK contract version, e.g. `MUXSDKStats 4.12.0`>
- Any other authority sources

Verdict: <ONE OF: DO NOT MERGE — defects must be fixed / MERGE WITH FOLLOW-UPS / READY TO MERGE>

## Critical (must fix before merge)

### [C1] <title>
**File:** <path>:<lines>
**Issue:** <one sentence>
**Impact:** <one or two sentences — production consequence>
**Fix:** <exact remediation, code if applicable>

### [C2] ...

## High (fix before merge, may require additional tickets)

### [H1] ...

## Medium (should fix, acceptable in follow-up)

### [M1] ...

## Low (polish, no blocking impact)

### [L1] ...

## Missing tests (required before merge)

### [T1] <test title>
**Scenario:** <what is being tested>
**File:** <where to add it>
**Stub:**
\`\`\`swift
@Test("...")
func ...() async throws {
  // ...
}
\`\`\`

## Things the existing implementation gets right

(One paragraph listing what is solid. This is a balance check, not flattery —
if there are genuine strengths, name them with file references. If the diff
is uniformly bad, say so plainly.)
```

**Rules for findings:**
- Every finding cites a specific file and line range. No abstract complaints.
- Severity must reflect production impact, not personal taste. A naming-style
  preference is `Low`, never `Critical`.
- A single defect can be both code-quality and concurrency — grade it at the
  highest severity it matches.
- Be exhaustive. A defect not found in review will be found in production.
- Do not soften findings. State problems plainly. The engineer reads this
  and knows what to fix without you holding their hand.

---

## Step 5 — Self-correction log

If during this task you self-correct — retry a tool call, backtrack on an
approach, fix your own output, or recover from a misunderstanding — append
an entry to a `## Corrections` section at the bottom of the findings doc.
Format:

```markdown
### {Short title of mistake}
- **What I did:** {one sentence}
- **Why it was wrong:** {one sentence}
- **What I did instead:** {one sentence}
- **Rule to remember:** {one sentence}
```

---

## Notes

- This skill is intended for **plan mode** on Opus by default. Sonnet can run
  it but is more likely to under-call findings on broad-scope adversarial
  reviews. If invoked on Sonnet, ask the user to confirm before proceeding.
- The skill does NOT raise the PR, fix any finding, or update Jira. It
  produces the findings doc; the engineer triages and acts.
- If the diff is small (< 5 files, no SDK additions, no lifecycle changes),
  recommend `swift-code-review` instead — this skill is for high-stakes
  reviews and produces unnecessary ceremony on small diffs.
