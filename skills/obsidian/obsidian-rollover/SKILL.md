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

Compute today's path in bash:
```bash
YEAR=$(date +%Y); MM=$(date +%m); MMM=$(date +%b); YY=$(date +%y); D=$(date +%-d)
TODAY="$VAULT/daily/$YEAR/$MM-$MMM/$YY-$MM-$D.md"
```

---

## Step 1 — Locate today's note

Compute today's path (formula above). If the file does not exist, create it
from the template at `$VAULT/templates/daily-note.md` using `Write`:

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

## Step 2 — Read today's existing todos

`Read` today's file. Extract every line that begins with `- [ ]` from the
`## To-Do` section. This is the **dedupe list** — any task whose text already
appears here must not be added again (case-insensitive, strip markdown links to
compare plain text).

---

## Step 3 — Find recent past notes

Calculate the last **7 days** of dates (excluding today) from `currentDate`.
For each date, construct the path using the same formula and `Read` the file.
Process in reverse chronological order (most recent first). Skip any date
where the file does not exist.

---

## Step 4 — Extract incomplete items

For each past note (most recent first), collect lines matching `- [ ]` that:

1. Are **not** already in today's dedupe list
2. Are **not** blank placeholders (`- [ ]` alone or with only whitespace after)
3. Have **not** been completed (do not appear as `- [x]` in any note being scanned)

Deduplicate across source dates — if the same task appears in multiple past
notes, only include it once. Stop scanning beyond 7 days.

---

## Step 5 — Insert into today's note

Use the `Edit` tool on today's file to insert the new incomplete items directly
into the `## To-Do` section, immediately before the `---` divider that follows
it (or above `## Meetings` if that section exists). No grouping labels, no
headers — just plain `- [ ]` lines, with a blank line separating them from the
last existing item.

---

## Step 6 — Report

Print a brief summary:

```
Rolled over N task(s):
  - task text
  - task text

Nothing new to roll over.   ← use this if N = 0
```

No extra output. No explanation of what the skill does.
