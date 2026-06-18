---
name: spec-pipeline
description: >
  Runs the full spec-to-PR pipeline: distil a spec from a Jira ticket, an
  existing markdown spec, or a free-form prompt; validate the plan fits the
  codebase; implement task-by-task through the engineer → test-writer →
  concurrency-auditor → dual-reviewer inner loop; whole-diff review; then
  open a PR via /git-pr. Runs in-place on a fresh branch (no worktree).
  Inputs are passed as flags. Use when the user says "ship this ticket",
  "run the pipeline", "spec-pipeline PROJ-123", "build this spec", or
  "/spec-pipeline …". Project must declare its config in a fenced
  spec_pipeline YAML block in CLAUDE.md — see SCHEMA.md.
---

# Spec Pipeline

`/spec-pipeline` implements **one** child spec end-to-end. It validates inputs,
creates a fresh branch on the current checkout (in-place — no worktree), then
drives Phases 1–5 inline by dispatching one leaf specialist agent at a time.

Decomposition and the master-spec tree are `/spec-master`'s job; this skill ships
one unit. It creates branches and commits. **Never auto-invoke.** Always an
explicit user trigger.

> **Related:** `/spec-master` decomposes a Jira story into a GitHub master issue +
> child sub-issues; run `/spec-pipeline --from-issue <#>` per child, in dependency
> order. The two are aligned — see the ADR on the master-spec layer (which
> supersedes the worktree-isolation distinction in
> `docs/adr/0003-workflow-and-spec-pipeline-are-distinct-aligned-tools.md`).

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
  2. (--from-issue) Sequencing gate: hard-stops until every depends_on child is
     merged to main. Then creates a fresh branch IN-PLACE (no worktree).
  3. Distils the input into docs/specs/ and docs/plans/ (gitignored)
  4. (--from-issue) Drift gate: traceability + drift-auditor vs the master spec
  5. Drives engineer → test-writer → test gate → concurrency-auditor →
     two diverse-lens reviewers (both must PASS) per task
  6. Whole-diff swift-spec-review (up to 3 cycles before escalation)
  7. Opens a PR via /git-pr; reconciles the child sub-issue + master issue

Scope decomposition lives in /spec-master, not here. If a --from-jira/-spec/
-prompt input is too big for one PR, run /spec-master --from-jira KEY first.

One-time project setup:
  - Add a spec_pipeline YAML block to the project's CLAUDE.md, including
    github_repo and (optional) coverage_floor (see SCHEMA.md)
  - Add docs/specs/, docs/plans/, master-plan.md to .gitignore

Durable artefacts after a run:
  - The PR (on GitHub) and the branch on the current checkout
  - The reconciled GitHub master issue + child sub-issue (--from-issue)
  - Audit log at $OBSIDIAN_VAULT/AI/plans/<spec-id>.md
    (full spec + full plan + phase log)

You're asked at minimum twice during a run, and more when the input or spec
has unresolved questions:
  - Before Phase 1: lightweight summary confirmation
  - Before Phase 1 (Jira only): scope-split confirmation if the ticket is too
    big — may be zero questions
  - During Phase 1: one question per conflict or open UI decision (may be zero)
  - During Phase 3: one question per spec ambiguity the engineer cannot infer
    from the codebase (may be zero)
  - Before Phase 5: PR body confirmation
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

- `--from-issue <GH#>` — resolves a child spec from a GitHub sub-issue created by
  `/spec-master` (the intended path; carries the traceability spine and sequencing)
- `--from-jira <KEY>` — fetches the ticket via the Atlassian MCP
- `--from-spec <PATH>` — reads an existing markdown spec
- `--from-prompt "<TEXT>"` — distils a free-form description

`--from-issue` is the canonical entry point: it inherits the frozen AC IDs,
`covers`, and `depends_on` from the master spec, which feed the sequencing gate
(Step 3.7), the drift gate (Step 5.6), and the test gate (Phase 3). The other
three sources have no master to track against — their drift/sequencing gates are
skipped (a one-off spec with no master is its own authority).

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

- Option A: **Generate it inline with `architecture-doc`** (Recommended) — apply the `architecture-doc` skill in this session to produce the architecture doc at the configured path, then continue to Step 2.
- Option B: **Proceed without it** — unset `SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC` for the rest of this run so agents skip it cleanly. Use this when you've decided the doc isn't worth producing for this work.
- Option C: **Abort** — stop and let the user fix the config (e.g. correct the path or remove the field from CLAUDE.md).

On Option A:
- Apply skill `architecture-doc` to generate the doc at
  `$SPEC_PIPELINE_TARGET_ARCHITECTURE_DOC`.
- When the skill reports completion, re-verify the file exists, then
  continue to Step 2 without exiting the pipeline.

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

### `--from-issue <GH#>`

1. Resolve the repo (`$SPEC_PIPELINE_GITHUB_REPO`, else `gh repo view --json
   nameWithOwner -q .nameWithOwner`). Verify `gh auth status` succeeds.
2. Read the child sub-issue:
   ```bash
   gh issue view "<GH#>" --repo "$REPO" --json number,title,body,parent,labels
   ```
   From the body, parse the fenced spine block: `covers: [<AC ids>]` and
   `depends_on: [<child-issue-#s>]`. Capture `master_issue` = the `parent` number.
3. Read the master issue body (`gh issue view "$master_issue" …`) to obtain the
   verbatim AC text for each ID in `covers`, plus the Jira story link.
4. Compose `raw_text` as a markdown blob: the child title + summary, the covered
   ACs (ID + text), and a pointer to the Jira story. Carry `covers` and
   `depends_on` forward as pipeline variables — they are written into the spec
   frontmatter the distiller produces (`covers:`) and drive Steps 3.7 / 5.6.
5. ```bash
   spec_id="$(bash ${SKILL_DIR}/scripts/derive-spec-id.sh --from-spec "<child-issue-title-slug>")"
   branch_id="${spec_id}"
   ```
6. `source_type=issue`. Record `master_issue`, `child_issue=<GH#>`, `covers`,
   `depends_on` for later phases.

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
     by Step 3.5 to skip Phase 0 on tickets that are already sub-tasks)
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
**Source:** <issue #GH | jira KEY | spec PATH | prompt>
**Mode:** in-place on the current checkout (no worktree)
**Branch (to be created):** <type>/<branch-id> (type: feat | bug | chore — derived
                                              from spec source or defaulted to feat)
**Cycle budget:** ${SPEC_PIPELINE_CYCLE_BUDGET}
**Audit log:** ${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/<spec-id>.md
```

If the source is `issue`, also show: master issue #, covers (AC IDs), depends_on.
If the source is `jira`, also show: Summary, Type, Labels, AC count.

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

## Step 3.5 — Scope decomposition has moved to `/spec-master`

Splitting a large story into sequential specs is no longer done here. That is
`/spec-master`'s job: it reads the Jira story, freezes AC IDs, and creates a
GitHub master issue + child sub-issues. `/spec-pipeline` implements **one** unit
of work.

- `--from-issue` — the child was already scoped by `/spec-master`; nothing to do.
- `--from-jira` / `--from-spec` / `--from-prompt` — treated as a single spec as
  given (no in-pipeline split). If the input is too big to ship as one PR, stop
  and run `/spec-master --from-jira <KEY>` to decompose it first.

---

## Step 3.7 — Sequencing gate (`--from-issue` only)

Skip unless `source_type == issue` with a non-empty `depends_on`. This enforces
the user's hard-stop rule: a child does not start until every child it depends on
is **merged to main**.

For each issue number in `depends_on`:

```bash
state="$(gh issue view "<dep#>" --repo "$REPO" --json state,stateReason -q '.state')"
# A child is "complete" when its issue is CLOSED by a merged PR.
```

Confirm the dependency's linked PR is merged (the issue is closed as completed,
and `gh pr list --search "<dep#>" --state merged` shows its PR). If **any**
dependency is not merged, halt:

```
⛔️ Sequencing gate — child #<GH#> depends on #<dep#>, which is not yet merged.
   Finish and merge #<dep#> first, then re-run:
   /spec-pipeline --from-issue <GH#>
```

Do not create the branch. When all dependencies are merged, continue to Step 4.

---

## Step 4 — Branch management (in-place, no worktree)

This pipeline runs **in-place** on the current checkout — it does not create a
git worktree. If you want isolation, set up a worktree manually before invoking
`/spec-pipeline`; the pipeline simply runs wherever it is invoked.

`worktree_path` below is retained as the variable name for the in-place checkout
root so the per-task `git -C "$worktree_path"` calls downstream are unchanged.

```bash
repo_root="$(git rev-parse --show-toplevel)"
worktree_path="$repo_root"          # in-place — NOT a separate worktree
repo_name="$(basename "$repo_root")"
```

Compute the branch name. Type is `bug/` for ticket type Bug, `chore/` for
Chore, otherwise `feat/`:

```bash
branch="<type>/${branch_id}"
```

### Dirty-tree preflight

```bash
git -C "$repo_root" status --porcelain
current_branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"
```

- If the working tree is dirty, surface the changes and ask via `AskUserQuestion`
  whether to proceed (stash / commit first / proceed anyway / abort). Running a
  pipeline over uncommitted local edits risks mixing them into pipeline commits.
- The base branch must be `main` (or the configured base). If `current_branch` is
  not the base, ask before branching from a non-base HEAD.

### Create or resume the branch

```bash
if git -C "$repo_root" rev-parse --verify "$branch" >/dev/null 2>&1; then
  # Branch already exists — resuming this spec. Check it out.
  git -C "$repo_root" checkout "$branch"
else
  git -C "$repo_root" checkout -b "$branch"   # branches off the current base (clean main)
fi
cd "$worktree_path"
```

On resume (branch already existed), read `master-plan.md` if present and show the
user the last status before continuing.

> The in-place checkout is already configured to build — there is no separate
> workspace-setup step. (The old worktree-buildability setup was removed when the
> pipeline moved in-place.)

---

## Step 5 — Initialise audit log + state

The Agent tool is gated to top-level sessions only in this Claude Code
build — subagents cannot dispatch further subagents. So the SKILL drives
Phases 1–5 inline (Steps 6–10 below), dispatching one leaf specialist at
a time. The full design rationale and historical orchestrator prose are
preserved under `playbooks/spec-pipeline-orchestrator.md` and
`playbooks/swift-spec-implement.md` next to this file.

### Phase variables (bash shell state)

Set these once near the top of the implementation flow. They persist
across every subsequent Bash tool call in this session.

```bash
spec_path="${worktree_path}/${SPEC_PIPELINE_SPEC_DIR:-docs/specs}/${spec_id}.md"
plan_path="${worktree_path}/${SPEC_PIPELINE_PLAN_DIR:-docs/plans}/${spec_id}.md"
audit_path="${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/${spec_id}.md"
cycle=0
cycle_budget="${SPEC_PIPELINE_CYCLE_BUDGET:-3}"
amendment_attempted=0
blockers_path=""        # set in Phase 4 BLOCKED loop
blocked_cycle=""        # "1" while re-entering Phase 3 after Phase 4 BLOCKED
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
**Checkout:** ${worktree_path} (in-place)
**Branch:** $(git -C "$worktree_path" rev-parse --abbrev-ref HEAD)

---

## Phase Log
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
3. Parse the agent's stdout per the rules in each Phase below.
4. Append a phase-transition section to `$audit_path` before and after
   the dispatch (see per-Phase append patterns).

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
`Pre-flight clean.`, proceed to Phase 1 without further prompting.

The dirty-tree preflight inside Step 4 is narrower than this pre-flight — both
run; they are not redundant. The Step 4 check guards the in-place branch
creation itself; the pipeline pre-flight guards the pipeline's downstream
assumptions about doc accuracy.

---

## Step 5.6 — Drift gate (`--from-issue` only)

Skip unless `source_type == issue`. A spec with no master is its own authority;
there is nothing to drift against.

Run **after** the distiller has written the spec/plan (so it can be re-ordered
to run at the top of Phase 1's tail — dispatch the distiller first, then gate).
Two layers, both must pass before implementation:

1. **Deterministic** — child-scope traceability, **scope-only** (no tests exist
   yet, so the UNTESTED check is deferred to the Phase 3 test gate):
   ```bash
   bash ${SCRIPTS}/check-traceability.sh \
     --spec "$spec_path" --plan "$plan_path" --scope-only
   ```
   This runs the SCOPE-CREEP and UNPLANNED checks only. A non-zero exit means the
   plan's `implements:` tags drifted from the child's `covers:` → escalate via
   Step 10.

2. **Semantic** — dispatch `drift-auditor` (`subagent_type: drift-auditor`) with
   the `master_issue` reference, `spec_path`, and `covers`. On `VERDICT:
   BLOCKED`, write its findings to the audit log and escalate via Step 10 with
   reason `Drift from master`. (Subagent crash → `subagent-reliability`.)

The master-scope coverage check (every master AC covered by some child) is **not**
run here — it reads all sibling sub-issues from GitHub and lives in `/spec-master`.

---

## Step 6 — Phase 1: Spec Distiller

Append phase-start entry:

```bash
cat <<EOF >> "$audit_path"

## Phase 1 — Spec Distiller — $(date '+%Y-%m-%d %H:%M:%S')

Dispatching spec-distiller for ${spec_id}.
EOF
```

Dispatch the `spec-distiller` agent via the `Agent` tool
(`subagent_type: spec-distiller`) with an invocation prompt containing:

- The absolute path to `$agents_dir/spec-distiller.md`
- `spec_id`, `source_type`
- The full `SPEC_PIPELINE_*` block
- The `raw_text` (issue/Jira blob, spec contents, or prompt text — verbatim,
  inside a `<<<RAW … RAW` fence)
- **(`source_type=issue` only)** `covers` (the frozen master AC IDs **with their
  verbatim text** from the master issue) and `depends_on`. The distiller writes
  these into the spec frontmatter, labels the ACs with the frozen IDs, and tags
  each plan task `implements: [...]` — this is what makes Steps 5.6 / the test
  gate able to run. Without it the spine is inert.
- (On Phase 2 amendment re-entry only) an appended `## Amendment notes`
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

   ### Phase 1 BLOCKED — $(date '+%Y-%m-%d %H:%M:%S')

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

### Phase 1 complete — $(date '+%Y-%m-%d %H:%M:%S')

## Full Spec
EOF
cat "$spec_path" >> "$audit_path"
```

Continue to Step 7.

---

## Step 7 — Phase 2: Planner

Append phase-start entry:

```bash
cat <<EOF >> "$audit_path"

## Phase 2 — Planner — $(date '+%Y-%m-%d %H:%M:%S')

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

  ### Phase 2 PASS — $(date '+%Y-%m-%d %H:%M:%S')

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
     `### Phase 2 amendment — <ts>`.
  4. Re-dispatch `spec-distiller` with the original prompt **plus** an
     `## Amendment notes` block carrying the planner's verbatim
     reasoning. The distiller's idempotence check (its Step 1) rewrites
     the spec/plan in place.
  5. Re-dispatch `planner`. Goto step 1 of this list.

`amendment_attempted` is a one-shot guard: at most one distiller rewrite
per pipeline run.

---

## Step 8 — Phase 3: Per-task implementation loop

**SourceKit diagnostics during this phase:** when `<new-diagnostics>` system
reminders fire post-edit but the agent's own `xcodebuild build` ran clean,
apply the "Build vs SourceKit truth" rule in
`~/.claude/skills/swift-engineer/SKILL.md`. The build is the truth source;
do not re-spawn the agent on the diagnostic alone.

**Subagent crashes during this phase:** if a dispatched agent returns no
usable result (raw API error, socket-closed, timeout — distinct from a
reported failure), apply
`[SKILL: ~/.claude/skills/subagent-reliability/SKILL.md]`. A
recover-in-place or resumed outcome does not consume a retry-budget slot.

Append phase-start entry:

```bash
cat <<EOF >> "$audit_path"

## Phase 3 — Implementation — $(date '+%Y-%m-%d %H:%M:%S')

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
   `SPEC_PIPELINE_*` block, and (for `source_type=issue`) the
   `xcresult_path` defined in step 4 below with the instruction to run the
   targeted suite **with coverage** to that bundle (`-enableCodeCoverage YES
   -resultBundlePath "$xcresult_path"`). The test-writer also annotates each
   `@Test` with `// AC: <frozen id>` so the gate can map tests to ACs.

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

4. **Test gate** — deterministic, before any reviewer sees the task. Skipped for
   non-`issue` sources (no master ⇒ no `covers` to gate). Two checks.

   The test-writer (step 2) is instructed to run its targeted suite **with
   coverage** to a known bundle so the gate can read it:
   ```bash
   xcresult_path="${TMPDIR:-/tmp}/spec-pipeline-${spec_id}-task${task_n}.xcresult"
   # test-writer runs: xcodebuild test … -enableCodeCoverage YES \
   #   -resultBundlePath "$xcresult_path"   (rm -rf it first; xcodebuild won't overwrite)
   tests_dir="${SPEC_PIPELINE_TESTS_DIR:-$(git -C "$worktree_path" ls-files \
     | grep -E '(Tests/|UITests/)' | sed -E 's#/[^/]+$##' | sort -u | head -1)}"
   exclusions="${TMPDIR:-/tmp}/spec-pipeline-${spec_id}-test-exclusions.txt"
   ```

   a. **AC→test mapping** (every covered AC has an asserting test, or is excluded):
      ```bash
      bash ${SCRIPTS}/check-traceability.sh \
        --spec "$spec_path" --plan "$plan_path" \
        --tests-dir "$worktree_path/$tests_dir" \
        $( [[ -f "$exclusions" ]] && printf -- '--exclusions %s' "$exclusions" )
      ```
   b. **Changed-line coverage** ≥ `${SPEC_PIPELINE_COVERAGE_FLOOR}` (default 90):
      ```bash
      bash ${SCRIPTS}/coverage-gate.sh \
        --xcresult "$xcresult_path" --base main \
        --floor "${SPEC_PIPELINE_COVERAGE_FLOOR}" --root "$worktree_path" \
        $( [[ -f "$exclusions" ]] && printf -- '--exclusions %s' "$exclusions" )
      ```

   On either failure, re-dispatch `test-writer` (missing/insufficient tests) or
   `engineer` (genuinely untestable code that should be refactored, or an
   exclusion to record) with the gate output by path. Re-run the gate. If it
   still fails after one fix cycle → escalate via Step 10 with reason
   `Test gate failed`. A genuinely-untestable path is added to the exclusions
   file with a one-line reason — never silently dropped.

5. **Dual review — two diverse lenses, in parallel, blind to each other.**
   Dispatch BOTH in a single message (two `Agent` calls) so neither sees the
   other's verdict:
   - `task-reviewer` (`subagent_type: task-reviewer`) — spec-correctness lens.
   - `quality-reviewer` (`subagent_type: quality-reviewer`) — architecture &
     code-quality lens.
   Pass each `plan_path`, `spec_path`, `task_n`, full `SPEC_PIPELINE_*` block.

   The task proceeds to commit only when **both** return `✅ PASS`. For each that
   returns `VERDICT: BLOCKED`:
   - Write that reviewer's blockers to a tmp file
     (`$TMPDIR/spec-pipeline-${spec_id}-<lens>-task${task_n}.md`). If both
     blocked, concatenate both files so the engineer fixes them in one pass.
   - Re-dispatch `engineer` with the blockers path(s). Then re-run the full chain
     **from test-writer onwards** (test-writer → test gate → concurrency-auditor →
     both reviewers). If either lens is still BLOCKED after the retry → escalate.

6. **Commit** — inline `/git-commit` semantics. Do not dispatch an
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

7. **Update plan + master-plan** — only on first-time completion (not
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

8. **Append per-task done entry** to the audit log with the commit hash
   and modified file count.

### After the loop

```bash
cat <<EOF >> "$audit_path"

### Phase 3 complete — $(date '+%Y-%m-%d %H:%M:%S')

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

## Step 9 — Phase 4: Whole-diff review

Append phase-start entry:

```bash
cat <<EOF >> "$audit_path"

## Phase 4 — Spec Review (cycle ${cycle}) — $(date '+%Y-%m-%d %H:%M:%S')

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
  `### Phase 4 PASS — <ts>`. Continue to Step 10.

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

## Step 10 — Phase 5: PR (or escalation)

### On Phase 4 PASS — invoke /git-pr

Append phase-start entry:

```bash
cat <<EOF >> "$audit_path"

## Phase 5 — PR — $(date '+%Y-%m-%d %H:%M:%S')

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

### On success — reconcile GitHub, append Final Outcome, exit

**Reconcile the master spec (`--from-issue` only).** Before writing the outcome,
update the GitHub tree so the master issue reflects reality:

1. Tick this child's per-AC checkboxes in its sub-issue body for every covered AC
   now implemented + tested (`gh issue edit "$child_issue" --repo "$REPO"
   --body-file <updated>`).
2. Tick this child's row in the master issue's `## Child specs` task-list
   (`gh issue edit "$master_issue" …`). The PR merging will close the sub-issue;
   the master's native sub-issue progress bar advances automatically.
3. Add a comment on the child sub-issue linking the PR
   (`gh issue comment "$child_issue" --repo "$REPO" --body "Implemented in <PR URL>"`).

These are the durable drift-tracking writes — the master issue stays the single
source of truth and visibly tracks every child to completion.

```bash
cat <<EOF >> "$audit_path"

## Final Outcome — $(date '+%Y-%m-%d %H:%M:%S')

**Status:** ✅ SHIPPED
**PR:** <PR URL from /git-pr output>
**Commits:** $(git -C "$worktree_path" rev-list --count main..HEAD)
**Cycles:** $((cycle + 1))
**Child issue:** <#GH, reconciled to master> (issue source only)
**Notes:** <any SHOULD-FIX / NICE-TO-HAVE from Phase 4>
EOF
```

Print the final block to the user:

```
✅ Pipeline complete
   PR:        <URL>
   Branch:    <branch> (in-place, on the current checkout)
   Audit log: <audit path>
   Master:    <master issue URL — child reconciled>   (issue source only)
```

### On any escalation (from any earlier step)

Any halt jumps here. Append `## Final Outcome — ESCALATED — <reason>` to
the audit log with the failing phase label, the cycle count at
escalation, and the last blockers table verbatim (if any). The branch and
its commits are left in place for manual inspection.

```bash
cat <<EOF >> "$audit_path"

## Final Outcome — $(date '+%Y-%m-%d %H:%M:%S')

**Status:** ⚠️  ESCALATED — <reason>
**Failing phase:** <Phase N label>
**Cycle at escalation:** ${cycle}
**Branch:** $(git -C "$worktree_path" rev-parse --abbrev-ref HEAD) (in-place, preserved for inspection)
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
   Branch:       <branch> (in-place, preserved for manual inspection)
   Failing phase: <phase label>
```

**Never** create a PR on escalation. **Never** discard the branch or its commits.

### Failure modes that trigger escalation

| Phase | Reason |
|---|---|
| Phase 1 | Spec has Open Questions after distillation |
| Phase 2 | Plan still invalid after one amendment |
| Phase 3 | Engineer halts on ambiguity / build failure |
| Phase 3 | Test-writer cannot fix failing test |
| Phase 3 | Concurrency-auditor BLOCKED twice in a row |
| Phase 3 | Task-reviewer BLOCKED twice in a row |
| Phase 3 | Pre-commit hook fails persistently |
| Phase 4 | Spec-review BLOCKED past `cycle_budget` |
| Phase 5 | `/git-pr` reports blockers or fails |

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

   The pipeline writes these on the in-place branch. The Obsidian audit log
   and the GitHub master/child issues are the durable records.

---

## Hard rules

- **Never auto-invoke** — user trigger only. The skill creates branches and
  commits; do not invoke it from description-matching alone.
- **One source flag** — never accept two of
  `--from-issue / --from-jira / --from-spec / --from-prompt`
- **Stop on missing required config** — never invent `workspace`/`scheme`/
  `destination`/`tests_target`
- **Runs in-place, never creates a worktree** — Phases 1–5 run on a fresh branch
  off the current base in the current checkout. The user sets up a worktree
  manually beforehand if they want isolation.
- **Never run directly on the base branch** — always branch first (Step 4)
- **Never auto-confirm the branch create** — the lightweight confirmation in
  Step 3 and the dirty-tree preflight in Step 4 are required
- **Honour the sequencing gate** — never start a child whose `depends_on` is not
  fully merged to main (Step 3.7)
- **Never invent acceptance criteria** — if the input has none, stop and ask

---

## Model & mode

The SKILL runs in the **top-level session** and owns every branching decision. It
drives Phases 1–5 inline rather than nesting an orchestrator subagent, because
the Agent tool is gated to top-level sessions in this Claude Code build —
subagents cannot dispatch further subagents.

Each leaf agent (`spec-distiller`, `planner`, `engineer`, `test-writer`,
`concurrency-auditor`, `task-reviewer`, `swift-spec-review`) is dispatched via the
Agent tool using its own agent-definition file under `$agents_dir`, which sets
that agent's model. There is no single `SUBAGENT_MODEL` constant — model choice
is per-agent by design.
