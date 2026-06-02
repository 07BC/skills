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

Without skills, Claude pattern-matches on its training data. That works for generic tasks but falls apart for domain-specific ones. `swift-tvos` exists because tvOS focus-engine bugs are a case where Claude confidently shuffles code around and declares the bug fixed when nothing changed — the skill enforces the diagnostic discipline that prevents it. `swift-engineer` locks in the MV (Model-View) pattern rather than defaulting to MVVM. `swift-code-review` knows to check Swift 6 concurrency, actor isolation, and `@unchecked Sendable` — not just style.

This repo is the source of truth. It installs via `make install`, which symlinks skills into `~/.claude/skills/` and commands into `~/.claude/commands/`.

---

## The delivery model — three altitudes

Every skill here is a **phase** in one delivery lifecycle: shape → architect → discover → build → test → clean → review → ship. The only question is how much of that lifecycle you hand to Claude at once. There are three altitudes, and they share the same underlying skills:

| Altitude | You run | What happens | When to use |
|---|---|---|---|
| **Full-auto** | `/spec-pipeline TICKET` | A whole ticket → PR, autonomously, in a disposable git worktree (60–90 min, hands-off). Splits oversized tickets first. | A well-specified ticket you want built end-to-end without babysitting. |
| **Orchestrated** | `/workflow SUBTASK` | One subtask → PR, with the orchestrator (Opus) deciding and subagents (Sonnet) executing each phase, plus GitHub architecture-drift tracking across the story. | A single scoped subtask where you want control points and architecture tracking. |
| **Manual** | the skills below, one at a time | You drive each phase yourself: `/swift-discovery`, `/swift-engineer`, `/swift-testing`, `/swift-code-review`, `/git-pr`. | Exploratory work, learning, or anything where you want to see each step. |

The key idea: **the orchestrators are just the manual pipeline automated.** `/workflow` and `/spec-pipeline` call the same `swift-discovery` → `swift-engineer` → `swift-testing` → `swift-code-review` skills you'd run by hand. Learn the manual skills and you understand what the orchestrators do; reach for an orchestrator when you want the whole chain run for you.

```
shape ─► architect ─► discover ─► build ─► test ─► clean ─► review ─► ship
 │           │           │          │       │        │        │        │
grill-me  swift-     swift-     swift-   swift-   swift-   swift-    swift-pr-gate
story-to- architect  discovery  engineer testing  quality  code-     git-pr
 spec     swiftopher (per       swiftui- swift-            review
mr-j      -columbus   subtask)  liquid-  uitest           swift-pre-
                                glass                      pr-review
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

### 1. Shape the work — idea/ticket → spec

Pin down *what* you're building before any code. `/grill-me` interviews you until the plan holds together; `/grill-with-docs` does the same but updates `CONTEXT.md` and ADRs as decisions settle. `/story-to-spec` distils a Jira story, a markdown file, or a free-form prompt into a structured spec. `/mr-j` frames a spec, ticket, or PR description so it survives senior review — every claim explains why the work exists, the root cause, rejected alternatives, the simplest version, and how failure recovers. `/discovery-jira` turns a finished plan into a Jira ticket; `/jira-bulk` does fix-version and status changes across many tickets at once.

### 2. Establish the architecture — once per project, or before a big feature

`/swift-architect` scaffolds a new MV (Model-View) app skeleton, or audits an existing app for MVVM drift. `/swiftopher-columbus` reads the whole codebase and produces a living architecture document — the authority every downstream skill reads. `/swift-mv-guardian` keeps the MV pattern honest as the app grows. Get this right and discovery + engineering have a source of truth to follow.

### 3. Scope the subtask — before touching code

`/swift-discovery` produces a scoped discovery note for one subtask: which types to touch, which to create, edge cases, patterns to follow, and — crucially — what **not** to touch. It is the engineer's primary input. For multi-subtask stories, `/discovery` (and its `discovery-init` / `discovery-check` / `discovery-audit` skills) maintain a branch-independent architecture-drift store in GitHub issues so the architecture stays coherent across the whole story.

### 4. Build

`/swift-engineer` is the main building skill — new Swift 6.2 features, SwiftUI views, services, and async work within the MV pattern (it loads `swift-style` automatically for write-time quality). `/swiftui-liquid-glass` covers the iOS 26+ Liquid Glass API. `/swift-concurrency` explains async/await, actors, and Sendable; `/swift-concurrency-expert` fixes concrete data races and isolation errors. `/swift-tvos` diagnoses Apple TV focus-engine and navigation bugs — always use it rather than guessing.

### 5. Test

`/swift-testing` writes unit tests with Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). `/swift-uitest` writes XCUITest UI tests; `/swift-uitest-debug` fixes failing ones via a Sonnet-then-Opus escalation. `/swift-test-all` runs the suite and reports. `/regression-check` audits in-progress changes for blast radius and behavioural ripples before you commit.

### 6. Clean & review

`/swift-quality` rewrites code to meet the style guide and architecture rules without changing behaviour. `/swift-code-review` performs an in-session review (BLOCKER / WARNING / SUGGESTION with inline fixes). For high-stakes branches — a new SDK, infrastructure, lifecycle changes — `/swift-pre-pr-review` does a ruthless senior pass and writes a prioritised findings doc. `/swift-deep-audit` audits a whole codebase when you need the big picture.

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

### Steps

```bash
git clone git@github.com:07BC/skills.git
cd skills
make install
```

Skills are then available as `/<skill-name>` — e.g. `/swift-engineer`, `/swift-tvos`. Commands are available as `/workflow`, `/spec-pipeline`, etc.

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
| [/story-to-spec](./skills/documentation/story-to-spec/SKILL.md) | Distils a Jira story, local file, or prompt into a structured spec in the Obsidian vault. Spec authoring only — no code. | Opus · Direct |
| [/mr-j](./skills/productivity/mr-j/SKILL.md) | Frames a PR, ticket, or spec to senior-review standard — why it exists, root cause, rejected alternatives, simplest version, failure recovery. | Opus · Direct |
| [/discovery-jira](./skills/discovery/discovery-jira/SKILL.md) | Converts a plan or spec into a structured Jira ticket. Asks for confirmation before creating. | Sonnet · Direct |
| [/jira-bulk](./skills/productivity/jira-bulk/SKILL.md) | Bulk Jira operations — set fix version, transition status — across many tickets in one invocation. | Sonnet · Direct |

### Architect

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-architect](./skills/engineering/swift-architect/SKILL.md) | Scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. | Opus · Plan → Execute |
| [/swiftopher-columbus](./skills/documentation/swiftopher-columbus/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase — the downstream authority. | Opus · Plan → Execute |
| [/swift-mv-guardian](./skills/engineering/swift-mv-guardian/SKILL.md) | MV architecture guardian — setup mode or audit mode. Complements swift-architect. | Opus · Plan → Execute |

### Discover

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-discovery](./skills/documentation/swift-discovery/SKILL.md) | Produces a scoped discovery note for a single subtask. The engineer's primary input — written before any code is touched. | Opus · Direct |
| [/discovery-init](./skills/discovery/discovery-init/SKILL.md) | Creates the GitHub architecture master issue and per-subtask sub-issues for a story. Runs once per story. | Opus · Orchestrated |
| [/discovery-check](./skills/discovery/discovery-check/SKILL.md) | Reconciles completed subtask work and checks the current subtask against the master architecture; updates both on drift. | Opus+Sonnet · Orchestrated |
| [/discovery-audit](./skills/discovery/discovery-audit/SKILL.md) | Audits the finished story against its master architecture. Runs after the final subtask completes. | Opus · Orchestrated |

### Build

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-engineer](./skills/engineering/swift-engineer/SKILL.md) | Main building skill — new Swift 6.2 features, SwiftUI views, services, and async work within the MV pattern. | Sonnet · Direct |
| [/swift-style](./skills/engineering/swift-style/SKILL.md) | Code style, quality rules, and Swift 6 essentials for clean code from the first line. Loaded as a dependency by swift-engineer; not invoked directly. | Sonnet · Orchestrated |
| [/swiftui-liquid-glass](./skills/engineering/swiftui-liquid-glass/SKILL.md) | Implement, review, or improve SwiftUI features using the iOS 26+ Liquid Glass API. | Sonnet · Direct |
| [/swift-tvos](./skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus-engine bugs. Always use this — do not attempt tvOS focus diagnosis ad hoc. | Sonnet · Direct |
| [/swift-concurrency](./skills/engineering/swift-concurrency/SKILL.md) | Conceptual guidance — async/await, actors, Sendable, Swift 6 migration. Use to learn or explain. | Sonnet · Direct |
| [/swift-concurrency-expert](./skills/engineering/swift-concurrency-expert/SKILL.md) | Action-oriented — fix concrete concurrency errors, data races, isolation warnings, and Sendable gaps in existing code. | Sonnet · Direct |

### Test

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-testing](./skills/engineering/swift-testing/SKILL.md) | Generates unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). Not for UI tests. | Sonnet · Direct |
| [/swift-uitest](./skills/testing/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. Runs out-of-process via XCTest. Not for unit tests. | Sonnet · Direct |
| [/swift-uitest-debug](./skills/testing/swift-uitest-debug/SKILL.md) | Diagnoses and fixes failing XCUITest tests — two Sonnet attempts, then Opus diagnosis. | Sonnet → Opus · Direct |
| [/swift-test-all](./skills/testing/swift-test-all/SKILL.md) | Runs the full test suite once and reports. Detects workspace, scheme, and simulator from `CLAUDE.md`. | Sonnet · Direct |
| [/regression-check](./skills/testing/regression-check/SKILL.md) | Audits in-progress changes for side effects before committing — blast radius, behavioural ripples, concurrency regressions. | Sonnet · Direct |

### Clean & review

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-quality](./skills/testing/swift-quality/SKILL.md) | Rewrites code to meet the Swift Style Guide and architecture rules without changing behaviour. | Sonnet · Direct |
| [/swift-code-review](./skills/engineering/swift-code-review/SKILL.md) | In-session review — BLOCKER / WARNING / SUGGESTION findings with inline fixes. Run before commit or PR. | Opus · Direct |
| [/swift-pre-pr-review](./skills/engineering/swift-pre-pr-review/SKILL.md) | Ruthless senior pre-PR review for high-stakes branches (new SDK, infra, lifecycle changes). Writes a prioritised findings doc. | Opus · Plan → Execute |
| [/swift-deep-audit](./skills/engineering/swift-deep-audit/SKILL.md) | Exhaustive whole-codebase audit — Swift 6 concurrency, separation of concerns, state management, test quality. | Opus · Plan → Execute |

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
| [/spec-pipeline](./skills/engineering/spec-pipeline/SKILL.md) | Whole-spec orchestrator — ships an entire Jira ticket / spec / prompt to a PR autonomously in a disposable worktree, driving engineer → test-writer → concurrency-auditor → task-reviewer per task. | Opus+Sonnet · Orchestrated |
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

| Command | What it does |
|---|---|
| `/workflow` | One subtask → PR — Jira / spec / prompt → discovery → engineer → test → quality → review → PR, with GitHub architecture-drift tracking across the story. |
| `/spec-pipeline` | (skill) Whole ticket → PR, autonomously, in a disposable worktree. Splits oversized tickets first. |
| `/audit-codebase` | Structured codebase audit — per-layer Sonnet subagents apply `swift-code-review`, findings consolidated and prioritised into remediation batches ready to feed `/workflow`. |
| `/uitest-pipeline` | End-to-end XCUITest pipeline — AC intake → plan → execute → debug → PR artefacts. |
| `/discovery` | Standalone architecture tracking — set up the GitHub master issue + sub-issues, check drift, or import an existing arch doc when subtasks already exist. |

---

## Choosing an orchestrator

Both `/workflow` and `/spec-pipeline` take a Jira ticket, spec, or prompt to a PR, but they are deliberately distinct tools (see [ADR 0003](./docs/adr/0003-workflow-and-spec-pipeline-are-distinct-aligned-tools.md)):

- **`/workflow`** — drives **one subtask** in-place on a branch, wired into GitHub architecture-drift tracking (`/discovery-init` · `/discovery-check` · `/discovery-audit`) and the JIRA subtask lifecycle. Reach for it when implementing a single scoped subtask and you want architecture tracking across the story.
- **`/spec-pipeline`** — ships a **whole spec** of many tasks autonomously in a disposable worktree (a 60–90 min unattended run). Reach for it when you want an entire ticket built end-to-end, hands-off.

`/audit-codebase` finds the work and emits batches that `/workflow` then implements one at a time. `/uitest-pipeline` is the UI-test specialisation of the same orchestrator shape.

---

## Architecture & conventions

The library follows a few documented conventions, all enforced or recorded:

- **Orchestrator contract** — every orchestrator (`workflow`, `uitest-pipeline`, `audit-codebase`, `spec-pipeline`) shares one structure: variables block, model declaration, preflight, phase gates, halt conditions, and a state-placement convention. See [`docs/orchestrator-contract.md`](./docs/orchestrator-contract.md). `tests/python/test_orchestrator_conformance.py` enforces it.
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
skills/documentation/           — spec, discovery-note, DocC, architecture-doc, and skills-ADR authoring
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
