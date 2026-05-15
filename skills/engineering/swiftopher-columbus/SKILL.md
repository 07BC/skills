---
name: swiftopher-columbus
description: >
  Produces a thorough, living architecture document for an iOS/macOS Swift
  codebase by systematically reading the project before writing anything.
  Use this skill whenever someone asks to "document the architecture",
  "map out how this app works", "understand the codebase", "create an
  architecture doc", "explain the project structure", or wants an end-to-end
  overview covering setup, code structure, and deployment. Also trigger when
  onboarding a new engineer, preparing for a refactor, or when asked to
  "explain this project" at any level of detail. Always use this skill — do
  not attempt to write an architecture document from memory or filenames alone.
---

# Swift Architect

Produces a living `docs/architecture.md` for a Swift/SwiftUI iOS codebase.
**Read the codebase first. Write second. Never summarise from filenames alone.**

---

## Phase 1 — Explore Before Writing

Run these explorations in order before drafting any prose:

```bash
# 1. Top-level shape
find . -maxdepth 3 -name "*.swift" | head -60
ls -la

# 2. Package graph
cat Package.swift 2>/dev/null || true
find . -name "project.pbxproj" | head -1 | xargs grep -E "SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|PRODUCT_BUNDLE_IDENTIFIER" 2>/dev/null | sort -u

# 3. Entry point
find . -name "*App.swift" -o -name "AppDelegate.swift" | head -5

# 4. Local packages
ls LocalPackages/ 2>/dev/null || true

# 5. CI / deployment config
find . -name "Fastfile" -o -name "*.yml" -o -name "*.yaml" | grep -v ".build" | head -10
```

Open and **read** every file you find above. Do not skip this step.

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
`actor` boundaries, `@MainActor` annotation strategy, `Mutex` vs legacy
`NSLock`, Swift 6 strict-concurrency decisions, `sendable` conformances,
`AsyncStream` / `AsyncThrowingStream` usage.

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
| `references/concurrency.md` | Writing Layer 5 (actors, Mutex, Swift 6) |
| `references/testing.md` | Writing Layer 8 (Swift Testing, mocks, CI) |
