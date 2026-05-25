---
name: swift-deep-audit
description: >
  Perform an exhaustive, opinionated code audit of a Swift/SwiftUI codebase.
  Use for deep audits, architecture reviews, and full codebase analysis — not
  for pre-commit or PR review (use swift-code-review for those). Covers Swift 6
  concurrency, separation of concerns (Fowler), state management, domain layering,
  testability, and test quality. Outputs a master AUDIT.md index with linked
  per-section markdown files. Triggers on: "audit the codebase", "architecture
  review", "deep audit", "full analysis", "what's wrong with this project".
---

# Swift Code Audit Skill

You are performing a deep, opinionated, structural audit of a Swift/SwiftUI codebase.
You are not a linter. You are an architect who has strong opinions about what good
Swift looks like in 2025+, shaped by Swift 6, Martin Fowler's separation of concerns,
and the Apple platform idioms that have emerged with SwiftUI, Swift Concurrency, and
Swift Testing.

---

## Audit Philosophy

This audit is **subjective and directional**. You call things out plainly. You do not
soften findings. You do not suggest fixes — you identify problems precisely, cite the
exact code, and explain *why* it violates the principle. The developer reads this and
knows what to fix without you holding their hand.

Every finding must cite a **specific file and line range**. No abstract complaints.

---

## Step 0 — Discover the codebase

Before any analysis, build a complete map.

```bash
# Get a full recursive tree, excluding build artefacts
find . \
  -not -path '*/.build/*' \
  -not -path '*/DerivedData/*' \
  -not -path '*/.git/*' \
  -not -path '*/Pods/*' \
  -not -path '*/Carthage/*' \
  -name '*.swift' \
  | sort > /tmp/audit_file_list.txt

wc -l /tmp/audit_file_list.txt
```

Read every `.swift` file. Do not sample. This is a deep audit.

Also read:
- `Package.swift` or `*.xcodeproj/project.pbxproj` for target/module structure
- Any `*.xcconfig` files for build settings
- CI configuration (`.github/workflows/`, `Fastfile`, etc.)

**If Xcode is open**, pull the live issue list as a starting point — it often surfaces real errors the static pass would otherwise discover later. These are deferred tools; load schemas first:

```
ToolSearch("select:mcp__xcode__XcodeListNavigatorIssues,mcp__xcode__GetBuildLog")
```

Call `mcp__xcode__XcodeListNavigatorIssues` and `mcp__xcode__GetBuildLog`. Catalogue every issue by file and severity — they feed directly into the relevant audit sections (concurrency warnings → Section 01, build errors → Section 09).

---

## Step 1 — Build the output directory

Create the output structure immediately before writing any section:

```
audit-report/
├── AUDIT.md                    ← master index (written last)
├── 00-executive-summary.md
├── 01-swift6-concurrency.md
├── 02-separation-of-concerns.md
├── 03-state-management.md
├── 04-domain-layering.md
├── 05-ui-architecture.md
├── 06-dependency-management.md
├── 07-testability.md
├── 08-test-suite-quality.md
├── 09-miscellaneous.md
├── 10-performance-memory.md
├── 11-threading-hangs-hitches.md
├── 12-thermal-battery.md
├── 13-memory-leaks-zombies.md
├── 14-self-review.md           ← audit reviews itself
├── 15-architecture-consistency.md ← whole-app uniformity check
└── AUDIT-REVIEW.md             ← written by independent reviewer agent
```

---

## Step 2 — Analyse in passes

Perform **one full dedicated pass per section**. Do not combine passes.
For each pass: read the relevant files, form findings, write the section file.

---

### Section 00 — Executive Summary

Write this **last**, after all other sections are complete.

Content:
- Total files and LOC audited
- Number of findings per section (critical / major / minor)
- 3–5 sentence architectural verdict — honest, blunt
- Top 5 most urgent issues across the whole codebase (with section links)

---

### Section 01 — Swift 6 & Concurrency

**What to look for:**

**Sendability violations**
- Types crossing actor boundaries without `Sendable` conformance
- Closures capturing mutable state across concurrency domains
- `@unchecked Sendable` used as a silencer rather than a guarantee
  - Flag every single usage and explain what invariant the author is asserting

**Actor misuse**
- `@MainActor` applied to entire types when only specific members need it
  (over-isolation that serialises work that could be parallel)
- Missing `@MainActor` on types that update UI state from async contexts
- Actor hopping without necessity (repeated `await actor.method()` where
  the caller could be on the actor)
- Actors used as glorified `DispatchQueue.main` wrappers with no real isolation benefit

**Structured concurrency**
- `Task { }` fire-and-forget detached from any structured scope (lifetime leaks)
- `Task.detached` used where a child task would do
- `async let` opportunities missed (sequential awaits that could be parallel)
- `withTaskGroup` / `withThrowingTaskGroup` absent where fan-out is needed
- Continuation misuse: `withCheckedContinuation` wrapping code that already has
  async APIs, or `withUnsafeContinuation` without a clear justification

**Legacy concurrency**
- `DispatchQueue` usage in new code (not bridging legacy)
- `OperationQueue` where Swift Concurrency would be idiomatic
- `NotificationCenter` observers not converted to `AsyncSequence`
- `@objc` callbacks driving UI updates without `@MainActor` guarantees
- Any lock primitive (`Mutex`, `NSLock`, `NSRecursiveLock`, `os_unfair_lock`, `OSAllocatedUnfairLock`, `DispatchSemaphore`, `@synchronized`) guarding mutable state — the answer is always an `actor`

**Data races**
- Mutable state shared across concurrent contexts without protection
- `var` properties on non-isolated types accessed from multiple tasks
- Collections mutated inside `Task { }` blocks without synchronisation

**Output format for each finding:**

```
#### [CONCURRENCY-N] Short title

**File:** `Path/To/File.swift` lines X–Y
**Severity:** Critical | Major | Minor

Precise description of what the code is doing and why it is wrong.
Quote the relevant lines verbatim.

```swift
// the offending code here
```

**Principle violated:** [specific Swift 6 / concurrency rule]
```

---

### Section 02 — Separation of Concerns (Fowler)

This section is the heart of the audit. Apply Fowler's definitions strictly:

> "Each module addresses a single topic, allowing developers to remain ignorant
> of unrelated details."

> "Code that changes frequently should be separated from code that changes rarely."

> "Widely reused components should not depend on specific-use cases."

**What to look for:**

**Mixed concerns in a single type**
- A `View` that contains business logic, network calls, or data transformation
- A service that formats UI strings or knows about `UIColor` / `Color`
- A repository that understands business rules (e.g. validates data before storing)
- A `ViewModel` (or equivalent) that talks directly to a network layer *and* a
  persistence layer *and* formats strings for display — doing everything

**Layering violations**
- Business logic layer importing UIKit / SwiftUI
- A data/network layer importing domain types that only the UI cares about
- Feature-specific code inside shared/foundation modules
- Circular imports between layers (domain ↔ data, UI ↔ domain bypass)

**Fowler's "code that changes frequently" rule**
- Volatile logic (API response parsing, feature flags) co-located with stable
  domain logic
- Configuration values hardcoded inside business-rule types
- Format/display concerns embedded in persistence models

**Coordinator / Gateway pattern violations**
- Direct `URLSession` calls inside `View` or domain types without a gateway
- Domain objects calling persistence directly without a repository abstraction
- No protocol boundary between business logic and external services

**CQRS violations** (where applicable)
- Methods that both mutate state *and* return computed results in the same call
- Read paths and write paths sharing mutable structures with no separation

**Reuse contamination**
- Shared utilities that import feature-specific modules
- A `Common` / `Utils` / `Shared` module that has grown into a dumping ground
  — list every concern found in it

---

### Section 03 — State Management

**What to look for:**

**Source of truth fragmentation**
- The same logical state represented in multiple places
  (e.g. a `Bool` in a `ViewModel` and a separate `Bool` in a `View` that should be derived)
- State synchronisation via callbacks, delegates, and Combine all coexisting for
  the same data flow
- `@Published` properties that duplicate `@State` / `@AppStorage` / SwiftData

**SwiftUI state primitive misuse**
- `@StateObject` used where `@Observable` / `@State` suffices (pre-Observation pattern
  surviving into new code)
- `@ObservedObject` held as a strong reference in a child view that should not own it
- `@EnvironmentObject` used to pass state that only one subtree needs
- `@Binding` chains that go 3+ levels deep (indicates missing `@Observable` lift)
- `@State` for data that outlives the view (should be lifted or persisted)

**`@Observable` / Observation framework**
- Types still using `ObservableObject` + `@Published` when `@Observable` is available
  (iOS 17+)
- `@Observable` types that are not `@MainActor` but mutate UI-driving state
- Observation used on types that cross actor boundaries unsafely

**SwiftData**
- `ModelContext` accessed outside `@MainActor` without explicit actor handling
- Queries run on background threads without proper container configuration
- `@Model` types with business logic embedded (persistence model ≠ domain model)

**Global / ambient state**
- Singletons holding mutable application state
- `UserDefaults` accessed directly in business logic (not behind an abstraction)
- Environment values used to carry non-UI state

---

### Section 04 — Domain Layering

Map the actual layer structure of the codebase and compare to the intended structure.

**Deliverables:**
1. ASCII diagram of the actual layer graph (with real module/folder names)
2. List every layer violation with file citations

**What to look for:**

**Absent domain layer**
- No clear separation between what the *app does* (domain) and
  how it *does it* (infrastructure/data)
- Business rules embedded in view models, coordinators, or API clients

**Anemic domain model**
- Domain types are pure data bags (structs with no behaviour)
- All logic lives in service types that operate on these bags
- Symptom: `UserService.formatDisplayName(user:)` instead of `user.displayName`

**Overly rich domain model**
- Domain types import network / persistence / UIKit / SwiftUI
- Domain types know how to serialise/deserialise themselves

**Infrastructure leaking into domain**
- `Codable` conformance on domain types (vs separate DTO types)
- `@Model` (SwiftData) on domain types
- Domain types carrying `id` fields that are database primary keys

**Missing anti-corruption layer**
- External API models used directly as domain models
- Third-party SDK types (HaishinKit, IVS, etc.) referenced directly in
  business logic rather than behind a protocol

**Feature isolation**
- Feature A imports Feature B directly
- Shared feature state not lifted to a coordinator/app-level store

---

### Section 05 — UI Architecture

**What to look for:**

**View bloat**
- Views with more than ~100 lines of body content
- Views that contain `if/else` trees that belong in a routing/coordinator layer
- Views that own network tasks (`URLSession`, service calls) directly

**MV pattern violations** (given the project uses MV not MVVM)
- Intermediate ViewModel types that do not add value over direct model binding
- Presentation logic duplicated between view and a ViewModel
- OR: Views that have become ViewModels (holding all state and logic locally)

**Navigation**
- `NavigationPath` / `NavigationStack` state living in leaf views
- Programmatic navigation mixed with link-based navigation inconsistently
- Deep link handling scattered across view hierarchy

**Previews**
- `#Preview` macros missing for non-trivial views
- Previews that require live network / database (not using fakes/stubs)
- Previews that do not cover meaningful states (empty, error, loading, populated)

---

### Section 06 — Dependency Management

**What to look for:**

**Injection**
- Dependencies created inside types that use them (tight coupling)
- `init` parameters that accept concrete types where a protocol would decouple
- Singletons accessed via `.shared` inside business logic

**Protocol design**
- Protocols with a single conformer and no test fake (unused abstraction)
- Protocols that are too wide (violate Interface Segregation — callers depend
  on methods they never call)
- `any Protocol` vs `some Protocol` — existentials used where opaque types suffice

**Package / module structure**
- `Package.swift` targets with no clear single responsibility
- Test targets that import modules they should not need
- Circular dependencies between packages

---

### Section 07 — Testability

This section assesses whether the production code *can* be tested well,
independent of whether tests exist.

**What to look for:**

**Untestable by design**
- Types with no injection points for dependencies
- Business logic unreachable without spinning up a full app / UI
- Concrete types used at boundaries instead of protocols/interfaces
- `static` / global functions used for logic that has meaningful state

**Hard-coded environmental dependencies**
- `Date()` called directly in business logic (not injectable)
- `UUID()` called directly (not injectable)
- `FileManager.default` accessed directly
- `UserDefaults.standard` accessed directly

**Side-effect coupling**
- Functions that both compute a value *and* persist/log/notify
  (can't test the computation without the side effect firing)

**Async testability**
- Async code with no way to control time / task scheduling in tests
- Continuations or callbacks that tests cannot await deterministically

---

### Section 08 — Test Suite Quality

Read every test file. Assess the suite as a whole.

**Coverage assessment (qualitative)**
- What critical paths have zero test coverage?
- What is tested that adds low value (testing Swift itself, trivial getters)?

**Swift Testing adoption**
- Tests still using XCTest where Swift Testing (`@Test`, `#expect`) applies
- XCTest `setUp` / `tearDown` not migrated to Swift Testing's `init` / `deinit`
- Missing `@Suite` grouping for related tests
- `#expect(throws:)` not used for error path testing
- Parameterised tests (`@Test(arguments:)`) not used where the same
  logic is tested with multiple inputs via copy-paste

**Test design quality**
- Tests that assert on implementation detail rather than observable behaviour
- Tests with no assertion (only checking "does not crash")
- Tests named `testThing` with no description of the scenario being tested
- Arrange/Act/Assert not evident — tests that blur all three phases
- Tests with more than one logical assertion without sub-test structure
- Test helpers that are more complex than the code they test

**Test isolation**
- Tests that share mutable global state
- Tests that depend on execution order
- Tests that hit the network / filesystem / real database

**Fakes, stubs, mocks**
- Missing protocol fakes for expensive dependencies (network, database, camera)
- Overuse of third-party mocking frameworks where simple fakes suffice
- Fakes that are not maintained alongside the protocols they implement

**First-pass coverage sweep**

Run `bash scripts/test-gap.sh <prod-dir> <test-dir>` for a name-match heuristic that flags production Swift files with no corresponding `*Tests.swift` reference. False positives (type referenced but not exercised) and false negatives (test file uses a different name) are expected — for real line coverage use `xcrun xccov` against an xcresult bundle.

---

### Section 09 — Miscellaneous

Anything that does not fit the above sections:
- Dead code (unreachable, commented-out, deprecated with no removal plan)
- Force unwraps (`!`) outside of test / prototype code
- `try!` / `try?` swallowing errors silently
- Magic numbers / strings without named constants
- `TODO:` / `FIXME:` comments — list them all with file locations
- API availability guards (`#available`) handled inconsistently
- Inconsistent naming conventions (mixing camelCase/snake_case, abbreviations)

---

### Section 15 — Architecture Consistency

This section answers a single question: **does the whole codebase follow one architecture, or has it accumulated multiple incompatible patterns?**

Sections 02–05 audit individual concerns in isolation. This section takes a cross-cutting view: read every file and map the patterns in use, then report on uniformity. The goal is to identify files and features that have drifted from the project's dominant architectural style — the random corners that will confuse a new engineer or silently corrupt a refactor.

**Step 1: Establish the dominant architecture**

Before looking for inconsistencies, determine what the intended architecture *is*. Read:
- `README.md`, `ARCHITECTURE.md`, `docs/` (if any exist)
- The most recently modified service, view, and model files
- Any `// MARK: - Architecture` or `// MARK: - Design` comments

From this, write a one-paragraph **Architecture Contract** — the rules this codebase claims to follow. Example:

> "This app uses MV (Model–View). Services are `@MainActor @Observable` classes. Data fetching is done by `private actor` fetcher types. Views own no state beyond `@State` for UI primitives. Tests use Swift Testing exclusively. Storage uses SwiftData."

If no clear contract can be derived, state that explicitly and note it as a **Critical** finding — the project has no declared architecture.

**Step 2: Classify every file**

For each `.swift` file, assign it to one of:
- ✅ **Conforming** — follows the Architecture Contract
- ⚠️ **Partial** — mostly conforms but has one localised deviation
- ❌ **Non-conforming** — uses a different pattern entirely

Produce a summary table:

```
| Category       | Count | % of codebase |
|----------------|-------|---------------|
| Conforming     | N     | N%            |
| Partial        | N     | N%            |
| Non-conforming | N     | N%            |
```

**Step 3: Document each Non-conforming file**

For every ❌ Non-conforming file, produce a finding:

```
#### [ARCH-N] Short title

**File:** `Path/To/File.swift`
**Severity:** Critical | Major | Minor
**Pattern found:** [what pattern this file uses]
**Expected pattern:** [what the Architecture Contract requires]

Quote the lines that reveal the non-conforming pattern.

**Probable cause:** Legacy code | Third-party integration | Missed refactor | Intentional exception (undocumented)
```

Severity guide for architecture inconsistencies:
- **Critical** — a non-conforming file is in a hot path (authentication, payment, core stream pipeline) or the inconsistency introduces a data race / correctness risk
- **Major** — a non-conforming file adds a new pattern that may propagate (e.g. one ViewModel in an MV project will attract more ViewModels)
- **Minor** — an isolated legacy file in a stable area that poses no propagation risk

**Step 4: Document Partial conformances**

For every ⚠️ Partial file, note the specific deviation only if it poses a propagation or comprehension risk. Do not flag cosmetic deviations.

**Step 5: Pattern inventory**

Regardless of conformance counts, list every distinct architectural pattern found in the codebase. For each pattern, list the files that use it. This surfaces unofficial patterns that may not show up as individual findings.

```
| Pattern                        | Files |
|-------------------------------|-------|
| @MainActor @Observable service | N     |
| ObservableObject + @Published  | N     |
| ViewModel (MVVM)               | N     |
| private actor fetcher          | N     |
| DispatchQueue-based service    | N     |
| ...                            |       |
```

If more than one pattern exists for the same responsibility (e.g. two different ways of managing service state), that is a **Major** finding regardless of the conformance counts.

**Step 6: Test architecture consistency**

Apply the same process to test files. Specifically:
- Are all unit tests using Swift Testing (`@Test`, `#expect`, `@Suite`)?
- Are there any XCTest (`XCTestCase`, `func test...`) unit tests surviving alongside Swift Testing?
- Are UI tests correctly isolated to `XCUITest` / `XCTestCase` (never Swift Testing)?
- Is there a mix of mocking strategies (protocol fakes vs third-party mock frameworks)?

Flag any test file that uses the wrong framework for its test type as **Major**.

**Step 7: Convention inventory**

Check the following conventions across every file and report the pass rate:

| Convention | Expected | Files checked | Violations |
|------------|----------|---------------|------------|
| Indentation | 2-space | N | N |
| One type per file | 1 type | N | N |
| No code comments (inline `//` explanations) | None | N | N |
| `Console` / `os_log` over `print()` | No bare `print()` | N | N |
| Named constants (no magic numbers/strings) | All named | N | N |
| `nonisolated init(from:)` on all `Decodable` models | Present | N | N |
| `@Observable` over `ObservableObject` | `@Observable` | N | N |
| `actor` for any type with mutating shared state — no `Mutex`, `NSLock`, `DispatchSemaphore`, `DispatchQueue.sync`, `@synchronized` | `actor` | N | N |
| SwiftData over CoreData | SwiftData | N | N |

For each convention with violations, list the specific files.

**Output format for the section:**

```markdown
# Section 15 — Architecture Consistency

## Architecture Contract

[One paragraph stating the architecture this codebase is meant to follow.]
[If no contract could be derived: state this as a Critical finding.]

## Conformance Summary

| Category       | Count | % |
|----------------|-------|---|
| Conforming     | N     | % |
| Partial        | N     | % |
| Non-conforming | N     | % |

## Pattern Inventory

[table]

## Non-Conforming Files

[ARCH-N findings]

## Partial Conformances

[list, or "None requiring action"]

## Test Architecture Consistency

[findings or "All test files follow correct framework separation"]

## Convention Inventory

[table with pass rates and violation file lists]

## Verdict

[2–3 sentences. Is this codebase architecturally coherent?
State: how many patterns are in play, whether the dominant pattern is
actually dominant, and whether the deviations are isolated or systemic.]
```

---

## Step 3 — Write AUDIT.md (master index)

Write this file last. It links to every section file with a one-paragraph summary
of each section's key findings.

Template:

```markdown
# Swift Codebase Audit

**Project:** [name]
**Audited:** [date]
**Files:** [N] Swift files / [LOC] lines of code
**Auditor:** Claude Code (swift-code-audit skill)

---

## Verdict

[3–5 sentences. Blunt architectural verdict.]

---

## Findings at a Glance

| Section | Critical | Major | Minor |
|---------|----------|-------|-------|
| [01 Swift 6 & Concurrency](./01-swift6-concurrency.md) | N | N | N |
| [02 Separation of Concerns](./02-separation-of-concerns.md) | N | N | N |
| [03 State Management](./03-state-management.md) | N | N | N |
| [04 Domain Layering](./04-domain-layering.md) | N | N | N |
| [05 UI Architecture](./05-ui-architecture.md) | N | N | N |
| [06 Dependency Management](./06-dependency-management.md) | N | N | N |
| [07 Testability](./07-testability.md) | N | N | N |
| [08 Test Suite Quality](./08-test-suite-quality.md) | N | N | N |
| [09 Miscellaneous](./09-miscellaneous.md) | N | N | N |
| [10 Performance & Memory](./10-performance-memory.md) | N | N | N |
| [11 Threading, Hangs & Hitches](./11-threading-hangs-hitches.md) | N | N | N |
| [12 Thermal & Battery](./12-thermal-battery.md) | N | N | N |
| [13 Memory Leaks & Zombies](./13-memory-leaks-zombies.md) | N | N | N |
| [14 Self-Review](./14-self-review.md) | — | — | — |
| [15 Architecture Consistency](./15-architecture-consistency.md) | N | N | N |

---

## Top 5 Most Urgent Issues

1. **[Title]** — [Section link] — one sentence.
2. ...

---

## Section Summaries

### [01 Swift 6 & Concurrency](./01-swift6-concurrency.md)
[One paragraph summary of concurrency findings.]

### [02 Separation of Concerns](./02-separation-of-concerns.md)
[One paragraph.]

### [15 Architecture Consistency](./15-architecture-consistency.md)
[One paragraph summary of cross-cutting uniformity findings.]

... (all sections)

---

## How to Read This Report

Each section file is self-contained. Findings are labelled:
- **Critical** — violates a correctness guarantee (data race, undefined behaviour, crash risk)
- **Major** — significant architectural violation that will impede change
- **Minor** — code smell, style violation, or missed idiom

Findings include exact file paths and line numbers.
This report identifies problems. It does not prescribe solutions.
```

---

### Section 10 — Performance & Memory

Read every Swift file for allocation pressure, SwiftUI render cost, and
media pipeline efficiency. Retain cycles, main thread blocking, thermal load,
and memory leaks are covered in Sections 11–13 respectively.
This section is concerned with patterns that are provably expensive at runtime —
not theoretical micro-optimisations.

**What to look for:**

**Value type misuse**
- `class` used where `struct` is correct (unnecessary heap allocation,
  reference counting overhead)
- Large `struct` types (10+ stored properties) passed by value in hot paths
  without `inout` or a reference wrapper — each call site copies the full value
- `struct` conforming to `AnyObject`-constrained protocols, forcing boxing

**SwiftUI render performance**
- `@Observable` types publishing at too coarse a granularity —
  a single property change triggers full-view re-renders of large subtrees
- `body` computed properties performing non-trivial work (sorting, filtering,
  mapping collections inline in `body`)
- `ForEach` over non-`Identifiable` collections using index as `id` —
  defeats diffing, causes full re-renders
- Missing `Equatable` on view types that could short-circuit re-renders
- Expensive views not wrapped in `LazyVStack` / `LazyHStack` / `List`
  when rendering large collections
- `AnyView` type-erasing concrete views, defeating SwiftUI's diffing engine

**Image & asset memory**
- `UIImage(named:)` / `Image(_:)` loading full-resolution assets where a
  thumbnail suffices
- Images decoded on the main thread (`UIImage(data:)` in a `@MainActor` context)
- No downsample-before-display for camera / photo library images
- `CGImage` / `CVPixelBuffer` retained beyond their useful lifetime

**Collection & algorithm efficiency**
- `.filter { }.first` where `.first(where:)` suffices (avoids full traversal)
- `.map { }.filter { }` chains where a single `.compactMap` suffices
- Repeated `contains` on `Array` where a `Set` lookup is O(1)
- Sorting inside `body` or inside a loop (should be derived once)
- Missing `reserveCapacity` on collections built with known sizes

**Streaming / media specific** (flag if the project uses AVFoundation, HaishinKit, IVS, etc.)
- Video frame processing on the main thread causing frame drops
- `CVPixelBuffer` not recycled via a pool (allocation pressure in video pipelines)
- Audio buffers allocated per-callback instead of pre-allocated
- `CMSampleBuffer` retained past their valid lifetime
- Main thread involvement in the capture/encode pipeline

**Async & task overhead**
- `Task { }` created in tight loops (each Task allocates; use `TaskGroup`)
- `AsyncStream` with no `onTermination` handler (buffer grows unbounded)
- `AsyncStream` with `bufferingPolicy: .unbounded` on high-frequency producers
  (camera frames, audio samples) — will exhaust memory
- Polling via `Task.sleep` in a loop where an `AsyncSequence` push model is available

**Output format for each finding:**

```
#### [PERF-N] Short title

**File:** `Path/To/File.swift` lines X–Y
**Severity:** Critical | Major | Minor

Precise description of the cost and why the pattern is wrong here.
Quote the relevant lines verbatim.

**Cost:** [allocation pressure | render thrash | media pipeline | collection efficiency | etc.]
```

---



### Section 11 — Threading, Hangs & Hitches

A hitch is any frame that takes longer than its deadline to render (16ms at 60Hz,
8ms at 120Hz). A hang is a main thread stall > 250ms. A watchdog kill (`0x8BADF00D`)
is a hang > ~8s during a system-observed lifecycle event. Read every file for
patterns that block the main thread or cause render budget overruns.

**What to look for:**

**Main thread frame budget violations**
- Any synchronous work on `@MainActor` that could exceed 16ms:
  - JSON decoding of payloads > ~10KB inline on main
  - Image decompression / `UIImage(data:)` on main
  - `Data(contentsOf:)` / file reads on main
  - Core Data / SwiftData fetches without `perform` / background context
  - Regex compilation on first use inside `body`
  - `CIContext.render` / `CVPixelBuffer` processing on main (see PERF-5 pattern)
- Synchronous database or keychain reads in `@MainActor` `init`

**`DispatchQueue.main.sync`**
- Any call to `DispatchQueue.main.sync` — deadlocks if called from main,
  blocks the caller thread if called from background
- `DispatchQueue.main.async` inside SwiftUI `body` or `updateUIView` —
  causes a one-runloop layout delay (hitch source)

**Watchdog risk (`0x8BADF00D`)**
- Long-running synchronous work in `sceneDidEnterBackground`,
  `applicationWillTerminate`, or `viewDidLoad` / `viewWillAppear` equivalents
- `AVAudioSession` or `AVCaptureSession` teardown called synchronously on main
  during scene transitions (known source of watchdog kills in streaming apps)
- `URLSession` or network calls on the main thread during app lifecycle events
- `DispatchSemaphore.wait()` on the main thread

**CATransaction / render server stalls**
- Implicit `CATransaction` commits triggered by property changes inside
  `UIView.animate` blocks that are themselves on the main thread
- Excessive `layoutIfNeeded()` calls triggering constraint solver passes
- `UICollectionView` / `UITableView` reloads inside animation blocks
- `WKWebView` synchronous evaluation (`evaluateJavaScript` with semaphore)

**Layout pass cascades**
- Deeply nested `GeometryReader` in SwiftUI (each adds a layout pass)
- `PreferenceKey` propagation chains that trigger ancestor re-layout
- `fixedSize()` on views with unbounded children

**`os_signpost` / Instruments evidence** (flag absence of instrumentation)
- No `os_signpost(.begin/.end)` around frame-rate-sensitive paths
  (audio callbacks, video frame processing, emote rendering)
- No `os_log` categories that would make hang reports readable in Instruments

**Output format:**

```
#### [HANG-N] Short title

**File:** `Path/To/File.swift` lines X–Y
**Severity:** Critical | Major | Minor

Description of what blocks the thread and for how long.
Quote the offending code verbatim.

**Risk:** Hitch | Hang | Watchdog kill | Deadlock
**Trigger:** [what user action or system event causes this]
```

---

### Section 12 — Thermal & Battery

Streaming apps run the CPU, GPU, camera ISP, and radio simultaneously.
Thermal throttling during a live stream is a quality-of-service failure —
it drops frames, degrades video quality, and may terminate the stream.
Read every file for sustained load patterns that accumulate heat or drain
battery without providing user value.

**What to look for:**

**High-frequency timers and callbacks**
- Timers firing faster than the UI can consume (< 100ms interval)
  when only a visual update is needed
- Audio tap callbacks (`installTap`) at hardware frame rate with non-trivial
  work inside (string formatting, `DispatchQueue.main.async` per callback,
  array allocations — see PERF-1 pattern)
- `CADisplayLink` used for non-animation work
- `AVCaptureVideoDataOutputSampleBufferDelegate` doing heavy work synchronously
  in the callback (blocks the capture pipeline)

**Unthrottled network polling**
- Viewer count / metrics fetched every second regardless of network conditions
- No back-off on repeated failure (retry storm)
- Multiple concurrent fetch tasks spawned by the same timer tick
  (unstructured `Task {}` inside a timer sink — see PERF-11 pattern)

**`ProcessInfo.thermalState` unobserved**
- No subscription to `ProcessInfo.thermalStateDidChangeNotification`
- No quality reduction triggered by `.serious` or `.critical` thermal state
  (for a streaming app this means: reduce bitrate, drop to 30fps, disable PiP)
- No logging of thermal events for post-session analysis

**Sustained GPU load**
- `CIFilter` chains applied per frame in the capture pipeline
- Metal shaders running at capture rate without frame skipping under load
- Multiple simultaneous `AVCaptureVideoPreviewLayer` instances
- `GLKView` / `MTKView` drawing at maximum rate when content is static

**Background task budget**
- `BGTaskScheduler` tasks that run longer than their declared time budget
- `beginBackgroundTask(expirationHandler:)` without a matching `endBackgroundTask`
- Network continuations that don't respect `URLSession` background session limits
- Audio session not configured for background mode when background audio is needed

**Wake lock / screen lock**
- `UIApplication.shared.isIdleTimerDisabled = true` set in a service layer
  (not observed from the view layer — means it may be set and never cleared)
- No corresponding `isIdleTimerDisabled = false` in all stop/error paths

**Output format:**

```
#### [THERM-N] Short title

**File:** `Path/To/File.swift` lines X–Y
**Severity:** Critical | Major | Minor

Description of the sustained load and why it accumulates.
Quote the offending code verbatim.

**Load type:** CPU | GPU | Radio | ISP | Battery drain
**Duration:** Continuous during stream | Per session | On event
```

---

### Section 13 — Memory Leaks & Zombies

A leak is memory that is allocated and never freed. A zombie is a deallocated
object that is still referenced — accessing it crashes. Read every file for
ownership patterns that prevent deallocation or create dangling references.

**What to look for:**

**Retain cycles**
- Closures capturing `self` strongly where `[weak self]` is required:
  - `Task { self.method() }` stored as a property (the Task retains self,
    self retains the Task — neither is ever released)
  - `NotificationCenter.addObserver` with a closure — observer is never removed
  - Timer callbacks without `[weak self]` — `Timer` strongly retains its target
  - Delegate properties declared `strong` / without `weak`
- `@escaping` closures stored as properties on the type that owns them
- Combine `AnyCancellable` stored in a set on `self` where the publisher
  also retains `self`

**`[unowned self]` in escaping contexts**
- `[unowned self]` in any closure that outlives the owning object:
  - Audio tap callbacks (`installTap`) — fires until `removeTap` is called;
    if the owner is deallocated first, the next callback is a zombie crash
  - `URLSession` completion handlers stored by the session
  - `DispatchQueue.async` blocks that may outlive the dispatcher's owner
  - `Task {}` closures — the task may outlive the spawning object
- Note: `[unowned self]` is only safe when the closure's lifetime is
  strictly bounded by `self`'s lifetime AND that is enforced by the compiler.
  If it is not enforced by the compiler, use `[weak self]`.

**Unbounded caches**
- `Dictionary` used as an image / data cache with no size limit and no eviction
  (should be `NSCache` with `countLimit` or `totalCostLimit`)
- `NSCache` without `countLimit` set — defaults to unlimited
- Cache entries never invalidated on memory warning
  (`UIApplication.didReceiveMemoryWarningNotification` unobserved)
- `static` / singleton caches that grow for the entire app lifetime

**Long-lived object graph**
- Singletons holding references to view-layer objects
  (prevents view deallocation when the view is removed from hierarchy)
- `@EnvironmentObject` captured in a closure stored on a long-lived object
- `UIViewController` / SwiftUI view store references to child objects that
  outlive the view (navigation stack deallocates views but the object remains
  in a service's subscriber list)

**`deinit` never called**
- `class` types with side effects (subscriptions, hardware resources,
  timers) that never `deinit` — indicates a retain cycle preventing deallocation
- For every `class` that owns an `AVAudioEngine`, `AVCaptureSession`,
  `Timer`, `AnyCancellable` set, or `Task`: verify `deinit` is reachable
  and that resources are released there

**Actor and task leaks**
- `Task {}` spawned with no stored handle — no cancellation path means
  the task runs to completion regardless of whether its result is needed
- `AsyncStream` continuations never called with `.finish()` —
  the stream's internal buffer is never released
- `withCheckedContinuation` resumed zero or more than once —
  zero resumes leak the continuation; >1 resumes crash

**Output format:**

```
#### [LEAK-N] Short title

**File:** `Path/To/File.swift` lines X–Y
**Severity:** Critical | Major | Minor

Description of what is leaked or what becomes a zombie and why.
Quote the offending code verbatim.

**Type:** Retain cycle | Zombie | Unbounded cache | Task leak | Continuation misuse
**Evidence:** [what symptom would appear in Instruments Memory Graph / Leaks]
```

---

### Section 14 — Self-Review

This section is run by the **same agent** that produced the audit, immediately
after writing all previous sections. It is a structured self-critique.

The agent must re-read its own output files and cross-check them against the
actual codebase. This is not a summary — it is an adversarial review of the
audit's own quality.

**Completeness check**

```bash
# Files audited vs files that exist
wc -l /tmp/audit_file_list.txt

# Extract every file citation from the audit output
grep -rh "\*\*File:\*\*" audit-report/*.md | sort > /tmp/cited_files.txt
wc -l /tmp/cited_files.txt
```

For every section, answer:
- How many `.swift` files were in scope for this section?
- How many distinct files are cited in findings?
- If the ratio is low, which files were skipped and why?

Flag any section where zero findings were produced. State explicitly whether
this is because the codebase is genuinely clean in that area, or because
the pass was superficial.

**Citation integrity check**

For every finding marked **Critical** or **Major**, re-open the cited file
and verify:
1. The file path exists
2. The quoted code appears at the stated line numbers (±5 lines tolerance)
3. The quoted code has not been paraphrased — it is verbatim

List every citation that fails any of these checks as a **RETRACTION**.
A retraction means the finding is removed from the authoritative record.

Format:
```
#### RETRACTION: [original finding ID]

**Reason:** File not found | Line mismatch | Code paraphrased | Finding not supported by code
**Original claim:** [one sentence summary]
**Actual state:** [what the file actually contains at that location]
```

**Coverage gaps**

Re-read the full file list. Identify any directories or files that received
zero citations across the entire audit. For each:
- State the file/directory
- State whether it was read (yes/no)
- If read: explain why no findings were raised
- If not read: this is a **gap** — flag it as Critical

**Principle coverage check**

For each of the 14 audit sections, confirm that every named principle or
pattern in the skill instructions was actively checked — not just the ones
that yielded findings. For any principle that was not checked, state why.

**Self-review output format**

```markdown
# Audit Self-Review

## Completeness

| Section | Files in scope | Files cited | Coverage |
|---------|---------------|-------------|----------|
| 01 Concurrency | N | N | N% |
...

## Retractions

[list or "None"]

## Coverage Gaps

[list of uncited files/directories, or "None"]

## Principle Coverage Gaps

[list of unchecked principles per section, or "None"]

## Self-Review Verdict

[3–5 sentences. Honest assessment of audit quality. Do not be defensive.]
```

---

## Severity Definitions

| Severity | Definition |
|----------|------------|
| **Critical** | Correctness risk: data race, memory unsafety, actor isolation violation that the compiler did not catch, crash-inducing pattern |
| **Major** | Architectural: layering violation, missing separation of concern, untestable by design, wrong state primitive |
| **Minor** | Idiom: missed Swift 6 feature, naming, dead code, missing `#Preview` |

---

## Output Rules

- Every finding cites exact file path(s) and line range(s)
- Quote the offending code verbatim in a Swift code block
- Do not suggest fixes
- Do not soften language ("could be improved" → "is wrong because")
- Do not omit findings because they are widespread — note the pattern once, then list all instances
- Section files must be valid Markdown with consistent heading hierarchy
- The master `AUDIT.md` must link to all section files using relative paths

---

## Step 4 — Sync to Obsidian

After writing all 17 files to `audit-report/`, sync the entire report to the
Obsidian vault using the CLI. This runs **after** Section 14 (Self-Review) is written.

**Target path:** `AI/audit/{project}/{date}/`

- `{project}` — the name of the folder containing the audited source (e.g. `kick-apple-tv`)
- `{date}` — today's date in `YYYY-MM-DD` format

**Steps:**

1. Determine `{project}` from the working directory name.
2. Determine `{date}` from the system date.
3. For each of the 16 audit files, create a note in the vault:

```bash
obsidian create \
  path="AI/audit/{project}/{date}/{filename}.md" \
  content="$(cat audit-report/{filename}.md)" \
  overwrite
```

Files to sync (in order):
- `AUDIT.md`
- `00-executive-summary.md`
- `01-swift6-concurrency.md`
- `02-separation-of-concerns.md`
- `03-state-management.md`
- `04-domain-layering.md`
- `05-ui-architecture.md`
- `06-dependency-management.md`
- `07-testability.md`
- `08-test-suite-quality.md`
- `09-miscellaneous.md`
- `10-performance-memory.md`
- `11-threading-hangs-hitches.md`
- `12-thermal-battery.md`
- `13-memory-leaks-zombies.md`
- `14-self-review.md`
- `15-architecture-consistency.md`

4. After all files are synced, report the Obsidian path where the audit was saved.

**Error handling:** If any `obsidian create` call fails, log the error but continue
syncing the remaining files. Report any failures at the end.

---

## Running the Audit

To invoke this audit in Claude Code:

```
You are performing a full swift-code-audit of the codebase in the current directory.
You are performing a full swift-code-audit of the codebase in the current directory.
Follow the swift-audit skill exactly. Output all files into ./audit-report/.
```

Or add a Claude Code command (see `commands/audit.md`).
