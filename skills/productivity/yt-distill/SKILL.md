---
name: yt-distill
description: >
  Distils a folder of YouTube transcript markdown files (the output of
  yt-research) into a structured Obsidian reference library — 4 category
  folders (skills, plugins, prompts, techniques) plus a master index.md.
  Use when the user says "distill the transcripts", "organise these
  transcripts", "extract insights from <channel>", "run yt-distill on
  <folder>", "distill those transcripts", "extract skills and prompts from
  the transcripts", or as the natural follow-up to yt-research finishing.
  Always use this skill — do not write the reference library ad hoc.
---

# yt-distill

Converts a folder of YouTube transcript `.md` files (produced by
`yt-research`) into a focused Obsidian reference library. A Python script
pre-extracts candidates (verbatim prompts, blockquotes, slash-commands,
keyword paragraphs) into compact JSONL so the model synthesises from
structured data rather than re-reading every raw transcript.

## Prerequisite — yt-research

This skill processes the output of `yt-research`. If the user hasn't
run `yt-research` yet, run that first to produce the transcript folder
under `<vault>/AI/<channel-slug>/transcript`, then return here. The
source folder this skill expects is precisely that path.

---

## Step 0 — Resolve inputs

Ask (or infer) two paths:

- **Source folder** — directory containing the `.md` transcripts and
  optional `*-prompts.md` files. E.g. `~/Developer/docs/DIYSmartCode/`.
- **Destination folder** — where to write the reference library. Default:
  `~/Developer/obsidian/AI/<channel-name>/`, where `<channel-name>` is the
  basename of the source folder.

If the source folder is missing or ambiguous, ask via `AskUserQuestion`
before proceeding.

---

## Step 1 — Check dependencies

Run `scripts/ensure_deps.sh`. It exits 0 when Python 3.8+ is available.
If it exits non-zero, report the error and stop.

---

## Step 2 — Extract candidates

Run `scripts/extract_candidates.py` against all `.md` files in the source
folder, writing JSONL to a temp file:

```
python3 scripts/extract_candidates.py <source_folder>/*.md \
  > /tmp/yt-distill-<channel>.jsonl
```

Stream stderr live (it shows `OK: <file> — N candidates` per file).

Each line of the output file is a JSON record:

| Field | Values |
|---|---|
| `source_file` | basename of the source `.md` file |
| `source_kind` | `"prompts_file"` (verbatim, high trust) or `"transcript"` (audio-derived) |
| `line` | 1-indexed line number |
| `heading_path` | list of heading texts above this candidate |
| `type` | `"verbatim_prompt"` / `"blockquote"` / `"code_block"` / `"slash_command"` / `"keyword_paragraph"` |
| `category_hint` | `"skills"` / `"plugins"` / `"prompts"` / `"techniques"` / `"?"` |
| `text` | extracted content |

---

## Step 3 — Synthesise the reference library

Read `/tmp/yt-distill-<channel>.jsonl`. Group candidates by `category_hint`
(`skills`, `plugins`, `prompts`, `techniques`). Cluster semantically related
candidates into sub-topics — each cluster becomes one `.md` file in the
matching category folder under `<dest>/`.

Create these four folders inside `<dest>/`:

- `skills/` — Claude Code skills and slash commands
- `plugins/` — MCP servers, connectors, and integrations
- `prompts/` — verbatim and reconstructed prompt templates
- `techniques/` — workflow patterns, mental models, best practices

**Process one category at a time.** Write each file with the Write tool
before moving to the next.

### Verbatim vs reconstructed

- `source_kind: "prompts_file"` → **verbatim**. Copy text exactly into a
  `> "..."` blockquote. No `[reconstructed]` tag.
- `source_kind: "transcript"` + wording inferred → append `[reconstructed]`
  after the entry title. If the transcript quoted something explicitly
  (full sentence in quotes), treat it as verbatim.

### Per-file entry format

All files: **no frontmatter**, H1 at top, prompts use `> "..."` blockquotes
(never fenced code blocks), every entry cites its source file.

**skills/ — one file per topic cluster:**

```markdown
# <Topic> Skills

## /<slash-command> or Skill Name

- **What it does:** one sentence
- **When to invoke:** the triggering condition
- **Source:** `<source-file>.md`
- **Exact prompt to create it:**
  > "..."
```

**plugins/ — one file per plugin or tool:**

```markdown
# Plugin Name

- **What it does:** one sentence
- **How to add it:** setup steps if described
- **Key commands:** what it unlocks
- **When it's worth using:** use cases
- **Source:** `<source-file>.md`
```

**prompts/ — one file per prompt category:**

```markdown
# <Category> Prompts

## Prompt Name [reconstructed]

- **Source:** `<source-file>.md`
- **When to use:** the situation it's designed for

  > "exact prompt text here"
```

**techniques/ — one file per theme:**

```markdown
# <Theme> Techniques

## Technique Name

- **What it is:** 2–3 sentences
- **How to apply:** concrete steps
- **Why it works:** the principle behind it (if explained)
- **Source:** `<source-file>.md`
```

### Constraints

- **Never merge** two distinct ideas into one entry to save space — each
  concept gets its own H2.
- **Never thin out** a prompt — if the text is there, reproduce it in full.
- **De-duplicate by H2 title** only: if two candidates produce the same H2
  (case-insensitive), merge into one entry noting both sources.
- **No commentary or opinion** — extract and organise only.
- If `category_hint` is `"?"`, use your judgment based on content. Prefer
  `techniques/` for general advice and `prompts/` for instructions to Claude.

---

## Step 4 — Write `index.md`

Write `<dest>/index.md`:

```markdown
# <Channel Name> — Reference Library

<1–2 sentence intro about the channel and what this library covers.>

## Sub-documents

| Document | What's inside |
|---|---|
| [<file title>](<category>/<filename>.md) | brief description |
...

## Core philosophy

<5–8 bullet points summarising the creator's overall approach.>

## Source videos

| Video title | Source file |
|---|---|
| <title> | `<filename>.md` |
...

## Quick reference — 5 things to do today

1. <most immediately actionable item>
...
```

Every generated sub-document must appear in the Sub-documents table.
Every source transcript must appear in the Source videos table.

---

## Step 5 — Validate

Run `scripts/validate_output.py <dest>` and fix any `ERROR:` lines:

```
python3 scripts/validate_output.py <dest>
```

Common fixes:
- Broken link in `index.md` → correct the relative path
- Missing H1 → add one
- Missing source citation → add `- **Source:** \`<file>.md\`` to the entry
- Duplicate H2 → merge the entries

Report the final OK summary and destination path to the user.

---

## Summary output

After validation passes:

```
=== yt-distill: <channel> ===
Skills:     N files
Plugins:    N files
Prompts:    N files
Techniques: N files
Output:     <dest>
===
```

---

## What to avoid

- Do not re-read raw transcript files during synthesis — use only `candidates.jsonl`.
- Do not use fenced code blocks for prompts — use `> "..."` blockquotes.
- Do not add frontmatter to distilled files.
- Do not skip candidates because they seem similar — deduplicate by H2 title only.
- Do not add commentary, opinions, or elaborations beyond what the source says.
- Do not mark a prompt `[reconstructed]` if it came from a `*-prompts.md` file.
