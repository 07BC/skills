# swift-skills — internal notes

This repo is a Claude Code plugin installed via `/plugin marketplace add 07BC/skills`. Skills are invoked with the `/jls:` namespace prefix (e.g. `/jls:swift-engineer`).

## Layout

Skills live under `skills/<bucket>/<skill-name>/SKILL.md`. Buckets keep the tree organised as it grows.

- `git/` — generic git workflow: commit, push, PR creation.
- `engineering/` — Swift, SwiftUI, Xcode, CI, testing, concurrency, architecture, code review.
- `obsidian/` — Obsidian vault management, auditing, and knowledge extraction.
- `personal/` — skills tied to my own setup; **not** in `README.md`, but symlinked locally by `link-skills.sh`.
- `in-progress/` — drafts not ready to ship; not auto-discovered by the plugin.
- `deprecated/` — kept for reference; skipped by `link-skills.sh` and not auto-discovered.

Skills are auto-discovered from the `skills/` directory — no enumeration needed in `plugin.json`.

Every shipped skill must be referenced in `README.md` using the `/jls:<name>` prefix.

## Adding a new skill

1. Create `skills/<bucket>/<name>/SKILL.md` (frontmatter: `name`, `description`).
2. Add a row to the table in `README.md` with `/jls:<name>` as the skill label.
3. Run `scripts/link-skills.sh` to expose it locally, or run `/plugin update j` if the plugin is installed.

## Removing or deprecating

- Move the dir to `skills/deprecated/<name>/` and remove from `README.md`.
- `link-skills.sh` already skips `deprecated/`, and the plugin system won't auto-discover it.
