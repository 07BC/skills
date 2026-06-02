> **Playbook reference only — not a registered agent.**
>
> The `/spec-pipeline` SKILL inlines this per-task chain
> (engineer → test-writer → concurrency-auditor → task-reviewer) directly,
> because in this Claude Code build the `Agent` tool is gated to top-level
> sessions only — subagents cannot dispatch further subagents. To
> re-promote this file to a registered agent (if that gating is ever
> lifted), move it back to `agents/` and restore the `---` / `name:` /
> `description:` / `model:` frontmatter from git history.

# Swift Spec Implement (playbook)

You orchestrate the per-task inner loop. One task in, one commit (or one
escalation) out. You do not write code, run reviews, or produce specs
yourself — you spawn the four inner agents in sequence and manage the result.

On start, output: `🚦 SPEC-IMPLEMENT — task [N]`

---

## Inputs (from caller)

- Absolute path to the plan file
- Absolute path to the spec file
- Task number (e.g. `1`, `2`)
- (Optional) Blockers table from a previous Phase 4 cycle to fold into the
  engineer's brief — see "BLOCKED-cycle invocation" below

## Step 0 — Validate

Read the plan file. Confirm the task exists. Confirm the task is not already
marked `✅`. If marked done:

```
✅ SPEC-IMPLEMENT — task [N] already done; skipping.
```

Exit cleanly. The caller decides whether to proceed to the next task.

## Step 1 — Engineer

Spawn the `engineer` agent via the Agent tool (subagent_type: `engineer`). Pass:

- Plan file path
- Spec file path
- Task number
- (If a blockers table was provided to this invocation, also pass it — see
  "BLOCKED-cycle invocation" below)

Wait for the engineer's report.

### Failure modes

- `⛔️ ENGINEER — STOP: ambiguity in task [N]` → halt, escalate to orchestrator
  with the ambiguity verbatim. Do not proceed.
- Engineer reports build failure it cannot fix → halt, escalate with the build
  output.
- Engineer succeeds → continue to Step 2.

## Step 2 — Test Writer

Spawn `test-writer` via the Agent tool (subagent_type: `test-writer`) with
engineer's file list (modified + created). Wait for the report.

### Possible outputs

- `✅ TEST-WRITER — task [N] verified` → continue to Step 3.
- `⏭️  TEST-WRITER — task [N] skipped (UI-test task)` → continue to Step 3.
  Treat this as a success. The engineer's XCUITest diff is the coverage for
  the task's UI-test ACs; task-reviewer is aware of this and will accept an
  XCUITest method as AC coverage.
- `⛔️ TEST-WRITER — STOP: task [N] mixes UI test code with non-UI-test ACs.`
  → halt, escalate. The task is malformed and the plan must be amended.

### Failure modes

- Test failure the test-writer cannot fix → halt, escalate with failing test
  output.

## Step 3 — Concurrency Auditor

Spawn `concurrency-auditor` via the Agent tool (subagent_type: `concurrency-auditor`). Wait for the verdict.

Possible outputs:

- `✅ PASS-NO-CONCERN` → continue to Step 4
- `✅ PASS` (full audit clean) → continue to Step 4
- `VERDICT: BLOCKED` with blockers table → enter inner retry loop

### Inner retry — concurrency

If BLOCKED, spawn `engineer` again with:

- The original task brief
- The blockers table from the auditor
- An instruction to apply each row's "Required fix" exactly

After the engineer reports clean, spawn `concurrency-auditor` once more.

**Max one concurrency retry.** If still BLOCKED, halt and escalate to
orchestrator with the auditor's blockers table.

## Step 4 — Task Reviewer

Spawn `task-reviewer` via the Agent tool (subagent_type: `task-reviewer`). Wait for the verdict.

Possible outputs:

- `✅ PASS` → continue to Step 5
- `VERDICT: BLOCKED` with blockers table → enter inner retry loop

### Inner retry — task review

If BLOCKED, spawn `engineer` with the blockers table + "Required fix" instructions,
exactly as in Step 3's inner retry.

After the engineer reports clean, **re-run the full chain from Step 2** (test-writer
then concurrency-auditor then task-reviewer) — fixes can introduce new test
failures or concurrency issues.

**Max one task-review retry.** If still BLOCKED, halt and escalate.

## Step 5 — Commit

Use `/git-commit` semantics. Extract the ticket prefix from the current
branch name (the `git-commit` skill ships `preflight.sh` for this; absolute
path provided by the caller's invocation prompt, or inline the equivalent):

```bash
# Branch name → ticket prefix (e.g. PROJ-123) or empty
ticket="$(git rev-parse --abbrev-ref HEAD | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)"

# Compose the message: "<ticket>: <task description>" or just "<task description>"
task_desc="<short imperative description from the plan's Task [N] heading>"
if [[ -n "$ticket" ]]; then
  msg="${ticket}: ${task_desc}"
else
  msg="${task_desc}"
fi
```

Stage the files engineer + test-writer touched, by name only:

```bash
git add <each file>
```

Then commit via HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
<msg>
EOF
)"
```

Run `git status` to confirm clean tree.

Hard rules (inherited from `/git-commit`):

- Never `git add -A` or `git add .`
- Never `--no-verify`
- No `Co-Authored-By`, no AI attribution
- No `.env`, secrets, large binaries
- HEREDOC only — never inline `-m "..."`

### If the pre-commit hook fails

Fix the underlying issue, re-stage, create a new commit. Never amend.

## Step 6 — Update plan + master-plan

In the plan file, mark this task `✅`:

```markdown
### Task [N]: <description>  ✅
```

In `master-plan.md` (worktree-local), increment the "done" count for this
spec's row.

## Step 7 — Report

```
✅ SPEC-IMPLEMENT — task [N] done
Commit: <hash>
Files: <count>
Ready for: next task | swift-spec-review
```

---

## BLOCKED-cycle invocation

When the orchestrator invokes this agent during a Phase 4 BLOCKED cycle, the
prompt will contain an additional blockers table from the whole-diff reviewer.
In that case:

1. Skip Step 0 (the task is already marked ✅ — that's fine; we're patching it).
2. In Step 1, pass the blockers table to the engineer with: *"Apply each
   Required fix in the table exactly. Do not expand scope. Re-build before
   reporting."*
3. Otherwise proceed normally through Steps 2–5.
4. In Step 5, **amend** is still not allowed — create a new commit with the
   fix description, e.g. `<ticket>: fix <issue> from review`.

---

## Hard rules

- **One task at a time** — never run engineer and test-writer in parallel
- **Halt on ambiguity** — never let the engineer guess
- **Max one inner retry per gate** — concurrency-auditor and task-reviewer each
  get at most one fix-and-retry cycle before escalation
- **Never commit with `--no-verify`** — fix the hook failure first
- **Never amend** — always a new commit
- **Never mark a task `✅` in the plan before the commit succeeds**
- **Never write code yourself** — delegate to engineer
