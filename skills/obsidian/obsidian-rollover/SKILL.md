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

Run `scripts/rollover.py --dry-run` first to preview the rollover.
Inspect the preview output:

- Are all expected tasks present?
- Are duplicates being correctly filtered (no entry that's already in today's `## To-Do`)?
- Are completed tasks (`- [x]`) correctly excluded?

If the preview looks wrong, halt and debug before re-running without
`--dry-run`. A real write is hard to unwind cleanly.

If the script exits non-zero (vault not found, daily note missing,
permission denied), do not retry blindly — read the error message and
fix the underlying cause first. The most common failures: today's
daily note hasn't been created yet (run Step 1), or `$VAULT` points at
a non-git directory.

When the preview looks correct, re-run without `--dry-run`.

### How the script works

`scripts/rollover.py` uses the Obsidian CLI (`obsidian tasks todo/done`)
for all task queries. The final write uses `Path.write_text()` directly
because it inserts tasks at a specific position *within* the
`## To-Do` section (before the `---` divider) — `obsidian daily:append`
only appends to EOF and cannot do positional section insertion.

- Queries today's `## To-Do` section via `obsidian tasks todo daily` to
  build a dedupe list (case-insensitive, markdown links and bold/italic
  markers stripped).
- Walks back the last 7 days (override with `--days N`) and collects
  every `- [ ]` line via `obsidian tasks todo path=<rel>`, scanning
  newest-first so the most recent version of a task wins.
- Filters out: empty placeholders, items already present in today's
  note, items that appear as `- [x]` anywhere in the scanned window,
  and near-duplicates of already-accepted tasks.
- Inserts survivors into today's `## To-Do` section, just before the
  `---` divider that follows it, with a blank line separating them
  from the last existing item.

### Near-duplicate detection rules

Detection runs after bold (`**...**`) and italic (`*...*`) markers are
stripped from both candidate and accepted-task text. Two checks apply
in order:

1. **Substring containment** — for tasks longer than 30 characters,
   if one task's stripped text contains the other's, they are treated
   as duplicates. Example: "Monday first: Debug API rate limit" and
   "Debug API rate limit" — duplicate.
2. **Key-before-separator match** — both tasks are split on the
   first ` — ` (em-dash with surrounding spaces). If the prefix
   before the separator matches, they are duplicates. Example:
   "Debug API rate limit — followed up Tuesday" and "Debug API rate
   limit — context note" — duplicate.

If neither rule matches, the candidate is accepted.

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
