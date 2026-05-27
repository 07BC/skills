# swift-skills

> [!IMPORTANT]
> **This is a personal project.** It reflects my workflow, my opinions, and my tooling — and it will keep changing as those evolve. It suits my purposes and will always be shaped by them first.
>
> Feedback, suggestions, issues, and PRs are welcome. But ultimately this is MY workflow, so I'll take what fits and leave what doesn't.

## Why this exists

Claude Code's skill system lets you encode domain expertise into focused `SKILL.md` files rather than burying everything in a monolithic `CLAUDE.md`. Each skill is a self-contained module that tells Claude exactly how to approach a specific class of task — what to check, what to avoid, which model to reach for, and what a good outcome looks like.

Without skills, Claude pattern-matches on its training data. That works for generic tasks, but it falls apart for domain-specific ones. The `swift-tvos` skill exists because tvOS focus engine bugs are a case where Claude confidently shuffles code around and declares the bug fixed when nothing has changed — the skill enforces the diagnostic discipline that prevents that failure mode. The `swift-engineer` skill locks in the MV (Model-View) pattern rather than defaulting to MVVM. The `swift-code-review` skill knows to check Swift 6 concurrency, actor isolation, and `@unchecked Sendable` usage — not just style.

This repo is the source of truth for those skills. It installs via `make install`, which symlinks skills into `~/.claude/skills/` and commands into `~/.claude/commands/`.

## How skills work

Claude Code loads skills from `~/.claude/skills/`. Each skill is a directory containing a `SKILL.md` file with a `name:` and `description:` in its frontmatter. Claude uses the description to decide when to trigger the skill automatically, and you can invoke any skill explicitly with `/<skill-name>`.

## My Workflow

### Model and flow key

| Symbol | Meaning |
|---|---|
| **Opus** | Use Opus 4. Better for deep reasoning, architectural judgment, and multi-step synthesis. |
| **Sonnet** | Use Sonnet 4 (default). Faster for well-defined execution tasks. |
| **Plan → Execute** | Enter plan mode first. Claude proposes an approach before touching any files — essential when the wrong move is expensive. |
| **Direct** | Just invoke it. The task is well-scoped enough to execute without a planning phase. |

---

### Swift development pipeline

```
swift-architect ──► swift-engineer ──► swift-quality ──► swift-code-review
   (design)            (build)            (clean)             (review)
```

## Install

### Prerequisites

- A [Mac](https://apple.com)
- [Brew](https://brew.sh)
- [Claude Code](https://claude.ai/code) installed and authenticated

> [!important]
> Python that ships with Xcode tools is unreliable. Install Python via brew.

### Steps

```bash
git clone git@github.com:07BC/skills.git
cd skills
make install
```

Skills are then available as `/<skill-name>` — e.g. `/swift-engineer`, `/swift-tvos`.

### Keeping up to date

```bash
git pull
make install
```

## Skills

### Git workflow

| Skill | What it does | Model · Flow |
|---|---|---|
| [/git-commit](./skills/git/git-commit/SKILL.md) | Stages specific files and commits with a short imperative message. Extracts a ticket prefix from the branch name if present. | Sonnet · Direct |
| [/git-push](./skills/git/git-push/SKILL.md) | Runs the project formatter, commits, then pushes. Builds on git-commit. | Sonnet · Direct |
| [/git-pr](./skills/git/git-pr/SKILL.md) | Commits, pushes, runs tests and code review, then creates a PR with a summary and end-user test plan. Builds on git-push. | Sonnet · Direct |

### Planning & spec

| Skill | What it does | Model · Flow |
|---|---|---|
| [/story-to-spec](./skills/engineering/story-to-spec/SKILL.md) | Distils a Jira story, local file, or prompt into a structured spec in the Obsidian vault. Spec authoring only — no code. | Opus · Direct |
| [/grill-me](./skills/engineering/grill-me/SKILL.md) | Interviews you relentlessly about a plan until reaching shared understanding — one question at a time. | Opus · Direct |
| [/grill-with-docs](./skills/engineering/grill-with-docs/SKILL.md) | Same as grill-me, plus updates `CONTEXT.md` and ADRs inline as decisions crystallise. | Opus · Direct |

### Building

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-architect](./skills/engineering/swift-architect/SKILL.md) | Scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. | Opus · Plan → Execute |
| [/swift-mv-guardian](./skills/engineering/swift-mv-guardian/SKILL.md) | MV architecture guardian — setup mode or audit mode. Complements swift-architect. | Opus · Plan → Execute |
| [/swift-engineer](./skills/engineering/swift-engineer/SKILL.md) | Main building skill — writes new Swift 6.2 features, SwiftUI views, services, and async work within the MV pattern. | Sonnet · Direct |
| [/swift-discovery](./skills/engineering/swift-discovery/SKILL.md) | Produces a scoped discovery note for a single subtask. The engineer's primary input — written before any code is touched. | Opus · Direct |
| [/swift-quality](./skills/testing/swift-quality/SKILL.md) | Rewrites code to meet the Swift Style Guide and project architecture rules without changing behaviour. | Sonnet · Direct |
| [/swift-style](./skills/engineering/swift-style/SKILL.md) | Code style, quality rules, and Swift 6 essentials for writing clean Swift/SwiftUI from the first line. Loaded by swift-engineer. | Sonnet · Direct |
| [/swiftui-liquid-glass](./skills/engineering/swiftui-liquid-glass/SKILL.md) | Implement, review, or improve SwiftUI features using the iOS 26+ Liquid Glass API. | Sonnet · Direct |
| [/swift-tvos](./skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus engine bugs. Always use this — do not attempt tvOS focus diagnosis ad hoc. | Sonnet · Direct |

### Documenting

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-document](./skills/engineering/swift-document/SKILL.md) | Adds or updates Apple DocC-style `///` documentation on Swift symbols. **Opt-in only** — the project defaults to no `///`; only invoke when explicitly requested. | Sonnet · Direct |
| [/swiftopher-columbus](./skills/engineering/swiftopher-columbus/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase. | Opus · Plan → Execute |

### Testing

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-testing](./skills/engineering/swift-testing/SKILL.md) | Generates unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). Not for UI tests. | Sonnet · Direct |
| [/swift-uitest](./skills/testing/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. Runs out-of-process via XCTest. Not for unit tests. | Sonnet · Direct |
| [/swift-uitest-debug](./skills/testing/swift-uitest-debug/SKILL.md) | Diagnoses and fixes failing XCUITest tests — two Sonnet attempts, then Opus diagnosis. Always use this — do not debug UI tests ad hoc. | Sonnet → Opus · Direct |
| [/swift-test-all](./skills/testing/swift-test-all/SKILL.md) | Runs the full test suite once and reports results. Detects workspace, scheme, and simulator from `CLAUDE.md`. | Sonnet · Direct |
| [/regression-check](./skills/testing/regression-check/SKILL.md) | Audits in-progress code changes for side effects and regressions before they are committed — blast radius, behavioural ripples, concurrency regressions. | Sonnet · Direct |

### Reviewing & auditing

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-code-review](./skills/engineering/swift-code-review/SKILL.md) | Performs a Swift code review in-session — BLOCKER / WARNING / SUGGESTION findings with inline fixes. Run before commit or PR. | Opus · Direct |
| [/swift-deep-audit](./skills/engineering/swift-deep-audit/SKILL.md) | Exhaustive opinionated audit of a Swift/SwiftUI codebase — Swift 6 concurrency, separation of concerns, state management, test quality. | Opus · Plan → Execute |

### Concurrency

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-concurrency](./skills/engineering/swift-concurrency/SKILL.md) | Conceptual guidance — async/await, actors, Sendable, Swift 6 migration. Use to learn or explain. | Sonnet · Direct |
| [/swift-concurrency-expert](./skills/engineering/swift-concurrency-expert/SKILL.md) | Action-oriented — fix concrete concurrency errors, data races, isolation warnings, and Sendable gaps in existing code. | Sonnet · Direct |

### Tooling & CI

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-cidi](./skills/engineering/swift-cidi/SKILL.md) | Debug GitHub Actions CI for Xcode projects — flaky tests, xcresult artefacts, xctestplan setup. | Sonnet · Direct (Opus for complex failures) |
| [/swift-lint](./skills/engineering/swift-lint/SKILL.md) | Finds the nearest `.swiftlint.yml` and runs SwiftLint from the right directory. | Sonnet · Direct |
| [/xcodebuildmcp-cli](./skills/engineering/xcodebuildmcp-cli/SKILL.md) | Canonical CLI skill for XcodeBuildMCP — build, test, run, debug, log, UI automation on Apple platforms. | Sonnet · Direct |

### Pipelines

| Skill | What it does | Model · Flow |
|---|---|---|
| [/pipeline-preflight](./skills/pipelines/pipeline-preflight/SKILL.md) | Pre-flight checks before any pipeline starts — progress-doc drift, out-of-scope stories, dirty working tree. Cited by orchestrator commands; not invoked directly. | Sonnet · Direct |
| [/subagent-reliability](./skills/pipelines/subagent-reliability/SKILL.md) | Recovery procedure for dropped or crashed subagents — recover-in-place, resume, or re-spawn. Cited by orchestrators; not invoked directly. | Sonnet · Direct |

### Obsidian

| Skill | What it does | Model · Flow |
|---|---|---|
| [/obsidian-audit](./skills/obsidian/obsidian-audit/SKILL.md) | Vault hygiene sweep — fixes tags, normalises frontmatter, lifts inline fields into YAML. Auto-applies and logs a revertible changelog. | Sonnet · Direct |
| [/obsidian-learn](./skills/obsidian/obsidian-learn/SKILL.md) | Extracts durable knowledge from the current session and appends it to the Obsidian knowledge base. Run at end of session. | Sonnet · Direct |
| [/obsidian-manage](./skills/obsidian/obsidian-manage/SKILL.md) | Read, create, edit, search, and organise notes in the Obsidian vault. | Sonnet · Direct |
| [/obsidian-rollover](./skills/obsidian/obsidian-rollover/SKILL.md) | Carries incomplete to-do items from recent past daily notes into today's daily note. | Sonnet · Direct |
| [/daily-notes](./skills/obsidian/daily-notes/SKILL.md) | Generates first-person daily work notes from git history, file changes, and Jira. Runs entirely under Claude Code — no Claude.ai conversation tools required. | Sonnet · Direct |
| [/session-saver](./skills/obsidian/session-saver/SKILL.md) | Processes saved Claude Code session transcripts and extracts durable knowledge into the Obsidian knowledge base. | Sonnet · Direct |

### Productivity

| Skill | What it does | Model · Flow |
|---|---|---|
| [/plan-to-jira](./skills/productivity/plan-to-jira/SKILL.md) | Converts a plan or spec into a structured Jira ticket. Asks for confirmation before creating. | Sonnet · Direct |
| [/jira-bulk](./skills/productivity/jira-bulk/SKILL.md) | Bulk Jira operations — set fix version, transition status — across multiple tickets in one invocation. | Sonnet · Direct |
| [/yt-research](./skills/productivity/yt-research/SKILL.md) | Downloads transcripts and extracts prompts from a YouTube channel's recent videos, saving each as markdown in the Obsidian vault. | Sonnet · Direct |
| [/yt-distill](./skills/productivity/yt-distill/SKILL.md) | Distils a folder of YouTube transcript markdown files (output of yt-research) into a structured Obsidian reference library — skills, plugins, prompts, and techniques categories plus a master index. | Sonnet · Direct |

## Commands

Commands are markdown files under `commands/<bucket>/<name>.md` that Claude Code exposes as slash commands from `~/.claude/commands/`. They coordinate multiple skills into end-to-end pipelines.

### Mr Will

| Command | What it does |
|---|---|
| `/workflow` | Full ticket-to-PR pipeline — Jira / spec / prompt → discovery → engineer → test → quality → review → PR. Opus orchestrates; Sonnet handles execution phases. |
| `/audit-codebase` | Structured codebase audit — per-layer Sonnet subagents apply `swift-code-review`, findings grouped and prioritised into remediation batches ready for `/workflow`. |
| `/uitest-pipeline` | End-to-end XCUITest pipeline — AC intake → plan → execute → debug → PR artefacts. |

## Layout

```
Makefile                        — install, link, commands, hook targets
scripts/link-skills.sh          — symlinks skills into ~/.claude/skills/
scripts/link-commands.sh        — symlinks commands into ~/.claude/commands/
commands/                       — slash command markdown files
skills/engineering/             — Swift / iOS / Xcode / CI skills
skills/git/                     — generic git workflow skills
skills/obsidian/                — Obsidian vault management skills
skills/personal/                — personal setup skills (not listed in README; symlinked locally)
skills/pipelines/               — pipeline orchestration helpers (preflight, subagent reliability)
skills/productivity/            — Jira, planning, YouTube research, etc.
skills/testing/                 — Swift testing, quality, UI testing, regression auditing
skills/in-progress/             — drafts; not auto-discovered
skills/deprecated/              — retired skills; skipped by link-skills.sh
```

## Adding a skill

1. Create `skills/<bucket>/<name>/SKILL.md` with `name:` and `description:` frontmatter.
2. Add a row to the table above using the `/<name>` format.
3. Run `make link` to expose it locally.

## Adding a command

1. Create `commands/<bucket>/<name>.md` with the command definition.
2. Add a row to the Commands table above.
3. Run `make commands` to expose it locally.

See [`CLAUDE.md`](./CLAUDE.md) for the full bucket convention and the `in-progress` / `deprecated` lifecycle.
