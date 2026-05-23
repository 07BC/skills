---
name: ai-index
description: >
  Rebuilds the cross-channel AI reference index at AI/index/ by aggregating
  all yt-distill output across every channel in the AI folder. Produces
  theme-grouped files inside type subfolders (skills/, prompts/, techniques/,
  plugins/) with full content inline, lightweight topic discovery files, and a
  master index. Invoked automatically by yt-distill after each run, or manually
  when the user says "rebuild the AI index", "update the AI index", "index my
  AI content", "refresh ai-index", or "run ai-index".
---

# ai-index

Aggregates all yt-distill output from `AI/` into a browsable index at
`AI/index/`. Each type (skills, prompts, techniques, plugins) gets its own
subfolder; within each subfolder, items are grouped into theme files. Full
content inline. Lightweight topic files provide cross-type discovery.

---

## Step 0 — Resolve paths

- **AI root** — the vault's `AI/` folder. Default: `~/Developer/obsidian/AI/`.
- **Output** — always `<ai_root>/index/`. Create it and all subfolders if absent.

Output structure:

```
AI/index/
├── index.md
├── skills/
│   ├── <theme>.md
│   └── ...
├── prompts/
│   ├── <theme>.md
│   └── ...
├── techniques/
│   ├── <theme>.md
│   └── ...
├── plugins/
│   ├── <theme>.md
│   └── ...
└── topics/
    ├── <slug>.md
    └── ...
```

Skill directory: `~/.claude/skills/ai-index/`

---

## Step 1 — Extract items

```
python3 <skill_dir>/scripts/extract_items.py <ai_root> \
  > /tmp/ai-index-items.jsonl
```

Each JSONL line:

| Field | Description |
|---|---|
| `channel` | channel folder name |
| `type` | `skills` / `prompts` / `techniques` / `plugins` |
| `source_file` | relative path from AI root |
| `h2_title` | H2 heading text |
| `content` | everything under that H2, verbatim |

---

## Step 2 — Deduplicate

Group items by `(type, normalised h2_title)`:

- **Exact match** (case-insensitive): merge; list all sources.
- **Semantic match** (same concept, different phrasing — high confidence only): merge; note both titles.
- **Related but distinct**: keep separate.

For merged items, use the most descriptive title. If content differs meaningfully, reproduce each version under a `> From: <channel>` blockquote.

---

## Step 3 — Cluster into themes and write type subfolders

For **each type**, cluster the deduplicated items into **5–8 themes**. Themes
should be broad enough to hold 15–40 items each, narrow enough to be useful.

**Good theme names per type:**

| Type | Example themes |
|---|---|
| skills | `slash-commands`, `skill-authoring`, `memory-and-context`, `agent-patterns`, `automation`, `domain-specific` |
| prompts | `skill-building`, `workflow-and-planning`, `code-and-review`, `content-and-marketing`, `agent-automation` |
| techniques | `agent-design`, `context-management`, `code-quality`, `product-strategy`, `workflow`, `ai-models`, `content-marketing` |
| plugins | `claude-tools`, `mcp-servers`, `transport-comparison`, `other-tools` |

Create `AI/index/<type>/` and write one file per theme:

### Theme file format

```markdown
# <Theme Name>

_N entries — last updated: YYYY-MM-DD_

---

## <H2 Title>

**Source:** `<source_file>` [`, <source_file2>`]

<full item content verbatim>

---
```

- Entries sorted alphabetically within each theme file.
- Separate entries with `---`.
- Reproduce content verbatim — no summarising.
- Items that span two themes go in the best-fit theme only.
- Uncategorised items go in a `general.md` theme file.

### Type index file

Also write `AI/index/<type>/index.md` listing all theme files for that type:

```markdown
# <Type> Index

_N entries across M themes — last updated: YYYY-MM-DD_

| Theme | Entries | Description |
|---|---|---|
| [<Theme Name>](<theme>.md) | N | one-line description |
...
```

---

## Step 4 — Derive topics and write topic files

Cluster the full item set (all types) into **10–20 cross-type topics**.

Create `AI/index/topics/<slug>.md` for each topic:

```markdown
# <Topic Name>

_N items — last updated: YYYY-MM-DD_

| Item | Type | Channel | Source |
|---|---|---|---|
| [<H2 Title>](<relative-path-to-source-file>) | skill/prompt/technique/plugin | <channel> | `<source_file>` |
...
```

- Relative links point to the **channel's source file** (e.g. `../../mattpocockuk/skills/triage.md`).
- Lightweight tables only — no full content in topic files.
- One item may appear in multiple topic files.

---

## Step 5 — Write index.md

Write `AI/index/index.md`:

```markdown
# AI Reference Index

_Last updated: YYYY-MM-DD. N channels, M items total._

## Type folders (primary access)

| Folder | Entries | Themes | What's inside |
|---|---|---|---|
| [Skills](skills/index.md) | N | M | Slash commands, skill ideas, agent capabilities |
| [Prompts](prompts/index.md) | N | M | Verbatim and reconstructed prompt templates |
| [Techniques](techniques/index.md) | N | M | Workflow patterns, mental models, best practices |
| [Plugins](plugins/index.md) | N | M | Tools, MCP servers, integrations, CLIs |

## Topic files (cross-type discovery)

| Topic | Items |
|---|---|
| [<Topic Name>](topics/<slug>.md) | N |
...

## Channels indexed

| Channel | Items |
|---|---|
| <channel> | N |
...
```

---

## Step 6 — Report

```
=== ai-index ===
Skills:     N entries across M themes
Prompts:    N entries across M themes
Techniques: N entries across M themes
Plugins:    N entries across M themes
Topics:     N files
Output:     AI/index/
===
```

---

## What to avoid

- Do not write a single flat `<type>.md` file — always use the subfolder + theme structure.
- Do not read raw transcript files — work only from yt-distill output.
- Do not thin or summarise item content in theme files — reproduce verbatim.
- Do not create more than 8 theme files per type or more than 20 topic files.
- Do not add frontmatter to any generated file.
- Do not merge items unless the match is confident — false merges lose information.
