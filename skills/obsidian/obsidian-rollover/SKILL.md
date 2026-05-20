---
name: obsidian:rollover
description: >
  Carries incomplete to-do items from recent past daily notes into today's
  Obsidian daily note. Use when the user says "rollover", "obsidian rollover",
  "roll todos forward", or "copy incomplete tasks to today". Runs silently and
  reports what was moved.
---

# Obsidian Rollover Skill

Copies incomplete `- [ ]` items from past daily notes into today's `## To-Do`
section. Never duplicates. Never carries forward completed items.

---

## Vault root

Resolved at runtime via the Obsidian CLI:

```bash
obsidian vault info=path   # → absolute vault root
obsidian daily:path        # → today's note relative to vault root
```

Use `scripts/daily_note_path.sh` to get the absolute path for today (no arg) or
a specific date (`scripts/daily_note_path.sh 2026-05-16`). The script calls the
CLI internally — no hardcoded path needed.

---

## Step 0 — (optional) Vault preflight

If the user wants a clean baseline before the rollover edit, run
`scripts/vault_preconditions.sh`. It exits non-zero if the vault is missing,
not a git repo, or has uncommitted changes. Treat the failure as a soft
warning — the user can decide to proceed or stash first.

---

## Step 1 — Ensure today's note exists

Run `scripts/daily_note_path.sh` to get today's path. If the file does not
exist, create it from the template at `$VAULT/templates/daily-note.md` using
`Write`:

```
---
tags:
- daily
---

# {YYYY-MM-DD}

## To-Do

- [ ]

---

## Notes
```

Substitute `{YYYY-MM-DD}` with today's ISO date.

---

## Step 2 — Roll over incomplete tasks

Run `scripts/rollover.py`. The script uses the Obsidian CLI (`obsidian tasks todo/done`) for all task queries and handles the full workflow:

- Queries today's `## To-Do` section via `obsidian tasks todo daily` to build a dedupe list (case-insensitive, markdown links and bold/italic markers stripped).
- Walks back the last 7 days (override with `--days N`) and collects every `- [ ]` line via `obsidian tasks todo path=<rel>`, scanning newest-first so the most recent version of a task wins.
- Filters out: empty placeholders, items already present in today's note, items that appear as `- [x]` anywhere in the scanned window, and near-duplicates of already-accepted tasks.
- Near-duplicate detection strips bold/italic markers then applies two checks: (1) substring containment for tasks longer than 30 chars (catches a task prefixed with e.g. "Monday first: " matching a later version without the prefix); (2) same key before the ` — ` separator (catches the same task heading with a rephrased context note).
- Inserts survivors into today's `## To-Do` section, just before the `---` divider that follows it, with a blank line separating them from the last existing item.

Use `--dry-run` first if you want to see what would change before writing.

Output on success:

```
Rolled over N task(s):
  - task text
  - task text
```

Or, if there is nothing to do:

```
Nothing new to roll over.
```
