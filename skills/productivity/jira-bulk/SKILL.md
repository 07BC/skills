---
name: jira-bulk
description: >
  Bulk operations on Jira issues — set fix version, transition status — across
  multiple tickets in a single invocation. Use when the user says "set fix
  version on these tickets", "transition NAT-XXX to In Review", "bulk jira",
  "update these tickets", or "/j:jira-bulk". For single-ticket creation use
  plan-to-jira instead.
disable-model-invocation: true
compatibility:
  tools:
    - mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources
    - mcp__plugin_atlassian_atlassian__editJiraIssue
    - mcp__plugin_atlassian_atlassian__getTransitionsForJiraIssue
    - mcp__plugin_atlassian_atlassian__transitionJiraIssue
    - AskUserQuestion
---

# jira-bulk

Applies one operation to a list of Jira tickets. Operations: `fix-version`,
`transition`. Each ticket is independent — partial success is reported, not
aborted.

---

## Step 1 — Parse the request

From the user message, extract:

- **Operation**: `fix-version` or `transition`
- **Value**: the version name (e.g. `"26.5"`) or target status (e.g. `"In Review"`)
- **Ticket list**: one or more Jira keys (e.g. `NAT-123 NAT-124 NAT-125`)

If any of these is unclear, ask via `AskUserQuestion` before proceeding.

---

## Step 2 — Get cloud ID

Call `getAccessibleAtlassianResources`. Use the `id` of the first result as
`cloudId`. Do **not** hardcode it.

---

## Step 3 — Apply operation per ticket

Process each ticket independently. Continue on failure — do not abort the
batch.

### fix-version

Call `editJiraIssue` with:

```json
{
  "issueKey": "NAT-XXX",
  "fields": {
    "fixVersions": [{ "name": "<value>" }]
  }
}
```

If the version doesn't exist in the project, the API will error — record the
failure with the error message.

### transition

1. Call `getTransitionsForJiraIssue(issueKey)` to get available transitions.
2. Match the target status name (case-insensitive substring match against
   transition `name` field).
3. If no match: record failure and list the available transitions in the
   error row.
4. If matched: call `transitionJiraIssue(issueKey, transitionId)`.

---

## Step 4 — Report

Emit a summary banner:

```
=== jira-bulk: fix-version "26.5" ===
NAT-123 ✅
NAT-124 ✅
NAT-125 ❌ version "26.5" not found in project
=== 2/3 succeeded ===
```

For transition failures, include the available transitions:

```
NAT-126 ❌ no transition named "In Review" — available: To Do, In Progress, Done
```
