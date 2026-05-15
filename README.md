# swift-skills

A Claude Code plugin that packages Swift/iOS and Obsidian skills as discrete, reusable prompt modules.

## Why this exists

Claude Code's skill system lets you encode domain expertise into focused `SKILL.md` files rather than burying everything in a monolithic `CLAUDE.md`. Each skill is a self-contained module that tells Claude exactly how to approach a specific class of task — what to check, what to avoid, which model to reach for, and what a good outcome looks like.

Without skills, Claude pattern-matches on its training data. That works for generic tasks, but it falls apart for domain-specific ones. The `swift-tvos` skill exists because tvOS focus engine bugs are a case where Claude confidently shuffles code around and declares the bug fixed when nothing has changed — the skill enforces the diagnostic discipline that prevents that failure mode. The `swift-engineer` skill locks in the MV (Model-View) pattern rather than defaulting to MVVM. The `swift-audit` skill knows to check Swift 6 concurrency, actor isolation, and `@unchecked Sendable` usage — not just style.

This repo is the source of truth for those skills. It is also a Claude Code plugin, so it can be loaded project-by-project without touching the global `~/.claude/` setup.

## How skills work

Claude Code loads skills from `~/.claude/skills/`. Each skill is a directory containing a `SKILL.md` file with a `name:` and `description:` in its frontmatter. Claude uses the description to decide when to trigger the skill automatically, and you can invoke any skill explicitly with `/<skill-name>`.

The broader skill library (git, PM, GitNexus, prompting, daily notes, etc.) lives in [`~/Developer/myzsh`](https://github.com/jamiels/myzsh) alongside the install scripts that wire everything together. This repo contributes the Swift engineering and Obsidian buckets to that library.

## Install

### Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated
- `~/.claude/skills/` either absent or a real directory (not a symlink)

### Steps

```bash
git clone <repo-url> ~/Developer/Personal/skills
bash ~/Developer/Personal/skills/scripts/link-skills.sh
```

`link-skills.sh` walks every `skills/*/` bucket, finds each `SKILL.md`, and symlinks its parent directory into `~/.claude/skills/` using the directory name as the skill name. It skips `deprecated/` automatically.

Re-running the script is safe — it uses `ln -sfn` so existing symlinks are updated in place.

**One-time safety check:** if `~/.claude/skills` is itself a symlink pointing back into this repo, the script aborts with a clear error. Remove the stale symlink (`rm ~/.claude/skills`) and re-run — it will recreate the target as a real directory.

After install, verify the links:

```bash
ls -la ~/.claude/skills/
```

You should see one symlink per skill, each pointing into `~/Developer/Personal/skills/skills/`.

### Keeping skills up to date

```bash
git -C ~/Developer/Personal/skills pull
bash ~/Developer/Personal/skills/scripts/link-skills.sh
```

The symlinks already point into the repo, so a `git pull` alone updates skill content. Re-run the script only when skills are added or removed.

## Skills

Model and flow key from the broader skill library:

| Symbol | Meaning |
|---|---|
| **Opus** | Deep reasoning, architectural judgment, multi-step synthesis |
| **Sonnet** | Faster execution for well-defined tasks (default) |
| **Plan → Execute** | Enter plan mode first; Claude proposes an approach before touching files |
| **Direct** | Invoke and go — the task is well-scoped |

### Building

| Skill | What it does | Model · Flow |
|---|---|---|
| [swift-architect](./skills/engineering/swift-architect/SKILL.md) | Scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. | Opus · Plan → Execute |
| [swift-engineer](./skills/engineering/swift-engineer/SKILL.md) | Main building skill — writes new Swift 6.2 features, SwiftUI views, services, async work within the MV pattern. | Sonnet · Direct |
| [swift-quality](./skills/engineering/swift-quality/SKILL.md) | Rewrites code to meet the Swift Style Guide and project architecture rules without changing behaviour. | Sonnet · Direct |
| [swiftui-liquid-glass](./skills/engineering/swiftui-liquid-glass/SKILL.md) | Implement, review, or improve SwiftUI features using the iOS 26+ Liquid Glass API. | Sonnet · Direct |
| [swift-tvos](./skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus engine bugs in SwiftUI codebases. Always use this — do not attempt tvOS focus diagnosis ad hoc. | Sonnet · Direct |

### Documenting

| Skill | What it does | Model · Flow |
|---|---|---|
| [swift-document](./skills/engineering/swift-document/SKILL.md) | Adds or updates Apple DocC-style `///` documentation comments on Swift symbols. | Sonnet · Direct |
| [swiftopher-columbus](./skills/engineering/swiftopher-columbus/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase. | Opus · Plan → Execute |

### Testing

| Skill | What it does | Model · Flow |
|---|---|---|
| [swift-testing](./skills/engineering/swift-testing/SKILL.md) | Generates unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). Not for UI tests. | Sonnet · Direct |
| [swift-uitest](./skills/engineering/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. Not for unit tests — runs out-of-process via XCTest. | Sonnet · Direct |
| [swift-test-all](./skills/engineering/swift-test-all/SKILL.md) | Runs the test suite once and reports results. Detects workspace, scheme, and simulator from `CLAUDE.md`. | Sonnet · Direct |

### Reviewing & auditing

| Skill | What it does | Model · Flow |
|---|---|---|
| [swift-code-review](./skills/engineering/swift-code-review/SKILL.md) | Performs a Swift code review in-session — BLOCKER / WARNING / SUGGESTION findings with inline fixes. Run before commit/PR. | Opus · Direct |
| [swift-audit](./skills/engineering/swift-audit/SKILL.md) | Exhaustive audit of a Swift/SwiftUI codebase — Swift 6 concurrency, separation of concerns, state management, test quality. Outputs `AUDIT.md` with linked per-section files. | Opus · Plan → Execute |

### Concurrency

| Skill | What it does | Model · Flow |
|---|---|---|
| [swift-concurrency](./skills/engineering/swift-concurrency/SKILL.md) | Conceptual guidance — async/await, actors, Sendable, Swift 6 migration. Use to learn or explain. | Sonnet · Direct |
| [swift-concurrency-expert](./skills/engineering/swift-concurrency-expert/SKILL.md) | Action-oriented — fix concrete concurrency errors, data races, isolation warnings, and Sendable gaps in existing code. | Sonnet · Direct |

### Tooling & CI

| Skill | What it does | Model · Flow |
|---|---|---|
| [swift-cidi](./skills/engineering/swift-cidi/SKILL.md) | Debug GitHub Actions CI for Kick iOS/tvOS projects — flaky tests, xcresult artefacts, xctestplan setup. | Sonnet · Direct (Opus for complex failures) |
| [xcodebuildmcp-cli](./skills/engineering/xcodebuildmcp-cli/SKILL.md) | Use the XcodeBuildMCP CLI for iOS/macOS/watchOS/tvOS/visionOS work — build, test, run, debug, log, UI automation. | Sonnet · Direct |

### Obsidian

| Skill | What it does | Model · Flow |
|---|---|---|
| [daily-notes](./skills/obsidian/daily-notes/SKILL.md) | Generates daily work notes from git, Jira, and conversation activity. Appends a Work Log block to today's Obsidian daily note. | Sonnet · Direct |
| [obsidian-audit](./skills/obsidian/obsidian-audit/SKILL.md) | Vault hygiene sweep — fixes tags, normalises frontmatter, lifts inline fields into YAML properties. | Sonnet · Direct |
| [obsidian-learn](./skills/obsidian/obsidian-learn/SKILL.md) | Extracts durable knowledge from the current session and writes it to the Obsidian knowledge base. Run at end of session. | Sonnet · Direct |
| [obsidian-manage](./skills/obsidian/obsidian-manage/SKILL.md) | Read, create, edit, search, and organise notes in the Obsidian vault at `~/raw`. | Sonnet · Direct |
| [obsidian-rollover](./skills/obsidian/obsidian-rollover/SKILL.md) | Carries incomplete to-do items from recent past daily notes into today's daily note. | Sonnet · Direct |
| [session-saver](./skills/obsidian/session-saver/SKILL.md) | Processes raw Claude Code session transcripts from `~/raw/sessions/` and extracts durable knowledge into `~/raw/knowledge/`. Requires the `hooks/session-saver` binary — see [`hooks/README.md`](./hooks/README.md). | Sonnet · Direct |

## Layout

```
.claude-plugin/plugin.json   — plugin manifest (skills array)
scripts/link-skills.sh       — symlinks skills into ~/.claude/skills/
hooks/                       — hook binaries; see hooks/README.md for install steps
skills/engineering/          — Swift / iOS / Xcode / CI skills
skills/obsidian/             — Obsidian vault management skills
skills/in-progress/          — drafts; not listed in plugin.json
skills/deprecated/           — retired skills; skipped by link-skills.sh
```

## Adding a skill

1. Create `skills/engineering/<name>/SKILL.md` with `name:` and `description:` frontmatter.
2. Add `./skills/engineering/<name>` to the `skills` array in `.claude-plugin/plugin.json`.
3. Add a row to the table above.
4. Run `scripts/link-skills.sh` to expose it locally.

See [`CLAUDE.md`](./CLAUDE.md) for the full bucket convention and the `in-progress` / `deprecated` lifecycle.
