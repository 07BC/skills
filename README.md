# swift-skills

## Why this exists

Claude Code's skill system lets you encode domain expertise into focused `SKILL.md` files rather than burying everything in a monolithic `CLAUDE.md`. Each skill is a self-contained module that tells Claude exactly how to approach a specific class of task — what to check, what to avoid, which model to reach for, and what a good outcome looks like.

Without skills, Claude pattern-matches on its training data. That works for generic tasks, but it falls apart for domain-specific ones. The `swift-tvos` skill exists because tvOS focus engine bugs are a case where Claude confidently shuffles code around and declares the bug fixed when nothing has changed — the skill enforces the diagnostic discipline that prevents that failure mode. The `swift-engineer` skill locks in the MV (Model-View) pattern rather than defaulting to MVVM. The `swift-audit` skill knows to check Swift 6 concurrency, actor isolation, and `@unchecked Sendable` usage — not just style.

This repo is the source of truth for those skills. It is also a Claude Code plugin, so it can be loaded project-by-project without touching the global `~/.claude/` setup.

## How skills work

Claude Code loads skills from `~/.claude/skills/`. Each skill is a directory containing a `SKILL.md` file with a `name:` and `description:` in its frontmatter. Claude uses the description to decide when to trigger the skill automatically, and you can invoke any skill explicitly with `/<skill-name>`.

## My Workflow

### Model and flow key

| Symbol | Meaning |
|---|---|
| **Opus** | Use Opus 4 (`/model opus`). Better for deep reasoning, architectural judgment, and multi-step synthesis. |
| **Sonnet** | Use Sonnet 4 (default). Faster for well-defined execution tasks. |
| **Plan → Execute** | Enter plan mode first (the ↗ button or `/plan`). Claude proposes an approach before touching any files — essential when the wrong move is expensive. |
| **Direct** | Just invoke it. The task is well-scoped enough to execute without a planning phase. |

---

### Swift development pipeline

The five Swift skills below form a feature-development pipeline. Pick by
**verb**, not by file type.

```
swift:architect ──► swift:engineer ──► swift:quality ──► swift:code-review ──► swift:audit
    (design)           (build)            (clean)             (review)              (audit)
```

## Install

### Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated

### Steps

In any Claude Code session:

```
/plugin marketplace add 07BC/skills
/plugin install j@07BC-skills
```

Skills are then available as `/j:<skill-name>` — e.g. `/j:swift-engineer`, `/j:swift-tvos`.

### Keeping skills up to date

```
/plugin update j
```

## Skills

Model and flow key from the broader skill library:

| Symbol | Meaning |
|---|---|
| **Opus** | Deep reasoning, architectural judgment, multi-step synthesis |
| **Sonnet** | Faster execution for well-defined tasks (default) |
| **Plan → Execute** | Enter plan mode first; Claude proposes an approach before touching files |
| **Direct** | Invoke and go — the task is well-scoped |

### Git workflow

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:git-commit](./skills/git/git-commit/SKILL.md) | Stages specific files and commits with a short imperative message. Extracts a ticket prefix from the branch name if present. | Sonnet · Direct |
| [/j:git-push](./skills/git/git-push/SKILL.md) | Runs the project formatter, commits, then pushes. Builds on git-commit. | Sonnet · Direct |
| [/j:git-pr](./skills/git/git-pr/SKILL.md) | Commits, pushes, runs tests and code review, then creates a PR with a summary and end-user test plan. Builds on git-push. | Sonnet · Direct |

### Building

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:swift-architect](./skills/engineering/swift-architect/SKILL.md) | Scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. | Opus · Plan → Execute |
| [/j:swift-engineer](./skills/engineering/swift-engineer/SKILL.md) | Main building skill — writes new Swift 6.2 features, SwiftUI views, services, async work within the MV pattern. | Sonnet · Direct |
| [/j:swift-quality](./skills/engineering/swift-quality/SKILL.md) | Rewrites code to meet the Swift Style Guide and project architecture rules without changing behaviour. | Sonnet · Direct |
| [/j:swiftui-liquid-glass](./skills/engineering/swiftui-liquid-glass/SKILL.md) | Implement, review, or improve SwiftUI features using the iOS 26+ Liquid Glass API. | Sonnet · Direct |
| [/j:swift-tvos](./skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus engine bugs in SwiftUI codebases. Always use this — do not attempt tvOS focus diagnosis ad hoc. | Sonnet · Direct |

### Documenting

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:swift-document](./skills/engineering/swift-document/SKILL.md) | Adds or updates Apple DocC-style `///` documentation comments on Swift symbols. | Sonnet · Direct |
| [/j:swiftopher-columbus](./skills/engineering/swiftopher-columbus/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase. | Opus · Plan → Execute |

### Testing

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:swift-testing](./skills/engineering/swift-testing/SKILL.md) | Generates unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). Not for UI tests. | Sonnet · Direct |
| [/j:swift-uitest](./skills/engineering/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. Not for unit tests — runs out-of-process via XCTest. | Sonnet · Direct |
| [/j:swift-test-all](./skills/engineering/swift-test-all/SKILL.md) | Runs the test suite once and reports results. Detects workspace, scheme, and simulator from `CLAUDE.md`. | Sonnet · Direct |

### Reviewing & auditing

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:swift-code-review](./skills/engineering/swift-code-review/SKILL.md) | Performs a Swift code review in-session — BLOCKER / WARNING / SUGGESTION findings with inline fixes. Run before commit/PR. | Opus · Direct |
| [/j:swift-audit](./skills/engineering/swift-audit/SKILL.md) | Exhaustive audit of a Swift/SwiftUI codebase — Swift 6 concurrency, separation of concerns, state management, test quality. Outputs `AUDIT.md` with linked per-section files. | Opus · Plan → Execute |

### Concurrency

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:swift-concurrency](./skills/engineering/swift-concurrency/SKILL.md) | Conceptual guidance — async/await, actors, Sendable, Swift 6 migration. Use to learn or explain. | Sonnet · Direct |
| [/j:swift-concurrency-expert](./skills/engineering/swift-concurrency-expert/SKILL.md) | Action-oriented — fix concrete concurrency errors, data races, isolation warnings, and Sendable gaps in existing code. | Sonnet · Direct |

### Tooling & CI

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:swift-cidi](./skills/engineering/swift-cidi/SKILL.md) | Debug GitHub Actions CI for Kick iOS/tvOS projects — flaky tests, xcresult artefacts, xctestplan setup. | Sonnet · Direct (Opus for complex failures) |
| [/j:xcodebuildmcp-cli](./skills/engineering/xcodebuildmcp-cli/SKILL.md) | Use the XcodeBuildMCP CLI for iOS/macOS/watchOS/tvOS/visionOS work — build, test, run, debug, log, UI automation. | Sonnet · Direct |

### Obsidian

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:obsidian-audit](./skills/obsidian/obsidian-audit/SKILL.md) | Vault hygiene sweep — fixes tags, normalises frontmatter, lifts inline fields into YAML properties. | Sonnet · Direct |
| [/j:obsidian-learn](./skills/obsidian/obsidian-learn/SKILL.md) | Extracts durable knowledge from the current session and writes it to the Obsidian knowledge base. Run at end of session. | Sonnet · Direct |
| [/j:obsidian-manage](./skills/obsidian/obsidian-manage/SKILL.md) | Read, create, edit, search, and organise notes in the Obsidian vault at `~/raw`. | Sonnet · Direct |
| [/j:obsidian-rollover](./skills/obsidian/obsidian-rollover/SKILL.md) | Carries incomplete to-do items from recent past daily notes into today's daily note. | Sonnet · Direct |

### Productivity

| Skill | What it does | Model · Flow |
|---|---|---|
| [/j:plan-to-jira](./skills/productivity/plan-to-jira/SKILL.md) | Converts a plan or spec into a structured Jira ticket. Infers project, labels, and components from context, then asks via `AskUserQuestion` before creating. | Sonnet · Direct |

## Layout

```
.claude-plugin/plugin.json      — plugin manifest
.claude-plugin/marketplace.json — marketplace registration
scripts/link-skills.sh          — symlinks skills into ~/.claude/skills/ (local dev)
skills/engineering/             — Swift / iOS / Xcode / CI skills
skills/git/                     — generic git workflow skills
skills/obsidian/                — Obsidian vault management skills
skills/productivity/            — cross-project productivity skills (Jira, planning, etc.)
skills/in-progress/             — drafts; not auto-discovered
skills/deprecated/              — retired skills; skipped by link-skills.sh
```

## Adding a skill

1. Create `skills/<bucket>/<name>/SKILL.md` with `name:` and `description:` frontmatter.
2. Add a row to the table above using the `/j:<name>` prefix.
3. Run `scripts/link-skills.sh` to expose it locally, or reinstall the plugin.

See [`CLAUDE.md`](./CLAUDE.md) for the full bucket convention and the `in-progress` / `deprecated` lifecycle.
