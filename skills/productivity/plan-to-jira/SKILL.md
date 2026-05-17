---
name: plan-to-jira
description: >
  Converts a plan, spec, or design into a Jira ticket using a structured template.
  Use this skill whenever the user says "create a Jira ticket", "turn this into a ticket",
  "raise a ticket for this", "log this as a Jira issue", "make a Jira card", "plan-to-jira",
  or any time a plan or feature description needs to become a trackable Jira issue.
  Also trigger when the user finishes a planning or grilling session and wants to capture
  the outcome. Always use this skill — do not create Jira tickets ad hoc without it.
disable-model-invocation: true
compatibility:
  tools:
    - mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources
    - mcp__plugin_atlassian_atlassian__getVisibleJiraProjects
    - mcp__plugin_atlassian_atlassian__createJiraIssue
    - mcp__plugin_atlassian_atlassian__lookupJiraAccountId
    - AskUserQuestion
---

# plan-to-jira

Turns a plan into a well-structured Jira ticket. The goal is a ticket that is
**useful to a developer picking it up cold** — enough context to understand why,
enough clarity to know when it's done, no implementation prescription unless
genuinely required.

---

## Step 1 — Locate the plan

The plan may come from one of these sources (check in order):

1. **Current plan file** — if plan mode was active, check `~/.claude/plans/` for the most recent `.md` file.
2. **Conversation context** — the user may have described or pasted the plan directly.
3. **A file the user referenced** — read it.

If none of the above is clear, ask the user where the plan is before continuing.

---

## Step 2 — Read project context

Before asking the user anything, try to infer as much as possible from the environment:

- Read `CLAUDE.md` in the current working directory — look for Jira project keys, component names, team names, or any mention of labels.
- Read the git remote URL: `git remote get-url origin` — the repo name often reveals the project or team.
- Scan the plan itself for Jira project keys (e.g. `NAT-`, `PROJ-`), component names, or any other signals.

Collect what you can infer vs. what you still need to ask.

---

## Step 3 — Discover Jira resources

Call `getAccessibleAtlassianResources` to get the available cloud IDs, then
call `getVisibleJiraProjects` to retrieve the list of projects. This gives you
real project names and keys to offer as options in Step 4.

---

## Step 4 — Ask the user (always use AskUserQuestion)

You **must** use the `AskUserQuestion` tool for all questions — never ask via text.
Ask at most 4 questions in one call. Batch as many as possible together.

Before asking, determine which of these you can already infer confidently from Step 2:

| Question | Infer from | Ask if |
|---|---|---|
| Jira project | Project key in CLAUDE.md or plan | Not found |
| Labels | CLAUDE.md or existing ticket patterns | Not found |
| Component | CLAUDE.md or repo name | Not found |
| Assignee | Assume the current user unless otherwise obvious | Always confirm |
| Priority | Severity language in the plan ("critical", "blocking") | Not obvious |
| Issue type | Plan nature — bug vs. feature vs. task | Not obvious |

For the **Jira project** option, use real project names from Step 3 as the options.
For **labels** and **components**, list any you inferred and offer "Other / none" as an option.
For **assignee**, default option should be "Assign to me" — always confirm rather than silently assigning.

---

## Step 5 — Draft the ticket

Map the plan content to the ticket template below. Keep sections **high-level**:

- **Do** describe what the feature or fix achieves from a user or system perspective.
- **Do not** include specific function names, class hierarchies, file paths, or step-by-step implementation instructions — those belong in the PR, not the ticket.
- If the plan has implementation detail, summarise it into intent and put specifics in Technical Notes only.
- If a section has no content, omit it rather than leaving a placeholder.

```markdown
# {Summary}

{One sentence describing the work or problem}

---

## Context

{Why this matters — what triggered it, relevant background, user impact, links}

---

## Problem

{What is currently wrong, missing, unclear, or inefficient}

---

## Proposed Solution

{What should change at a high level. Avoid over-specifying implementation unless required}

---

## Acceptance Criteria

- Given {initial state}
  When {action or event}
  Then {expected result}

- Given {another state}
  When {action or event}
  Then {expected result}

---

## Technical Notes

{Implementation hints, affected areas, APIs, dependencies, constraints, migration notes — only if genuinely useful}

---

## Test Plan

- [ ] Unit tests added/updated
- [ ] UI tested manually
- [ ] Edge cases verified
- [ ] Regression areas checked
- [ ] Tested on relevant devices/OS versions

---

## Out of Scope

{Anything explicitly not included in this ticket}
```

### Writing good Acceptance Criteria

Each criterion should describe observable behaviour, not implementation:

- **Good:** Given the user has muted their mic, when they go live, then the mic indicator shows muted state.
- **Bad:** Given `MicrophoneService.isMuted == true`, when `BroadcastViewModel.startStream()` is called, then `UIState.micIcon` is `.muted`.

Write as many criteria as needed to fully describe "done". Cover the happy path first, then error states and edge cases.

---

## Step 6 — Confirm before creating

Show the user the full draft ticket and ask for confirmation before creating it.
Do this via a short text message — not another AskUserQuestion call. Wait for the user to say "yes", "go ahead", or similar before proceeding.

If the user wants changes, apply them and show the revised draft again.

---

## Step 7 — Create the ticket

Once the user confirms, call `createJiraIssue` with:

- `cloudId` from Step 3
- `projectKey` from Step 4
- `summary` — the one-sentence Summary line (without the `#`)
- `issueType` — from Step 4 (default: `Story` or `Task` if the user didn't specify)
- `description` — the full template body in Atlassian Document Format (ADF)
- `labels` — from Step 4 (may be empty)
- `components` — from Step 4 (may be empty)
- `assignee` — the account ID from `lookupJiraAccountId` if assigning to a user

After creation, output the ticket URL and key (e.g. `NAT-1234`).

---

## What to avoid

- **Over-specifying implementation** — a ticket says *what* and *why*, not *how*. If the plan went deep on implementation, summarise it.
- **Vague acceptance criteria** — "it works correctly" is not a criterion.
- **Copying the plan verbatim** — the plan is a design artifact; the ticket is a communication artifact. Rewrite for clarity.
- **Silent defaults** — always use AskUserQuestion for assignee, labels, and components rather than assuming.
