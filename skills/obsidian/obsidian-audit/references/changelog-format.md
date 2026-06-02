# Changelog Format

Each audit run writes one markdown file at `~/obsidian/.audit/YYYY-MM-DD-HHMM-audit.md`.

## Top-level structure

```markdown
# Vault audit — 2026-04-29 15:42

- **Files audited:** 24
- **Files changed:** 18
- **Files unchanged:** 6
- **New tags accepted:** 2 (`screen-capture`, `analytics-events`)
- **New tags rejected (single-occurrence):** 7
- **Tags pruned:** 11
- **Properties added:** 47
- **Inline bullets lifted:** 9
- **Errors:** 0

## Per-file changes

### `projects/Onboarding/feature-separation-plan.md`

- **type:** _none_ → `plan`
- **status:** _none_ → `active` (lifted from inline `**Status:** In Progress`)
- **created:** _none_ → `2026-03-15`
- **updated:** _none_ → `2026-04-29`
- **jira:** _none_ → `PROJ-123` (lifted from inline `**Jira:** PROJ-123`)
- **tags added:** `plan`, `feature-work`
- **tags kept:** `ios`, `project-a`, `implementation-plan`
- **tags dropped:** _none_
- **bullets removed:** `- **Status:** In Progress`, `- **Jira:** PROJ-123`

### `inbox/random-thought.md`

- **type:** _none_ → `inbox`
- **created:** _none_ → `2026-04-28`
- **updated:** _none_ → `2026-04-28`
- **tags added:** `inbox`
- **tags dropped:** `xyz-123` (single-occurrence in vault, not relevant to content)

…

## Rejected new-tag candidates

These were proposed during Pass 1 but only matched 1 file each. Rejected per the 2+ rule.

- `legacy-auth-rewrite` — proposed for `projects/Auth Rewrite/legacy-auth-rewrite.md` only.
- `pusher-keepalive` — proposed for `projects/WebSocket/pusher-keepalive-investigation.md` only.

If you want any of these committed manually, run `/obsidian:manage` and add them via `property:set`.

## Flagged for review

These weren't auto-changed but the audit suggests the user look:

- `daily/2026/03-Mar/26-03-15.md` — has tag `project-a` (382 vault occurrences) but no body content mentioning the project. Consider removing.
- `reference/swift-concurrency-cheatsheet.md` — `mtime` is 187 days old. Consider `status: archived` or move to `reference/archive/`.

## Errors

None.

---

To revert everything from this audit:

    git -C ~/obsidian reset --hard HEAD

To revert one file:

    git -C ~/obsidian checkout HEAD -- <relative-path>
```

## Per-file entry rules

For every changed file, include:
- **Each property added/changed**, in the form `**<key>:** <old> → <new>` (use `_none_` for missing). When the value was lifted from an inline bullet, append `(lifted from inline ...)`.
- **Tag changes** as `**tags added:**`, `**tags kept:**`, `**tags dropped:**` lines. Always show the `dropped` line even when empty so the diff is auditable.
- **Bullets removed** when any inline-field bullet was lifted.

Do NOT include unchanged files in the per-file section. They appear only in the top-level `Files unchanged` count.

## Section ordering

1. Run header + summary counts
2. Per-file changes (alphabetical by relative path)
3. Rejected new-tag candidates
4. Flagged for review
5. Errors (always present, even if empty)
6. Revert instructions

## Markdown conventions

- Use level-1 heading for the run, level-2 for sections, level-3 for per-file entries.
- File paths are relative to the vault root, wrapped in backticks.
- Tag names appear without the `#` prefix (frontmatter style).
- Australian spelling throughout.
