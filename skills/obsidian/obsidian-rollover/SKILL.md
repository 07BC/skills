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

```
VAULT="$HOME/raw"
```

The Obsidian CLI is flaky (silent path-resolution failures). Operate on the
vault as plain markdown files using `Read`, `Edit`, `Write`, `Glob`, `Grep`.

Daily note path format:
```
$VAULT/daily/YYYY/MM-MMM/YY-MM-D.md
```
where `YYYY` = full year, `MM` = zero-padded month (`05`), `MMM` = three-letter
month (`May`), `YY` = two-digit year (`26`), `D` = day **without** leading zero
(`1`, `2`, …, `31`).

Use `scripts/daily_note_path.sh` to compute the path for today (no arg) or for
a specific date (`scripts/daily_note_path.sh 2026-05-16`).

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

Run `scripts/rollover.py`. The script handles the full workflow:

- Reads today's `## To-Do` section to build a dedupe list (case-insensitive,
  markdown links stripped).
- Walks back the last 7 days (override with `--days N`) and collects every
  `- [ ]` line from any daily note that exists.
- Filters out: empty placeholders, items already present in today's note, and
  items that appear as `- [x]` anywhere in the scanned window.
- Inserts survivors into today's `## To-Do` section, just before the `---`
  divider that follows it, with a blank line separating them from the last
  existing item.

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
