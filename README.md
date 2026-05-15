# swift-skills

A Claude Code plugin bundling my Swift, SwiftUI, and Xcode skills — focused on the MV (Model-View) pattern, Swift 6 concurrency, and iOS / tvOS work.

## Install

Clone, then symlink each skill into `~/.claude/skills/`:

```bash
git clone <repo-url> ~/Developer/Personal/skills
bash ~/Developer/Personal/skills/scripts/link-skills.sh
```

`link-skills.sh` symlinks the parent directory of every `SKILL.md` under `skills/` into `~/.claude/skills/`. It refuses to run if `~/.claude/skills` itself is a symlink into this repo (which would create cycles).

## Skills

### Building

| Skill | What it does |
|---|---|
| [swift-architect](./skills/engineering/swift-architect/SKILL.md) | Scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. |
| [swift-engineer](./skills/engineering/swift-engineer/SKILL.md) | Main building skill — writes new Swift 6.2 features, SwiftUI views, services, async work. |
| [swift-quality](./skills/engineering/swift-quality/SKILL.md) | Rewrites code to meet the Swift Style Guide and project architecture rules. |
| [swiftui-liquid-glass](./skills/engineering/swiftui-liquid-glass/SKILL.md) | Implement, review, or improve SwiftUI features using the iOS 26+ Liquid Glass API. |
| [swift-tvos](./skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus engine bugs in SwiftUI codebases. |

### Documenting

| Skill | What it does |
|---|---|
| [swift-document](./skills/engineering/swift-document/SKILL.md) | Adds or updates Apple DocC-style `///` documentation comments on Swift symbols. |
| [swiftopher-columbus](./skills/engineering/swiftopher-columbus/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase. |

### Testing

| Skill | What it does |
|---|---|
| [swift-testing](./skills/engineering/swift-testing/SKILL.md) | Generate unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). |
| [swift-uitest](./skills/engineering/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. |
| [swift-test-all](./skills/engineering/swift-test-all/SKILL.md) | Runs the Swift test suite once for the current project and reports results. |

### Reviewing & auditing

| Skill | What it does |
|---|---|
| [swift-code-review](./skills/engineering/swift-code-review/SKILL.md) | Performs a Swift code review with BLOCKER / WARNING / SUGGESTION findings and inline fixes. |
| [swift-audit](./skills/engineering/swift-audit/SKILL.md) | Exhaustive, opinionated audit of a Swift/SwiftUI codebase — outputs `AUDIT.md` with linked sections. |

### Concurrency

| Skill | What it does |
|---|---|
| [swift-concurrency](./skills/engineering/swift-concurrency/SKILL.md) | Conceptual guidance and reference for Swift Concurrency patterns. |
| [swift-concurrency-expert](./skills/engineering/swift-concurrency-expert/SKILL.md) | Action-oriented review and fix for Swift Concurrency issues in existing code. |

### Tooling & CI

| Skill | What it does |
|---|---|
| [swift-cidi](./skills/engineering/swift-cidi/SKILL.md) | GitHub Actions CI/CD workflows for Kick iOS and tvOS Xcode projects. |
| [xcodebuildmcp-cli](./skills/engineering/xcodebuildmcp-cli/SKILL.md) | Official skill for the XcodeBuildMCP CLI (build, test, run, debug, log, UI automation). |

## Layout

```
.claude-plugin/plugin.json   # plugin manifest
scripts/link-skills.sh       # symlink skills into ~/.claude/skills/
skills/engineering/          # all shipped skills live here
```

See [`CLAUDE.md`](./CLAUDE.md) for the bucket convention and how to add a new skill.
