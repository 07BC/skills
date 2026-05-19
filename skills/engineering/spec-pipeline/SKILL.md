---
name: spec-pipeline
description: >
  Runs the full spec-to-PR pipeline: distil a spec from a Jira ticket, an
  existing markdown spec, or a free-form prompt; validate the plan fits the
  codebase; implement task-by-task through the engineer → test-writer →
  concurrency-auditor → task-reviewer inner loop; whole-diff review; then
  open a PR via /jls:git-pr. Each pipeline runs in its own git worktree.
  Inputs are passed as flags. Use when the user says "ship this ticket",
  "run the pipeline", "spec-pipeline NAT-1234", "build this spec", or
  "/jls:spec-pipeline …". Project must declare its config in a fenced
  spec_pipeline YAML block in CLAUDE.md — see SCHEMA.md.
disable-model-invocation: true
---

# Spec Pipeline

`/jls:spec-pipeline` is the top-level entry point. It validates inputs, sets
up a worktree, and hands off to the `spec-pipeline-orchestrator` agent.

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
  1. Reads spec_pipeline YAML config from your CLAUDE.md (see SCHEMA.md)
  2. Creates a per-pipeline git worktree at ../<repo>-<spec-id>/ on a fresh branch
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
  - The worktree at ../<repo>-<spec-id>/ until you remove it with
    `git worktree remove`

You're asked twice during a run:
  - Before Stage 1: lightweight summary confirmation
  - Before Stage 5: PR body confirmation
Otherwise the pipeline interrupts only on hard failure (spec ambiguity,
plan invalid after one amendment, cycle budget exceeded, /git-pr blocker).

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

3. If the ticket has no acceptance criteria, stop. Tell the user to add ACs
   before re-running. Never invent acceptance criteria.

4. Compose `raw_text` as a single markdown blob containing all of the above.

5. Derive the spec ID:

   ```bash
   spec_id="$(bash ${SKILL_DIR}/scripts/derive-spec-id.sh --from-jira "<KEY>" "<summary>")"
   ```

6. `source_type=jira`

### `--from-spec <PATH>`

1. Verify the file exists. If not, stop with a clear error.
2. `raw_text="$(cat <PATH>)"`
3. ```bash
   spec_id="$(bash ${SKILL_DIR}/scripts/derive-spec-id.sh --from-spec "<PATH>")"
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

4. `source_type=prompt`

---

## Step 3 — Lightweight confirmation

Show the user a summary before any disk operation:

```
## Pipeline ready

**Spec ID:** <spec-id>
**Source:** <jira KEY | spec PATH | prompt>
**Worktree (to be created):** <repo-parent>/<repo-name>-<spec-id>
**Branch (to be created):** <type>/<spec-id> (type: feat | bug | chore — derived
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

---

## Step 4 — Worktree management

Compute the worktree path:

```bash
repo_root="$(git rev-parse --show-toplevel)"
repo_name="$(basename "$repo_root")"
worktree_path="$(dirname "$repo_root")/${repo_name}-${spec_id}"
```

Compute the branch name. Type is `bug/` for ticket type Bug, `chore/` for
Chore, otherwise `feat/`:

```bash
branch="<type>/${spec_id}"
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

After the worktree is created (or resumed), before spawning the orchestrator,
check for project setup instructions.

```bash
cd "$worktree_path"
```

### Check for README.md

```bash
if [[ ! -f README.md ]]; then
  echo "⚠️  No README.md found in ${worktree_path}. Skipping workspace setup."
  echo "    Projects should include a README.md with setup instructions."
fi
```

If `README.md` is absent, print the warning and continue. Do not halt.

### Read and extract setup steps

If `README.md` exists, read it. Look for sections that describe first-time or
workspace setup — headings like **Setup**, **Getting Started**, **Development
Setup**, **Prerequisites**, **Installation**, or **Configuration**. Under those
sections, identify any shell commands or scripts to run (e.g. `python
./Scripts/chagi-configuration.py`, `make setup`, `bundle install`,
`./configure`).

If no setup commands are found, continue to Step 5 without action.

### Run setup commands

If setup commands are found, surface them to the user before running anything:

```
## Workspace setup

README.md lists the following setup steps:

  1. python ./Scripts/chagi-configuration.py
  (... any others found ...)

Running now in: <worktree_path>
```

Then run each command in order from the worktree root. If any command exits
non-zero, halt:

> Setup step failed: `<command>` exited with code <N>.
> Fix the setup issue before the pipeline can continue.
> Worktree is preserved at: <worktree_path>

Do not proceed to Step 5 if setup fails — the engineer agents will build against
an unconfigured workspace.

If all setup commands succeed, print a one-line confirmation and continue.

---

## Step 5 — Spawn the orchestrator

Compose the orchestrator invocation prompt. It must contain:

- The agent definition file: `agents/spec-pipeline-orchestrator.md`
- The state: `spec_id`, `source_type`, `raw_text`, `worktree_path`, `audit_path`
- The config: every `SPEC_PIPELINE_*` variable

Where to write the audit log:

```bash
audit_path="${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/${spec_id}.md"
mkdir -p "$(dirname "$audit_path")"
```

Invoke via the Task tool with the orchestrator agent. Suggested invocation
prompt skeleton:

```
Read the following agent definition file in full before doing anything:

<absolute path to agents/spec-pipeline-orchestrator.md>

You are the Spec Pipeline Orchestrator described in that file.

## State
spec_id:        <spec-id>
source_type:    <jira | spec | prompt>
worktree_path:  <worktree path>
audit_path:     <audit log path>
cycle_budget:   <SPEC_PIPELINE_CYCLE_BUDGET>

## Project config
SPEC_PIPELINE_WORKSPACE='<...>'
SPEC_PIPELINE_SCHEME='<...>'
SPEC_PIPELINE_DESTINATION='<...>'
SPEC_PIPELINE_TESTS_TARGET='<...>'
SPEC_PIPELINE_TICKET_PREFIX='<...>'
SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC='<...>'
SPEC_PIPELINE_CONTEXT_DOCS='<...>'
SPEC_PIPELINE_SPEC_DIR='<...>'
SPEC_PIPELINE_PLAN_DIR='<...>'

## Raw input
<<<RAW
<raw_text verbatim>
RAW

Begin Stage 1.
```

Wait for the orchestrator to complete. It will either:

- Print `## Final Outcome — ... SHIPPED` and a PR URL → success
- Print `## Final Outcome — ... ESCALATED` → escalation

Either way, the audit log at `audit_path` contains the full record.

---

## Step 6 — Final report

On success, print:

```
✅ Pipeline complete
   PR:        <URL>
   Worktree:  <worktree path>
   Audit log: <audit path>

After the PR merges, remove the worktree:
  git worktree remove <worktree path>
```

On escalation, print:

```
⚠️  Pipeline ESCALATED — see audit log for details
   Audit log:    <audit path>
   Worktree:     <worktree path> (preserved for manual inspection)
   Failing stage: <stage label>
```

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

- **Never auto-invoke** — `disable-model-invocation: true`. User trigger only.
- **One source flag** — never accept two of `--from-jira / --from-spec / --from-prompt`
- **Stop on missing required config** — never invent `workspace`/`scheme`/
  `destination`/`tests_target`
- **Never run on `main` without a worktree** — the orchestrator runs inside a
  fresh worktree, on a fresh branch
- **Never auto-confirm the worktree create** — even when the path is clear,
  the lightweight confirmation in Step 3 is required
- **Never invent acceptance criteria** — if the input has none, stop and ask
- **Never auto-remove worktrees** — the user removes them post-merge
