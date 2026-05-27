---
name: daily-notes
description: >
  Generates daily work notes from real activity — git commits, file changes,
  and Jira tickets. Use this skill whenever the user asks to "write up today's
  notes", "log what we did", "create daily notes", "summarise this week's
  work", "write up what I did today", or wants to catalogue work done on a
  project over any time period. Also trigger when the user asks to "add today
  to my notes" or "update my work log". Always use this skill — do not attempt
  to write daily notes from memory alone.
---

# Daily Notes Skill

Generates accurate, first-person daily work notes from real activity data.
Notes are written as tasks the user completed — no mention of Claude, prompts,
AI tools, or tooling. Plain, professional engineer's log.

This skill runs entirely under Claude Code. Data sources are git, the file
system, and Jira via the Atlassian MCP. Conversation tools are not used.

---

## Variables

| Variable | Source |
| --- | --- |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` |
| `VAULT` | env override, defaults to `$HOME/Developer/obsidian` |
| `PLANS_DIR` | `${VAULT}/${PROJECT_NAME}/plans` |
| `ATLASSIAN_CLOUD_ID` | declared in `CLAUDE.md` (`jira:` config block) or resolved at runtime via `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources` |

---

## Optional vault preflight

Before any vault write, `scripts/vault_preconditions.sh` is available to
check that `$VAULT` exists, is a git repo, and has a clean working tree.
Treat a failure as a soft warning — the user can decide to proceed or stash.

---

## Step 1 — Establish the time window

If the user says "today", use today's date.
If the user says "this week" or "since Monday", calculate the date range
from the current date.
If no period is specified, default to today.

Compute the boundary timestamps `START_TS` and `END_TS` for the steps below.

---

## Step 2 — Gather git activity

Run from each repo the user worked in. If the user is currently inside a
repo, default to that one; otherwise ask which repo(s) to include.

```bash
git log --since="$START_TS" --until="$END_TS" \
  --author="$(git config user.name)" \
  --format="%h %ad %s" --date=short --all
```

For any commit whose message is thin, read the diff stat:

```bash
git show --stat <hash>
```

Use the commit messages + diff stats to extract concrete things done:
files touched, areas refactored, bugs fixed, features added. The commit
log is the primary source — Jira and file scans only supplement it.

---

## Step 3 — Scan recently changed files (optional)

When a commit message is too thin to identify the area, scan modified
files in the window:

```bash
find . -newermt "$START_TS" ! -newermt "$END_TS" \
  -name "*.swift" \
  -not -path "*/DerivedData/*" \
  -not -path "*/.git/*" \
  -not -path "*/.build/*" \
  | sort
```

Use changed files to infer what areas were worked on. Skip generated
files and build artefacts.

---

## Step 4 — Gather Jira activity (optional)

If the Atlassian MCP is available **and** a cloud ID is resolvable (from
`CLAUDE.md` or `getAccessibleAtlassianResources`), query for tickets
updated in the window:

```
searchJiraIssuesUsingJql(
  cloudId: $ATLASSIAN_CLOUD_ID,
  jql: "assignee = currentUser() AND updated >= $START_TS ORDER BY updated DESC",
  fields: ["summary", "status", "description"]
)
```

If the MCP is not available or the cloud ID can't be resolved, skip this
step and report in the summary that Jira data was not included.

---

## Step 5 — Extract tasks

From git + file + Jira data, extract only concrete things that were done:

- Code written, refactored, or fixed
- Architecture decisions made (visible in commit messages or merged PR
  descriptions)
- Bugs investigated or resolved
- Documents, plans, or specs created (visible in non-code commits or
  Obsidian timestamps)
- Tools, configs, or CI set up
- Reviews or audits completed

Discard: ephemeral exploration that didn't produce an artefact,
abandoned branches, and meta-conversation. The skill is producing a
work log, not a session log.

---

## Step 6 — Write the notes

Write one markdown file per day. If multiple days were requested, write
one file per day.

### Format

```markdown
# Daily Notes — [Weekday, DD Month YYYY]

## [Project Name]

- [Task as a past-tense statement of work done]
- [Task]
- ...

## [Another Project if applicable]

- [Task]
```

### Voice and style rules — critical

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

### Prohibitions (red flags)

Never include any of these words / phrases:

- "prompt", "AI", "Claude Code", "Claude.ai", "model"
- "wrote a skill", "ran a skill", "used a tool"
- "agent", "subagent", "spawned"
- "MCP", "tool call", "tool result"

Always include:

- Concrete file names (`LazyVStack`, `VODPlayerViewModel.swift`)
- Concrete method / function names
- Concrete root causes ("fixed the width calculation" not "fixed a bug")

---

## Step 7 — Save to Obsidian daily note

Append the generated notes to today's Obsidian daily note via the CLI.

```bash
# Get today's relative path
obsidian daily:path
# → daily/YYYY/MM-MMM/YY-MM-D.md (day not zero-padded)

# If today's note doesn't exist yet, create it
obsidian create path=<rel> content="---\ntags:\n- daily\n---\n\n# YYYY-MM-DD\n\n## To-Do\n\n- [ ]\n\n---\n\n## Notes\n"

# Append the Work Log block — `## Notes` is the last section in the
# template, so EOF append lands under it
obsidian daily:append content="## Work Log\n\n### [Project Name]\n\n- [task]\n- [task]\n"

# Verify
obsidian daily:read
```

Report the absolute path of the updated daily note to the user.

---

## Quality checklist

Before reporting completion, verify the daily note:

- [ ] Written in first person, past tense
- [ ] No mention of Claude, AI, prompts, or tooling (run the
  prohibition list)
- [ ] Tasks are specific enough to be meaningful — not just "worked on X"
- [ ] Grouped by project
- [ ] Filename / date matches the requested window
- [ ] Only days with actual work are included
