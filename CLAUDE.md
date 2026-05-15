# swift-skills — internal notes

This repo is a Claude Code plugin (`.claude-plugin/plugin.json`) holding my Swift / iOS / tvOS skills.

## Layout

Skills live under `skills/<bucket>/<skill-name>/SKILL.md`. Buckets keep the tree organised as it grows.

- `git/` — generic git workflow: commit, push, PR creation.
- `engineering/` — Swift, SwiftUI, Xcode, CI, testing, concurrency, architecture, code review.
- `obsidian/` — Obsidian vault management, auditing, and knowledge extraction.
- `personal/` — skills tied to my own setup; **not** listed in `plugin.json` or `README.md`, but symlinked locally by `link-skills.sh`.
- `in-progress/` — drafts not ready to ship; **not** listed in `plugin.json`.
- `deprecated/` — kept for reference; **not** listed in `plugin.json` and skipped by `link-skills.sh`.

Every shipped skill must be referenced in both:

1. `.claude-plugin/plugin.json` — the `skills` array.
2. `README.md` — the table of skills.

## Adding a new skill

1. Create `skills/engineering/<name>/SKILL.md` (frontmatter: `name`, `description`).
2. Add `./skills/engineering/<name>` to `plugin.json`.
3. Add a row to the table in `README.md`, linking the name to its `SKILL.md`.
4. Run `scripts/link-skills.sh` to expose it locally.

## Removing or deprecating

- Move the dir to `skills/deprecated/<name>/` and remove from `plugin.json` and `README.md`.
- `link-skills.sh` already skips `deprecated/`.
