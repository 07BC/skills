---
name: obsidian:manage
description: Manage notes in the Obsidian vault at $HOME/raw using direct file operations. Use for reading, creating, editing, searching, or organising vault notes; working with daily notes; managing todos; browsing tags/properties/frontmatter; checking backlinks or orphans. Triggers on mentions of Obsidian, vault, daily note, knowledge base, second brain, or ~/raw paths. Not for vault-wide audits or tag taxonomy fixes — use obsidian:audit for those.
---

# Obsidian Vault Management

Manage the raw folder at `$HOME/raw` using direct file operations.

## Why direct file ops, not the Obsidian CLI

The Obsidian CLI (`obsidian` binary) has been observed to silently fail on
path resolution — `vault=obsidian` does not always resolve to the actual vault
location, and errors are emitted only on stderr (often suppressed by callers).

The vault is plain markdown files on disk. Use `Read`, `Edit`, `Write`,
`Glob`, `Grep`, and `Bash` for everything. No CLI binary required.

## Vault root

```bash
VAULT="$HOME/raw"
```

## Vault structure

```
$VAULT/
├── inbox/         # Unprocessed notes and ideas
├── daily/         # Daily notes: YYYY/MM-MMM/YY-MM-D.md
├── projects/      # Active project documentation
├── templates/     # Note templates
├── assets/        # Attachments (images, PDFs)
├── AI/            # AI-related artefacts (plans, sessions, knowledge)
│   ├── plans/
│   ├── sessions/
│   └── knowledge/
└── CLAUDE.md      # Vault-specific instructions
```

## Daily-note path formula

```
$VAULT/daily/YYYY/MM-MMM/YY-MM-D.md
```

- `YYYY` — full year (`2026`)
- `MM`   — zero-padded month (`05`)
- `MMM`  — three-letter month (`May`)
- `YY`   — two-digit year (`26`)
- `D`    — day **without** leading zero (`1`, `2`, …, `31`)

Compute today's path in bash:
```bash
YEAR=$(date +%Y); MM=$(date +%m); MMM=$(date +%b); YY=$(date +%y); D=$(date +%-d)
TODAY="$VAULT/daily/$YEAR/$MM-$MMM/$YY-$MM-$D.md"
```

## Core workflows

### 1. Read a note

Use the `Read` tool against the absolute path. For files known by name only,
use `Glob` to locate first:
```
Glob: $VAULT/**/<name>.md
```

### 2. Create a note

Use the `Write` tool. Default location is `$VAULT/inbox/<slug>.md` unless the
user specifies otherwise. Always include YAML frontmatter with at least
`tags`:
```markdown
---
tags:
- inbox
---

# Title

Content
```

### 3. Append or prepend to a note

Use `Edit` against the file. For a clean trailing append, find the last line
and insert after it. For prepending, insert immediately after the closing `---`
of the frontmatter.

### 4. Daily notes

Read today's note:
```bash
YEAR=$(date +%Y); MM=$(date +%m); MMM=$(date +%b); YY=$(date +%y); D=$(date +%-d)
TODAY="$VAULT/daily/$YEAR/$MM-$MMM/$YY-$MM-$D.md"
```
Then `Read` `$TODAY`. If it does not exist, create it from
`$VAULT/templates/daily-note.md`, substituting `{{date:YYYY-MM-DD}}` with
today's ISO date.

The daily-note template has these sections — preserve order:
1. **To-Do** — `- [ ]` checkboxes
2. **Notes** — freeform content (and any later sections like `## Work Log`,
   `## Meetings` appended below)

To add a todo: `Edit` the file, inserting `- [ ] <task>` at the end of the
`## To-Do` section.

To add meeting/work-log content: `Edit` the file, inserting a new
`## <Section>` block after the existing `## Notes` heading.

### 5. Search the vault

Use the `Grep` tool. Examples:
```
Grep pattern="search term" path=$VAULT
Grep pattern="search term" path=$VAULT/projects glob="*.md"
Grep pattern="^- \[ \]" path=$VAULT  # all open todos
```

### 6. Manage tasks

Open todos across the vault:
```
Grep pattern="^- \[ \]" path=$VAULT output_mode=content -n=true
```

Open todos in today's daily note: `Read` `$TODAY` and filter lines starting
with `- [ ]`.

Mark a task as done: `Edit` the file, changing `- [ ]` to `- [x]` on the
specific line.

### 7. Tags and properties

Find files with a given tag:
```
Grep pattern="^tags:" path=$VAULT -A=10 | grep -B 1 "<tag>"
```

Read a property value: `Read` the frontmatter and parse manually — frontmatter
is always between two `---` lines at the top of the file.

Set a property: `Edit` the frontmatter directly. For YAML lists (e.g. `tags`),
preserve the indentation:
```yaml
tags:
  - foo
  - bar
```

### 8. Browse and navigate

List files in a folder:
```
Glob pattern="$VAULT/projects/**/*.md"
```

List top-level folders:
```bash
ls -d $VAULT/*/
```

### 9. Links and backlinks

Outgoing links from a note: `Read` the file, extract `[text](path/to/file.md)`
and `[[wikilink]]` patterns.

Backlinks to a note:
```
Grep pattern="<target-filename>" path=$VAULT --include="*.md"
```
This is approximate — use the filename without extension as the search term.

Orphans / dead-ends / unresolved links: out of scope for direct file ops.
If the user explicitly needs them, fall back to running the Obsidian app
manually, or accept that the answer requires the index.

### 10. Move and organise

Move a note: `Bash` `mv "$VAULT/inbox/foo.md" "$VAULT/projects/foo.md"`. Then
update any internal links that reference the old path.

Rename a note: `Bash` `mv "$VAULT/<old>.md" "$VAULT/<new>.md"` then update
links.

Delete a note: `Bash` `rm "$VAULT/<file>.md"`. Confirm with the user before
deleting — there is no Obsidian trash with direct file ops.

## Conventions

- **File naming**: kebab-case for general notes, `YY-MM-D.md` for daily notes,
  `NAT-[number]-[description].md` for specs.
- **Links**: Use markdown links `[text](path/to/file.md)`, not wikilinks.
- **Frontmatter**: All notes should have YAML frontmatter with at least `tags`.
- **Spelling**: Australian English (colour, behaviour, organisation).
- **New notes**: Default to `inbox/` unless a specific location is given.
- **Templates**: Browse `$VAULT/templates/` for available templates.

## Legacy CLI reference

For historical context only — do not use in new work. See
[references/cli-reference.md](references/cli-reference.md).
