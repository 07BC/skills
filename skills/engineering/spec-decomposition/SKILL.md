---
name: spec-decomposition
description: >
  Turns a Jira story into a GitHub-backed technical master spec and its
  sequential child specs. Reads the story's acceptance criteria, freezes a stable
  AC ID for each, decomposes the work into one or more child specs via
  spec-scope-guardian, then creates a GitHub master issue plus native child
  sub-issues (gh api graphql) carrying the traceability matrix. Does NOT
  implement — hand each child to /spec-pipeline with --from-issue. Use when the
  user says "decompose this story", "set up the master spec", "spec-decomposition
  NAT-1234", or "/spec-decomposition …". Project must declare its spec_pipeline YAML
  block (incl. github.repo) in CLAUDE.md — see ../spec-pipeline/SCHEMA.md.
disable-model-invocation: true
---

# Spec Master

`/spec-decomposition` is the front door to the spec pipeline. It owns **decomposition
and tracking**: Jira story → GitHub master issue + sequential child sub-issues,
each linked into a traceability matrix that later gates drift. It does not write
code and does not create worktrees. Implementation is `/spec-pipeline`'s job, one
child at a time.

This skill creates GitHub issues — an outward, hard-to-undo side effect. **Never
auto-invoke.** Always an explicit user trigger.

> **Why GitHub, not Jira, for the spec tree:** Jira owns the user story and its
> acceptance criteria (the product *what*). GitHub owns the *technical* spec
> decomposition (the *how*) — branch-independent, team-visible, queryable via
> `gh`, and rendered as a native sub-issue tree with a progress bar. See the ADR
> on the master-spec layer.

---

## Help mode

If `$ARGUMENTS` is empty, `--help`, `-h`, or `help`, print the block below
verbatim and exit — no config read, no MCP call, no `gh` call.

````
/spec-decomposition — decompose a Jira story into a GitHub master spec + child sub-issues

Usage:
  /spec-decomposition --from-jira KEY     read the story, freeze AC IDs, decompose, create issues
  /spec-decomposition KEY                 shorthand when KEY matches ^[A-Z]+-[0-9]+$
  /spec-decomposition --help              show this message

What it does:
  0. Preflight (pipeline-preflight + gh/MCP/auth checks)
  1. Read the Jira story; freeze a stable ID for each AC (KEY-AC1, KEY-AC2, …)
  2. Decompose via spec-scope-guardian → one child (SCOPE: OK) or N (SCOPE: SPLIT)
  3. Confirm the decomposition with you
  4. Create the GitHub master issue + native child sub-issues (gh api graphql),
     each carrying its covers/depends_on and the AC checklist

Durable artefacts after a run:
  - The GitHub master issue (the technical master spec — single source of truth)
  - N child sub-issues, sequenced by depends_on
  - An audit log at $OBSIDIAN_VAULT/<audit_dir>/<KEY>-master.md

Next step:
  Run each child in dependency order:  /spec-pipeline --from-issue <child-issue-#>
  A child hard-stops until every depends_on child is merged to main.
````

---

## Inputs

Primary input is a Jira story key. Accept `--from-jira <KEY>`, or a bare positional
`KEY` matching `^[A-Z]+-[0-9]+$` (per the orchestrator argument-style convention).
The story **must** have acceptance criteria — never invent them.

## Variables

Resolve config once (reuses the spec-pipeline config reader):

```bash
SCRIPTS="$HOME/.claude/skills/spec-pipeline/scripts"
eval "$(bash ${SCRIPTS}/read-pipeline-config.sh)"
```

This exports `SPEC_PIPELINE_*`. `/spec-decomposition` additionally needs
`SPEC_PIPELINE_GITHUB_REPO` (the `github.repo` key, `owner/name`); if unset, fall
back to the current repo (`gh repo view --json nameWithOwner -q .nameWithOwner`).
`SPEC_PIPELINE_TICKET_PREFIX` anchors the AC ID namespace.

## Model confirmation

> Running as: Claude Opus (top-level session) — normal mode. Opus owns every
> branching decision; the only subagent is `spec-scope-guardian` (decomposition).

---

## Phase 0 — Preflight

1. Apply skill `pipeline-preflight`. Surface any signal via `AskUserQuestion`
   (Reconcile / Proceed / Abort); continue only on `Pre-flight clean.` or Proceed.
2. Verify tooling, halting with a clear message on any failure:
   - `gh auth status` succeeds and the resolved repo exists.
   - Atlassian MCP loads (`ToolSearch("select:mcp__plugin_atlassian_atlassian__getJiraIssue")`).
   - `gh api graphql` is reachable (a trivial `viewer { login }` query).

## Phase 1 — Read story & freeze AC IDs

1. Fetch the story via `mcp__plugin_atlassian_atlassian__getJiraIssue`. Extract
   summary, description, and the acceptance criteria **verbatim**.
2. If there are no ACs, halt — ask the user to add them. Never invent ACs.
3. Assign a **frozen** ID to each AC in document order: `<KEY>-AC1`, `<KEY>-AC2`, …
   These IDs are the spine. Once written to the master issue they are immutable —
   inserting a new Jira AC later appends a new ID; it never renumbers existing
   ones. (Phase 4 below records this rule in the issue body.)
4. Idempotence: if a master issue for this KEY already exists (search
   `gh issue list --search "<KEY>" --label spec-decomposition`), read its frozen AC IDs
   and reuse them rather than re-freezing. Offer the user Resume / Recreate / Abort.

## Phase 2 — Decompose

Spawn `spec-scope-guardian` via the Agent tool (`subagent_type:
spec-scope-guardian`). Pass `jira_key`, `raw_text`, the frozen `master_acs` (ID +
text), and a `proposal_path` under `$TMPDIR`. If it returns no usable result (raw
API error, socket-closed, timeout — not a reported verdict), apply
`[SKILL: ~/.claude/skills/subagent-reliability/SKILL.md]`; a recovered run does not
consume a retry slot.

Parse the last non-empty line:
- `SCOPE: OK` → a single child covering every AC (id defaults to the story slug).
- `SCOPE: SPLIT` → read the child-spec proposal YAML at `proposal_path`.
- anything else → halt: "spec-scope-guardian produced no SCOPE: verdict."

## Phase 3 — Confirm

Render the decomposition: the frozen AC list, and each proposed child with its
`covers`, `depends_on`, and rationale. Validate **before** asking: every AC lands
in exactly one child's `covers`, no orphan, no duplicate, `depends_on` acyclic. If
validation fails, halt — re-run decomposition or escalate.

Ask via `AskUserQuestion`:
- **Approve — create the master issue + sub-issues** (Recommended)
- **Adjust** — let me change the split first (re-run Phase 2 with notes)
- **Abort** — no GitHub writes

## Phase 4 — Create GitHub issues

On Approve, all writes go through `gh` (never curl / REST / octokit).

1. **Master issue.** Body contains: a link to the Jira story; an
   `## Acceptance Criteria` list, one line per frozen ID
   (`- **<KEY>-AC1** — <text>`); a `## Child specs` task-list (filled in step 3);
   and the **AC-ID immutability rule** verbatim. Label `spec-decomposition`.
   ```bash
   master_num=$(gh issue create --repo "$REPO" --label spec-decomposition \
     --title "[spec] <KEY> — <summary>" --body-file "$body" \
     | grep -oE '[0-9]+$')
   master_id=$(gh issue view "$master_num" --repo "$REPO" --json id -q .id)
   ```
2. **Child sub-issues**, in dependency order. For each child:
   ```bash
   child_num=$(gh issue create --repo "$REPO" --label spec-child \
     --title "<child title>" --body-file "$child_body" | grep -oE '[0-9]+$')
   child_id=$(gh issue view "$child_num" --repo "$REPO" --json id -q .id)
   gh api graphql \
     -f query='mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){subIssue{number}}}' \
     -f p="$master_id" -f c="$child_id"
   ```
   Each child body declares, in a fenced block the pipeline parses,
   `covers: [<ids>]` and `depends_on: [<child-issue-#s>]`, plus a per-AC checklist.
   > If `addSubIssue` is rejected as an unknown field, retry the same call with
   > `-H "GraphQL-Features: sub_issues"`. Still `gh`, not curl.
3. **Backfill the master `## Child specs` task-list** with each child's number,
   title, `covers`, and `depends_on` (`gh issue edit "$master_num" --body-file`).
   This rendered list **is** the traceability matrix — the single source of truth.

Then write the audit log at
`${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/<KEY>-master.md` (decomposition,
frozen AC IDs, issue numbers) and print the master issue URL plus the suggested
`/spec-pipeline --from-issue <#>` run order.

## Halt Conditions

The run halts and reports (no partial GitHub tree left dangling without a note)
when:
- Preflight tooling fails (gh auth, MCP, GraphQL unreachable).
- The Jira story has no acceptance criteria.
- `spec-scope-guardian` returns no `SCOPE:` verdict, or proposes a split that
  fails AC-distribution / acyclicity validation.
- A `gh issue create` or `addSubIssue` call fails mid-creation — print the issues
  already created and their links, name the failed step, and ask
  (Retry / Accept-partial-and-note-master / Stop). **Never auto-delete** created
  issues; GitHub deletion is destructive.

## Model & mode

Opus orchestrates in the top-level session and owns every branching decision.
The single leaf agent (`spec-scope-guardian`, Opus) is dispatched via the Agent
tool. No worktree, no implementation, no code edits — `/spec-decomposition` only reads
Jira and writes GitHub.
