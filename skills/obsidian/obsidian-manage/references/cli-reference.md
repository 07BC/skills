# Obsidian CLI Reference

## Binary & Invocation

```bash
OBS="/Applications/Obsidian.app/Contents/MacOS/obsidian"
# All commands require vault= when multiple vaults exist
$OBS <command> [options] vault=obsidian
```

The first two lines of output are deprecation warnings. Pipe through `tail -n +3` to strip them, or redirect stderr with `2>/dev/null` and use `tail -n +2`.

## File Resolution

- `file=<name>` resolves by name (like wikilinks) — matches any file with that name anywhere in vault
- `path=<path>` is exact relative path from vault root (e.g., `path="20-projects/streaming-ios/notes.md"`)
- Most commands default to the active file when file/path is omitted
- Quote values with spaces: `name="My Note"`
- Use `\n` for newline, `\t` for tab in content values

## Commands by Category

### Reading Notes

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `read` | Read file contents | `file=`, `path=` |
| `file` | Show file info (size, dates, links) | `file=`, `path=` |
| `search` | Search vault for text | `query=` (required), `path=`, `limit=`, `format=text\|json` |
| `search:context` | Search with matching line context | `query=` (required), `path=`, `limit=`, `format=text\|json` |
| `outline` | Show headings for a file | `file=`, `path=`, `format=tree\|md\|json` |
| `wordcount` | Count words and characters | `file=`, `path=`, `words`, `characters` |
| `random:read` | Read a random note | `folder=` |

### Creating & Writing

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `create` | Create a new file | `name=`, `path=`, `content=`, `template=`, `overwrite`, `open` |
| `append` | Append content to a file | `file=`/`path=`, `content=` (required), `inline` |
| `prepend` | Prepend content to a file | `file=`/`path=`, `content=` (required), `inline` |
| `delete` | Delete a file | `file=`/`path=`, `permanent` |
| `move` | Move or rename a file | `file=`/`path=`, `to=` (required) |
| `rename` | Rename a file | `file=`/`path=`, `name=` (required) |

### Daily Notes

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `daily` | Open daily note | `paneType=tab\|split\|window` |
| `daily:read` | Read daily note contents | — |
| `daily:path` | Get daily note path | — |
| `daily:append` | Append content to daily note | `content=` (required), `inline`, `open` |
| `daily:prepend` | Prepend content to daily note | `content=` (required), `inline`, `open` |

### Properties (Frontmatter)

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `properties` | List properties in vault or file | `file=`, `path=`, `name=`, `counts`, `format=yaml\|json\|tsv` |
| `property:read` | Read a property value | `name=` (required), `file=`/`path=` |
| `property:set` | Set a property on a file | `name=`, `value=` (required), `type=text\|list\|number\|checkbox\|date\|datetime` |
| `property:remove` | Remove a property | `name=` (required), `file=`/`path=` |

### Tags

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `tags` | List tags in vault or file | `file=`, `path=`, `counts`, `sort=count`, `format=json\|tsv\|csv` |
| `tag` | Get tag info | `name=` (required), `total`, `verbose` |

### Tasks

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `tasks` | List tasks in vault | `file=`, `path=`, `done`, `todo`, `verbose`, `format=json\|tsv\|csv`, `daily` |
| `task` | Show or update a task | `ref=<path:line>`, `toggle`, `done`, `todo`, `status="<char>"`, `daily` |

### Links & Graph

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `links` | List outgoing links from a file | `file=`, `path=`, `total` |
| `backlinks` | List backlinks to a file | `file=`/`path=`, `counts`, `format=json\|tsv\|csv` |
| `orphans` | Files with no incoming links | `total`, `all` |
| `deadends` | Files with no outgoing links | `total`, `all` |
| `unresolved` | Unresolved links in vault | `total`, `counts`, `verbose` |
| `aliases` | List aliases | `file=`, `path=`, `verbose` |

### Vault & File Browsing

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `vault` | Show vault info | `info=name\|path\|files\|folders\|size` |
| `files` | List files in the vault | `folder=`, `ext=`, `total` |
| `folders` | List folders in the vault | `folder=`, `total` |
| `folder` | Show folder info | `path=` (required), `info=files\|folders\|size` |

### Templates

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `templates` | List templates | `total` |
| `template:read` | Read template content | `name=` (required), `resolve`, `title=` |
| `template:insert` | Insert template into active file | `name=` (required) |

### Bookmarks

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `bookmark` | Add a bookmark | `file=`, `subpath=`, `folder=`, `search=`, `url=`, `title=` |
| `bookmarks` | List bookmarks | `total`, `verbose`, `format=json\|tsv\|csv` |

### History & Sync

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `history` | List file history versions | `file=`, `path=` |
| `history:read` | Read a history version | `file=`, `path=`, `version=` |
| `history:restore` | Restore a history version | `file=`, `path=`, `version=` (required) |
| `sync:status` | Show sync status | — |
| `diff` | Diff local/sync versions | `file=`, `path=`, `from=`, `to=` |

### Plugins

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `plugins` | List installed plugins | `filter=core\|community`, `versions` |
| `plugins:enabled` | List enabled plugins | `filter=core\|community` |
| `plugin:enable` | Enable a plugin | `id=` (required) |
| `plugin:disable` | Disable a plugin | `id=` (required) |

### Navigation & UI

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `open` | Open a file in Obsidian | `file=`, `path=`, `newtab` |
| `search:open` | Open search view | `query=` |
| `recents` | List recently opened files | `total` |
| `tabs` | List open tabs | `ids` |
| `command` | Execute an Obsidian command | `id=` (required) |
| `commands` | List available command IDs | `filter=` |

### Bases (Database Views)

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `bases` | List all base files | — |
| `base:views` | List views in a base | — |
| `base:query` | Query a base | `file=`/`path=`, `view=`, `format=json\|csv\|tsv\|md\|paths` |
| `base:create` | Create item in a base | `file=`/`path=`, `view=`, `name=`, `content=`, `open` |
