# swift-skills

## What is it

This is a repository of custom skills for Developement on apple devices.

It covers:

- Swift
- SwiftUI
- Swift Test
- Apple Liquid Glass
- iOS, MacOS, tvOS

It also covers note management for Obsidian.

## Target Architectures

The [Target Architecture](docs/target_architecture/README.md) contains the layout for a modern, MV (Model View) Application

### Managing Claude

This repo is installed locally via `make install`. 
- Skills are symlinked into `~/.claude/skills/`
- Commands are symlinked into `~/.claude/commands/`
- Agents are symlinked into `~/.claude/agents/`
- Hooks are installed into `~/.claude/hooks/`

## Layout

- Skills live under `skills/<bucket>/<skill-name>/SKILL.md`. Buckets keep the tree organised as it grows.
- Commands live under `commands/<bucket>/<command-name>.md`. Buckets keep the tree organised as it grows.
- Agents live under `agents/<name>.md` (flat directory). Symlinked into `~/.claude/agents/` by `make agents`.

- `git/` — generic git workflow: commit, push, PR creation.
- `engineering/` — Swift, SwiftUI, Xcode, CI, testing, concurrency, architecture, code review.
- `documentation/` — document-authoring skills: specs, discovery notes, DocC comments, architecture docs, and skill-library ADRs.
- `obsidian/` — Obsidian vault management, auditing, and knowledge extraction.
- `personal/` — skills tied to my own setup; **not** in `README.md`, but symlinked locally by `link-skills.sh`.
- `in-progress/` — drafts not ready to ship. NOTE: `link-skills.sh` does NOT currently
  exclude `in-progress/`, so these skills ARE symlinked and auto-discovered. The ios-*
  skills (`ios-app-intents`, `ios-debugger-agent`, `ios-ettrace-performance`,
  `ios-memgraph-leaks`) live here pending a ship-or-consolidate decision. Do not add
  them to `README.md` without resolving their README/consolidation status first.
- `deprecated/` — kept for reference; skipped by `link-skills.sh` and not auto-discovered.

Skills are auto-discovered from the `skills/` directory — no manual enumeration needed.

Every shipped skill must be referenced in `README.md` using the `/<name>` prefix.

## Skill species

Skills fall into three species, distinguished by frontmatter (see
[ADR 0004](docs/adr/0004-skill-species-invocation-frontmatter.md)). The two
fields are not interchangeable: `disable-model-invocation: true` stops Claude
auto-firing the skill but still allows explicit invocation (the Skill tool, a
`/command`); `user-invocable: false` only hides it from the user's `/` menu and
does **not** stop auto-fire.

| Species | Meaning | Frontmatter |
| --- | --- | --- |
| **Executor** | Does work; auto-fires on its description; the default. | none |
| **Policy** | Cited by orchestrators via the Skill tool; must not auto-fire on user messages (e.g. `pipeline-preflight`, `subagent-reliability`). | `disable-model-invocation: true` |
| **Dependency** | Loaded by another skill, not a user action (e.g. `swift-style`). | `user-invocable: false` + `disable-model-invocation: true` |

Reference skills that should still surface on relevant questions but aren't a
user action (e.g. `swift-concurrency`) take `user-invocable: false` alone.
`tests/python/test_skill_taxonomy.py` enforces the policy/dependency markers.

## Adding a new skill

1. Create `skills/<bucket>/<name>/SKILL.md` (frontmatter: `name`, `description`).
2. Add a row to the table in `README.md` with `/<name>` as the skill label.
3. Run `make link` to expose it locally.

## Adding a new command

1. Create `commands/<bucket>/<name>.md` with command definition.
2. Run `make commands` to expose it locally.

## Adding a new orchestrator

An orchestrator is a command or skill that drives multi-step work by spawning
subagents and gating phases (`workflow`, `uitest-pipeline`, `audit-codebase`,
`solve`, `spec-pipeline`). Follow [`docs/orchestrator-contract.md`](docs/orchestrator-contract.md)
— copy its skeleton, then add the new file's path to the `ORCHESTRATORS` list in
`tests/python/test_orchestrator_conformance.py`. `make test` enforces the
contract.

## Removing or deprecating

- Move the dir to `skills/deprecated/<name>/` and remove from `README.md`.
- `link-skills.sh` already skips `deprecated/`, so it won't be symlinked or auto-discovered.
