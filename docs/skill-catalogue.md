# Skill catalogue

Every shipped skill, grouped by the lifecycle stage it serves. Skills auto-trigger from their description, or you can invoke any one explicitly with `/<name>`.

For the mental model behind these stages — and how to drive them at three altitudes — see the [README](../README.md). For the manual lifecycle stage by stage, see [delivery-lifecycle.md](./delivery-lifecycle.md).

## Model & flow key

Each skill is tagged with the model to reach for and how to run it.

| Symbol | Meaning |
|---|---|
| **Opus** | Deep reasoning, architectural judgment, multi-step synthesis. |
| **Sonnet** | Faster, for well-defined execution tasks (the default). |
| **Plan → Execute** | Enter plan mode first; Claude proposes an approach before touching files. |
| **Direct** | Well-scoped enough to just run. |
| **Orchestrated** | Not run by hand — invoked by a command/pipeline as one of its phases. |

---

## Shape — planning & spec

| Skill | What it does | Model · Flow |
|---|---|---|
| [/grill-me](../skills/engineering/grill-me/SKILL.md) | Interviews you relentlessly about a plan until reaching shared understanding — one question at a time. | Opus · Direct |
| [/grill-with-docs](../skills/engineering/grill-with-docs/SKILL.md) | Same as grill-me, plus updates `CONTEXT.md` and ADRs inline as decisions crystallise. | Opus · Direct |
| [/product-planning](../skills/documentation/product-planning/SKILL.md) | **Decomposes** an idea/ticket into a PRD + build-ordered, PR-sized story files under `docs/`. One round of clarifying questions first. | Opus · Direct |
| [/story-to-spec](../skills/documentation/story-to-spec/SKILL.md) | **Distils** one Jira story, file, or prompt into one structured spec doc. Spec authoring only — no code, no story breakdown. | Opus · Direct |
| [/mr-j](../skills/productivity/mr-j/SKILL.md) | Frames a PR, ticket, or spec to senior-review standard — why it exists, root cause, rejected alternatives, simplest version, failure recovery. | Opus · Direct |
| [/discovery-jira](../skills/discovery/discovery-jira/SKILL.md) | Converts a plan or spec into a structured Jira ticket. Asks for confirmation before creating. | Sonnet · Direct |
| [/jira-bulk](../skills/productivity/jira-bulk/SKILL.md) | Bulk Jira operations — set fix version, transition status — across many tickets in one invocation. | Sonnet · Direct |

## Architect

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-mv-architecture](../skills/engineering/swift-mv-architecture/SKILL.md) | MV architecture guardian — scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. | Opus · Plan → Execute |
| [/swift-mvvm-architecture](../skills/engineering/swift-mvvm-architecture/SKILL.md) | Modern `@Observable` MVVM architecture guardian — scaffolds a new MVVM app (Repository + ViewModel + View triad), or audits an existing app for legacy drift. | Opus · Plan → Execute |
| [/architecture-doc](../skills/documentation/architecture-doc/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase — the downstream authority. | Opus · Plan → Execute |

## Discover

| Skill | What it does | Model · Flow |
|---|---|---|
| [/implementation-brief](../skills/documentation/implementation-brief/SKILL.md) | Produces a scoped brief for a single subtask. The engineer's primary input — written before any code is touched. | Opus · Direct |
| [/discovery-init](../skills/discovery/discovery-init/SKILL.md) | Creates the GitHub architecture master issue and per-subtask sub-issues for a story. Runs once per story. | Opus · Orchestrated |
| [/discovery-check](../skills/discovery/discovery-check/SKILL.md) | Reconciles completed subtask work and checks the current subtask against the master architecture; updates both on drift. | Opus+Sonnet · Orchestrated |
| [/discovery-audit](../skills/discovery/discovery-audit/SKILL.md) | Audits the finished story against its master architecture. Runs after the final subtask completes. | Opus · Orchestrated |

## Build

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-engineering](../skills/engineering/swift-engineering/SKILL.md) | **THE entry point for all Swift writing and editing** — new Swift 6.2 code, SwiftUI views, services, async work, behaviour-preserving rewrites, `@Observable` migrations, and fixing concrete Swift 6 concurrency errors. Loads `swift-style` automatically. | Sonnet · Direct |
| [/swift-style](../skills/engineering/swift-style/SKILL.md) | **A part of the Engineer** — code style, quality rules, and Swift 6 essentials. Auto-applied by `/swift-engineering`; never invoked directly. | Sonnet · Orchestrated |
| [/swiftui-liquid-glass](../skills/engineering/swiftui-liquid-glass/SKILL.md) | **A part of the Engineer** — implement, review, or improve SwiftUI features with the iOS 26+ Liquid Glass API. `/swift-engineering` loads it automatically for Liquid Glass work. | Sonnet · Direct |
| [/swift-tvos](../skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus-engine bugs. Always use this — do not attempt tvOS focus diagnosis ad hoc. | Sonnet · Direct |
| [/swift-concurrency](../skills/engineering/swift-concurrency/SKILL.md) | **A part of the Engineer** — async/await, actors, Sendable, Swift 6 migration. Auto-loaded by `/swift-engineering` for async work; invoke directly only to *learn or explain* concepts (not to write or fix code). | Sonnet · Direct |
| [/swiftui-performance-audit](../skills/engineering/swiftui-performance-audit/SKILL.md) | Audit SwiftUI runtime performance from code first — slow rendering, janky scrolling, expensive updates, profiling. | Sonnet · Direct |
| [/swift-security](../skills/engineering/swift-security/SKILL.md) | Client-side security reference — Keychain/`SecItem`, CryptoKit, Secure Enclave, biometrics/`LAContext`, data protection, getting secrets off `UserDefaults`. Surfaces on security questions. | Sonnet · Direct |
| [/swift-format-style](../skills/engineering/swift-format-style/SKILL.md) | `FormatStyle` reference — format dates, numbers, currency, measurements, durations and lists with `.formatted()`; replace legacy `DateFormatter`/`NumberFormatter`. | Sonnet · Direct |
| [/swiftui-design-principles](../skills/engineering/swiftui-design-principles/SKILL.md) | Visual design system reference — spacing grid, typography scale, colour discipline, card/row conventions, WidgetKit visuals. | Sonnet · Direct |
| [/proxyman-scripting](../skills/engineering/proxyman-scripting/SKILL.md) | Write and edit Proxyman JS scripts to intercept and modify HTTP/HTTPS traffic — mock APIs, inject headers/tokens, map remote→local, rewrite status/body, use built-in addons (Base64/JWT/AES/GZip). | Sonnet · Direct |

## Test

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-testing](../skills/engineering/swift-testing/SKILL.md) | Generates unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). Not for UI tests. | Sonnet · Direct |
| [/swift-uitest](../skills/testing/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. Runs out-of-process via XCTest. Not for unit tests. | Sonnet · Direct |
| [/swift-uitest-debug](../skills/testing/swift-uitest-debug/SKILL.md) | Diagnoses and fixes failing XCUITest tests — two Sonnet attempts, then Opus diagnosis. | Sonnet → Opus · Direct |
| [/swift-test-all](../skills/testing/swift-test-all/SKILL.md) | Runs the full test suite once and reports. Detects workspace, scheme, and simulator from `CLAUDE.md`. | Sonnet · Direct |
| [/regression-check](../skills/testing/regression-check/SKILL.md) | Audits in-progress changes for side effects before committing — blast radius, behavioural ripples, concurrency regressions. | Sonnet · Direct |
| [/spec-test-plan](../skills/testing/spec-test-plan/SKILL.md) | Generates a device-testable QA test plan from a spec (`docs/specs/*.md`). Use when a spec exists; otherwise use `pr-test-plan` (PR, no spec) or `claude-regression` (neither). | Sonnet · Direct |

## Clean & review

Behaviour-preserving rewrites and refactors are part of `/swift-engineering` (rewrite mode) — not a separate skill. `/swift-code-review` is for reviewing code without changing it.

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-code-review](../skills/engineering/swift-code-review/SKILL.md) | Reviews existing code — BLOCKER / WARNING / SUGGESTION with inline fixes. Two modes: (1) standard diff review before commit/PR; (2) adversarial deep mode for high-stakes branches (new SDK, infra, lifecycle). Do not use for writing or rewriting — use `/swift-engineering`. | Opus · Direct |

## Ship — git, gate & CI

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-pr-gate](../skills/engineering/swift-pr-gate/SKILL.md) | Mechanical pre-PR gate — build clean, tests pass, scope tight, branch named, PR description complete. Run immediately before raising a PR. | Opus · Direct |
| [/git-commit](../skills/git/git-commit/SKILL.md) | Stages specific files and commits with a short imperative message. Extracts a ticket prefix from the branch name if present. | Sonnet · Direct |
| [/git-push](../skills/git/git-push/SKILL.md) | Runs the project formatter, commits, then pushes. Builds on git-commit. | Sonnet · Direct |
| [/git-pr](../skills/git/git-pr/SKILL.md) | Commits, pushes, runs tests and code review, then creates a PR with a summary and end-user test plan. Builds on git-push. | Sonnet · Direct |
| [/build-status](../skills/engineering/build-status/SKILL.md) | Reports whether the in-flight build, test run, or CI check finished and whether it passed — reads the latest background build log and the branch's CI run. | Sonnet · Direct |
| [/swift-cidi](../skills/engineering/swift-cidi/SKILL.md) | Debug GitHub Actions CI for Xcode projects — flaky tests, xcresult artefacts, xctestplan setup. | Sonnet · Direct (Opus for complex failures) |
| [/swift-lint](../skills/engineering/swift-lint/SKILL.md) | Finds the nearest `.swiftlint.yml` and runs SwiftLint from the right directory. | Sonnet · Direct |
| [/xcodebuildmcp-cli](../skills/engineering/xcodebuildmcp-cli/SKILL.md) | Canonical CLI skill for XcodeBuildMCP — build, test, run, debug, log, UI automation on Apple platforms. | Sonnet · Direct |

## Document

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-document](../skills/documentation/swift-document/SKILL.md) | Adds or updates Apple DocC `///` documentation. **Opt-in only** — the project defaults to no `///`; only invoke when asked. | Sonnet · Direct |
| [/skills-adr](../skills/documentation/skills-adr/SKILL.md) | Records an Architecture Decision Record for a skill-library decision into `docs/adr/`. The skill-library counterpart to grill-with-docs' project ADRs. | Sonnet · Direct |

## Pipelines & helpers

| Skill | What it does | Model · Flow |
|---|---|---|
| [/spec-decomposition](../skills/engineering/spec-decomposition/SKILL.md) | Decomposition front door — turns a Jira story into a GitHub master issue + sequential child sub-issues (native, via `gh api graphql`), freezing a stable AC ID per criterion and building the traceability matrix. Does not implement. | Opus · Orchestrated |
| [/spec-pipeline](../skills/engineering/spec-pipeline/SKILL.md) | Implements one child spec → PR, in-place on a fresh branch (no worktree), driving engineer → spec-test-writer → test gate → spec-concurrency-auditor → two diverse-lens reviewers (both must PASS) per task, then reconciling the child + master issues. Hard-stops until its `depends_on` children are merged. Run `--from-issue <#>` per child from `/spec-decomposition`. | Opus+Sonnet · Orchestrated |
| [/spec-loop](../skills/engineering/spec-loop/SKILL.md) | Autonomous master driver above `/spec-pipeline`. Drives a whole master (`--from-master <#>` GitHub, or `--from-master-doc <path>` local, which it decomposes itself) to completion: loops the spec-* chain over every child sequentially on ONE branch, finishing only when every master AC is covered + tested + passing and a whole-diff review against the master PASSes, then stops at one PR. Resumes from git; finite sweep ceiling + stall detector; parks stuck children. | Opus+Sonnet · Orchestrated |
| [/spec-validation](../skills/pipelines/spec-validation/SKILL.md) | Validates drafted specs against the live codebase with a multi-lens agent panel, then reconciles findings back into the spec — run after a fix is designed (e.g. by `/solve`), before implementation. Confirms every file/line/symbol and proposed diff is real. | Opus · Direct |
| [/pipeline-preflight](../skills/pipelines/pipeline-preflight/SKILL.md) | Pre-flight checks before any pipeline starts — progress-doc drift, out-of-scope stories, dirty working tree. Cited by orchestrators; does not auto-fire. | Sonnet · Orchestrated |
| [/subagent-reliability](../skills/pipelines/subagent-reliability/SKILL.md) | Recovery procedure for dropped or crashed subagents — recover-in-place, resume, or re-spawn. Cited by orchestrators; does not auto-fire. | Sonnet · Orchestrated |
