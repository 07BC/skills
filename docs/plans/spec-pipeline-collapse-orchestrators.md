# Spec-Pipeline — Collapse Orchestrators Into the SKILL

**Status:** Plan only (no code changes yet)
**Date:** 2026-05-20
**Author:** Jamie Le Souëf
**Scope:** `skills/engineering/spec-pipeline/` and `agents/spec-pipeline-orchestrator.md`, `agents/swift-spec-implement.md`

---

## Context

The `/jls:spec-pipeline` flow has a structural failure. In this Claude Code
build, the `Agent` tool is gated to top-level sessions only — subagents
cannot dispatch further subagents. The current design has two
orchestrator-shaped subagents (`spec-pipeline-orchestrator`,
`swift-spec-implement`) whose entire job is to call `Agent` repeatedly.
Both hit the same wall every run.

The fix is structural, not textual: collapse both orchestration layers into
the SKILL (which runs at top level and **does** have `Agent` access). Leaf
specialist agents (`spec-distiller`, `planner`, `engineer`, `test-writer`,
`concurrency-auditor`, `task-reviewer`, `swift-spec-review`,
`spec-scope-guardian`) stay untouched — they don't spawn anything, only get
dispatched to.

The user-facing flow, scope checks, gates, audit log shape, worktree
behaviour, and `cycle_budget` semantics must all be preserved.

---

## Q1 — Structural shape for each orchestrator file

| File | Decision | Reason |
|---|---|---|
| `agents/spec-pipeline-orchestrator.md` | **Option (b) — demote to playbook doc, relocate to `skills/engineering/spec-pipeline/playbooks/`** | The file's prose (~300 lines) is the canonical specification of Stage 1–5 sequencing, retry shape, audit log format, and escalation rules. Deleting it (option a) loses load-bearing prose. Keeping the frontmatter (option c) leaves a non-functional agent registered with Claude Code, which is confusing. Demotion strips the `name:`/`description:`/`model:` frontmatter, **and** the file is moved out of `agents/` entirely so it cannot accidentally be loaded as an agent — relying on undocumented loader behaviour ("rejects .md without `name:` frontmatter") is brittle. Co-locating the playbook under the SKILL directory makes the relationship explicit. |
| `agents/swift-spec-implement.md` | **Option (b) — demote, same relocation** | Same logic. ~210 lines of inner-loop prose (engineer → test-writer → concurrency-auditor → task-reviewer, retry rules, BLOCKED-cycle re-entry semantics, commit semantics). Preserves prose; the SKILL becomes the single source of truth. |

**Target location:** `skills/engineering/spec-pipeline/playbooks/spec-pipeline-orchestrator.md` and `…/playbooks/swift-spec-implement.md`.

**Why a subdirectory and not just `agents/` with stripped frontmatter:** the
Makefile's `agents:` target globs `agents/*.md` (non-recursive). Moving the
files out of `agents/` removes them from the symlink loop entirely. No
behavioural assumption about Claude Code's loader is required. The
spec-pipeline SKILL is the only consumer of this prose, so co-locating
under the SKILL directory is also semantically correct.

If the Agent-subagent gating is lifted in a future Claude Code build,
both files can be promoted back to agents by moving them back to
`agents/` and restoring their frontmatter (from git history). The SKILL's
collapsed inline flow can then be reverted to its current "spawn the
orchestrator" shape.

---

## Q2 — Stage flow in the SKILL

The SKILL already does Steps 0–4.5 unchanged. New Steps 5–10 below replace
the existing "Step 5 — Spawn the orchestrator" and "Step 6 — Final report".

The model executes each step in turn inside the worktree. State is held in
Bash shell variables (see Q3). Every Agent dispatch returns text whose
last non-empty line is parsed; multi-line blockers tables are written to a
tmp file path captured in `$BLOCKERS_PATH` for re-use across stages.

### Step 5 — Initialise audit log

```bash
audit_path="${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/${spec_id}.md"
mkdir -p "$(dirname "$audit_path")"
```

Append the header block (Started / Source / Spec ID / Worktree / Branch /
`## Stage Log`) via heredoc if the file does not exist.

### Step 6 — Stage 1: Spec distiller

Append audit entry. Dispatch via `Agent` tool with `subagent_type:
spec-distiller`. Invocation prompt carries `spec_id`, `source_type`,
`raw_text`, and the full `SPEC_PIPELINE_*` config block.

Parse the distiller's output:
- Read `docs/specs/<spec-id>.md` from the worktree
- If the spec's frontmatter `Status:` is `🟡 BLOCKED on Open Questions`:
  - Append Open Questions to audit log
  - Append `## Final Outcome — BLOCKED — Spec Open Questions`
  - Print audit path + questions; exit
- Otherwise: `cat $SPEC_PATH >> $AUDIT_PATH` under `## Full Spec`

### Step 7 — Stage 2: Planner

Dispatch with `subagent_type: planner`. Invocation prompt carries
`SPEC_PATH`, `PLAN_PATH`, full `SPEC_PIPELINE_*` config block.

Parse last non-empty line:
- `PLAN VALID` → append rationale to audit; `cat $PLAN_PATH >> $AUDIT_PATH`
  under `## Full Plan`; continue to Step 8
- `PLAN NEEDS AMENDMENT: <reason>` → enter amendment loop:
  1. **If `amendment_attempted == 1` already** → escalate via Step 10
     with `ESCALATED — Plan invalid after amendment` (the planner's
     second-pass reason is appended to the audit log first).
  2. Set `amendment_attempted=1`.
  3. Append `### Stage 2 amendment — <ts>` to the audit log with the
     planner's reason verbatim.
  4. Dispatch `spec-distiller` again with amendment notes (the planner's
     reasoning verbatim, appended to the original `raw_text` under a
     "## Amendment notes" heading).
  5. Re-dispatch `planner` and re-parse. Goto step 1 of this list.

`amendment_attempted` is a one-shot guard: at most one distiller rewrite
per pipeline run. If a future run resumes from this state, the variable
starts at `0` again — same as the current orchestrator behaviour.

### Step 8 — Stage 3: Per-task implementation loop

Read `PLAN_PATH`. Extract task headings via `grep -nE '^### Task [0-9]+:'`.
For each task not marked `✅` (or, in BLOCKED-cycle mode, for every task
regardless of mark):

```
loop_step "engineer"           — dispatch + halt-or-continue
loop_step "test-writer"        — dispatch + halt-or-continue
loop_step "concurrency-auditor"— dispatch + PASS / PASS-NO-CONCERN / BLOCKED→retry
loop_step "task-reviewer"      — dispatch + PASS / BLOCKED→retry
loop_step "commit"             — inline /jls:git-commit semantics
loop_step "update-plan"        — mark task ✅, increment master-plan count
```

Each inner step is a top-level `Agent` call (see Q4 for full retry shape).
Per-task audit entries are appended at task start and task end.

### Step 9 — Stage 4: Whole-diff review

Dispatch `swift-spec-review` with `SPEC_PATH`, `PLAN_PATH`, branch base.
Parse last non-empty line:

- `VERDICT: PASS` → record any SHOULD-FIX/NICE-TO-HAVE notes; **clear
  `BLOCKED_CYCLE=""`**; continue to Step 10
- `VERDICT: BLOCKED` → BLOCKED loop:
  1. Extract the blockers table into `$TMPDIR/spec-pipeline-${spec_id}-blockers-cycle${cycle}.md`
  2. Set `BLOCKERS_PATH` to that file; set `BLOCKED_CYCLE=1`
  3. Append blockers table to audit log
  4. `cycle=$((cycle+1))`
  5. If `cycle > cycle_budget - 1` → escalate via Step 10
  6. Otherwise jump back to Step 8 in **BLOCKED-cycle mode** — see Q4

### Step 10 — Stage 5: PR (or escalation)

On Stage 4 PASS: invoke `/jls:git-pr` skill (not via `Agent`; it is a
skill, dispatched through the `Skill` tool with `skill: "git-pr"`). The
skill handles push, final test run, code review, draft PR body, and human
confirmation. The SKILL does **not** inline `gh pr create`.

If `/jls:git-pr` reports blockers its review pass found, halt — do not
bypass.

On success: append `## Final Outcome — ✅ SHIPPED` block (PR URL, commit
count, cycle count, notes). Print cleanup reminder.

On any escalation: append `## Final Outcome — ESCALATED — <reason>` with
the failing stage, the cycle count at escalation, and the last blockers
table verbatim. Print audit log path. Exit. **Never** create a PR.
**Never** remove the worktree.

### Failure modes preserved (from the orchestrator file)

| Failure | Stage | Behaviour |
|---|---|---|
| Spec has Open Questions | Stage 1 | Escalate immediately |
| Plan remains invalid after one amendment | Stage 2 | Escalate |
| Engineer halts on ambiguity / build failure | Stage 3 | Escalate |
| Test-writer cannot fix failing test | Stage 3 | Escalate |
| Concurrency-auditor BLOCKED twice in a row | Stage 3 | Escalate |
| Task-reviewer BLOCKED twice in a row | Stage 3 | Escalate |
| Pre-commit hook keeps failing | Stage 3 | Escalate |
| Spec-review BLOCKED past `cycle_budget` | Stage 4 | Escalate |
| `/jls:git-pr` reports blockers or fails | Stage 5 | Halt + surface |

---

## Q3 — Cycle / retry state

**Model: pure Bash shell variables, with multi-line content in tmp files
whose paths are stored in variables.** This matches the SKILL's existing
shell-state pattern (`eval "$(read-pipeline-config.sh)"`, `SPEC_PIPELINE_*`
vars set by Step 1). Mixing shell + prose state would create drift.

| Variable | Purpose | Initial value | Mutator |
|---|---|---|---|
| `spec_id`, `source_type`, `worktree_path` | Set in Steps 2–4 | (Step 2/4) | — |
| `audit_path` | Audit log file path | Step 5 | — |
| `cycle` | Stage 4 retry counter | `0` | Stage 4 BLOCKED loop |
| `cycle_budget` | Max Stage 4 cycles | `${SPEC_PIPELINE_CYCLE_BUDGET:-3}` | — |
| `SPEC_PATH` | `${worktree_path}/docs/specs/<spec-id>.md` | Step 5 | — |
| `PLAN_PATH` | `${worktree_path}/docs/plans/<spec-id>.md` | Step 5 | — |
| `BLOCKERS_PATH` | Path to current cycle's blockers tmp file (empty when no BLOCKED cycle in flight) | `""` | Stage 4 BLOCKED loop |
| `BLOCKED_CYCLE` | `1` while re-entering Stage 3 after Stage 4 BLOCKED, else empty | `""` | Stage 4 BLOCKED loop sets; cleared by Stage 4 PASS or escalation |
| `amendment_attempted` | Stage 2 amendment retry guard — `1` after one distiller-rewrite cycle | `0` | Set inside Stage 2 amendment loop; never reset (one retry total per pipeline run) |

Bash shell state persists across `Bash` tool calls in a Claude Code
session — the working directory and all exported vars survive between
calls. The model reads `echo "$cycle $BLOCKERS_PATH"` to recover state if
conversation compaction obscures recent reasoning. The audit log itself is
the durable record across runs (cycle/BLOCKERS state is not preserved
across pipeline re-invocations — by design, the same as the current
orchestrator).

### Why bash, not natural-language plan state

The Stage 4 BLOCKED loop needs a strict numerical counter that survives
multiple `Agent` dispatches (each of which may produce hundreds of lines
of output, triggering context compaction). A shell variable is the
cheapest unambiguous representation. Natural-language plan state in the
SKILL prose is too easily corrupted by the model paraphrasing it.

### Why tmp files for BLOCKERS content

The blockers table is a multi-line markdown string. Embedding it inline in
the next Agent invocation prompt would require careful escaping. Writing
it to `$TMPDIR/spec-pipeline-${spec_id}-blockers-cycle${cycle}.md` and
passing the **path** sidesteps escaping entirely. The leaf `engineer`
agent already knows how to read a file path passed to it.

---

## Q4 — Per-task inner loop

**Option (a) — inline SKILL logic.** Confirmed: no third option exists.
Any "single per-task driver" implementation runs as a subagent and
re-introduces the same gating failure.

### Outer per-task loop

```
for task_n in $(extract_tasks "$PLAN_PATH"); do
  if task_done "$task_n" && [[ -z "$BLOCKED_CYCLE" ]]; then
    continue  # already ✅, normal mode skips it
  fi
  run_task_chain "$task_n"
done
```

In BLOCKED-cycle mode (Stage 4 BLOCKED → Stage 3 re-entry), every task is
re-visited regardless of ✅ state — matching the orchestrator file's
"BLOCKED-cycle invocation" semantics (`Skip Step 0 (the task is already
marked ✅ — that's fine; we're patching it)`).

### Inner chain per task

Each leaf agent is dispatched via `Agent` at top level. Retry rules are
preserved from the existing `swift-spec-implement.md`.

1. **Engineer**
   - Pass: `PLAN_PATH`, `SPEC_PATH`, `task_n`, full `SPEC_PIPELINE_*`
     block.
   - If `$BLOCKERS_PATH` is non-empty, additionally pass the blockers file
     path with the instruction: *"Apply each Required fix in the table
     exactly. Do not expand scope. Re-build before reporting."*
   - On `⛔️ ENGINEER — STOP: ambiguity` → escalate.
   - On build failure the engineer cannot fix → escalate.
   - On `✅ ENGINEER — task [N] implemented` → continue.

2. **Test-writer**
   - Pass: `SPEC_PATH`, `task_n`, the engineer's file list (parsed from
     the engineer's `Files modified:` / `Files created:` blocks).
   - On test failure the test-writer cannot fix → escalate.
   - On `✅ TEST-WRITER` → continue.

3. **Concurrency-auditor**
   - Pass: `task_n`, the combined file list (engineer + test-writer).
   - Parse:
     - `✅ PASS-NO-CONCERN` → continue
     - `✅ PASS` → continue
     - `VERDICT: BLOCKED` → inner retry: re-dispatch engineer with the
       auditor's blockers table (write to a separate tmp file
       `concurrency-blockers-task${task_n}.md`), then re-dispatch
       concurrency-auditor exactly once. If still BLOCKED → escalate.

4. **Task-reviewer**
   - Pass: `PLAN_PATH`, `SPEC_PATH`, `task_n`.
   - Parse:
     - `✅ PASS` → continue
     - `VERDICT: BLOCKED` → inner retry: re-dispatch engineer with the
       reviewer's blockers table; then re-run the **full chain from
       test-writer** (test-writer → concurrency-auditor → task-reviewer).
       If still BLOCKED → escalate.

5. **Commit** (inline, not an agent call)
   - Inherit `/jls:git-commit` semantics from the existing
     `swift-spec-implement.md` Step 5: derive ticket from branch via
     `grep -oE '[A-Z]+-[0-9]+'`, compose `<ticket>: <task desc>`, stage
     specific files, commit via HEREDOC. Never `--no-verify`. Never `git
     add -A`. Never amend.
   - In BLOCKED-cycle mode, commit message is `<ticket>: fix <issue> from
     review`.
   - On pre-commit hook failure: fix, re-stage, new commit.

6. **Update plan + master-plan**
   - Mark `### Task [N]:` → `### Task [N]: <desc>  ✅` in `PLAN_PATH`.
   - Increment "Done" count for this spec's row in
     `${worktree_path}/master-plan.md`.
   - In BLOCKED-cycle mode, the ✅ mark is unchanged (already ✅); only
     the commit is added.

### Halt conditions

- Engineer ambiguity (`⛔️ STOP`)
- Engineer build failure after one attempt
- Test-writer test failure after one attempt
- Concurrency-auditor BLOCKED twice (one inner retry consumed)
- Task-reviewer BLOCKED twice (one inner retry consumed)
- Pre-commit hook fails persistently

All halt conditions escalate via Step 10.

### BLOCKED-cycle invocation (Stage 4 → Stage 3 re-entry)

Triggered when Step 9 sets `BLOCKERS_PATH` and `BLOCKED_CYCLE=1` and
re-enters Step 8.

- `BLOCKED_CYCLE=1` flips the per-task "already ✅ skip" check off, so the
  chain re-runs over every task.
- For each task, `BLOCKERS_PATH` is passed into the engineer call alongside
  the original task brief.
- The engineer applies the relevant fixes (and no-ops for fixes that don't
  apply to this task's files — relying on the engineer's existing scope
  discipline).
- Steps 2–6 of the inner chain run normally. Commit message uses the
  BLOCKED-cycle template (`<ticket>: fix <issue> from review`).
- After all tasks complete, control returns to Step 9 for the next
  Stage 4 cycle. `BLOCKED_CYCLE` is **not** cleared here — it is cleared
  by Stage 4 PASS, or implicitly on escalation.

### Known cost: BLOCKED-cycle re-runs every task

In BLOCKED-cycle mode the inner chain re-runs for **every** task in the
plan, not just tasks the blockers touch. On a 10-task plan, one BLOCKED
cycle is 10 engineer + 10 test-writer + 10 concurrency-auditor + 10
task-reviewer dispatches even when blockers touch two files. The engineer
no-ops on files outside its task's scope (relying on existing scope
discipline) so the work is bounded, but the dispatch overhead is real.

This preserves the existing orchestrator behaviour exactly. A future
optimisation could parse the blockers table for file paths and re-run
only the tasks that own those files — out of scope for this collapse.

---

## Q5 — Audit log

**Mechanism: SKILL drives Bash `cat <<EOF >> "$AUDIT_PATH"` heredocs
directly. No helper script.** The audit log is already line-oriented
append-only markdown; a helper would add complexity without changing
behaviour.

### Initialisation (Step 5)

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

### Per-stage appends

Every stage transition appends a section. Section heading format:
`## Stage N — <Label> — <timestamp>` or `### Cycle <cycle> blockers — <timestamp>`.

| When | Section | Mechanism |
|---|---|---|
| Step 6 start | `## Stage 1 — Spec Distiller — <ts>` heredoc | inline |
| Step 6 success | `## Full Spec` followed by `cat "$SPEC_PATH" >> "$audit_path"` | `cat $SPEC_PATH >> $AUDIT_PATH` |
| Step 7 start | `## Stage 2 — Planner — <ts>` heredoc | inline |
| Step 7 PASS | `## Full Plan` followed by `cat "$PLAN_PATH" >> "$audit_path"` | `cat $PLAN_PATH >> $AUDIT_PATH` |
| Step 8 start | `## Stage 3 — Implementation — <ts>` heredoc | inline |
| Per task start | `### Task N start — <ts>` heredoc | inline |
| Per task done | `### Task N done — commit <hash> — files <count>` heredoc | inline |
| Step 8 complete | `### Stage 3 complete — <ts> — all N tasks` heredoc | inline |
| Step 9 start | `## Stage 4 — Spec Review (cycle <cycle>) — <ts>` heredoc | inline |
| Step 9 BLOCKED | `### Cycle <cycle> blockers — <ts>` then `cat "$BLOCKERS_PATH" >> "$audit_path"` | `cat $BLOCKERS_PATH >> $AUDIT_PATH` |
| Step 10 start | `## Stage 5 — PR — <ts>` heredoc | inline |
| Step 10 SHIPPED | `## Final Outcome — SHIPPED — <ts>` heredoc with PR URL, commit count, cycle count, notes | inline |
| Escalation (any step) | `## Final Outcome — ESCALATED — <reason> — <ts>` heredoc with failing stage, cycle at escalation, last blockers verbatim | inline |

### Append-only invariant

The SKILL never uses `>` (truncate). Only `>>` (append) and `cat ... >>`.
The audit log accrues. No existing section is rewritten — even on
amendment loops, the new distiller / planner runs append fresh sections
under timestamps.

---

## Q6 — Per-leaf-agent invocation prompts

Each row below is the contract the SKILL must honour when composing the
`Agent` invocation prompt for that leaf agent. The leaf agent's own
definition file specifies what it expects to read — this table pins down
what the SKILL must pass.

| Agent | Context the SKILL must pass |
|---|---|
| `spec-scope-guardian` | `jira_key`, `raw_text`, `proposal_path`, full `SPEC_PIPELINE_*` block (so the agent can read `target_architecture_doc` and `context_docs`). Already correctly composed by the SKILL today; no change. |
| `spec-distiller` | `spec_id`, `source_type`, `raw_text` (verbatim), full `SPEC_PIPELINE_*` block. On amendment retry, additionally pass the planner's `PLAN NEEDS AMENDMENT: …` reasoning verbatim as an "amendment notes" block. |
| `planner` | `SPEC_PATH`, `PLAN_PATH`, full `SPEC_PIPELINE_*` block. |
| `engineer` | `PLAN_PATH`, `SPEC_PATH`, `task_n`, full `SPEC_PIPELINE_*` block. In BLOCKED-cycle or inner-retry mode, additionally `BLOCKERS_PATH` (file path) with the instruction *"Apply each Required fix in the table exactly. Do not expand scope. Re-build before reporting."* |
| `test-writer` | `SPEC_PATH`, `task_n`, engineer's file list (parsed from engineer's `Files modified:` / `Files created:` blocks), full `SPEC_PIPELINE_*` block. |
| `concurrency-auditor` | `task_n`, combined file list (engineer + test-writer), full `SPEC_PIPELINE_*` block (it builds against the same workspace). |
| `task-reviewer` | `PLAN_PATH`, `SPEC_PATH`, `task_n`, full `SPEC_PIPELINE_*` block. |
| `swift-spec-review` | `SPEC_PATH`, `PLAN_PATH`, branch base (default `main`), full `SPEC_PIPELINE_*` block. |

Every invocation prompt begins with the line `Read the following agent
definition file in full before doing anything:` followed by the absolute
path under `$REPO/agents/<name>.md`. The SKILL stores `$AGENTS_DIR` once
near the top (resolved from the agent symlink dir).

---

## Q7 — Files to change

| Path | Change | Approx lines added / removed |
|---|---|---|
| `skills/engineering/spec-pipeline/SKILL.md` | Replace "Step 5 — Spawn the orchestrator" and "Step 6 — Final report" with new Steps 5–10 (init audit log, Stage 1, Stage 2, Stage 3 per-task loop, Stage 4 review loop, Stage 5 PR / escalation). Add a "## State variables" subsection near the top of the new Stage section. | +650 / −90 |
| `agents/spec-pipeline-orchestrator.md` → `skills/engineering/spec-pipeline/playbooks/spec-pipeline-orchestrator.md` | `git mv`. Strip `---` / `name:` / `description:` / `model:` frontmatter. Replace with a 3–5 line preamble: *"Playbook reference only — not a registered agent. The spec-pipeline SKILL inlines this logic. Restore the frontmatter block and move back to `agents/` to re-enable as a subagent when Agent-from-subagent dispatch is supported."* | move file; +5 / −12 |
| `agents/swift-spec-implement.md` → `skills/engineering/spec-pipeline/playbooks/swift-spec-implement.md` | Same `git mv` + demotion. | move file; +5 / −12 |
| `README.md` | Remove the `spec-pipeline-orchestrator` row from the "Agents involved" table. Update the agentic-flow ASCII (see sketch below). | +2 / −6 |
| `agents/{engineer,test-writer,concurrency-auditor,task-reviewer,spec-distiller,planner,swift-spec-review}.md` | **Mandatory** edit: in each `description:` field, replace "Invoked by spec-pipeline-orchestrator" / "Invoked by swift-spec-implement" with "Invoked by the spec-pipeline SKILL". These fields surface in the agent listing the top-level session itself reads; stale references mislead future readers and any new pipeline run. | 1-line edit per file (≈7 files) |
| `Makefile` `agents:` target | No change. The target globs `agents/*.md` (non-recursive); the relocated playbooks under `skills/engineering/spec-pipeline/playbooks/` are naturally excluded. |
| `scripts/link-skills.sh` | No change. Operates on `skills/`, not `agents/`. The `playbooks/` subdirectory under the SKILL is along for the ride when the SKILL is symlinked — but since `link-skills.sh` only acts on `SKILL.md` files (`find … -name SKILL.md`), the playbook files are not separately symlinked. They are reachable as `~/.claude/skills/spec-pipeline/playbooks/*.md` only via the parent skill-dir symlink, which is exactly what we want. |
| `skills/engineering/spec-pipeline/scripts/` | No change. No new helper script needed (audit log writes are inlined heredocs). |
| `skills/engineering/spec-pipeline/SCHEMA.md` | No change. Config schema is untouched. |
| `skills/engineering/spec-pipeline/playbooks/` | **New directory.** Holds the two demoted playbook files. |

### README agentic-flow replacement sketch

Replace the existing block in `README.md` (current lines ~77–112) with:

```
The pipeline is driven by the `/jls:spec-pipeline` SKILL itself, which
runs at the top level and dispatches a chain of specialist agents in
sequence. You are interrupted only at defined gates.

SKILL: spec-pipeline (top-level driver — runs all stages inline)
│
├─ Stage 0  ── 🛂 spec-scope-guardian (Opus)            [Jira only]
│              Checks ticket scope before any work starts.
│              SCOPE: OK → continue │ SCOPE: SPLIT → create sub-tasks + halt
│
├─ Stage 1  ── 📐 spec-distiller (Opus)
│              Distils raw input → engineering spec + implementation plan.
│              Asks one question per conflict and one per UI decision.
│
├─ Stage 2  ── 🗺 planner (Sonnet)
│              Validates the plan fits the existing codebase.
│              PLAN VALID → continue │ PLAN NEEDS AMENDMENT → re-distil (1 retry)
│
├─ Stage 3  ── Per-task loop (driven inline by the SKILL)
│  │
│  ├──── 🔨 engineer (Sonnet)              implement one task, build clean
│  ├──── ✅ test-writer (Sonnet)           write @Test / @Suite tests for it
│  ├──── 🔒 concurrency-auditor (Sonnet)   check Sendable / actor / async safety
│  └──── 🔍 task-reviewer (Sonnet)         verify task against spec slice
│
├─ Stage 4  ── 🧐 swift-spec-review (Sonnet)
│              Whole-diff review of the branch against the full spec.
│              VERDICT: PASS → continue │ VERDICT: BLOCKED → loop back (max 3 cycles)
│
└─ Stage 5  ── /jls:git-pr (Sonnet)
               Push branch, run tests, code review, draft PR body,
               await your confirmation before `gh pr create`.
```

---

## Q8 — Backwards compatibility

### Grep results — references to the two collapsing agents

**`/Users/j.lesouef/.claude/skills` and `/Users/j.lesouef/.claude/agents`:**
no hits. The user's installed Claude dir does not contain stale copies (the
agents/skills are symlinks back into this repo, so any change here
propagates).

**Source repo `/Users/j.lesouef/Developer/Personal/skills`:**

| Path | Reference | After refactor |
|---|---|---|
| `agents/spec-pipeline-orchestrator.md` | The file itself. | `git mv` to `skills/engineering/spec-pipeline/playbooks/spec-pipeline-orchestrator.md`. Frontmatter stripped; prose preserved. No agent registration. |
| `agents/swift-spec-implement.md` | The file itself. | `git mv` to `skills/engineering/spec-pipeline/playbooks/swift-spec-implement.md`. Same treatment. |
| (playbook) `spec-pipeline-orchestrator.md:170` | `Spawn swift-spec-implement with (SPEC_PATH, …)` | Prose remains in the relocated playbook. Stays accurate as historical description. |
| (playbook) `spec-pipeline-orchestrator.md:297` | `Never write code — delegate to engineer via swift-spec-implement` | Same — historical prose. |
| `skills/engineering/spec-pipeline/SKILL.md:19,647,658,664` | Skill prose dispatching the orchestrator. | All replaced by inline Stage 1–5 in new Steps 5–10. |
| `agents/spec-distiller.md:7` | `description:` says "Invoked by spec-pipeline-orchestrator after the input adapter resolves" | Mandatory one-line edit to "Invoked by the spec-pipeline SKILL". |
| `agents/planner.md:7` | `description:` says "Invoked by spec-pipeline-orchestrator as Stage 2" | Mandatory one-line edit. |
| `agents/swift-spec-review.md:8` | `description:` says "Invoked by spec-pipeline-orchestrator as Stage 4" | Mandatory one-line edit. |
| `agents/engineer.md:8` | `description:` says "Invoked by swift-spec-implement; not directly by the user" | Mandatory one-line edit. |
| `agents/test-writer.md:6` | `description:` says "Invoked by swift-spec-implement after engineer reports clean build" | Mandatory one-line edit. |
| `agents/concurrency-auditor.md:9` | `description:` says "Invoked by swift-spec-implement after test-writer; never invoked directly" | Mandatory one-line edit. |
| `agents/task-reviewer.md:8` | `description:` says "Invoked by swift-spec-implement after concurrency-auditor; never invoked directly" | Mandatory one-line edit. |
| `README.md:79,181` | Mentions `spec-pipeline-orchestrator` as the driver and lists it in the agents table. | Removed / rewritten (sketch in Q7). |

### Operational compatibility

- Existing worktrees from previous runs work without change — the
  collapsed SKILL re-enters at Step 5 fresh.
- Existing audit logs at `$OBSIDIAN_VAULT/AI/plans/*.md` are unchanged in
  format; the SKILL writes the same section headings.
- Project `CLAUDE.md` config blocks need no changes.
- `cycle_budget`, `target_architecture_doc`, `context_docs`,
  `ticket_prefix` all preserved.
- `/jls:git-pr` and `/jls:git-commit` semantics unchanged.

---

## Q9 — Migration order

Each step lands as a single commit on this feature branch. Each is
followed by a test that confirms the repo is still consistent before
moving to the next.

| # | Step | Test |
|---|---|---|
| 0 | **Empirical probe (preflight, no edits):** dispatch a trivial `Agent` call from inside a subagent and observe the actual failure. If the gating premise holds (subagent cannot dispatch), proceed. If a different failure shows up (schema mismatch, working-directory issue, tool-permission scope), STOP and re-scope. | Probe output shows a clear "Agent tool not available in subagent context" or equivalent. If output is different, surface it before any edit. |
| 1 | Create `skills/engineering/spec-pipeline/playbooks/` directory. | `test -d skills/engineering/spec-pipeline/playbooks`. |
| 2 | `git mv agents/spec-pipeline-orchestrator.md skills/engineering/spec-pipeline/playbooks/spec-pipeline-orchestrator.md`. Then strip frontmatter and add playbook preamble. | `head -n 6 skills/engineering/spec-pipeline/playbooks/spec-pipeline-orchestrator.md` shows the preamble, not `---` / `name:`. `test ! -f agents/spec-pipeline-orchestrator.md`. |
| 3 | `git mv agents/swift-spec-implement.md skills/engineering/spec-pipeline/playbooks/swift-spec-implement.md`. Same demotion. | Same checks for the second file. |
| 4 | Run `make agents` to refresh agent symlinks. The relocated playbooks should no longer appear under `~/.claude/agents/`. | `ls ~/.claude/agents/ \| grep -E 'spec-pipeline-orchestrator\|swift-spec-implement'` returns zero hits. |
| 5 | Add Steps 5–10 to `skills/engineering/spec-pipeline/SKILL.md` (Stages 1–5 inline). Keep the old Step 5/6 in place for one commit so the file is still functional and a regression is recoverable. | `grep -nE 'Stage [1-5]' skills/engineering/spec-pipeline/SKILL.md` shows all 5 stages inlined. Read the diff for sanity. |
| 6 | In a second SKILL.md edit, delete the old "Step 5 — Spawn the orchestrator" and "Step 6 — Final report" blocks. | `grep -n 'spec-pipeline-orchestrator' skills/engineering/spec-pipeline/SKILL.md` returns at most one playbook-pointer line. |
| 7 | Update `README.md` — remove the orchestrator row from the agents table; replace the agentic-flow ASCII with the sketch in Q7. | `grep 'spec-pipeline-orchestrator' README.md` returns zero hits. The agents table still lists 8 agents (was 9). |
| 8 | Update `description:` fields on the 7 leaf agents to say "Invoked by the spec-pipeline SKILL". Run `make agents` to refresh. | `grep -l 'spec-pipeline-orchestrator\|swift-spec-implement' agents/*.md` returns zero files. |

If step 5 produces a SKILL.md that doesn't dispatch correctly, the repo
remains recoverable: rolling back step 5 alone restores a SKILL that
referenced the (now-relocated) orchestrator file. Re-add the
`agents/spec-pipeline-orchestrator.md` symlink and restore the
frontmatter to fully revert. The playbook files under `playbooks/` are
the historical source.

After step 6 the SKILL no longer references the orchestrator; the
relocation in steps 2–3 already prevented the orchestrator from being
loaded as an agent. Steps 7–8 are purely cosmetic-but-mandatory cleanups.

---

## Q10 — Verification plan (smoke test for the execute-phase session)

After all migration steps land, the execute-phase session runs:

1. **Choose a small Jira test ticket** — ideally one already used to debug
   the prior failure (the user's `NAT-1768-…` ticket, or any small ticket
   with 2–3 ACs).
2. `/jls:spec-pipeline --from-jira NAT-XXXX`
3. **Observe Stage 1**: the SKILL dispatches `spec-distiller` via `Agent`.
   Expected: distiller prints `📐 SPEC-DISTILLER — <spec-id>`, writes
   `docs/specs/<spec-id>.md` inside the worktree, writes
   `docs/plans/<spec-id>.md`. This was the previously failing point —
   confirming it now works proves the structural fix.
4. **Observe Stage 2**: planner runs, prints either `PLAN VALID` or
   `PLAN NEEDS AMENDMENT:`. If the latter, distiller re-runs once.
5. **Observe Stage 3**: at least one per-task chain runs end-to-end —
   `engineer` → `test-writer` → `concurrency-auditor` → `task-reviewer` →
   commit. Verify `git log` shows at least one commit on the feature branch
   with a NAT prefix.
6. **Observe Stage 4**: `swift-spec-review` runs. Expected `VERDICT: PASS`
   on a clean small ticket. If `VERDICT: BLOCKED`, verify the BLOCKED loop
   re-enters Stage 3 with the blockers table file path passed to the
   engineer.
7. **Observe Stage 5**: `/jls:git-pr` is invoked. Confirm the user is
   asked to confirm the PR body before `gh pr create`.
8. **Confirm the audit log** at
   `$OBSIDIAN_VAULT/AI/plans/<spec-id>.md` accrues sections in order:
   header → `## Stage Log` → `## Stage 1 …` → `## Full Spec` →
   `## Stage 2 …` → `## Full Plan` → `## Stage 3 …` → per-task entries →
   `## Stage 4 …` → `## Stage 5 …` → `## Final Outcome — SHIPPED`.

### Negative smoke tests

- **`/jls:spec-pipeline --help`** still prints help and exits cleanly.
- **`/jls:spec-pipeline --from-jira NAT-OVERSIZED`** still routes through
  Stage 0 (`spec-scope-guardian`) and proposes a split before any
  worktree is created.
- **Resume**: invoke twice on the same ticket. Second invocation prompts
  with Resume / Restart / Abort options and resumes mid-flow.

The execute-phase session need not run all three. Steps 1–8 above suffice
to prove the structural collapse works.

---

## Advisor consultation

The `advisor` tool was called once before saving this plan, with the full
session transcript as context. Five concrete pieces of feedback came back
and were folded into the plan:

1. **Premise verification.** The advisor flagged that the
   "Agent-tool-gated-to-subagents" claim, while explicitly stated in the
   user's task, was never empirically verified in this session. A
   five-minute probe before any refactor would cost nothing and would
   prevent a 700-line refactor on a faulty premise. **Folded in as Step 0
   of the migration order in Q9** — the execute-phase session must run a
   trivial subagent → Agent probe before any edit. If the failure mode is
   not what the user described, the execute phase stops and re-scopes.
2. **Demotion mechanism.** The original draft relied on Claude Code's
   agent loader rejecting `.md` files without `name:` frontmatter. This is
   undocumented loader behaviour. The advisor recommended relocating the
   files to `skills/engineering/spec-pipeline/playbooks/` instead, which
   removes them from the Makefile's `agents/*.md` glob entirely and makes
   no assumption about loader semantics. **Folded into Q1, Q7, and Q9**.
3. **README ASCII sketch.** Q7 originally described the README update as
   prose. **Folded in as a literal replacement block in Q7** so the
   execute-phase session does not have to guess the new shape.
4. **Stage 2 amendment state.** Q3's state variable table did not include
   the amendment retry guard. **Folded in as `amendment_attempted` in
   Q3, with explicit set/reset/escalate semantics in Q2's Step 7
   description**.
5. **BLOCKED-cycle re-run cost.** The advisor confirmed the per-task loop
   must re-enter every task in BLOCKED mode (matching the existing
   playbook prose), but asked that the dispatch overhead be flagged as a
   known cost so the user is not surprised. **Folded into Q4 under
   "Known cost"**.

The advisor also recommended making the leaf-agent `description:` field
edits mandatory rather than optional (they affect the agent listing the
top-level session itself reads). **Folded into Q7 and Q9.**

No issues from the advisor are left unaddressed. Step 0 of Q9 (the
empirical probe) is the only remaining check the execute-phase session
must perform before applying the rest of the plan.

---

## Out of scope

- Executing the plan — a separate execute-phase session applies it.
- Re-architecting the leaf agents.
- Changing the spec / plan / master-plan markdown formats.
- Modifications to `/jls:git-pr` or `/jls:git-commit`.
- Changing the Obsidian audit log location or schema.
