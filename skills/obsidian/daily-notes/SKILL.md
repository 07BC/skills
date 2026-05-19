---
name: daily-notes
description: >
  Generates daily work notes from actual activity — conversations, commits, file
  changes, and Jira tickets. Use this skill whenever the user asks to "write up
  today's notes", "log what we did", "create daily notes", "summarise this
  week's work", "write up what I did today", or wants to catalogue work done on
  a project over any time period. Also trigger when the user asks to "add today
  to my notes" or "update my work log". Always use this skill — do not attempt
  to write daily notes from memory alone.
---

# Daily Notes Skill

Generates accurate, first-person daily work notes from real activity data.
Notes are written as tasks the user completed — no mention of Claude, prompts,
AI tools, or tooling. Plain, professional engineer's log.

---

## Environment detection

Determine which environment you are in before doing anything else:

- **Claude.ai** — `recent_chats` and `conversation_search` tools are available.
  Use them to gather data.
- **Claude Code** — No chat tools. Use git, file system, and Jira MCP to gather
  data. See the Claude Code section below.

---

## Optional vault preflight

Before any vault write, `scripts/vault_preconditions.sh` is available to
check that `$VAULT` exists, is a git repo, and has a clean working tree.
Treat a failure as a soft warning — the user can decide to proceed or stash.

---

## Claude.ai workflow

### Step 1 — Establish the time window

If the user says "today", use today's date.
If the user says "this week" or "since Monday", calculate the date range from
the current date.
If no period is specified, default to today.

### Step 2 — Gather conversation data

Fetch recent chats covering the time window:

```
recent_chats(n=20)
```

Filter to chats `updated_at` within the requested window.
For any chat with a relevant-sounding title, read its content to extract what
was actually done — not just the topic.

Also run targeted searches for known projects:

```
conversation_search(query="KickTV")
conversation_search(query="KickLive GoLive")
conversation_search(query="NAT Jira")
```

Add any results within the time window that weren't already in `recent_chats`.

### Step 3 — Extract tasks

From each conversation, extract only concrete things that were done:

- Code written, refactored, or fixed
- Architecture decisions made
- Bugs investigated or resolved
- Documents, plans, or specs created
- Tools, configs, or CI set up
- Reviews or audits completed

Discard: general questions, research that didn't produce an output, abandoned
explorations, and meta-conversation about how to do something.

### Step 4 — Write the notes

Write one markdown file per day. If multiple days were requested, write one
file per day.

**Format:**

```markdown
# Daily Notes — [Weekday, DD Month YYYY]

## [Project Name]

- [Task as a past-tense statement of work done]
- [Task]
- ...

## [Another Project if applicable]

- [Task]
```

**Voice and style rules — critical:**

- First person, past tense, active voice: "Fixed the grid layout…" not
  "A grid layout fix was made…"
- No mention of Claude, AI, prompts, skills, or tooling of any kind
- No mention of "wrote a prompt for…" or "used Claude Code to…" — just
  what was achieved
- Concise but specific — include enough detail to be meaningful in a
  retrospective ("Fixed `LazyVGrid` width calculation inside `LazyVStack`
  on tvOS" not "Fixed a bug")
- Group by project with a `##` heading
- Use plain bullet points — no sub-bullets, no bold, no tables
- If a day had no meaningful work logged, omit that day rather than
  writing an empty entry

### Step 5 — Save to Obsidian (direct file edit)

Append the generated notes to today's Obsidian daily note under the **Notes**
section by editing the file directly. Do **not** use the Obsidian CLI — it is
flaky and silently fails on path resolution.

Vault root: `$HOME/Developer/obsidian`.

Resolve today's daily-note path with `scripts/daily_note_path.sh` (no args for
today; honours `VAULT` env). Path format: `daily/YYYY/MM-MMM/YY-MM-D.md` —
the day is **not** zero-padded (`26-05-1.md`, not `26-05-01.md`).

Steps:
1. Check whether `$TODAY` exists. If not, create the parent folder and write
   the file from this template (substitute `{ISO_DATE}` with `YYYY-MM-DD`):
   ```
   ---
   tags:
   - daily
   ---

   # {ISO_DATE}

   ## To-Do

   - [ ]

   ---

   ## Notes
   ```
2. Use the `Edit` tool to append a `## Work Log` block under the existing
   `## Notes` section, in this shape:
   ```
   ## Work Log

   ### [Project Name]

   - [task]
   - [task]

   ### [Another Project]

   - [task]
   ```
3. Confirm the edit by re-reading the file and checking the new block is
   present.

### Step 6 — Output

Save each file to `~/Developer/obsidian/daily-notes/` using the filename
format `YYYY-MM-DD-weekday.md` (e.g. `2026-04-22-wednesday.md`).

Present all files using the `present_files` tool.

Confirm that the Obsidian daily note was updated successfully.

---

## Claude Code workflow

In Claude Code, there are no conversation tools. Use the following sources
instead.

### Step 1 — Git log

```bash
git log --since="YYYY-MM-DD 00:00" --until="YYYY-MM-DD 23:59" \
  --format="%h %s" --all
```

Adjust dates for the requested window. Read commit messages to understand
what was done. For any commit that's unclear, read the diff:

```bash
git show --stat <hash>
```

### Step 2 — File change timestamps

```bash
find . -newer <reference-file-or-date> -name "*.swift" \
  -not -path "*/DerivedData/*" \
  -not -path "*/.git/*" \
  | sort
```

Use changed files to infer what areas were worked on if commit messages are
thin.

### Step 3 — Jira (if MCP available)

If the Atlassian MCP server is available, query for tickets updated in the
window:

```
searchJiraIssuesUsingJql(
  cloudId: "6e66531e-dc70-4caa-93ad-a2524854ff4f",
  jql: "assignee = currentUser() AND updated >= YYYY-MM-DD ORDER BY updated DESC",
  fields: ["summary", "status", "description"]
)
```

Use ticket summaries and status changes to supplement the git data.

### Step 4 — Write and save notes

Follow the same format and style rules as the Claude.ai workflow above.

Save to `docs/daily-notes/YYYY-MM-DD-weekday.md` within the repo, or to the
location the user specifies.

### Step 5 — Save to Obsidian (direct file edit)

Append the generated notes to today's Obsidian daily note under the **Notes**
section by editing the file directly. Do **not** use the Obsidian CLI.

Vault root: `$HOME/Developer/obsidian`. Resolve today's path with
`scripts/daily_note_path.sh` (honours `VAULT` env).

If the file does not exist, create it from the template (see Claude.ai
workflow Step 5 above for the template). Then use the `Edit` tool to append a
`## Work Log` block under the existing `## Notes` section.

Confirm the note was updated by re-reading the file before presenting output.

---

## Quality checklist

Before presenting output, verify each note file:

- [ ] Written in first person, past tense
- [ ] No mention of Claude, AI, prompts, or tooling
- [ ] Tasks are specific enough to be meaningful — not just "worked on X"
- [ ] Grouped by project
- [ ] Filename matches date content
- [ ] Only days with actual work are included
