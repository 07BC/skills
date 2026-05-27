---
name: session-saver
description: >
  Processes raw Claude Code session transcripts saved to Obsidian and extracts
  durable knowledge into the AI knowledge base. Use this skill when the user
  says "process my sessions", "extract knowledge from sessions", "run session
  saver", or wants to turn saved session markdown files into structured
  knowledge entries. Also use when asked to review or summarise what was learned
  across multiple Claude Code sessions.
---

# Session Saver Skill

Reads raw session transcripts from `~/Developer/obsidian/sessions/` and
extracts durable knowledge into `~/Developer/obsidian/knowledge/`.

---

## When to use

- User says "process my sessions" / "extract from sessions" / "update knowledge base from sessions"
- User wants to review what was decided or learned across sessions
- User wants to build up architecture knowledge from real session history

---

## Step 0 — (optional) Vault preflight

`scripts/vault_preconditions.sh` is available to check that the vault is a
clean git repo before processing sessions. Treat a failure as a soft warning
— useful but not required to proceed.

---

## Step 1 — Find unprocessed sessions

Run `scripts/find_unprocessed_sessions.py` to list session transcripts in
`$VAULT/sessions/` whose frontmatter lacks `processed: true`. Where multiple
snapshots exist for the same session ID, the script prefers the final save
(no `-tN` suffix) over periodic snapshots; if only snapshots exist, it
returns the latest one. Output is one absolute path per line — read-only,
nothing is mutated.

`VAULT` env defaults to `$HOME/Developer/obsidian`.

---

## Step 2 — Extract knowledge entries

For each session, read the transcript and extract entries in these nine
categories. The list matches `obsidian-learn`'s category set so both
skills append to the same knowledge files. Only extract entries that are
**durable and reusable** — skip one-off decisions, user-specific config,
or anything that won't apply to future sessions.

### Categories

| Category | What to extract |
|---|---|
| **style** | Code style corrections, formatting rules reinforced, indentation or naming patterns |
| **architecture** | SwiftUI MV patterns, service design, `actor` boundaries, DI decisions, naming conventions |
| **prohibitions** | Things that must NOT be done — anti-patterns caught, wrong approaches corrected |
| **bugs** | Root causes of real bugs found, how they were diagnosed, what the fix was |
| **prompting** | Prompt patterns that worked well, patterns that failed, model/mode choices that paid off |
| **tooling** | Claude Code tooling, MCP servers, skill / command authoring lessons |
| **patterns** | Reusable code or design patterns that recurred across sessions |
| **research** | External references, papers, posts, or docs worth pinning |
| **git** | Git workflow lessons, commit / branch / rebase practices |

If a session has fewer than 2 entries across all nine categories, still
mark it processed (Step 4); report in the Step 5 summary that no
durable learnings were extracted.

### Entry format

Each entry is a single markdown bullet:

```
- [{date}] {concise statement of the learning}
```

Example:
```
- [2026-04-26] Mutating shared state must live in an `actor` — locks (`NSLock`, `Mutex`, `os_unfair_lock`, `DispatchSemaphore`) are not approved primitives in this project
- [2026-04-26] Never combine plan and execute phases in one Claude Code prompt — always split into two sessions
```

---

## Step 3 — Write to knowledge files

For each category with extracted entries, write entries to a temp file
(newline separated) and call `scripts/kb_append.py --target <path>
<entries-file>`. The script appends under a `## YYYY-MM-DD` heading and
deduplicates against the existing file contents. Use `--dry-run` first to
preview the change set.

Category → target file (inside `~/Developer/obsidian/knowledge/`).
**Filenames match `obsidian-learn`'s** so both skills feed the same
knowledge files:

| Category | File |
|---|---|
| style | `swift-style.md` |
| architecture | `architecture.md` |
| prohibitions | `prohibitions.md` |
| bugs | `bugs.md` |
| prompting | `prompting.md` |
| tooling | `tooling.md` |
| patterns | `patterns.md` |
| research | `research.md` |
| git | `git.md` |

`scripts/kb_append.py` auto-writes frontmatter on first creation:

```markdown
---
tags: [ai-knowledge, <category>]
---

# {Title}

> Auto-generated from Claude Code sessions. Do not edit manually.
```

No manual frontmatter step required.

---

## Step 4 — Mark sessions as processed

For each successfully processed session, set the `processed` property via the CLI:

```bash
obsidian property:set name=processed value=true type=checkbox path=sessions/<filename>.md
```

This ensures the file is skipped by `scripts/find_unprocessed_sessions.py` on future runs.

---

## Step 5 — Summary

Print a short summary:

```
Processed N session(s)
Added:
  - style: N entries → swift-style.md
  - architecture: N entries → architecture.md
  - prohibitions: N entries → prohibitions.md
  - bugs: N entries → bugs.md
  - prompting: N entries → prompting.md
  - tooling: N entries → tooling.md
  - patterns: N entries → patterns.md
  - research: N entries → research.md
  - git: N entries → git.md
```

---

## Notes

- Never delete session files — only mark them processed
- If a session has no durable learnings, mark it processed with a note in the summary
- Generic learnings (not Swift/iOS specific) go in `prompting-patterns.md` only
- Entries should be self-contained — readable without needing to open the session file
