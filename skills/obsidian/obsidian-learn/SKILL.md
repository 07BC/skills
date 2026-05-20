---
name: obsidian:learn
description: >
  Extracts knowledge from the current session and writes it to a persistent
  Obsidian knowledge base. Use this skill whenever the user says "learn from
  this session", "update the knowledge base", "save what we learned", "run
  learn", or wants to capture session learnings into Obsidian. Always use this
  skill at the end of a development session — it encodes code style
  corrections, architecture decisions, explicit prohibitions, bugs discovered,
  prompting patterns, tooling discoveries, and git lessons into topic-based
  running files in the vault.
---

# learn

Extracts durable knowledge from the current session and merges it into
topic-based running files in `~/Developer/obsidian/knowledge/`.

Each file is a living document — new entries are appended under the correct
heading, never duplicated.

---

## Step 0 — Preflight check

Before doing anything, ensure the knowledge directory exists:

```bash
mkdir -p ~/Developer/obsidian/knowledge
```

If the user wants a clean vault baseline before write, also run
`scripts/vault_preconditions.sh` — it exits non-zero if the vault is missing,
not a git repo, or has uncommitted changes. Treat a failure as a soft
warning, not a hard halt.

Proceed to Step 1.

---

## Step 1 — Extract session knowledge

Read the full conversation and extract entries across the nine categories
below. Aim for **at least 1–2 entries per relevant category** — if a category
seems empty, look harder before skipping it. Only skip a category if the
session genuinely had no signal for it.

Only extract things that are **durable and generalisable** — skip one-off
debugging steps, session-specific file paths, and things already obvious
from the codebase.

If you are uncertain whether something belongs, flag it in the Step 4 report
under "Uncertain — not written" rather than silently dropping it.

---

### Categories

**style** — Code style corrections made during the session
Things the user corrected, rewrote, or explicitly preferred.
- "Use 2-space indentation not 4"
- "No inline comments"
- "Prefer `guard` over nested `if`"

---

**architecture** — Decisions settled on during the session
Patterns, structures, or approaches agreed on. One sentence, specific enough
to act on.
- "`@MainActor @Observable final class` for all services"
- "Views receive services via `@Environment` only, never instantiate them"
- "Always split plan and execute into separate Claude Code sessions"

---

**prohibitions** — Things explicitly told not to do
Hard rules the user stated or corrected toward. Lead with "Never".
- "Never use `NSLock` — use `Mutex`"
- "Never combine plan and execute phases into one prompt"
- "Never write `@Test` functions in XCUITest targets"

---

**bugs** — Root causes or failure patterns discovered

This is the hardest category to get right. The distinction:

| Keep | Skip |
|---|---|
| Root cause + fix that will recur in other projects | A specific file you edited in this session |
| A framework behaviour you didn't know about | A typo you fixed |
| A pattern that explains a class of crashes or failures | A one-liner workaround with no transferable lesson |

Good entries name the cause, the symptom, and the remedy in one line:

- "`LazyVGrid` inside `LazyVStack` inside `ScrollView` breaks width on tvOS — give grid explicit `frame(maxWidth: .infinity)`"
- "IVS SDK teardown on main thread causes `0x8BADF00D` watchdog — always tear down off-main"
- "HaishinKit `onFCPublish` not forwarded by default — patch `RTMPStream` to forward or publish never completes"

Bad entries (skip these):
- "Fixed a crash in StreamViewController" — no cause, not generalisable
- "Ran `pod install` to fix the build" — session-specific, not a bug
- "Changed the timeout value" — no transferable lesson

---

**prompting** — Patterns that worked well or should be avoided
Prompt structure, model selection, mode choices.
- "Always end Claude Code prompts with Model & mode recommendation"
- "Opus for audit/root cause, Sonnet for mechanical execution"
- "Add `stop and ask rather than interpret` to every implementation prompt"
- "Split XCUITest prompts into plan and execute — never combine"

---

**tooling** — Claude Code, skills, agents, MCP, and workflow discoveries
Claude Code command/agent patterns, `.system/` skill lessons, MCP config.
- "Claude Code `PostToolUse` hook requires the hook file to be executable"
- "Skill `description:` field drives trigger accuracy — rewrite it if the skill misfires"
- "Use iTerm2 tabs over tmux for parallelising Claude Code sessions on macOS"
- "MCP Atlassian Cloud ID goes in `.mcp.json`, not in the prompt"

---

**patterns** — Reusable code patterns below architecture level
Snippets, idioms, or small structures worth repeating. Not style, not
architecture — things you'd copy-paste as a starting point.
- "Bridge async throws to sync using `Task { try await ... }.value` inside a `Mutex`-locked block"
- "Use `UIDevice.orientationDidChangeNotification` not `viewWillTransition` for physical rotation detection in streaming"
- "Inject test credentials via `XCUIApplication().launchEnvironment` — never hardcode in test files"

---

**research** — Things looked up that are worth retaining
API behaviour, third-party SDK quirks, App Store Connect workflows, spec details.
- "RTMP `FCPublish` must be sent before `publish` — not all servers enforce it but Kick does"
- "App Store Connect allows a hotfix submission alongside an in-progress version using a separate build train"
- "GitHub SSH keys cannot be shared across accounts — each account needs its own key pair"

---

**git** — Git, GitHub, and SSH lessons
Configuration, authentication, and workflow discoveries.
- "SSH agent doesn't auto-load keys with no passphrase — run `ssh-add` manually once per session"
- "Use separate SSH host aliases per GitHub account in `~/.ssh/config`"
- "`git push --force-with-lease` is safer than `--force` — fails if someone else pushed"

---

## Step 2 — Deduplication check

### 2a — Read the index

Read the compact index first using the `Read` tool:

```
Read ~/Developer/obsidian/knowledge/_index.md
```

The index contains one line per stored entry (key phrase only). If an entry
you want to write is already represented there, skip it.

If the index doesn't exist, that's fine — skip to 2b and create it after
writing.

### 2b — Read any file that still has candidates

For categories where the index check didn't resolve all duplicates, read
the full file using the `Read` tool:

```
Read ~/Developer/obsidian/knowledge/<category>.md
```

This is a fallback, not the primary dedup path. Prefer the index.

---

## Step 3 — Write to vault

### 3a — Write category files

For each category with new entries, write entries to a temp file (newline
separated) and call `scripts/kb_append.py --target <path> <entries-file>`.
Use `--dry-run` first to preview the change set. The script appends entries
under a `## YYYY-MM-DD` heading, deduplicates against the existing file
contents, and creates the parent directory if needed.

If a category file does not yet exist, the script creates it as a plain
markdown file (no frontmatter). Add frontmatter manually the first time:

```markdown
---
tags: [ai-knowledge, <category>]
---

# <Category Title>
```

### File map

| Category | Path | Title |
|---|---|---|
| style | `~/Developer/obsidian/knowledge/swift-style.md` | Swift Style |
| architecture | `~/Developer/obsidian/knowledge/architecture.md` | Architecture Decisions |
| prohibitions | `~/Developer/obsidian/knowledge/prohibitions.md` | Things Not To Do |
| bugs | `~/Developer/obsidian/knowledge/bugs.md` | Bugs & Root Causes |
| prompting | `~/Developer/obsidian/knowledge/prompting.md` | Prompting Patterns |
| tooling | `~/Developer/obsidian/knowledge/tooling.md` | Tooling & Workflow |
| patterns | `~/Developer/obsidian/knowledge/patterns.md` | Code Patterns |
| research | `~/Developer/obsidian/knowledge/research.md` | Research & References |
| git | `~/Developer/obsidian/knowledge/git.md` | Git & GitHub |

### 3b — Update the index

After writing all category files, append new entries to the index.
One line per entry — just the key phrase, no full sentence needed.

**If the index exists**, append via the CLI:

```bash
obsidian append path=knowledge/_index.md content="- <key phrase> (<category>, YYYY-MM-DD)\n"
```

**If the index doesn't exist yet**, create it via the CLI:

```bash
obsidian create path=knowledge/_index.md content="---\ntags: [ai-knowledge, index]\n---\n\n# Knowledge Index\n\n- <key phrase> (<category>, YYYY-MM-DD)\n"
```

> Note: `scripts/kb_append.py` (used in Step 3a) makes direct file writes because
> the CLI has no equivalent for dated-heading insertion with deduplication. The
> index append above is a simple EOF append — CLI is fine here.

---

## Step 4 — Report

After all writes are complete, print a summary:

```
## Knowledge base updated

**swift-style.md** — 2 new entries
**prohibitions.md** — 1 new entry
**prompting.md** — 3 new entries
**tooling.md** — 2 new entries

Nothing new for: architecture.md, bugs.md, patterns.md, research.md, git.md

Uncertain — not written:
- "Changed timeout to 30s in StreamManager" — session-specific, skipped
```

The "Uncertain — not written" section is optional. Only include it when
something was a genuine close call. If you skipped it confidently, don't list it.

---

## Rules

- Never duplicate an entry already in the index or file — check before writing
- Never rewrite or delete existing entries
- Skip anything session-specific or not generalisable
- Use plain bullet points — no sub-bullets, no bold, no tables inside entries
- Entries are written in imperative or declarative form — not as questions
- Keep entries concise: one line each, specific enough to be actionable
- Aim for at least 1–2 entries per relevant category — look hard before skipping
- Flag uncertain entries in the report rather than silently dropping them