---
name: spec-pipeline
description: >
  Runs the full spec-to-PR pipeline: distil a spec from a Jira ticket, an
  existing markdown spec, or a free-form prompt; validate the plan fits the
  codebase; implement task-by-task through the engineer → test-writer →
  concurrency-auditor → task-reviewer inner loop; whole-diff review; then
  open a PR via /git-pr. Each pipeline runs in its own git worktree.
  Inputs are passed as flags. Use when the user says "ship this ticket",
  "run the pipeline", "spec-pipeline NAT-1234", "build this spec", or
  "/spec-pipeline …". Project must declare its config in a fenced
  spec_pipeline YAML block in CLAUDE.md — see SCHEMA.md.
---

# Spec Pipeline

`/spec-pipeline` is the top-level entry point. It validates inputs, sets
up a worktree, then drives Stages 1–5 inline by dispatching one leaf
specialist agent at a time.

This skill creates git worktrees and branches. **Never auto-invoke.** Always
explicit user trigger.

---

## Help mode

Before doing anything else — before resolving paths, before reading config,
before any side effect — check `$ARGUMENTS`. If it is one of:

- empty (no arguments)
- `--help`
- `-h`
- `help`

print the help block below verbatim and exit. Do not parse config, do not
create a worktree, do not spawn the orchestrator, do not run any script.

````
/spec-pipeline — end-to-end spec-driven orchestration

Usage:
  /spec-pipeline --from-jira KEY        distil a Jira ticket → spec → plan → PR
  /spec-pipeline --from-spec PATH       build from an existing markdown spec
  /spec-pipeline --from-prompt "TEXT"   build from a free-form description
  /spec-pipeline KEY                    shorthand for --from-jira when KEY matches ^[A-Z]+-[0-9]+$

  /spec-pipeline --help                 show this message

What it does:
  0. (Jira only) Scope check — splits oversized tickets into sub-tasks before
     any other work. Skipped for --from-spec / --from-prompt, on resume, or
     when the ticket already has a parent or sub-tasks.
  1. Reads spec_pipeline YAML config from your CLAUDE.md (see SCHEMA.md)
  2. Creates a per-pipeline git worktree at ../<repo>-<branch-id>/ on a fresh branch
     (branch-id = ticket key for Jira, spec-id slug for other sources)
  3. Distils the input into docs/specs/ and docs/plans/ (gitignored, inside the worktree)
  4. Drives engineer → test-writer → concurrency-auditor → task-reviewer per task
  5. Whole-diff swift-spec-review (up to 3 cycles before escalation)
  6. Opens a PR via /git-pr after your confirmation

One-time project setup:
  - Add a spec_pipeline YAML block to the project's CLAUDE.md
    (see SCHEMA.md alongside this SKILL.md for the schema)
  - Add docs/specs/, docs/plans/, master-plan.md to .gitignore

Durable artefacts after a run:
  - The PR (on GitHub)
  - Audit log at $OBSIDIAN_VAULT/AI/plans/<spec-id>.md
    (full spec + full plan + stage log)
  - The worktree at ../<repo>-<branch-id>/ until you remove it with
    `git worktree remove`

You're asked at minimum twice during a run, and more when the input or spec
has unresolved questions:
  - Before Stage 1: lightweight summary confirmation
  - Before Stage 1 (Jira only): scope-split confirmation if the ticket is too
    big — may be zero questions
  - During Stage 1: one question per conflict or open UI decision (may be zero)
  - During Stage 3: one question per spec ambiguity the engineer cannot infer
    from the codebase (may be zero)
  - Before Stage 5: PR body confirmation
Otherwise the pipeline interrupts only on hard failure (spec ambiguity,
plan invalid after one amendment, cycle budget exceeded, /git-pr blocker).

Long pipelines (60–90+ min) may pause silently at the end of a turn due to
context growth. If the pipeline appears to stop with no message, type
`continue` — it will resume from where it left off.

For the full config schema and required vs optional fields, see SCHEMA.md
in this skill's directory.
````

---

## Resolving script paths

After `make install` (or `make link`), the scripts are always symlinked at:

```
$HOME/.claude/skills/spec-pipeline/scripts/read-pipeline-config.sh
$HOME/.claude/skills/spec-pipeline/scripts/derive-spec-id.sh
```

Use that path directly. Do not attempt to derive it from the SKILL.md's own
location — that was unreliable. If the path doesn't exist (non-standard
install), locate it with:

```bash
find "$HOME/.claude" -name "read-pipeline-config.sh" -maxdepth 5 2>/dev/null | head -1
```

Set once for the session:

```bash
SCRIPTS="$HOME/.claude/skills/spec-pipeline/scripts"
```

Then use `$SCRIPTS/read-pipeline-config.sh` etc. throughout.

---

## Inputs

Exactly one source flag is required:

- `--from-jira <KEY>` — fetches the ticket via the Atlassian MCP
- `--from-spec <PATH>` — reads an existing markdown spec
- `--from-prompt "<TEXT>"` — distils a free-form description

`$ARGUMENTS` from the slash-command invocation is parsed left-to-right; the
first flag wins. Unrecognised flags fail fast — print *"unknown flag <flag>;
run `/spec-pipeline --help` for usage"* and exit.

If no flag is provided but the argument looks like a Jira key
(matches `^[A-Z]+-[0-9]+$`), assume `--from-jira`.

If `$ARGUMENTS` is empty or matches the Help mode triggers above, this Step
is unreachable — the Help mode dispatch fires first.

---

## Step 1 — Read pipeline config

```bash
eval "$(bash ${SKILL_DIR}/scripts/read-pipeline-config.sh)"
```

If this exits non-zero, surface the script's stderr verbatim and stop:

> The project's `CLAUDE.md` does not have a valid `spec_pipeline` YAML block.
> See `skills/engineering/spec-pipeline/SCHEMA.md` for the schema.
> Required keys: `workspace`, `scheme`, `destination`, `tests_target`.

Do not invent defaults for required keys.

---

## Step 1.5 — Validate recommended paths

The architecture authority doc is recommended but not required. If
`SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC` is non-empty, check the file exists
before proceeding (resolved relative to the project root, i.e. the current
working directory):

```bash
if [[ -n "${SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC:-}" ]] && \
   [[ ! -f "${SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC}" ]]; then
  # arch doc set in config but file is missing — handle below
  :
fi
```

If the file is missing, ask the user via `AskUserQuestion`:

> The architecture doc at `<path>` doesn't exist. The pipeline can run
> without it, but spec-distiller, planner, and engineer fall back to the
> `swift-engineer` skill body as the only architecture authority. What would
> you like to do?

- Option A: **Stop and generate it with `/swiftopher-columbus`** (Recommended) — `/swiftopher-columbus` produces a thorough living architecture document for the codebase. Once it has written the file at the configured path, re-invoke `/spec-pipeline`.
- Option B: **Proceed without it** — unset `SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC` for the rest of this run so agents skip it cleanly. Use this when you've decided the doc isn't worth producing for this work.
- Option C: **Abort** — stop and let the user fix the config (e.g. correct the path or remove the field from CLAUDE.md).

On Option A:
- Print: `Run \`/swiftopher-columbus\` first, then re-invoke \`/spec-pipeline\`.`
- Exit. Do not create the worktree, do not spawn the orchestrator.

On Option B:
- Run `unset SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC` (or `export SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC=""`)
  so the variable is empty when the orchestrator's invocation prompt is
  composed. Agents already treat the "if set" case as "skip the read".
- Continue to Step 2.

On Option C:
- Print a one-line abort message and exit. Do not create the worktree.

The `context_docs` list is NOT validated here — missing context files are
lower-stakes and agents handle them with a per-file read that fails softly.

---

## Step 2 — Resolve input → (raw_text, spec_id)

### `--from-jira <KEY>`

1. Check the Atlassian MCP is connected. Load schemas via:

   ```
   ToolSearch("select:mcp__plugin_atlassian_atlassian__getJiraIssue,mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources")
   ```

   If either tool fails to load (MCP not available), stop:

   > Atlassian MCP is not available in this session. Use `--from-spec` or
   > `--from-prompt` instead.

2. Call `mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources`
   then `mcp__plugin_atlassian_atlassian__getJiraIssue` for the key. Extract:
   - Summary (one line)
   - Description (full body)
   - Acceptance criteria (verbatim)
   - Issue type (Bug / Story / Task / Chore)
   - Labels / Components
   - `parent_key` — the `parent.key` field if present, else empty (used
     by Step 3.5 to skip Stage 0 on tickets that are already sub-tasks)
   - `existing_subtask_keys` — array of keys from the `subtasks` field;
     defensive read (treat missing or empty as `[]`). Used by Step 3.5 to
     halt re-invocations on already-split parents.

3. If the ticket has no acceptance criteria, stop. Tell the user to add ACs
   before re-running. Never invent acceptance criteria.

4. Compose `raw_text` as a single markdown blob containing all of the above.

5. Derive the spec ID and branch ID:

   ```bash
   spec_id="$(bash ${SKILL_DIR}/scripts/derive-spec-id.sh --from-jira "<KEY>" "<summary>")"
   branch_id="<KEY>"   # worktree and branch use only the ticket number
   ```

6. `source_type=jira`

### `--from-spec <PATH>`

1. Verify the file exists. If not, stop with a clear error.
2. `raw_text="$(cat <PATH>)"`
3. ```bash
   spec_id="$(bash ${SKILL_DIR}/scripts/derive-spec-id.sh --from-spec "<PATH>")"
   branch_id="${spec_id}"
   ```
4. `source_type=spec`

### `--from-prompt "<TEXT>"`

1. `raw_text="<TEXT>"`
2. ```bash
   spec_id="$(bash ${SKILL_DIR}/scripts/derive-spec-id.sh --from-prompt "<TEXT>")"
   ```
3. Confirm the derived `spec_id` with the user via `AskUserQuestion` (prompts
   can produce odd slugs):

   - Option A: `<derived-slug>` (Recommended)
   - Option B: Let me type a different slug

4. ```bash
   branch_id="${spec_id}"
   ```
5. `source_type=prompt`

---

## Step 3 — Lightweight confirmation

Show the user a summary before any disk operation:

```
## Pipeline ready

**Spec ID:** <spec-id>
**Source:** <jira KEY | spec PATH | prompt>
**Worktree (to be created):** <repo-parent>/<repo-name>-<branch-id>
**Branch (to be created):** <type>/<branch-id> (type: feat | bug | chore — derived
                                              from spec source or defaulted to feat)
**Cycle budget:** ${SPEC_PIPELINE_CYCLE_BUDGET}
**Audit log:** ${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/<spec-id>.md
```

If the source is `jira`, also show:
- Summary, Type, Labels, AC count

Ask via `AskUserQuestion`:

- Option A: Looks right — proceed (Recommended)
- Option B: Stop — I want to fix something first

Do not proceed without explicit confirmation.

> **Long-pipeline note** — also display this block verbatim in the confirmation
> message so the user sees it before work begins:
>
> ```
> ⏱️  This pipeline can take 60–90+ minutes across multiple agent dispatches.
>    Claude Code may pause silently at the end of a long turn (context growth).
>    If the pipeline appears to stop with no message, type  continue  to resume.
>    The pipeline will pick up from where it left off.
> ```

---

## Step 3.5 — Scope check (Jira only)

Run only when `source_type == jira`. Otherwise skip to Step 4.

Compute the worktree path the same way Step 4 will:

```bash
repo_root="$(git rev-parse --show-toplevel)"
repo_name="$(basename "$repo_root")"
worktree_path="$(dirname "$repo_root")/${repo_name}-${branch_id}"
```

### Skip conditions — in order

1. **Resume in progress.** If `[[ -d "$worktree_path" ]]`, the user is
   resuming an in-flight pipeline. Skip Stage 0 and print one line:

   ```
   ⏭️  Scope check skipped — worktree exists, resuming
   ```

   Continue to Step 4.

2. **Ticket already has a parent.** If `parent_key` (from Step 2) is
   non-empty, this ticket is already a sub-task. Skip Stage 0 and print:

   ```
   ⏭️  Scope check skipped — ticket already has a parent
   ```

   Continue to Step 4.

3. **Parent already has sub-tasks.** If `existing_subtask_keys` is
   non-empty, the parent has already been split. Halt:

   ```
   Parent ticket <jira_key> already has sub-tasks: <KEY1, KEY2, ...>.
   Re-invoke /spec-pipeline --from-jira <child_key> per child.
   ```

   Exit. Do not create the worktree.

If none of the above apply, run scope-guardian.

### Scope-guardian invocation

```bash
proposal_path="${TMPDIR:-/tmp}/spec-pipeline-${spec_id}-proposal.yaml"
rm -f "$proposal_path"
```

Spawn `spec-scope-guardian` via the Agent tool (subagent_type: `spec-scope-guardian`). Pass:

- `jira_key`
- `raw_text` (the same blob assembled in Step 2)
- `proposal_path`
- The `SPEC_PIPELINE_*` config block (so the agent can read context_docs
  and target_architecture_doc)

Parse the agent's **last non-empty stdout line**:

- `SCOPE: OK` → continue to Step 4.
- `SCOPE: SPLIT` → run the split flow below.
- Anything else (missing verdict, truncated output, error) → halt:

  ```
  spec-scope-guardian produced no SCOPE: verdict — see output above.
  ```

  Do not create the worktree. The user re-invokes.

### Split flow

1. Read `proposal_path`. If absent or malformed YAML, halt with the same
   parse-error message as above.

2. Render the proposed sub-tasks (titles, summaries, AC distribution,
   rationales) and ask via `AskUserQuestion`:

   - Option A: **Approve and create sub-tickets** (Recommended) — proceed
     to step 3 below.
   - Option B: **Cancel** — exit with the hint *"Re-scope the ticket in
     Jira and re-invoke /spec-pipeline."* No worktree, no Jira writes.

3. On Approve, load Jira write tools:

   ```
   ToolSearch("select:mcp__plugin_atlassian_atlassian__getJiraProjectIssueTypesMetadata,mcp__plugin_atlassian_atlassian__createJiraIssue,mcp__plugin_atlassian_atlassian__createIssueLink,mcp__plugin_atlassian_atlassian__addCommentToJiraIssue")
   ```

   If any fail to load (MCP not available), halt with the same message as
   Step 2's MCP-unavailable case.

4. Resolve the Sub-task issue type:

   - Project key = the substring of `jira_key` before the `-`.
   - Call `mcp__plugin_atlassian_atlassian__getJiraProjectIssueTypesMetadata`.
   - Find an issue type whose name case-insensitively matches `Sub-task`,
     `Subtask`, or `Sub-Task`.
   - **Fallback if none exists** (some Kanban projects have no Sub-task
     type): ask via `AskUserQuestion`:
     - Option A: **Create siblings linked to the parent** — create issues
       of the same type as the parent and link them with
       `createIssueLink` relationship `"relates to"`.
     - Option B: **Abort** — exit without writes.

5. For each proposed sub-task in order, call
   `mcp__plugin_atlassian_atlassian__createJiraIssue` with:

   - `project: { key: <project_key> }`
   - `summary: <title>`
   - `description: <YAML's summary + the ACs rendered as a markdown
     checklist with - [ ] per AC>`
   - `issuetype: { name: <resolved type> }`
   - `parent: { key: <jira_key> }` (true Sub-task path) — OR omit the
     `parent` field and call `createIssueLink` after creation (sibling
     fallback path)

   Collect the returned KEY for each.

6. Post a comment to the parent via
   `mcp__plugin_atlassian_atlassian__addCommentToJiraIssue` with body:

   ```
   spec-pipeline scope-guardian split this ticket into N sub-tasks:
   - <KEY1>: <title1>
   - <KEY2>: <title2>
   Re-invoke /spec-pipeline --from-jira <KEY> per child when ready.
   ```

7. Print and exit:

   ```
   ## Scope SPLIT — sub-tickets created
   Parent:  <jira_key>  (comment posted)
   Created: <KEY1>, <KEY2>, ...
   Re-invoke /spec-pipeline --from-jira <KEY> per child when ready.
   ```

   Do NOT create the worktree. Do NOT spawn the orchestrator. The
   proposal file is left on disk for post-hoc debugging — the OS reaps
   tmpdir.

### Partial-failure handling

If `createJiraIssue` fails after some children have already been created,
print the keys that succeeded, name the one that failed, and ask via
`AskUserQuestion`:

- Option A: Retry the failed sub-task
- Option B: Accept the partial result and post the parent comment with
  what was created
- Option C: Stop — leave created sub-tickets as-is, skip the parent
  comment

**Never auto-rollback** created Jira issues. Jira undo is destructive and
noisy.

---

## Step 4 — Worktree management

Compute the worktree path:

```bash
repo_root="$(git rev-parse --show-toplevel)"
repo_name="$(basename "$repo_root")"
worktree_path="$(dirname "$repo_root")/${repo_name}-${branch_id}"
```

Compute the branch name. Type is `bug/` for ticket type Bug, `chore/` for
Chore, otherwise `feat/`:

```bash
branch="<type>/${branch_id}"
```

### If the worktree path exists

Read `${worktree_path}/master-plan.md` if present. Show the user:

```
A worktree for <spec-id> already exists at <worktree_path>.
Last status: <status from master-plan.md, or "unknown">
```

Ask via `AskUserQuestion`:

- Option A: Resume from where it left off (Recommended)
- Option B: Restart fresh (will require confirmation before removing the existing worktree)
- Option C: Abort

On **Resume**: jump straight to Step 5 in the existing worktree path.

On **Restart**:
1. Confirm one more time via `AskUserQuestion`:
   "This will run `git worktree remove ${worktree_path}` and delete its state. Confirm?"
2. If confirmed, run the removal, then continue to "create" below.

On **Abort**: stop. No changes.

### If the worktree path does not exist

Pre-flight check the current state of the parent repo:

```bash
git -C "$repo_root" status --porcelain
git -C "$repo_root" rev-parse --abbrev-ref HEAD
```

If `main` (or the configured base) has uncommitted changes, surface them and
ask the user whether to proceed anyway. Worktree create from a dirty main is
allowed but worth flagging.

Create the worktree:

```bash
git -C "$repo_root" worktree add "$worktree_path" -b "$branch"
cd "$worktree_path"
```

---

## Step 4.5 — Workspace setup

**Goal:** make the worktree buildable. This means understanding what the project
needs to compile and test, then providing it — not blindly running README commands.

```bash
cd "$worktree_path"
```

### Check for README.md

If `README.md` is absent, print a warning and continue. Do not halt.

```
⚠️  No README.md found in ${worktree_path}. Skipping workspace setup.
    Projects should include a README.md with setup instructions.
```

### Understand the setup holistically

If `README.md` exists, read the **entire file**. Do not scan only for code
blocks — understand the full narrative:

1. **What does each setup step produce?** Config files, generated Swift,
   `.xcconfig`, `.plist`, resolved packages, installed pods, etc.
2. **What does each step require?** API keys, CI credentials, developer team
   membership, environment variables, etc.
3. **Is the output per-worktree or shared?** Gitignored files generated by
   scripts are per-worktree. Package caches, SPM `.build/`, CocoaPods `Pods/`,
   and Xcode DerivedData are shared across worktrees automatically.

If the README contains no setup steps that affect the worktree's ability to
build, continue to Step 5 without action.

### Classify each setup step

Assign each identified step to one of three categories:

**Category A — Shared / auto-resolved (skip)**
`swift package resolve`, `pod install`, `npm install`, `bundle install`, or
anything that writes to a shared cache or a path already present in the
repo. Xcode resolves these automatically. **Skip** — do not re-run in the
worktree.

**Category B — Gitignored config or secrets generator**
A script that reads environment variables or credentials and writes one or
more files to gitignored paths (`.xcconfig`, `.swift`, `.plist`, `.env`,
`GoogleService-Info.plist`, etc.). These files are absent from a fresh
worktree because they are not in git.

For each Category B step:

1. **Identify the output paths** the script produces. Read the script itself
   if needed — look for `write_file`, `open(…, 'w')`, file path arguments, or
   grep for path strings. Cross-check with `.gitignore` to confirm the outputs
   are gitignored.

2. **Check the main working tree first:**
   ```bash
   test -f "${repo_root}/<output_path>"
   ```
   If all outputs exist in `repo_root`: **copy** them to the corresponding
   location in the worktree. This is the common case — the developer already
   has a configured checkout.
   ```bash
   mkdir -p "${worktree_path}/$(dirname <output_path>)"
   cp "${repo_root}/<output_path>" "${worktree_path}/<output_path>"
   ```

3. **If outputs are missing from the main tree:** check whether the required
   environment variables are set in the current shell. If yes, run the script
   from the worktree root. If no, halt with the message in the error section
   below.

**Category C — Developer environment / one-time setup (skip)**
Adding a team membership, installing Xcode, obtaining certificates, or
installing system tools. These are machine-level requirements. If the main
tree builds, they are already satisfied. **Skip.**

### Surface the plan, then execute

Before running or copying anything, print a brief plan:

```
## Workspace setup — <worktree_path>

  [skip]  <step description>  (Category A — shared with main tree)
  [copy]  <output_path>  (from main tree → worktree)
  [run]   <command>  (Category B — env vars present)
  [skip]  <step description>  (Category C — developer environment)
```

Then execute every `[copy]` and `[run]` step in order.

### Error: Category B script cannot be satisfied

If a Category B output is absent from both the main tree and the worktree, and
the required environment variables are not set, halt:

```
Setup cannot be completed automatically.

Script `<script>` produces `<output_path>` but:
  - The file does not exist in the main tree at `<repo_root>/<output_path>`
  - Required environment variables are not set: <VAR1>, <VAR2>, …

To proceed, either:
  1. Run the setup script manually in <worktree_path> with the required
     credentials, then re-invoke /spec-pipeline.
  2. Copy <output_path> from another configured checkout of this repo.

Worktree preserved at: <worktree_path>
```

Do not proceed to Step 5. The engineer agents will fail to build against an
unconfigured workspace.

### Success

If all `[copy]` and `[run]` steps complete without error, print one line and
continue:

```
✅ Workspace setup complete — <N> files copied, <M> commands run.
```

---

## Step 5 — Initialise audit log + state

The Agent tool is gated to top-level sessions only in this Claude Code
build — subagents cannot dispatch further subagents. So the SKILL drives
Stages 1–5 inline (Steps 6–10 below), dispatching one leaf specialist at
a time. The full design rationale and historical orchestrator prose are
preserved under `playbooks/spec-pipeline-orchestrator.md` and
`playbooks/swift-spec-implement.md` next to this file.

### Stage variables (bash shell state)

Set these once near the top of the implementation flow. They persist
across every subsequent Bash tool call in this session.

```bash
spec_path="${worktree_path}/${SPEC_PIPELINE_SPEC_DIR:-docs/specs}/${spec_id}.md"
plan_path="${worktree_path}/${SPEC_PIPELINE_PLAN_DIR:-docs/plans}/${spec_id}.md"
audit_path="${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/${spec_id}.md"
cycle=0
cycle_budget="${SPEC_PIPELINE_CYCLE_BUDGET:-3}"
amendment_attempted=0
blockers_path=""        # set in Stage 4 BLOCKED loop
blocked_cycle=""        # "1" while re-entering Stage 3 after Stage 4 BLOCKED
agents_dir="$HOME/.claude/agents"

mkdir -p "$(dirname "$audit_path")"
```

`spec_path` and `plan_path` are absolute paths under the worktree.
`audit_path` lives outside the worktree (in the Obsidian vault) and is
the durable cross-run record. Multi-line content (blockers tables,
amendment notes) is written to tmp files and passed by **path** to leaf
agents, never inlined in prompts.

### Initialise the audit log header

```bash
if [[ ! -f "$audit_path" ]]; then
  cat <<EOF > "$audit_path"
# Spec Pipeline Run — ${spec_id}

**Started:** $(date '+%Y-%m-%d %H:%M:%S')
**Source:** ${source_type}
**Spec ID:** ${spec_id}
**Worktree:** ${worktree_path}
**Branch:** $(git -C "$worktree_path" rev-parse --abbrev-ref HEAD)

---

## Stage Log
EOF
fi
```

All later appends to the audit log use `>>` (append) or `cat … >>` —
never `>` (truncate). Even amendment loops accrue fresh sections under
new timestamps.

### How to compose each Agent dispatch

For every leaf agent invocation in Steps 6–10 below:

1. Compose the invocation prompt as a heredoc string. It must begin with
   the line `Read the following agent definition file in full before
   doing anything:` followed by the absolute path under `$agents_dir`,
   then the agent-specific state/config block, then any raw blob.
2. Dispatch via the `Agent` tool with `subagent_type:
   <leaf-agent-name>` and the composed prompt.
3. Parse the agent's stdout per the rules in each Stage below.
4. Append a stage-transition section to `$audit_path` before and after
   the dispatch (see per-Stage append patterns).

The full `SPEC_PIPELINE_*` config block is included in every dispatch
prompt so the agent can read its config without re-parsing CLAUDE.md.

---

## Step 5.5 — Pipeline pre-flight

Before dispatching the spec distiller, run the shared pre-flight skill to
surface drift between the parent repo's state and the docs the pipeline
trusts (merged PRs vs progress doc, out-of-scope story markers, dirty
working tree on the parent repo's `main`).

Apply `[SKILL: ~/.claude/skills/pipeline-preflight/SKILL.md]`.

The skill produces signals only — the orchestrator owns the user-facing
decision. When a signal fires, ask the user how to proceed via
`AskUserQuestion` before dispatching the distiller. When the skill emits
`Pre-flight clean.`, proceed to Stage 1 without further prompting.

The existing parent-repo cleanliness check inside Step 4 (worktree create
path) is narrower than this pre-flight — both run; they are not redundant.
The worktree-side check guards the worktree creation itself; the pipeline
pre-flight guards the pipeline's downstream assumptions about doc accuracy.

---

## Step 6 — Stage 1: Spec Distiller

Append stage-start entry:

```bash
cat <<EOF >> "$audit_path"

## Stage 1 — Spec Distiller — $(date '+%Y-%m-%d %H:%M:%S')

Dispatching spec-distiller for ${spec_id}.
EOF
```

Dispatch the `spec-distiller` agent via the `Agent` tool
(`subagent_type: spec-distiller`) with an invocation prompt containing:

- The absolute path to `$agents_dir/spec-distiller.md`
- `spec_id`, `source_type`
- The full `SPEC_PIPELINE_*` block
- The `raw_text` (Jira blob, spec contents, or prompt text — verbatim,
  inside a `<<<RAW … RAW` fence)
- (On Stage 2 amendment re-entry only) an appended `## Amendment notes`
  block carrying the planner's verbatim reasoning

Wait for completion. The distiller writes `docs/specs/<spec-id>.md`,
`docs/plans/<spec-id>.md`, and updates `master-plan.md` inside the
worktree.

### Parse the result

Read the spec file. If its frontmatter `Status:` is `🟡 BLOCKED on Open
Questions`:

1. Extract the Open Questions block from the spec.
2. Append to `$audit_path`:
   ```bash
   cat <<EOF >> "$audit_path"

   ### Stage 1 BLOCKED — $(date '+%Y-%m-%d %H:%M:%S')

   <Open Questions block verbatim>

   ## Final Outcome — BLOCKED — Spec Open Questions — $(date '+%Y-%m-%d %H:%M:%S')

   **Status:** ⚠️  BLOCKED — Spec Open Questions
   **Worktree:** ${worktree_path} (preserved)
   EOF
   ```
3. Print the audit path and Open Questions to the user. Exit.

Otherwise — distiller succeeded. Copy the spec into the audit log under
`## Full Spec`:

```bash
cat <<EOF >> "$audit_path"

### Stage 1 complete — $(date '+%Y-%m-%d %H:%M:%S')

## Full Spec
EOF
cat "$spec_path" >> "$audit_path"
```

Continue to Step 7.

---

## Step 7 — Stage 2: Planner

Append stage-start entry:

```bash
cat <<EOF >> "$audit_path"

## Stage 2 — Planner — $(date '+%Y-%m-%d %H:%M:%S')

Dispatching planner to validate plan fits codebase.
EOF
```

Dispatch the `planner` agent via the `Agent` tool (`subagent_type:
planner`) with an invocation prompt containing the absolute path to
`$agents_dir/planner.md`, `spec_path`, `plan_path`, and the full
`SPEC_PIPELINE_*` block.

### Parse the verdict (last non-empty line)

- `PLAN VALID` → append rationale; continue to commit the plan into the
  audit log:
  ```bash
  cat <<EOF >> "$audit_path"

  ### Stage 2 PASS — $(date '+%Y-%m-%d %H:%M:%S')

  ## Full Plan
  EOF
  cat "$plan_path" >> "$audit_path"
  ```
  Continue to Step 8.

- `PLAN NEEDS AMENDMENT: <reason>` → enter amendment loop:

  1. If `amendment_attempted -eq 1` already, escalate via Step 10 with
     reason `Plan invalid after amendment` — the planner's second-pass
     reasoning is appended to the audit log first.
  2. Set `amendment_attempted=1`.
  3. Append the amendment reason verbatim to the audit log under
     `### Stage 2 amendment — <ts>`.
  4. Re-dispatch `spec-distiller` with the original prompt **plus** an
     `## Amendment notes` block carrying the planner's verbatim
     reasoning. The distiller's idempotence check (its Step 1) rewrites
     the spec/plan in place.
  5. Re-dispatch `planner`. Goto step 1 of this list.

`amendment_attempted` is a one-shot guard: at most one distiller rewrite
per pipeline run.

---

## Step 8 — Stage 3: Per-task implementation loop

**SourceKit diagnostics during this stage:** when `<new-diagnostics>` system
reminders fire post-edit but the agent's own `xcodebuild build` ran clean,
apply the "Build vs SourceKit truth" rule in
`~/.claude/skills/swift-engineer/SKILL.md`. The build is the truth source;
do not re-spawn the agent on the diagnostic alone.

**Subagent crashes during this stage:** if a dispatched agent returns no
usable result (raw API error, socket-closed, timeout — distinct from a
reported failure), apply
`[SKILL: ~/.claude/skills/subagent-reliability/SKILL.md]`. A
recover-in-place or resumed outcome does not consume a retry-budget slot.

Append stage-start entry:

```bash
cat <<EOF >> "$audit_path"

## Stage 3 — Implementation — $(date '+%Y-%m-%d %H:%M:%S')

Beginning per-task loop (blocked_cycle=${blocked_cycle:-0}).
EOF
```

### Extract task list

```bash
task_numbers="$(grep -oE '^### Task [0-9]+:' "$plan_path" | grep -oE '[0-9]+')"
```

For each `task_n` in `task_numbers`, in order:

```bash
# Has this task already been marked ✅?
if grep -qE "^### Task ${task_n}:.* ✅" "$plan_path"; then
  task_done=1
else
  task_done=0
fi

# Normal mode: skip ✅ tasks. BLOCKED-cycle mode: re-run regardless.
if [[ "$task_done" -eq 1 && -z "$blocked_cycle" ]]; then
  continue
fi
```

Then run the inner chain (Engineer → Test-writer → Concurrency-auditor →
Task-reviewer → commit → mark ✅).

### Inner chain — one task

Append `### Task N start — <ts>` to the audit log.

1. **Engineer dispatch** via `Agent` tool with `subagent_type: engineer`.
   Pass:
   - The absolute path to `$agents_dir/engineer.md`
   - `plan_path`, `spec_path`, `task_n`
   - Full `SPEC_PIPELINE_*` block
   - If `-n "$blockers_path"`: additionally pass the path with the
     instruction *"Apply each Required fix in the file at this path
     exactly. Do not expand scope. Re-build before reporting."*

   Failure modes:
   - `⛔️ ENGINEER — STOP: ambiguity` → escalate via Step 10 with the
     ambiguity message verbatim.
   - Engineer reports unrecoverable build failure → escalate with the
     build output.
   - Engineer succeeds → parse `Files modified:` / `Files created:`
     blocks into `engineer_files`; continue.

2. **Test-writer dispatch** via `Agent` tool with `subagent_type:
   test-writer`. Pass `spec_path`, `task_n`, `engineer_files`, full
   `SPEC_PIPELINE_*` block.

   Failure mode: unrecoverable test failure → escalate. Otherwise
   continue with combined `impl_files` = engineer_files ∪ new test
   files.

3. **Concurrency-auditor dispatch** via `Agent` tool with `subagent_type:
   concurrency-auditor`. Pass `task_n`, `impl_files`, full
   `SPEC_PIPELINE_*` block.

   Parse the verdict:
   - `✅ PASS-NO-CONCERN` → continue
   - `✅ PASS` → continue
   - `VERDICT: BLOCKED` → write the auditor's blockers table to a tmp
     file (`$TMPDIR/spec-pipeline-${spec_id}-concurrency-task${task_n}.md`).
     Re-dispatch `engineer` with that tmp path as a blockers file and
     the same "Apply each Required fix exactly" instruction. Then
     re-dispatch `concurrency-auditor` once. If still BLOCKED → escalate.

4. **Task-reviewer dispatch** via `Agent` tool with `subagent_type:
   task-reviewer`. Pass `plan_path`, `spec_path`, `task_n`, full
   `SPEC_PIPELINE_*` block.

   Parse the verdict:
   - `✅ PASS` → continue
   - `VERDICT: BLOCKED` → write the reviewer's blockers to a tmp file
     (`$TMPDIR/spec-pipeline-${spec_id}-task-review-task${task_n}.md`).
     Re-dispatch `engineer` with that tmp path. Then re-run the full
     chain **from test-writer onwards** (test-writer → concurrency-auditor
     → task-reviewer). If still BLOCKED → escalate.

5. **Commit** — inline `/git-commit` semantics. Do not dispatch an
   agent; the SKILL drives `git` directly.

   ```bash
   ticket="$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD \
             | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)"

   task_desc="$(grep -oE "^### Task ${task_n}:.*" "$plan_path" \
                | sed "s/^### Task ${task_n}: //; s/  ✅\$//")"

   if [[ -n "$blocked_cycle" ]]; then
     # BLOCKED-cycle mode — fix commit, not new task work
     msg_body="fix ${task_desc} from review"
   else
     msg_body="${task_desc}"
   fi

   if [[ -n "$ticket" ]]; then
     msg="${ticket}: ${msg_body}"
   else
     msg="${msg_body}"
   fi

   # Stage specific files only — never -A or .
   for f in $impl_files; do
     git -C "$worktree_path" add -- "$f"
   done

   git -C "$worktree_path" commit -m "$(cat <<COMMITMSG
$msg
COMMITMSG
   )"
   ```

   If the pre-commit hook fails: fix the hook's complaint, re-stage,
   create a **new** commit (never amend, never `--no-verify`). If the
   failure is not fixable after one attempt → escalate.

6. **Update plan + master-plan** — only on first-time completion (not
   BLOCKED-cycle, where the task is already ✅):

   ```bash
   if [[ -z "$blocked_cycle" ]]; then
     # Append ✅ to this task's heading
     sed -i '' -E "s/^(### Task ${task_n}:.*[^✅])\$/\\1  ✅/" "$plan_path"
     # Increment the "Done" count in master-plan.md
     # (use the existing pattern in the file — find the row for this spec
     #  and bump done/total)
   fi
   ```

7. **Append per-task done entry** to the audit log with the commit hash
   and modified file count.

### After the loop

```bash
cat <<EOF >> "$audit_path"

### Stage 3 complete — $(date '+%Y-%m-%d %H:%M:%S')

All tasks committed (blocked_cycle=${blocked_cycle:-0}).
EOF
```

Continue to Step 9.

### Known cost: BLOCKED-cycle re-runs every task

In BLOCKED-cycle mode the inner chain re-runs for **every** task in the
plan, not just tasks the blockers touch. The engineer no-ops on files
outside its task's scope (relying on existing scope discipline), but the
dispatch overhead is real. This matches the historical orchestrator
behaviour exactly.

---

## Step 9 — Stage 4: Whole-diff review

Append stage-start entry:

```bash
cat <<EOF >> "$audit_path"

## Stage 4 — Spec Review (cycle ${cycle}) — $(date '+%Y-%m-%d %H:%M:%S')

Dispatching swift-spec-review for whole-branch diff.
EOF
```

Dispatch `swift-spec-review` via the `Agent` tool (`subagent_type:
swift-spec-review`). Pass the absolute path to
`$agents_dir/swift-spec-review.md`, `spec_path`, `plan_path`, branch
base (default `main`), and the full `SPEC_PIPELINE_*` block.

### Parse the verdict (last non-empty line)

- `VERDICT: PASS` →
  ```bash
  blocked_cycle=""    # clear BLOCKED-cycle state
  ```
  Record any SHOULD-FIX / NICE-TO-HAVE notes in the audit log under
  `### Stage 4 PASS — <ts>`. Continue to Step 10.

- `VERDICT: BLOCKED` → BLOCKED loop:
  1. Extract the blockers table from the reviewer output.
  2. Write it to `$TMPDIR/spec-pipeline-${spec_id}-blockers-cycle${cycle}.md`.
     Store the path in `blockers_path`.
  3. Set `blocked_cycle=1`.
  4. Append the blockers table to the audit log under
     `### Cycle ${cycle} blockers — <ts>`:
     ```bash
     cat <<EOF >> "$audit_path"

     ### Cycle ${cycle} blockers — $(date '+%Y-%m-%d %H:%M:%S')

     EOF
     cat "$blockers_path" >> "$audit_path"
     ```
  5. `cycle=$((cycle+1))`.
  6. If `cycle > cycle_budget - 1` → escalate via Step 10 with reason
     `Spec review BLOCKED past cycle budget`.
  7. Otherwise jump back to Step 8 in BLOCKED-cycle mode.

---

## Step 10 — Stage 5: PR (or escalation)

### On Stage 4 PASS — invoke /git-pr

Append stage-start entry:

```bash
cat <<EOF >> "$audit_path"

## Stage 5 — PR — $(date '+%Y-%m-%d %H:%M:%S')

Invoking /git-pr.
EOF
```

Invoke the `git-pr` skill via the `Skill` tool with `skill: "git-pr"`.
The skill handles:

- Final push of the branch
- Full unit-test run against `tests_target`
- Code review on the diff
- PR draft with title/body
- Human confirmation before `gh pr create`

The SKILL does **not** inline `gh pr create`. If `/git-pr` reports
blockers from its own code-review pass that the whole-diff review
missed, halt — do not bypass.

### On success — append Final Outcome and exit

```bash
cat <<EOF >> "$audit_path"

## Final Outcome — $(date '+%Y-%m-%d %H:%M:%S')

**Status:** ✅ SHIPPED
**PR:** <PR URL from /git-pr output>
**Commits:** $(git -C "$worktree_path" rev-list --count main..HEAD)
**Cycles:** $((cycle + 1))
**Notes:** <any SHOULD-FIX / NICE-TO-HAVE from Stage 4>

### Cleanup reminder
After this PR merges, remove the worktree:
git worktree remove ${worktree_path}
EOF
```

Print the same final block to the user:

```
✅ Pipeline complete
   PR:        <URL>
   Worktree:  <worktree path>
   Audit log: <audit path>

After the PR merges, remove the worktree:
  git worktree remove <worktree path>
```

### On any escalation (from any earlier step)

Any halt jumps here. Append `## Final Outcome — ESCALATED — <reason>` to
the audit log with the failing stage label, the cycle count at
escalation, and the last blockers table verbatim (if any). State that
the worktree is preserved.

```bash
cat <<EOF >> "$audit_path"

## Final Outcome — $(date '+%Y-%m-%d %H:%M:%S')

**Status:** ⚠️  ESCALATED — <reason>
**Failing stage:** <Stage N label>
**Cycle at escalation:** ${cycle}
**Worktree:** ${worktree_path} (preserved for manual inspection)
EOF

if [[ -n "$blockers_path" ]]; then
  cat <<EOF >> "$audit_path"

### Last blockers table
EOF
  cat "$blockers_path" >> "$audit_path"
fi
```

Print to the user:

```
⚠️  Pipeline ESCALATED — see audit log for details
   Audit log:    <audit path>
   Worktree:     <worktree path> (preserved for manual inspection)
   Failing stage: <stage label>
```

**Never** create a PR on escalation. **Never** remove the worktree.

### Failure modes that trigger escalation

| Stage | Reason |
|---|---|
| Stage 1 | Spec has Open Questions after distillation |
| Stage 2 | Plan still invalid after one amendment |
| Stage 3 | Engineer halts on ambiguity / build failure |
| Stage 3 | Test-writer cannot fix failing test |
| Stage 3 | Concurrency-auditor BLOCKED twice in a row |
| Stage 3 | Task-reviewer BLOCKED twice in a row |
| Stage 3 | Pre-commit hook fails persistently |
| Stage 4 | Spec-review BLOCKED past `cycle_budget` |
| Stage 5 | `/git-pr` reports blockers or fails |

---

## Project setup (one-time)

A project must do two things to use this skill:

1. Add a `spec_pipeline` YAML block to its `CLAUDE.md` — see SCHEMA.md.
2. Add to `.gitignore`:

   ```
   docs/specs/
   docs/plans/
   master-plan.md
   ```

   The pipeline writes these inside each worktree. The Obsidian audit log
   is the durable record (the worktree is disposable).

---

## Hard rules

- **Never auto-invoke** — user trigger only. The skill creates worktrees and branches; do not invoke it from description-matching alone.
- **One source flag** — never accept two of `--from-jira / --from-spec / --from-prompt`
- **Stop on missing required config** — never invent `workspace`/`scheme`/
  `destination`/`tests_target`
- **Never run on `main` without a worktree** — Stages 1–5 run inside a
  fresh worktree, on a fresh branch
- **Never auto-confirm the worktree create** — even when the path is clear,
  the lightweight confirmation in Step 3 is required
- **Never create the worktree before the scope check passes** on Jira input —
  Step 3.5 either approves OK or halts on SPLIT before Step 4 runs
- **Never invent acceptance criteria** — if the input has none, stop and ask
- **Never auto-remove worktrees** — the user removes them post-merge
