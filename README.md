# swift-skills

> [!IMPORTANT]
> **This is a personal project.** It reflects my workflow, my opinions, and my tooling — and it will keep changing as those evolve. It suits my purposes and will always be shaped by them first.
>
> Feedback, suggestions, issues, and PRs are welcome. But ultimately this is MY workflow, so I'll take what fits and leave what doesn't.

A library of Claude Code **skills**, **commands**, and **agents** for shipping Swift / SwiftUI work — from a rough idea or a Jira ticket all the way to a reviewed pull request. Skills encode domain expertise into focused `SKILL.md` modules; agents are specialist subagents the session delegates to; commands chain both into end-to-end pipelines.

---

## Contents

- [Why this exists](#why-this-exists)
- [Install](#install)
- [Use it: the three altitudes](#use-it-the-three-altitudes)
- [Set up a project (`CLAUDE.md`)](#set-up-a-project-claudemd)
- [Documentation](#documentation)
- [Extending the library](#extending-the-library)

---

## Why this exists

Claude Code's skill system lets you encode domain expertise into focused `SKILL.md` files rather than burying everything in a monolithic `CLAUDE.md`. Each skill is a self-contained module that tells Claude exactly how to approach a specific class of task — what to check, what to avoid, which model to reach for, and what a good outcome looks like.

Without skills, Claude pattern-matches on its training data. That works for generic tasks but falls apart for domain-specific ones. `swift-tvos` exists because — in my experience — tvOS focus-engine bugs are a case where Claude pattern-matches the symptom, shuffles code around, and declares the bug fixed when nothing changed; the skill enforces the diagnostic discipline that prevents it. `swift-engineering` locks in the chosen architecture (MV or MVVM) rather than defaulting to whatever its training favours. `swift-code-review` knows to check Swift 6 concurrency, actor isolation, and `@unchecked Sendable` — not just style.

This repo is the **source of truth**. `make install` symlinks skills into `~/.claude/skills/`, commands into `~/.claude/commands/`, and agents into `~/.claude/agents/`.

### Out of scope

What this library deliberately does **not** cover:

- **Non-Apple platforms.** Swift / SwiftUI / Xcode only — no Android, web, or backend.
- **UIKit.** Skills assume SwiftUI only — no UIKit unless the platform requires it. Both MV and MVVM are supported, selected by the project's `CLAUDE.md` `architecture:` key.
- **A general-purpose agent framework.** These are my opinionated workflows, not a reusable toolkit — see the note at the top.
- **A zero-setup install.** Several skills require external services (see [External dependencies](#external-dependencies)); without them, those skills degrade or stop.

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

`make install` runs `link` (skills) + `commands` + `agents` + `hook`. Skills and commands are then available as `/<name>` — e.g. `/swift-engineering`, `/workflow`. Agents are available to delegate to by name — e.g. `swift-developer`, `swift-pr-reviewer`.

### Keeping up to date

```bash
git pull
make install
```

`make install` is idempotent — re-run it any time. If `~/.claude/skills` was ever created as a real directory rather than a symlink farm, `make link` reports it; remove the offending entry and re-run.

### External dependencies

The core build/review skills work with Claude Code alone. Others depend on external services — without them, those skills degrade or stop rather than failing silently. Wire up the ones whose skills you intend to use.

| Dependency                 | Owner                                     | Skills that need it                                                                        | If absent                                                      |
| -------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| **Atlassian MCP**          | Atlassian (connected in Claude Code)      | `story-to-spec`, `discovery-jira`, `jira-bulk`, `/workflow`, `/spec-pipeline` (Jira input) | Jira input/lifecycle steps stop; use spec/prompt input instead |
| **GitHub `gh` CLI**        | GitHub (authenticated locally)            | `git-pr`, `/discovery`, `/workflow` (architecture-drift tracking)                          | PR creation and issue tracking stop                            |
| **Obsidian CLI + a vault** | local (`obsidian` CLI, `$OBSIDIAN_VAULT`) | `daily-notes`, `obsidian-*`, and all `PLANS_DIR` artefacts                                 | vault skills stop; plans/discovery notes have nowhere to land  |
| **XcodeBuildMCP**          | local MCP server                          | `xcodebuildmcp-cli`, build/test phases when Xcode isn't open                               | falls back to raw `xcodebuild`                                 |
| **Context7 MCP**           | local MCP server                          | library-docs lookups inside several skills                                                 | skills proceed on training data, which may be stale            |

---

## Use it: the three altitudes

Every skill here is a **phase** in one delivery lifecycle: shape → architect → discover → build → test → clean → review → ship. The only question is how much of that lifecycle you hand to Claude at once. There are three altitudes, and they share the same underlying skills:

| Altitude         | You run                                                           | What happens                                                                                                                                                                                                                         | When to use                                                                                    |
| ---------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| **Full-auto**    | `/spec-decomposition TICKET` then `/spec-pipeline --from-issue #` | `/spec-decomposition` decomposes a story into a GitHub master issue + sequential child sub-issues; `/spec-pipeline` ships each child → PR, in-place, autonomously (unattended; ~60–90 min per child — an estimate, not a guarantee). | A well-specified story you want decomposed, tracked, and built end-to-end without babysitting. |
| **Orchestrated** | `/workflow SUBTASK`                                               | One subtask → PR, with the orchestrator (Opus) deciding and subagents (Sonnet) executing each phase, plus GitHub architecture-drift tracking across the story.                                                                       | A single scoped subtask where you want control points and architecture tracking.               |
| **Manual**       | the skills one at a time                                          | You drive each phase yourself: `/implementation-brief`, `/swift-engineering`, `/swift-testing`, `/swift-code-review`, `/git-pr`.                                                                                                     | Exploratory work, learning, or anything where you want to see each step.                       |

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

The full manual path, stage by stage, lives in **[delivery-lifecycle.md](./docs/delivery-lifecycle.md)**. Every skill in one place is in the **[skill catalogue](./docs/skill-catalogue.md)**.

---

## Set up a project (`CLAUDE.md`)

The skills and agents only route correctly if the consuming **project's** `CLAUDE.md` tells the session two things: **which agent owns which task**, and **which architecture the project uses**. The agent routing is the same for both architectures — only the `architecture:` key and what it loads differ. Pick the block matching your project and drop it into your `CLAUDE.md`.

#### MV project — `@Observable` services, no ViewModel layer

```markdown
## Session Setup — Agent Routing

This project uses specialist agents. The main session **orchestrates only** — it does not
write Swift code, tests, or PR content directly. Delegate every task below to the right agent.

| Task                                          | Agent                   |
| --------------------------------------------- | ----------------------- |
| Writing or refactoring any Swift code         | `swift-developer`       |
| Writing any unit tests (Swift Testing)        | `swift-test-writer`     |
| Writing any UI tests (XCUITest)               | `swift-uitest-writer`   |
| Debugging a UI-test failure (XCUITest)        | `swift-uitest-debugger` |
| Debugging a unit-test failure (Swift Testing) | `swift-test-writer`     |
| Debugging a runtime crash / simulator issue   | `swift-debugger-agent`  |
| Planning a feature or breaking down a ticket  | `swift-pm`              |
| Code audit or quality review                  | `swift-code-auditor`    |
| Architecture documentation                    | `swift-architect`       |
| Raising or reviewing a pull request           | `swift-pr-reviewer`     |

Agents live at `~/.claude/agents/` and carry their own Swift conventions — do not replicate or
override them here. This is an **iOS** target: there is no tvOS override
(`swift-tvos-developer` is not used in this project).

### Architecture declaration

architecture: MV

Architecture-aware skills and agents read this key to pick a ruleset. `MV` means
`@Observable` services with **no ViewModel layer** — views read state from services via
`@Environment`. They load the `swift-mv-architecture` rules; never introduce a ViewModel.
```

#### MVVM project — `@Observable` ViewModels + stateless Repositories

```markdown
## Session Setup — Agent Routing

This project uses specialist agents. The main session **orchestrates only** — it does not
write Swift code, tests, or PR content directly. Delegate every task below to the right agent.

| Task                                          | Agent                   |
| --------------------------------------------- | ----------------------- |
| Writing or refactoring any Swift code         | `swift-developer`       |
| Writing any unit tests (Swift Testing)        | `swift-test-writer`     |
| Writing any UI tests (XCUITest)               | `swift-uitest-writer`   |
| Debugging a UI-test failure (XCUITest)        | `swift-uitest-debugger` |
| Debugging a unit-test failure (Swift Testing) | `swift-test-writer`     |
| Debugging a runtime crash / simulator issue   | `swift-debugger-agent`  |
| Planning a feature or breaking down a ticket  | `swift-pm`              |
| Code audit or quality review                  | `swift-code-auditor`    |
| Architecture documentation                    | `swift-architect`       |
| Raising or reviewing a pull request           | `swift-pr-reviewer`     |

Agents live at `~/.claude/agents/` and carry their own Swift conventions — do not replicate or
override them here. This is an **iOS** target: there is no tvOS override
(`swift-tvos-developer` is not used in this project).

### Architecture declaration

architecture: MVVM

Architecture-aware skills and agents read this key to pick a ruleset. `MVVM` means modern
`@Observable` ViewModels + injected **stateless Repositories** — views own their ViewModel
via `@State`. They load the `swift-mvvm-architecture` rules, not MV.

## Read Before You Act

| Before you…                             | Read                                                                               |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| write or edit any Swift code            | `docs/architecture.md` + `docs/coding-standards.md`                                |
| build a new screen, feature, or service | `docs/target_architecture/architecture.md` + `docs/target_architecture/templates/` |
| write unit or UI tests                  | `docs/target_architecture/testing.md` + `docs/ui-test-architecture.md`             |
| touch any layout (focus engine)         | `docs/ui-test-architecture.md` **first**                                           |
| check non-negotiable invariants         | `docs/target_architecture/README.md`                                               |
```

> Keep the routing table to the rows your project actually uses (e.g. drop `swift-tvos-developer` on an iOS-only target). The `architecture:` line is the only part that must match your codebase.

### Routing reference — agent ↔ skill

Each routing row has both an **agent** (what the orchestrating session delegates to) and an equivalent **skill** (what you invoke by hand). Use whichever altitude you're working at — they share the same conventions.

| Task                                         | Agent                     | Skill                                                 |
| -------------------------------------------- | ------------------------- | ----------------------------------------------------- |
| Writing or refactoring Swift production code | `swift-developer`         | `/swift-engineering`                                  |
| Writing unit tests (Swift Testing)           | `swift-test-writer`       | `/swift-testing`                                      |
| Writing UI tests (XCUITest)                  | `swift-uitest-writer`     | `/swift-uitest`                                       |
| Debugging a UI-test failure                  | `swift-uitest-debugger`   | `/swift-uitest-debug`                                 |
| tvOS focus / navigation bugs                 | `swift-tvos-developer`    | `/swift-tvos`                                         |
| Planning a feature / breaking down a ticket  | `swift-pm`                | `/product-planning`                                   |
| Code audit or quality review                 | `swift-code-auditor`      | `/swift-code-review` · `/audit`                       |
| Architecture documentation                   | `swift-architect`         | `/architecture-doc`                                   |
| Architecture scaffold / adherence audit      | —                         | `/swift-mv-architecture` · `/swift-mvvm-architecture` |
| Raising or reviewing a PR                    | `swift-pr-reviewer`       | `/git-pr` · `/swift-pr-gate`                          |
| Build / test run (read-only)                 | `xcode-build-test-runner` | `/swift-test-all` · `/build-status`                   |
| Runtime profiling / memory leaks             | `ios-runtime-profiler`    | `/ios-ettrace-performance` · `/ios-memgraph-leaks`    |
| Simulator build / launch / debug             | `swift-debugger-agent`    | `/xcodebuildmcp-cli`                                  |
| Git operations (commit / branch / PR)        | `git-workflow-manager`    | `/git-commit` · `/git-push` · `/git-pr`               |
| Creating / editing Jira tickets              | `jira-ticket-manager`     | `/discovery-jira` · `/jira-bulk`                      |

## Read Before You Act

| Before you…                             | Read                                                                               |
| --------------------------------------- | ---------------------------------------------------------------------------------- |
| write or edit any Swift code            | `docs/architecture.md` + `docs/coding-standards.md`                                |
| build a new screen, feature, or service | `docs/target_architecture/architecture.md` + `docs/target_architecture/templates/` |
| write unit or UI tests                  | `docs/target_architecture/testing.md` + `docs/ui-test-architecture.md`             |
| touch any layout (focus engine)         | `docs/ui-test-architecture.md` **first**                                           |
| check non-negotiable invariants         | `docs/target_architecture/README.md`                                               |

### The two keys that change behaviour

- **`architecture: MV | MVVM`** — every architecture-aware skill and agent reads this to pick its ruleset. `MV` = `@Observable` services, no ViewModel layer; `MVVM` = modern `@Observable` ViewModels + stateless Repositories. Architecture **documentation** routes to `swift-architect` / `/architecture-doc`; architecture **scaffolding / adherence audit** routes to the matching `/swift-mv-architecture` or `/swift-mvvm-architecture` skill.
- **`discovery:`** — a YAML block declaring the planning backend (`jira` subtasks / `github` sub-issues / `local` docs) that `/discovery` materialises work items into. See [delivery-lifecycle.md](./docs/delivery-lifecycle.md#choosing-an-orchestrator).

---

## Documentation

| Doc                                                              | What's in it                                                                                                             |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [docs/skill-catalogue.md](./docs/skill-catalogue.md)             | Every shipped skill, grouped by lifecycle stage, with model · flow tags.                                                 |
| [docs/delivery-lifecycle.md](./docs/delivery-lifecycle.md)       | The manual path stage by stage, the commands/orchestrators, choosing an orchestrator, and what happens when a run fails. |
| [docs/conventions.md](./docs/conventions.md)                     | Architecture & conventions, repo layout, and how to add a skill or command.                                              |
| [docs/orchestrator-contract.md](./docs/orchestrator-contract.md) | The shared orchestrator structure + state-placement convention.                                                          |
| [docs/adr/](./docs/adr/)                                         | Architecture decision records for the library.                                                                           |
| [CLAUDE.md](./CLAUDE.md)                                         | Bucket convention, skill-species taxonomy, and the `in-progress` / `deprecated` lifecycle.                               |

---

## Extending the library

Quick version — full detail in [docs/conventions.md](./docs/conventions.md):

- **New skill** — create `skills/<bucket>/<name>/SKILL.md` (with `name:` + `description:` frontmatter), add a row to [skill-catalogue.md](./docs/skill-catalogue.md), run `make link`.
- **New command** — create `commands/<bucket>/<name>.md`; if it's an orchestrator, follow [orchestrator-contract.md](./docs/orchestrator-contract.md) and register it in `tests/python/test_orchestrator_conformance.py`; add a row to [delivery-lifecycle.md](./docs/delivery-lifecycle.md) and run `make commands`.

Run the conformance + script tests that back these conventions with `make test`.
