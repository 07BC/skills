---
name: obsidian:manage
description: Manage notes in the Obsidian vault at $HOME/Developer/obsidian using the Obsidian CLI. Use for reading, creating, editing, searching, or organising vault notes; working with daily notes; managing todos; browsing tags/properties/frontmatter; checking backlinks or orphans. Triggers on mentions of Obsidian, vault, daily note, knowledge base, second brain, or ~/Developer/obsidian paths. Not for vault-wide audits or tag taxonomy fixes — use obsidian:audit for those.
---

# Obsidian Vault Management

Manage the Obsidian vault at `$HOME/Developer/obsidian` using the Obsidian CLI
and direct file operations.

## Vault root

```bash
VAULT=$(obsidian vault info=path)   # resolves to $HOME/Developer/obsidian
```

Use the Obsidian CLI (`obsidian`) for all vault reads and writes — task lists,
tags, backlinks, search, daily-note path, creating notes, appending content,
and setting properties. Fall back to direct file ops (`Read`, `Edit`, `Write`,
`Glob`, `Grep`, `Bash`) only when the CLI has no equivalent (section-targeted
insertion, bulk renames, complex template substitution).

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

Run `scripts/daily_note_path.sh` to get the path: no args for today, or pass
`YYYY-MM-DD` for a specific date. The script honours the `VAULT` env var.

## Core workflows

### 1. Read a note

Use the `Read` tool against the absolute path. For files known by name only,
use `Glob` to locate first:
```
Glob: $VAULT/**/<name>.md
```

### 2. Create a note

Use the CLI. Default location is `inbox/<slug>.md` unless the user specifies otherwise.
Always include YAML frontmatter with at least `tags`:

```bash
obsidian create path=inbox/<slug>.md content="---\ntags:\n- inbox\n---\n\n# Title\n\nContent"
```

Pass `overwrite` if replacing an existing file.

### 3. Append or prepend to a note

Use the CLI:

```bash
obsidian append path=<rel> content="<text>"
obsidian prepend path=<rel> content="<text>"
```

For section-targeted insertion (e.g. insert before a specific heading or divider),
fall back to the `Edit` tool with an exact string match.

### 4. Daily notes

Get today's path and read the note:

```bash
obsidian daily:path      # → relative path (e.g. daily/2026/05-May/26-05-20.md)
obsidian daily:read      # → note contents
```

If the note doesn't exist, create it:

```bash
obsidian create path=<rel> content="---\ntags:\n- daily\n---\n\n# YYYY-MM-DD\n\n## To-Do\n\n- [ ]\n\n---\n\n## Notes\n"
```

To append a todo or section:

```bash
obsidian daily:append content="- [ ] <task>"          # adds to end of note
obsidian daily:append content="## Work Log\n\n- ..."  # new section
```

For inserting *within* a specific section (e.g. before the `---` divider in
`## To-Do`), fall back to the `Edit` tool with a precise string match.

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

List tags in a file or the vault:

```bash
obsidian tags path=<rel>        # tags in one file
obsidian tags                   # all vault tags
```

Read a property value:

```bash
obsidian property:read name=<prop> path=<rel>
```

Set or remove a property:

```bash
obsidian property:set name=<prop> value=<val> path=<rel>
obsidian property:remove name=<prop> path=<rel>
```

For `tags` (a list property), use `type=list` and pass a JSON array as value, or
edit the frontmatter directly with the `Edit` tool if you need fine-grained control.

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

Move or rename a note (CLI updates links automatically):

```bash
obsidian move path=inbox/foo.md to=projects/foo.md
obsidian rename path=<rel> name="New Title"
```

Delete a note (confirm with the user first):

```bash
obsidian delete path=<rel>           # moves to Obsidian trash
obsidian delete path=<rel> permanent  # bypasses trash — irreversible
```

## Conventions

- **File naming**: kebab-case for general notes, `YY-MM-D.md` for daily notes,
  `NAT-[number]-[description].md` for specs.
- **Links**: Use markdown links `[text](path/to/file.md)`, not wikilinks.
- **Frontmatter**: All notes should have YAML frontmatter with at least `tags`.
- **Spelling**: Australian English (colour, behaviour, organisation).
- **New notes**: Default to `inbox/` unless a specific location is given.
- **Templates**: Browse `$VAULT/templates/` for available templates.

## CLI reference

Full command list with options: [references/cli-reference.md](references/cli-reference.md).
