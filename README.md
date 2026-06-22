# swift-skills

> [!IMPORTANT]
> **This is a personal project.** It reflects my workflow, my opinions, and my tooling — and it will keep changing as those evolve. It suits my purposes and will always be shaped by them first.
>
> Feedback, suggestions, issues, and PRs are welcome. But ultimately this is MY workflow, so I'll take what fits and leave what doesn't.

A library of Claude Code **skills** and **commands** for shipping Swift / SwiftUI work — from a rough idea or a Jira ticket all the way to a reviewed pull request. The skills encode domain expertise into focused `SKILL.md` modules; the commands chain those skills into end-to-end pipelines.

---

## Contents

- [Why this exists](#why-this-exists)
- [The delivery model — three altitudes](#the-delivery-model--three-altitudes)
- [The delivery lifecycle, stage by stage](#the-delivery-lifecycle-stage-by-stage)
- [Install](#install)
- [Skill catalogue](#skill-catalogue)
- [Commands](#commands)
- [Choosing an orchestrator](#choosing-an-orchestrator)
- [Architecture & conventions](#architecture--conventions)
- [Layout, adding skills & commands](#layout)

---

## Why this exists

Claude Code's skill system lets you encode domain expertise into focused `SKILL.md` files rather than burying everything in a monolithic `CLAUDE.md`. Each skill is a self-contained module that tells Claude exactly how to approach a specific class of task — what to check, what to avoid, which model to reach for, and what a good outcome looks like.

Without skills, Claude pattern-matches on its training data. That works for generic tasks but falls apart for domain-specific ones. `swift-tvos` exists because — in my experience — tvOS focus-engine bugs are a case where Claude pattern-matches the symptom, shuffles code around, and declares the bug fixed when nothing changed; the skill enforces the diagnostic discipline that prevents it. `swift-engineering` locks in the MV (Model-View) pattern rather than defaulting to MVVM. `swift-code-review` knows to check Swift 6 concurrency, actor isolation, and `@unchecked Sendable` — not just style.

This repo is the source of truth. It installs via `make install`, which symlinks skills into `~/.claude/skills/` and commands into `~/.claude/commands/`.

### Out of scope

What this library deliberately does **not** cover:

- **Non-Apple platforms.** Swift / SwiftUI / Xcode only — no Android, web, or backend.
- **UIKit.** Skills assume SwiftUI only — no UIKit unless the platform requires it. Both MV and MVVM are supported; `swift-mv-architecture` audits MV projects and `swift-mvvm-architecture` audits MVVM projects, selected by the project's `CLAUDE.md` `architecture:` key.
- **A general-purpose agent framework.** These are my opinionated workflows, not a reusable toolkit — see the note at the top.
- **A zero-setup install.** Several skills require external services (see [External dependencies](#external-dependencies)); without them, those skills degrade or stop.

---

## The delivery model — three altitudes

Every skill here is a **phase** in one delivery lifecycle: shape → architect → discover → build → test → clean → review → ship. The only question is how much of that lifecycle you hand to Claude at once. There are three altitudes, and they share the same underlying skills:

| Altitude | You run | What happens | When to use |
|---|---|---|---|
| **Full-auto** | `/spec-decomposition TICKET` then `/spec-pipeline --from-issue #` | `/spec-decomposition` decomposes a story into a GitHub master issue + sequential child sub-issues; `/spec-pipeline` ships each child → PR, in-place, autonomously (unattended; ~60–90 min per child — an estimate, not a guarantee). | A well-specified story you want decomposed, tracked, and built end-to-end without babysitting. |
| **Orchestrated** | `/workflow SUBTASK` | One subtask → PR, with the orchestrator (Opus) deciding and subagents (Sonnet) executing each phase, plus GitHub architecture-drift tracking across the story. | A single scoped subtask where you want control points and architecture tracking. |
| **Manual** | the skills below, one at a time | You drive each phase yourself: `/implementation-brief`, `/swift-engineering`, `/swift-testing`, `/swift-code-review`, `/git-pr`. | Exploratory work, learning, or anything where you want to see each step. |

The key idea: **the orchestrators are just the manual pipeline automated.** `/workflow` and `/spec-pipeline` call the same `implementation-brief` → `swift-engineering` → `swift-testing` → `swift-code-review` skills you'd run by hand. Learn the manual skills and you understand what the orchestrators do; reach for an orchestrator when you want the whole chain run for you.

```
shape ─► architect ─► discover ─► build/clean ─► test ─► review ─► ship

shape        product-planning · grill-me · story-to-spec · mr-j
architect    swift-mv-architecture · swift-mvvm-architecture · architecture-doc
discover     implementation-brief (per subtask)
build/clean  swift-engineering (new code, rewrites, migrations, concurrency fixes)
test         swift-testing · swift-uitest
review       swift-code-review (std or deep mode)
ship         git-pr · swift-pr-gate

        └──────────────  /workflow  (one subtask, orchestrated)  ──────────────┘
        └──────────────  /spec-pipeline  (whole ticket, autonomous)  ──────────┘
```

### Model & flow key

The catalogue tags each skill with the model to reach for and how to run it.

| Symbol | Meaning |
|---|---|
| **Opus** | Deep reasoning, architectural judgment, multi-step synthesis. |
| **Sonnet** | Faster, for well-defined execution tasks (the default). |
| **Plan → Execute** | Enter plan mode first; Claude proposes an approach before touching files. |
| **Direct** | Well-scoped enough to just run. |
| **Orchestrated** | Not run by hand — invoked by a command/pipeline as one of its phases. |

---

## The delivery lifecycle, stage by stage

This is the manual path. Each stage names the skill to reach for and why. The orchestrators automate stages 3–7.

### 1. Shape the work — idea/ticket → document

Pin down *what* you're building before any code. These skills each produce a **different document** — the table below is the fast way to pick one:

| I have… | I want… | Skill |
|---|---|---|
| A vague idea | to think it through, no artefact yet | `/grill-me` |
| A plan to pressure-test | the same, **+ `CONTEXT.md`/ADRs updated** as decisions settle | `/grill-with-docs` |
| A ticket / raw idea / rough approach | a **PRD + build-ordered, PR-sized story files** (decompose) | `/product-planning` |
| One story / ticket / prompt | **one structured spec doc** | `/story-to-spec` |
| A whole codebase | a living **architecture document** | `/architecture-doc` |
| One subtask, about to code | a scoped **engineer brief** | `/implementation-brief` |
| A finished plan/spec | a **Jira ticket** | `/discovery-jira` |
| A spec exists (`docs/specs/*.md`) | a device **QA test plan** | `/spec-test-plan` |
| Any doc, before senior review | it **reframed to review standard** | `/mr-j` |

The boundaries that matter most, because they used to blur: **`/product-planning` decomposes** an idea into many stories; **`/story-to-spec` distils** one ticket into one spec; **`/grill-me` interrogates** a plan you already have. `/mr-j` frames a spec, ticket, or PR description so it survives senior review — every claim explains why the work exists, the root cause, rejected alternatives, the simplest version, and how failure recovers. `/jira-bulk` does fix-version and status changes across many tickets at once.

### 2. Establish the architecture — once per project, or before a big feature

`/swift-mv-architecture` scaffolds a new MV app skeleton or audits for drift; `/swift-mvvm-architecture` does the same for modern `@Observable` MVVM. Declare which architecture the project uses in its `CLAUDE.md` (`architecture: MV` or `architecture: MVVM`) — all engineering skills pick it up automatically. `/architecture-doc` reads the whole codebase and produces a living architecture document — the authority every downstream skill reads. Get this right and discovery + engineering have a source of truth to follow.

### 3. Scope the subtask — before touching code

`/implementation-brief` produces a scoped brief for one subtask: which types to touch, which to create, edge cases, patterns to follow, and — crucially — what **not** to touch. It is the engineer's primary input. For multi-subtask stories, `/discovery` (and its `discovery-init` / `discovery-check` / `discovery-audit` skills) maintain a branch-independent architecture-drift store in GitHub issues so the architecture stays coherent across the whole story.

### 4. Build & clean

`/swift-engineering` is **the single entry point for all Swift writing and editing** — think of it as the **Engineer**. Writing any Swift 6 + SwiftUI is one job: new code, SwiftUI views, services, async work, behaviour-preserving rewrites and clean-ups, `@Observable` migrations from `ObservableObject`/`@Published`, and fixing concrete Swift 6 concurrency errors. There is no separate "clean" or "refactor" skill — those all route here.

> **You don't pick a sub-skill when writing Swift.** `/swift-engineering` auto-applies `/swift-style` (style and Swift 6 rules) and pulls in `/swift-concurrency` (async / actor / Sendable work) and `/swiftui-liquid-glass` (iOS 26+ Liquid Glass UI) automatically as the task needs them. Those three are **parts of the Engineer**, not separate skills you invoke — they appear as their own catalogue rows below only because each is independently useful as a reference (e.g. asking `/swift-concurrency` to *explain* actor isolation without writing code).

`/swift-tvos` diagnoses Apple TV focus-engine and navigation bugs — always use it rather than guessing.

### 5. Test

`/swift-testing` writes unit tests with Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). `/swift-uitest` writes XCUITest UI tests; `/swift-uitest-debug` fixes failing ones via a Sonnet-then-Opus escalation. `/swift-test-all` runs the suite and reports. `/regression-check` audits in-progress changes for blast radius and behavioural ripples before you commit.

### 6. Review

`/swift-code-review` reviews existing code without changing it — BLOCKER / WARNING / SUGGESTION findings with inline fixes. Standard mode for any commit or PR; deep/adversarial mode for high-stakes branches (new SDK, infrastructure, lifecycle changes). `/audit` audits a whole codebase when you need the big picture across all layers.

### 7. Ship

`/swift-pr-gate` runs the mechanical pre-PR gate — build clean, tests pass, scope tight, branch named correctly, PR description complete. Then the git ladder: `/git-commit` → `/git-push` → `/git-pr` (which runs review and opens the PR with a summary and test plan). `/build-status` tells you whether the in-flight build or CI run finished and passed; `/swift-cidi` debugs CI failures; `/swift-lint` runs SwiftLint from the right directory.

### 8. Close the loop

`/swift-document` adds DocC `///` comments **only when you ask** (the default is no `///`). `/daily-notes` writes up what you did from git history and Jira; `/obsidian-learn` captures durable session learnings into the knowledge base.

---

## Install

### Prerequisites

- A [Mac](https://apple.com)
- [Brew](https://brew.sh)
- [Claude Code](https://claude.ai/code) installed and authenticated

> [!IMPORTANT]
> The Python that ships with Xcode tools is unreliable. Install Python via brew.

### External dependencies

The core build/review skills work with Claude Code alone. Others depend on external services — without them, those skills degrade or stop rather than failing silently. Wire up the ones whose skills you intend to use.

| Dependency | Owner | Skills that need it | If absent |
|---|---|---|---|
| **Atlassian MCP** | Atlassian (connected in Claude Code) | `story-to-spec`, `discovery-jira`, `jira-bulk`, `/workflow`, `/spec-pipeline` (Jira input) | Jira input/lifecycle steps stop; use spec/prompt input instead |
| **GitHub `gh` CLI** | GitHub (authenticated locally) | `git-pr`, `/discovery`, `/workflow` (architecture-drift tracking) | PR creation and issue tracking stop |
| **Obsidian CLI + a vault** | local (`obsidian` CLI, `$OBSIDIAN_VAULT`) | `daily-notes`, `obsidian-*`, and all `PLANS_DIR` artefacts | vault skills stop; plans/discovery notes have nowhere to land |
| **XcodeBuildMCP** | local MCP server | `xcodebuildmcp-cli`, build/test phases when Xcode isn't open | falls back to raw `xcodebuild` |
| **Context7 MCP** | local MCP server | library-docs lookups inside several skills | skills proceed on training data, which may be stale |

### Steps

```bash
git clone git@github.com:07BC/skills.git
cd skills
make install
```

Skills are then available as `/<skill-name>` — e.g. `/swift-engineering`, `/swift-tvos`. Commands are available as `/workflow`, `/spec-pipeline`, etc.

### Keeping up to date

```bash
git pull
make install
```

---

## Skill catalogue

Every shipped skill, grouped by the lifecycle stage it serves. Skills auto-trigger from their description, or you can invoke any one explicitly with `/<name>`.

### Shape — planning & spec

| Skill | What it does | Model · Flow |
|---|---|---|
| [/grill-me](./skills/engineering/grill-me/SKILL.md) | Interviews you relentlessly about a plan until reaching shared understanding — one question at a time. | Opus · Direct |
| [/grill-with-docs](./skills/engineering/grill-with-docs/SKILL.md) | Same as grill-me, plus updates `CONTEXT.md` and ADRs inline as decisions crystallise. | Opus · Direct |
| [/product-planning](./skills/documentation/product-planning/SKILL.md) | **Decomposes** an idea/ticket into a PRD + build-ordered, PR-sized story files under `docs/`. One round of clarifying questions first. | Opus · Direct |
| [/story-to-spec](./skills/documentation/story-to-spec/SKILL.md) | **Distils** one Jira story, file, or prompt into one structured spec doc. Spec authoring only — no code, no story breakdown. | Opus · Direct |
| [/mr-j](./skills/productivity/mr-j/SKILL.md) | Frames a PR, ticket, or spec to senior-review standard — why it exists, root cause, rejected alternatives, simplest version, failure recovery. | Opus · Direct |
| [/discovery-jira](./skills/discovery/discovery-jira/SKILL.md) | Converts a plan or spec into a structured Jira ticket. Asks for confirmation before creating. | Sonnet · Direct |
| [/jira-bulk](./skills/productivity/jira-bulk/SKILL.md) | Bulk Jira operations — set fix version, transition status — across many tickets in one invocation. | Sonnet · Direct |

### Architect

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-mv-architecture](./skills/engineering/swift-mv-architecture/SKILL.md) | MV architecture guardian — scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. | Opus · Plan → Execute |
| [/swift-mvvm-architecture](./skills/engineering/swift-mvvm-architecture/SKILL.md) | Modern `@Observable` MVVM architecture guardian — scaffolds a new MVVM app (Repository + ViewModel + View triad), or audits an existing app for legacy drift. | Opus · Plan → Execute |
| [/architecture-doc](./skills/documentation/architecture-doc/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase — the downstream authority. | Opus · Plan → Execute |

### Discover

| Skill | What it does | Model · Flow |
|---|---|---|
| [/implementation-brief](./skills/documentation/implementation-brief/SKILL.md) | Produces a scoped brief for a single subtask. The engineer's primary input — written before any code is touched. | Opus · Direct |
| [/discovery-init](./skills/discovery/discovery-init/SKILL.md) | Creates the GitHub architecture master issue and per-subtask sub-issues for a story. Runs once per story. | Opus · Orchestrated |
| [/discovery-check](./skills/discovery/discovery-check/SKILL.md) | Reconciles completed subtask work and checks the current subtask against the master architecture; updates both on drift. | Opus+Sonnet · Orchestrated |
| [/discovery-audit](./skills/discovery/discovery-audit/SKILL.md) | Audits the finished story against its master architecture. Runs after the final subtask completes. | Opus · Orchestrated |

### Build

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-engineering](./skills/engineering/swift-engineering/SKILL.md) | **THE entry point for all Swift writing and editing** — new Swift 6.2 code, SwiftUI views, services, async work, behaviour-preserving rewrites, `@Observable` migrations, and fixing concrete Swift 6 concurrency errors. Loads `swift-style` automatically. | Sonnet · Direct |
| [/swift-style](./skills/engineering/swift-style/SKILL.md) | **A part of the Engineer** — code style, quality rules, and Swift 6 essentials. Auto-applied by `/swift-engineering`; never invoked directly. | Sonnet · Orchestrated |
| [/swiftui-liquid-glass](./skills/engineering/swiftui-liquid-glass/SKILL.md) | **A part of the Engineer** — implement, review, or improve SwiftUI features with the iOS 26+ Liquid Glass API. `/swift-engineering` loads it automatically for Liquid Glass work. | Sonnet · Direct |
| [/swift-tvos](./skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus-engine bugs. Always use this — do not attempt tvOS focus diagnosis ad hoc. | Sonnet · Direct |
| [/swift-concurrency](./skills/engineering/swift-concurrency/SKILL.md) | **A part of the Engineer** — async/await, actors, Sendable, Swift 6 migration. Auto-loaded by `/swift-engineering` for async work; invoke directly only to *learn or explain* concepts (not to write or fix code). | Sonnet · Direct |
| [/swiftui-performance-audit](./skills/engineering/swiftui-performance-audit/SKILL.md) | Audit SwiftUI runtime performance from code first — slow rendering, janky scrolling, expensive updates, profiling. | Sonnet · Direct |
| [/swift-security](./skills/engineering/swift-security/SKILL.md) | Client-side security reference — Keychain/`SecItem`, CryptoKit, Secure Enclave, biometrics/`LAContext`, data protection, getting secrets off `UserDefaults`. Surfaces on security questions. | Sonnet · Direct |
| [/swift-format-style](./skills/engineering/swift-format-style/SKILL.md) | `FormatStyle` reference — format dates, numbers, currency, measurements, durations and lists with `.formatted()`; replace legacy `DateFormatter`/`NumberFormatter`. | Sonnet · Direct |
| [/swiftui-design-principles](./skills/engineering/swiftui-design-principles/SKILL.md) | Visual design system reference — spacing grid, typography scale, colour discipline, card/row conventions, WidgetKit visuals. | Sonnet · Direct |
| [/proxyman-scripting](./skills/engineering/proxyman-scripting/SKILL.md) | Write and edit Proxyman JS scripts to intercept and modify HTTP/HTTPS traffic — mock APIs, inject headers/tokens, map remote→local, rewrite status/body, use built-in addons (Base64/JWT/AES/GZip). | Sonnet · Direct |

### Test

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-testing](./skills/engineering/swift-testing/SKILL.md) | Generates unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). Not for UI tests. | Sonnet · Direct |
| [/swift-uitest](./skills/testing/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. Runs out-of-process via XCTest. Not for unit tests. | Sonnet · Direct |
| [/swift-uitest-debug](./skills/testing/swift-uitest-debug/SKILL.md) | Diagnoses and fixes failing XCUITest tests — two Sonnet attempts, then Opus diagnosis. | Sonnet → Opus · Direct |
| [/swift-test-all](./skills/testing/swift-test-all/SKILL.md) | Runs the full test suite once and reports. Detects workspace, scheme, and simulator from `CLAUDE.md`. | Sonnet · Direct |
| [/regression-check](./skills/testing/regression-check/SKILL.md) | Audits in-progress changes for side effects before committing — blast radius, behavioural ripples, concurrency regressions. | Sonnet · Direct |
| [/spec-test-plan](./skills/testing/spec-test-plan/SKILL.md) | Generates a device-testable QA test plan from a spec (`docs/specs/*.md`). Use when a spec exists; otherwise use `pr-test-plan` (PR, no spec) or `claude-regression` (neither). | Sonnet · Direct |

### Clean & review

Behaviour-preserving rewrites and refactors are part of `/swift-engineering` (rewrite mode) — not a separate skill. `/swift-code-review` is for reviewing code without changing it.

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-code-review](./skills/engineering/swift-code-review/SKILL.md) | Reviews existing code — BLOCKER / WARNING / SUGGESTION with inline fixes. Two modes: (1) standard diff review before commit/PR; (2) adversarial deep mode for high-stakes branches (new SDK, infra, lifecycle). Do not use for writing or rewriting — use `/swift-engineering`. | Opus · Direct |

### Ship — git, gate & CI

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-pr-gate](./skills/engineering/swift-pr-gate/SKILL.md) | Mechanical pre-PR gate — build clean, tests pass, scope tight, branch named, PR description complete. Run immediately before raising a PR. | Opus · Direct |
| [/git-commit](./skills/git/git-commit/SKILL.md) | Stages specific files and commits with a short imperative message. Extracts a ticket prefix from the branch name if present. | Sonnet · Direct |
| [/git-push](./skills/git/git-push/SKILL.md) | Runs the project formatter, commits, then pushes. Builds on git-commit. | Sonnet · Direct |
| [/git-pr](./skills/git/git-pr/SKILL.md) | Commits, pushes, runs tests and code review, then creates a PR with a summary and end-user test plan. Builds on git-push. | Sonnet · Direct |
| [/build-status](./skills/engineering/build-status/SKILL.md) | Reports whether the in-flight build, test run, or CI check finished and whether it passed — reads the latest background build log and the branch's CI run. | Sonnet · Direct |
| [/swift-cidi](./skills/engineering/swift-cidi/SKILL.md) | Debug GitHub Actions CI for Xcode projects — flaky tests, xcresult artefacts, xctestplan setup. | Sonnet · Direct (Opus for complex failures) |
| [/swift-lint](./skills/engineering/swift-lint/SKILL.md) | Finds the nearest `.swiftlint.yml` and runs SwiftLint from the right directory. | Sonnet · Direct |
| [/xcodebuildmcp-cli](./skills/engineering/xcodebuildmcp-cli/SKILL.md) | Canonical CLI skill for XcodeBuildMCP — build, test, run, debug, log, UI automation on Apple platforms. | Sonnet · Direct |

### Document

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-document](./skills/documentation/swift-document/SKILL.md) | Adds or updates Apple DocC `///` documentation. **Opt-in only** — the project defaults to no `///`; only invoke when asked. | Sonnet · Direct |
| [/skills-adr](./skills/documentation/skills-adr/SKILL.md) | Records an Architecture Decision Record for a skill-library decision into `docs/adr/`. The skill-library counterpart to grill-with-docs' project ADRs. | Sonnet · Direct |

### Pipelines & helpers

| Skill | What it does | Model · Flow |
|---|---|---|
| [/spec-decomposition](./skills/engineering/spec-decomposition/SKILL.md) | Decomposition front door — turns a Jira story into a GitHub master issue + sequential child sub-issues (native, via `gh api graphql`), freezing a stable AC ID per criterion and building the traceability matrix. Does not implement. | Opus · Orchestrated |
| [/spec-pipeline](./skills/engineering/spec-pipeline/SKILL.md) | Implements one child spec → PR, in-place on a fresh branch (no worktree), driving engineer → spec-test-writer → test gate → spec-concurrency-auditor → two diverse-lens reviewers (both must PASS) per task, then reconciling the child + master issues. Hard-stops until its `depends_on` children are merged. Run `--from-issue <#>` per child from `/spec-decomposition`. | Opus+Sonnet · Orchestrated |
| [/spec-validation](./skills/pipelines/spec-validation/SKILL.md) | Validates drafted specs against the live codebase with a multi-lens agent panel, then reconciles findings back into the spec — run after a fix is designed (e.g. by `/solve`), before implementation. Confirms every file/line/symbol and proposed diff is real. | Opus · Direct |
| [/pipeline-preflight](./skills/pipelines/pipeline-preflight/SKILL.md) | Pre-flight checks before any pipeline starts — progress-doc drift, out-of-scope stories, dirty working tree. Cited by orchestrators; does not auto-fire. | Sonnet · Orchestrated |
| [/subagent-reliability](./skills/pipelines/subagent-reliability/SKILL.md) | Recovery procedure for dropped or crashed subagents — recover-in-place, resume, or re-spawn. Cited by orchestrators; does not auto-fire. | Sonnet · Orchestrated |

### Obsidian & knowledge

| Skill | What it does | Model · Flow |
|---|---|---|
| [/daily-notes](./skills/obsidian/daily-notes/SKILL.md) | Generates first-person daily work notes from git history, file changes, and Jira. Runs entirely under Claude Code. | Sonnet · Direct |
| [/obsidian-learn](./skills/obsidian/obsidian-learn/SKILL.md) | Extracts durable knowledge from the current session and appends it to the Obsidian knowledge base. Run at end of session. | Sonnet · Direct |
| [/obsidian-manage](./skills/obsidian/obsidian-manage/SKILL.md) | Read, create, edit, search, and organise notes in the Obsidian vault. | Sonnet · Direct |
| [/obsidian-audit](./skills/obsidian/obsidian-audit/SKILL.md) | Vault hygiene sweep — fixes tags, normalises frontmatter, lifts inline fields into YAML. Logs a revertible changelog. | Sonnet · Direct |
| [/obsidian-rollover](./skills/obsidian/obsidian-rollover/SKILL.md) | Carries incomplete to-do items from recent past daily notes into today's daily note. | Sonnet · Direct |

### Research

| Skill | What it does | Model · Flow |
|---|---|---|
| [/yt-research](./skills/productivity/yt-research/SKILL.md) | Downloads transcripts and extracts prompts from a YouTube channel's recent videos, saving each as markdown in the vault. | Sonnet · Direct |
| [/yt-distill](./skills/productivity/yt-distill/SKILL.md) | Distils a folder of yt-research transcripts into a structured Obsidian reference library — skills, plugins, prompts, techniques, plus a master index. | Sonnet · Direct |

---

## Commands

Commands are markdown files under `commands/<bucket>/<name>.md` that Claude Code exposes as slash commands from `~/.claude/commands/`. They are **orchestrators**: an Opus orchestrator owns every branching decision, Sonnet subagents execute the phases, and no subagent branches. Each phase has a retry budget and explicit halt conditions, and large state is passed to subagents by path rather than re-read.

### Mr Will

| Command | What it does | Model · Flow |
|---|---|---|
| `/solve` | Diagnostic + solution-design panel — a bug / architecture problem → understand → fan out competing fixes → converge on one approved approach, ready to feed `/workflow`. Stops at the plan; never writes code. | Opus+Sonnet · Plan → Execute |
| `/workflow` | One subtask → PR — Jira / spec / prompt → discovery → engineer → test → quality → review → PR, with GitHub architecture-drift tracking across the story. | Opus+Sonnet · Plan → Execute |
| `/spec-pipeline` | (skill) Whole ticket → PR, autonomously, in a disposable worktree. Splits tickets too large for one run first. | Opus+Sonnet · Orchestrated |
| `/audit` | Structured codebase audit — per-layer Sonnet subagents apply `swift-code-review`, findings consolidated and prioritised into remediation batches ready to feed `/workflow`. | Opus+Sonnet · Plan → Execute |
| `/uitest` | End-to-end XCUITest pipeline — AC intake → plan → execute → debug → PR artefacts. | Opus+Sonnet · Plan → Execute |
| `/discovery` | Planning front door — Jira / GitHub issue / prompt / file → a Three-Amigos panel (PM + Architect + QA) plans the work, a devil's advocate trims scope creep, then it materialises tracked work items into the project's configured backend (`jira` / `github` / `local`) and hands off to `/workflow` or `/spec-pipeline`. Backend declared in a `discovery:` YAML block in the project `CLAUDE.md`. | Opus+Sonnet · Plan → Execute |

---

## Choosing an orchestrator

Both `/workflow` and `/spec-pipeline` take a Jira ticket, spec, or prompt to a PR, but they are deliberately distinct tools (see [ADR 0003](./docs/adr/0003-workflow-and-spec-pipeline-are-distinct-aligned-tools.md)):

- **`/workflow`** — drives **one subtask** in-place on a branch, wired into GitHub architecture-drift tracking (`/discovery-init` · `/discovery-check` · `/discovery-audit`) and the JIRA subtask lifecycle. Reach for it when implementing a single scoped subtask and you want architecture tracking across the story.
- **`/spec-pipeline`** — ships a **whole spec** of many tasks autonomously in a disposable worktree (an unattended run, ~60–90 min in practice). Reach for it when you want an entire ticket built end-to-end, hands-off.

`/audit` finds the work and emits batches that `/workflow` then implements one at a time. `/solve` sits one step earlier: when you have a single bug or architecture problem but *not yet a fix*, it diagnoses and designs the approach, then hands the approved plan to `/workflow`. `/uitest` is the UI-test specialisation of the same orchestrator shape.

`/discovery` is the **planning front door for a feature** (vs `/solve`, the front door for a *bug*): a ticket / issue / prompt / doc → a Three-Amigos panel (PM + Architect + QA) plans it, a devil's advocate trims scope creep, and the result is materialised as tracked work items in the backend declared by the project's `discovery:` config (`jira` subtasks / `github` sub-issues / `local` docs), then handed to `/workflow` or `/spec-pipeline`. It absorbs the former standalone architecture-tracking entry point — re-running on already-tracked work enters track/reconcile mode (via `discovery-init` · `discovery-check` · `discovery-audit`) instead of re-planning.

---

## When a run fails

The orchestrators are built to **halt and report, not to push through a broken state** — so recovery is always possible.

- **A phase fails** (build broken, tests red, review blocked): the orchestrator retries within that phase's budget, then halts. It does not continue to the next phase on a failure.
- **On halt**: it writes a blocked report to `PLANS_DIR` naming the failing phase and reason. For `/spec-pipeline`, the disposable worktree is **preserved** (never auto-removed) so you can inspect it; resume by re-invoking the same command, which picks up where it left off.
- **A subagent crashes** (no usable result, socket dropped): handled by `subagent-reliability` — recover-in-place, resume, or re-spawn — without burning the phase's retry budget.
- **Install / symlink trouble**: `make install` is idempotent — re-run it. If `~/.claude/skills` was created as a real directory rather than a symlink farm, `make link` reports it; remove the offending entry and re-run.

If a long unattended run appears to stop mid-flight with no message (context growth at a turn boundary), type `continue` — it resumes from the last completed phase.

---

## Architecture & conventions

The library follows a few documented conventions, all enforced or recorded:

- **Orchestrator contract** — every orchestrator (`workflow`, `uitest`, `audit`, `solve`, `spec-pipeline`) shares one structure: variables block, model declaration, preflight, phase gates, halt conditions, and a state-placement convention. See [`docs/orchestrator-contract.md`](./docs/orchestrator-contract.md). `tests/python/test_orchestrator_conformance.py` enforces it.
- **Skill species** — skills are **executor** (default; auto-fires), **policy** (cited by orchestrators, never auto-fires — `disable-model-invocation: true`), or **dependency** (loaded by another skill — `user-invocable: false`). See the "Skill species" section in [`CLAUDE.md`](./CLAUDE.md); `tests/python/test_skill_taxonomy.py` enforces the markers.
- **State placement** — each kind of cross-agent state has a designated home (GitHub issues / JIRA / Obsidian audit log / `PLANS_DIR` / tmp-by-path). See the "State placement" table in the orchestrator contract.
- **Decision records** — structural decisions about the library live as ADRs in [`docs/adr/`](./docs/adr/), written with the `/skills-adr` skill.

Run the test suite that backs these conventions with `make test`.

---

## Layout

```
Makefile                        — install, link, commands, hook, test targets
scripts/link-skills.sh          — symlinks skills into ~/.claude/skills/ (flattens by name, skips deprecated/)
scripts/link-commands.sh        — symlinks commands into ~/.claude/commands/
commands/                       — slash-command orchestrators
docs/orchestrator-contract.md   — the shared orchestrator structure + state-placement convention
docs/adr/                       — architecture decision records for the library
tests/python/                   — conformance + script tests (make test)
skills/discovery/               — architecture master-issue tracking (init, check, audit, jira)
skills/documentation/           — spec, PRD/stories (product-planning), implementation-brief, DocC, architecture-doc, and skills-ADR authoring
skills/engineering/             — Swift / iOS / Xcode / CI / concurrency skills + spec-pipeline
skills/git/                     — generic git workflow skills
skills/obsidian/                — Obsidian vault management skills
skills/personal/                — personal setup skills (not listed here; symlinked locally)
skills/pipelines/               — orchestration policy helpers (preflight, subagent reliability)
skills/productivity/            — Jira, framing, YouTube research
skills/testing/                 — Swift testing, quality, UI testing, regression auditing
skills/in-progress/             — drafts; not auto-discovered
skills/deprecated/              — retired skills; skipped by link-skills.sh
```

## Adding a skill

1. Create `skills/<bucket>/<name>/SKILL.md` with `name:` and `description:` frontmatter.
2. Add a row to the relevant catalogue table above using the `/<name>` format.
3. Run `make link` to expose it locally.

## Adding a command

1. Create `commands/<bucket>/<name>.md` with the command definition.
2. If it is an orchestrator, follow [`docs/orchestrator-contract.md`](./docs/orchestrator-contract.md) and add it to the `ORCHESTRATORS` list in `tests/python/test_orchestrator_conformance.py`.
3. Add a row to the Commands table above and run `make commands`.

See [`CLAUDE.md`](./CLAUDE.md) for the full bucket convention, the skill-species taxonomy, and the `in-progress` / `deprecated` lifecycle.
