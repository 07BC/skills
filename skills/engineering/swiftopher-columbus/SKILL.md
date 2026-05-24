---
name: swiftopher-columbus
description: >
  Produces a thorough, living architecture document for an iOS/macOS Swift
  codebase by systematically reading the project before writing anything.
  Use this skill whenever someone asks to "document the architecture",
  "map out how this app works", "understand the codebase", "create an
  architecture doc", "create a target architecture doc", "produce
  target-architecture.md", "produce docs/architecture.md", "write the
  architecture authority", "create a canonical architecture reference",
  "single source of truth for architecture", "spec the architecture",
  "draft an architecture overview", "produce a layer map" or "layer model",
  "explain the project structure", or wants an end-to-end overview covering
  setup, code structure, and deployment. Also trigger when the user asks to
  derive an architecture doc from the existing code ("based on the
  application's architecture", "based on what's there"), to audit or blueprint
  the architecture, when onboarding a new engineer, when preparing for a
  refactor, or when asked to "explain this project" at any level of detail.
  Trigger on implicit follow-ups too: "now create the doc", "execute the
  prompt", "do it" after a prior prompt-writing turn. Always use this skill —
  do not attempt to write an architecture document from memory or filenames
  alone. The resulting doc may codify the current pattern as the target
  (MVVM ratification) or describe a migration target (MV) — the skill body
  guides the decision; the script suite produces a recommendation.
---

# Swiftopher Columbus

Produces a living `docs/architecture.md` for a Swift/SwiftUI iOS codebase.
**Read the codebase first. Write second. Never summarise from filenames alone.**

**Scope boundary.** This skill *documents* an existing codebase. For
*scaffolding* a new MV app skeleton or *auditing* an existing one for MVVM
drift, use `swift-architect` instead.

---

## Phase 1 — Explore Before Writing

### 1.1 — Project shape

Run `scripts/explore.sh` to emit raw observations about the codebase before
drafting any prose. The script outputs newline-separated sections covering:

- Top-level swift files (depth 3)
- Directory listing
- Package graph (`Package.swift` if present)
- Xcode project settings (Swift version, deployment targets, bundle id)
- Entry-point candidates (`*App.swift`, `AppDelegate.swift`)
- Local packages (`LocalPackages/`, `Packages/`, or none)

### 1.2 — Architectural pattern detection

Run the inventory scripts to detect which architectural patterns are actually
present in the code. This determines whether the resulting doc ratifies the
current pattern or describes a migration target — do **not** infer this from
filenames or memory.

| Script | What it answers |
|---|---|
| `scripts/pattern-inventory.sh` | MV vs MVVM, `@Observable` vs `ObservableObject`, actor count, concurrency primitives, `@unchecked Sendable` flags |
| `scripts/di-inventory.sh` | `@Entry` vs `EnvironmentKey`, `@StateObject`/`@ObservedObject`/`@EnvironmentObject` counts, singletons, DI containers, `@Inject` |
| `scripts/persistence-inventory.sh` | SwiftData vs Core Data, `UserDefaults`, Keychain, `NSCoding`, image cache |
| `scripts/networking-inventory.sh` | `*ClientProtocol` boundaries, `URLSession` layering, async API shape, WebSocket transport, auth headers |
| `scripts/composition-root.sh` | `@main` entry, `WindowGroup` contents, the View struct that owns the most `@StateObject` declarations (the implicit DI root in MVVM apps) |
| `scripts/drift-report.sh` | Runs all of the above and prints a single recommendation: "Codify MV", "Codify MVVM", "Mid-migration: take a stance", or "No clear pattern" |

For a single-glance verdict run only `drift-report.sh`. For deep auditing run
each inventory individually so the per-section output is preserved.

When the drift report says **"Mid-migration: take a stance"**, stop and ask
the user before writing — the target direction is not inferable from code
alone in a mixed codebase.

### 1.3 — CI and deployment

Search for CI / deployment config (Fastfile, GitHub Actions workflows) —
intentionally not part of `explore.sh` because the shape of CI config varies
enough that synthesis is best done file-by-file:

```bash
find . -name "Fastfile" -o -name "*.yml" -o -name "*.yaml" | grep -v ".build" | head -10
```

### 1.4 — Read what the scripts surface

Open and **read** every file the scripts surface. Do not skip this step.
Scripts emit counts; the doc must cite specific lines.

---

## Phase 2 — Map These Nine Layers

Work through each layer. For every layer produce:
- A plain-English paragraph summary
- Key files/types with a one-line responsibility each
- Non-obvious decisions or gotchas
- A Mermaid diagram **only** where structure is clearer visually than in prose

> 📖 For Swift-specific patterns (concurrency, MV, SwiftData, DI) read the
> relevant reference file in `references/` before writing that section.

### Layer 1 — Project Setup
Targets, schemes, Swift version, deployment target, capabilities,
entitlements, third-party SPM dependencies, local packages.

*Read reference:* `references/project-setup.md`

### Layer 2 — App Entry & Lifecycle
`@main` App struct, `WindowGroup` / `UIWindowSceneDelegate`, DI bootstrap,
environment seeding, scene transition handling.

### Layer 3 — Feature Modules
Folder structure, module boundaries, how modules communicate
(protocols, Swift enums, callbacks, `@Environment`). Public API surface.

*Read reference:* `references/mv-architecture.md`

### Layer 4 — Data Layer
SwiftData models (`@Model`, `ModelContainer`, `ModelContext`), persistence
strategy, migration plan, any legacy Core Data remnants.

*Read reference:* `references/swiftdata.md`

### Layer 5 — Concurrency Model
`actor` boundaries, `@MainActor` annotation strategy, any lock primitives
present (`Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore` — all
treated as drift from actor-first), Swift 6 strict-concurrency decisions,
`Sendable` conformances, `AsyncStream` / `AsyncThrowingStream` usage.

*Read reference:* `references/concurrency.md`

### Layer 6 — Services & Dependency Injection
Which services are long-lived vs request-scoped, how they are injected
(custom DI, `@Environment`, `@Entry`, `@Inject`), ownership and teardown.

### Layer 7 — UI Layer
SwiftUI MV pattern conventions, navigation strategy (`NavigationStack` /
`NavigationSplitView`), shared environment objects, view-model boundaries,
reusable component library.

*Read reference:* `references/mv-architecture.md`

### Layer 8 — Build, CI & Testing
Schemes, test targets, Swift Testing usage patterns, mock/stub strategy,
Fastlane lanes, CI pipeline (GitHub Actions / Bitrise / etc.),
code signing approach.

*Read reference:* `references/testing.md`

### Layer 9 — Deployment & Release
Versioning strategy (marketing + build number automation), App Store
submission workflow, hotfix branch strategy, feature flags, crash reporting.

---

## Phase 3 — Output Format

Write a single Markdown file at `docs/architecture.md`.

```
# Architecture: <App Name>
> Last updated: <date> · Swift <version> · iOS <deployment target>+

## Table of Contents
[auto-generate with layer names]

## 1. Project Setup
...

## 2. App Entry & Lifecycle
...
[continue for all 9 layers]

---
## Open Questions / TODOs
List anything you could not confirm from the code with a ⚠️ prefix.
```

**Rules:**
- H2 per layer, H3 for subsections. Keep it scannable.
- Mermaid diagrams inside fenced ` ```mermaid ` blocks.
- Flag every gap you couldn't confirm with `⚠️ TODO: <what's missing>`.
- Do **not** fabricate implementation details. If you can't find it, say so.
- Target length: 600–1200 lines. Longer is fine if the codebase warrants it.

---

## Phase 4 — Validate Before Finishing

Before presenting the document, check:

- [ ] Every type/file mentioned actually exists in the codebase
- [ ] No layer is marked complete if you only read one file for it
- [ ] All `⚠️ TODO` gaps are listed in the Open Questions section
- [ ] Mermaid diagrams are syntactically valid (test with a simple render check)
- [ ] The Table of Contents links match the actual H2 headings

---

## Reference Files

| File | Read when… |
|------|-----------|
| `references/project-setup.md` | Writing Layer 1 (targets, SPM, local packages) |
| `references/mv-architecture.md` | Writing Layers 3 & 7 (modules, SwiftUI MV) |
| `references/swiftdata.md` | Writing Layer 4 (persistence) |
| `references/concurrency.md` | Writing Layer 5 (actors, Swift 6 strict concurrency, lock-primitive drift) |
| `references/testing.md` | Writing Layer 8 (Swift Testing, mocks, CI) |

## Scripts

All scripts are read-only, idempotent, and run from the repo root. Each
emits sectioned plain-text output suitable for piping into the doc draft.

| Script | Output |
|---|---|
| `scripts/explore.sh` | Project shape — top-level swift files, directory listing, package graph, Xcode project settings, entry points, local packages |
| `scripts/pattern-inventory.sh` | MV vs MVVM verdict, `@Observable` / `ObservableObject` / `@Published` counts, named ViewModels, actor declarations, `@MainActor` annotations, lock-primitive drift (`Mutex` / `NSLock` / `NSRecursiveLock` / `os_unfair_lock` / `OSAllocatedUnfairLock` / `DispatchSemaphore` / `@synchronized`), `@unchecked Sendable` flags |
| `scripts/di-inventory.sh` | DI style verdict, `@Entry` vs `EnvironmentKey` counts, `@StateObject` / `@ObservedObject` / `@EnvironmentObject` counts, `.shared` singletons, `AppDependencies` / `@Inject` detection |
| `scripts/persistence-inventory.sh` | Persistence verdict, SwiftData (`@Model`, `ModelContainer`, `@Query`), Core Data (`NSManagedObject`, `NSPersistentContainer`), `UserDefaults` / `@AppStorage`, Keychain, `NSCoding` legacy archival, image cache |
| `scripts/networking-inventory.sh` | `*ClientProtocol` / `*APIProtocol` boundaries, `URLSession` references and layering check, decoding sites, `async throws` / `AsyncStream` / `AsyncThrowingStream` adoption, WebSocket transport, auth header usage |
| `scripts/composition-root.sh` | `@main` entry, `WindowGroup` block, files with 3+ `@StateObject` (likely composition roots), the top candidate file with its `@StateObject` / `@State` / `@Environment` declarations |
| `scripts/drift-report.sh` | Composite: runs all of the above and prints a single recommendation (ratify MV / ratify MVVM / mid-migration / unknown) plus concurrency-audit flags |

**Recommended order for a fresh codebase:**

```bash
scripts/drift-report.sh > /tmp/arch-report.txt    # one-shot overview
# read /tmp/arch-report.txt, then read the files the report cites
# only then start drafting docs/architecture.md
```

**Recommended order for a known codebase you want to re-audit:**

```bash
scripts/pattern-inventory.sh   # has anything changed since last audit?
scripts/composition-root.sh    # did the composition root move?
# if either shows drift, re-read the relevant code before updating the doc
```
