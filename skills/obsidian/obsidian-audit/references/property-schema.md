# Property Schema

## Standard properties

Every audited note should have these properties in YAML frontmatter when relevant:

| Property | Type | Required? | Inference rule |
|---|---|---|---|
| `type` | string | yes | From folder + content. See [Type inference](#type-inference). |
| `created` | ISO 8601 date | yes | File birth time (`stat -f %SB -t '%Y-%m-%d' <file>` on macOS). Set on first audit only — never overwrite. |
| `updated` | ISO 8601 date | yes | File mtime (`stat -f %Sm -t '%Y-%m-%d' <file>`). Always overwrite. |
| `status` | string | when applicable | One of `draft`, `active`, `done`, `archived`. See [Status inference](#status-inference). Skip for `daily` and `reference` types. |
| `jira` | string | when matched | A Jira key like `PROJ-123`. From inline lift OR filename pattern OR body match. |
| `platform` | string | when matched | One of `ios`, `tvos`, `macos`, `web`. From inline lift OR matching tag. |

Properties are scalar where possible. Lists (`tags`) stay as YAML arrays.

## Type inference

Match in this order — first match wins:

1. File path under `daily/` → `type: daily`.
2. File path under `templates/` → skip (excluded from audit).
3. File path under `inbox/` AND has no other clear type signal → `type: inbox`.
4. File path under `reference/` → `type: reference`.
5. Filename matches `PROJ-\d+` OR body has `## Acceptance criteria` heading → `type: spec`.
6. File path under `projects/` AND body contains "implementation plan", "## Plan", or "## Steps" → `type: plan`.
7. File path under `projects/` AND body contains "## Problem" + "## Users" + "## Solution" headings → `type: prd`.
8. File path under `projects/` (default) → `type: project`.
9. Body contains "## Research", "## Findings", or "## Hypotheses" → `type: research`.
10. Otherwise → `type: note`.

## Status inference

Skip status for `daily` and `reference` types.

For `spec`, `plan`, `prd`, `project`, `note`:

| Body signal | Status |
|---|---|
| Inline field `**Status:** Draft` (case-insensitive) | `draft` |
| Inline field `**Status:** Active`, `In Progress`, `Doing` | `active` |
| Inline field `**Status:** Done`, `Complete`, `Shipped`, `Closed` | `done` |
| Inline field `**Status:** Archived`, `Abandoned`, `Cancelled` | `archived` |
| File `mtime` is older than 90 days AND no explicit status field | `archived` (only if no other signal — log "stale, set archived" in changelog) |
| Tag `wip`, `in-progress`, or `active` present | `active` |
| Tag `done` or `shipped` present | `done` |
| No signal | omit `status` |

Never overwrite an existing `status` value with a less-specific inference. Only fill in when missing.

## Inline-field lifting

Many notes have human-written field bullets near the top:

```markdown
- **Status:** Draft
- **Jira:** PROJ-123
- **Last updated:** 2026-04-12
- **Platform:** iOS
- **Version:** 0.1
- **Owner:** @jamie
```

When detected, lift them into frontmatter and **delete** the bullet line. Mapping:

| Bullet pattern | Frontmatter property |
|---|---|
| `- **Status:** <value>` | `status: <normalised>` (use status table above) |
| `- **Jira:** <value>` | `jira: <value>` (strip whitespace, uppercase the project prefix, e.g. `PROJ-123`) |
| `- **Last updated:** <date>` | `updated: <date>` (overrides mtime — explicit beats inferred) |
| `- **Platform:** <value>` | `platform: <lowercased>` |
| `- **Version:** <value>` | `version: <value>` |
| `- **Owner:** <value>` | `owner: <value>` |

The match is forgiving on whitespace and bold style (`**`/`__`). Match case-insensitively on the field label. The bullet must be a top-level list item in the first 30 lines of the body — don't lift bullets from deeper sections.

If the same field appears as both a frontmatter property and an inline bullet, **trust the bullet** (it's the human-written one). Update frontmatter, then delete the bullet.

## Defaults preserved

- Never touch existing `aliases`, `cssclass`, `publish`, or any property the schema doesn't list above. Leave them as-is.
- Never delete a frontmatter key just because the schema doesn't know about it.
- Never reorder existing keys — only add new ones at the bottom (or a stable order: `tags` first, then `type`, `status`, `created`, `updated`, then everything else).

## Worked example

Input note:

```markdown
---
tags:
- ios
- feature-work
---

# Feature separation plan

- **Status:** In Progress
- **Jira:** PROJ-123

## Summary
…
```

After audit:

```markdown
---
tags:
- ios
- feature-work
type: plan
status: active
created: 2026-03-15
updated: 2026-04-29
jira: PROJ-123
---

# Feature separation plan

## Summary
…
```

The two inline bullets were lifted and removed. `type: plan` was inferred from the body's "## Summary" + plan-style filename. `status: active` was inferred from `In Progress`.
