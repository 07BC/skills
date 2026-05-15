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

Reads raw session transcripts from `~/raw/sessions/` and
extracts durable knowledge into `~/raw/knowledge/`.

---

## When to use

- User says "process my sessions" / "extract from sessions" / "update knowledge base from sessions"
- User wants to review what was decided or learned across sessions
- User wants to build up architecture knowledge from real session history

---

## Step 1 — Find unprocessed sessions

List files in `~/raw/sessions/` that do not have a
corresponding `processed: true` frontmatter flag.

Prefer **final** saves (no `-tN` suffix) over periodic snapshots for the same
session ID. If only periodic snapshots exist, use the highest `-tN` count.

---

## Step 2 — Extract knowledge entries

For each session, read the transcript and extract entries in these five
categories. Only extract entries that are **durable and reusable** — skip
one-off decisions, user-specific config, or anything that won't apply to
future sessions.

### Categories

| Category | What to extract |
|---|---|
| **architecture** | SwiftUI MV patterns, service design, actor/Mutex usage, DI decisions, naming conventions |
| **prohibitions** | Things that must NOT be done — anti-patterns caught, wrong approaches corrected |
| **bugs** | Root causes of real bugs found, how they were diagnosed, what the fix was |
| **prompting** | Prompt patterns that worked well, patterns that failed, model/mode choices that paid off |
| **style** | Code style corrections, formatting rules reinforced, indentation or naming patterns |

### Entry format

Each entry is a single markdown bullet:

```
- [{date}] {concise statement of the learning}
```

Example:
```
- [2026-04-26] Use `Mutex` instead of `NSLock` for Swift 6 strict concurrency — NSLock is not Sendable
- [2026-04-26] Never combine plan and execute phases in one Claude Code prompt — always split into two sessions
```

---

## Step 3 — Write to knowledge files

Append extracted entries to the appropriate file in
`~/raw/knowledge/`:

| Category | File |
|---|---|
| architecture | `swift-architecture.md` |
| prohibitions | `swift-prohibitions.md` |
| bugs | `swift-bugs.md` |
| prompting | `prompting-patterns.md` |
| style | `swift-style.md` |

Create the file if it doesn't exist, with this header:

```markdown
---
tags: [ai-knowledge, claude-code]
---

# {Title}

> Auto-generated from Claude Code sessions. Do not edit manually.

```

Append new entries under a `## {YYYY-MM-DD}` heading for today's date.
Do not duplicate entries already present.

---

## Step 4 — Mark sessions as processed

Add `processed: true` to the frontmatter of each session file that was
successfully processed, so it is skipped on future runs.

---

## Step 5 — Summary

Print a short summary:

```
Processed N session(s)
Added:
  • architecture: N entries → swift-architecture.md
  • prohibitions: N entries → swift-prohibitions.md
  • bugs: N entries → swift-bugs.md
  • prompting: N entries → prompting-patterns.md
  • style: N entries → swift-style.md
```

---

## Notes

- Never delete session files — only mark them processed
- If a session has no durable learnings, mark it processed with a note in the summary
- Generic learnings (not Swift/iOS specific) go in `prompting-patterns.md` only
- Entries should be self-contained — readable without needing to open the session file
