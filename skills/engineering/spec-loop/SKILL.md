---
name: spec-loop
description: >
  Autonomously drives a whole master spec to completion. Loops over every child
  spec of a master — GitHub master issue + sub-issues, or a raw local master doc
  it decomposes itself — implementing each through the same spec-engineer →
  spec-test-writer → spec-concurrency-auditor → dual-reviewer chain spec-pipeline
  uses, on ONE branch. Finishes only when every master AC is covered, tested,
  passing, and a whole-diff review against the master passes, then stops at a
  single PR. Keeps a committed progress.md tracker; runs with no prompts mid-loop.
  Use when the user says "drive this master to done", "loop until the spec is
  complete", "build out the whole master", "spec-loop", or "/spec-loop …".
  Project must declare its config in a fenced spec_pipeline YAML block in
  CLAUDE.md — see ../spec-pipeline/SCHEMA.md.
disable-model-invocation: true
---

# Spec Loop

`/spec-loop` is the autonomous driver that sits **above** `/spec-pipeline`. Where
the pipeline ships **one** child spec and stops at a per-child PR, spec-loop drives
an **entire master** to completion: it resolves the master's children, implements
each one sequentially on a single branch reusing the proven spec-* agent chain, and
only finishes when the **master** spec is genuinely complete. It then stops at one
PR for human review.

It creates branches and commits and runs unattended. **Never auto-invoke.** Always
an explicit user trigger.

> **Related:**
> - `/spec-decomposition` mints a GitHub master issue + child sub-issues with a frozen
>   AC-ID spine. spec-loop drives those children to done (GitHub mode).
> - `/spec-pipeline` is the authority for the **inner per-child contract** (Phases 1–4:
>   distil → plan → per-task engineer/test/concurrency/dual-review → commit). spec-loop
>   reuses that contract verbatim with two deltas (below); it does **not** modify the
>   pipeline.
> - See `docs/adr/0017-spec-loop-autonomous-master-driver.md`.

**Two deltas from the pipeline's per-child contract:**
1. **Sequencing predicate** is *committed on this branch* (not *merged to main*) — everything lives on one branch.
2. **Pipeline Phase 5 (per-child PR) is skipped** — there is exactly one PR, at the end, for the whole master.

---

## Help mode

Before any side effect — before resolving paths, reading config, or branching —
check `$ARGUMENTS`. If it is empty, `--help`, `-h`, or `help`, print this block
verbatim and exit. Do not parse config, branch, decompose, or dispatch any agent.

````
/spec-loop — autonomously drive a whole master spec to one PR

Usage:
  /spec-loop --from-master GH#         drive a GitHub master issue's child sub-issues
  /spec-loop --from-master-doc PATH    decompose a local master doc, then drive its children
  /spec-loop --help                    show this message

What it does:
  1. Reads the spec_pipeline YAML config from your CLAUDE.md (+ optional spec_loop_max_sweeps)
  2. Resolves the master → ordered children (sub-issues, or freshly decomposed local children)
     with frozen AC IDs, covers, and depends_on
  3. Creates ONE fresh branch in-place (no worktree)
  4. Sweeps children sequentially in dependency order, implementing each via the
     spec-pipeline inner chain (engineer → test → concurrency → dual review → commit),
     committing a docs/specs/<master>-progress.md tracker after each child
  5. Repeats sweeps until the completion oracle passes (all children done, all master
     ACs covered + tested, branch tests pass, coverage floor met, whole-diff review vs
     the master PASSes) — or a stop condition trips
  6. Opens ONE PR via /git-pr for the whole master and stops for human review

Autonomy:
  - Commits freely; NEVER auto-creates or auto-merges the PR
  - No prompts mid-loop. A child that cannot pass (gate exhaustion OR unresolvable
    ambiguity) is PARKED if nothing depends on it (loop continues) or HALTS the run if
    a dependent is blocked. Parked children + their open questions are reported.

Termination guarantees:
  - spec_loop_max_sweeps (config, default 8) — a finite shared ceiling across all
    sweeps, including master-review fix sweeps
  - stall detector — a full sweep completing no new child and adding no new commits halts

Resume:
  - Source of truth is the git branch (commits + plan ✅ markers). Interrupt and re-invoke
    /spec-loop --from-master <#> (or --from-master-doc PATH) on the same branch; done
    children are skipped and progress.md is re-rendered to match.

One-time project setup: see ../spec-pipeline/SCHEMA.md (same config block).
````

---

## Resolving script paths

After `make install` (or `make link`), the helper scripts are symlinked at:

```
$HOME/.claude/skills/spec-loop/scripts/resolve-children.sh
$HOME/.claude/skills/spec-loop/scripts/render-progress.sh
$HOME/.claude/skills/spec-loop/scripts/check-master-coverage.sh
$HOME/.claude/skills/spec-pipeline/scripts/read-pipeline-config.sh
$HOME/.claude/skills/spec-pipeline/scripts/check-traceability.sh
$HOME/.claude/skills/spec-pipeline/scripts/coverage-gate.sh
```

Use those paths directly. spec-loop reuses spec-pipeline's config reader and gate
scripts unchanged — only the three `spec-loop/scripts/*` helpers are new.

---

## Inputs

Exactly **one** source flag (mutually exclusive):

| Flag | Mode | Children come from | AC spine |
|---|---|---|---|
| `--from-master <GH#>` | GitHub | the master issue's native sub-issues | the master issue body (frozen AC IDs) |
| `--from-master-doc <PATH>` | local | spec-loop decomposes the doc into local child specs | the master doc frontmatter (frozen AC IDs) |

Refuse if both are given, or neither (print help).

---

## Step 1 — Read pipeline config

Reuse spec-pipeline's reader; it emits the same `SPEC_PIPELINE_*` shell variables.

```bash
eval "$(bash "$HOME/.claude/skills/spec-pipeline/scripts/read-pipeline-config.sh")"
max_sweeps="${SPEC_PIPELINE_SPEC_LOOP_MAX_SWEEPS:-8}"
```

`spec_loop_max_sweeps` is an optional key in the same `spec_pipeline` block (default 8).
Stop on missing required config (`workspace`/`scheme`/`destination`/`tests_target`) exactly
as the pipeline does — never invent it.

---

## Step 2 — Resolve master → children + AC spine

### GitHub mode (`--from-master <GH#>`)

```bash
REPO="${SPEC_PIPELINE_GITHUB_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
master_key="$(gh issue view "<GH#>" --repo "$REPO" --json number -q .number)"
bash "$HOME/.claude/skills/spec-loop/scripts/resolve-children.sh" \
  --mode github --master "<GH#>" --repo "$REPO" > "$children_manifest"
```

`resolve-children.sh` emits a tab-separated **children manifest**, one row per child:

```
child_id<TAB>covers<TAB>depends_on<TAB>state
```

`state` is computed from the branch (see Step 5 resume); on first run it is `pending`.
The master's full frozen AC-ID set is read from the master issue body.

### Local mode (`--from-master-doc <PATH>`)

The master doc carries the frozen AC IDs in its frontmatter (`master_acs:` — ID + text).
There are no sub-issues, so **spec-loop decomposes the master itself**: dispatch the
decomposition brain (`spec-scope-guardian`) to propose the child split, then `spec-distiller`
to write each local child spec + plan under `$SPEC_PIPELINE_SPEC_DIR` / `$SPEC_PIPELINE_PLAN_DIR`.
Keep this a thin delegation — do not re-implement decomposition logic here.

**Frontmatter contract (required — `resolve-children.sh` keys on exactly these).**
Each generated child spec MUST carry, in its frontmatter:
- `master: <master_key>` — ties the child to this master (the resolver also accepts a
  filename prefixed `<master_key>-` as a fallback, but write `master:` explicitly).
- `covers: [<master AC IDs>]` — the frozen AC IDs this child implements.
- `depends_on: [<child slugs>]` — the **spec slugs** (basename without `.md`) of the
  children this one waits on, **not** free text. The slug is the child's `child_id` in
  the manifest, so the on-branch sequencing predicate matches `depends_on` tokens against
  `child_id`. A mismatch here means sequencing silently never fires.

Then resolve children from the generated files:

```bash
bash "$HOME/.claude/skills/spec-loop/scripts/resolve-children.sh" \
  --mode local --spec-dir "$SPEC_PIPELINE_SPEC_DIR" --master-key "$master_key" > "$children_manifest"
```

In both modes, after building the manifest assert master-AC coverage (every master AC
is in some child's `covers`):

```bash
bash "$HOME/.claude/skills/spec-loop/scripts/check-master-coverage.sh" \
  --master-acs "$master_acs_file" --manifest "$children_manifest"
```

Non-zero exit → escalate with reason `Master AC not covered by any child` (the
decomposition is incomplete; fix it before driving).

---

## Step 3 — Lightweight confirmation

Summarise to the user once: master key, child count + titles in dependency order,
mode (GitHub/local), branch name, and `max_sweeps`. This is the only pre-run
confirmation; after the branch is created the loop runs unattended.

---

## Step 4 — Branch management (in-place, one branch)

Identical to spec-pipeline Step 4, with one difference: **one branch covers the whole
master**, not one child. Branch name derives from the master key.

```bash
repo_root="$(git rev-parse --show-toplevel)"
worktree_path="$repo_root"          # in-place — NOT a separate worktree
branch="feat/${master_key}-master"  # bug/ or chore/ if the master is typed so
```

- Dirty-tree preflight: if dirty, ask (stash / commit first / proceed / abort).
- Base must be `main` (or configured base); ask before branching from a non-base HEAD.
- **Create or resume**: if `$branch` exists, check it out (this is a resume — Step 5
  re-derives done-ness from git); else `git checkout -b "$branch"`.
- **Never run directly on the base branch.**

---

## Step 5 — Initialise audit log + master state (resume from git)

The Agent tool is gated to top-level sessions — subagents cannot dispatch subagents.
So spec-loop drives the loop inline at the top level, dispatching one leaf agent at a
time, exactly as spec-pipeline does.

### Master state (bash shell state)

```bash
master_audit_path="${SPEC_PIPELINE_VAULT}/${SPEC_PIPELINE_AUDIT_DIR}/${master_key}-master-loop.md"
progress_path="${worktree_path}/${SPEC_PIPELINE_SPEC_DIR:-docs/specs}/${master_key}-progress.md"
children_manifest="${TMPDIR}/spec-loop-${master_key}-children.tsv"
sweeps_used=0
max_sweeps="${SPEC_PIPELINE_SPEC_LOOP_MAX_SWEEPS:-8}"
agents_dir="$HOME/.claude/agents"
mkdir -p "$(dirname "$master_audit_path")"
```

### Resume — git is the source of truth (decision 10)

A child is **done** when its plan file's tasks are all marked `✅` AND its task commits
exist on the branch. Compute each child's `state` from git + its plan `✅` markers; never
trust `progress.md` or issue checkboxes as truth — they are *rendered from* this. Update
the `state` column of `$children_manifest` accordingly (`done` / `pending` / `parked`).

### Initialise the master audit log + render progress.md

Append-only audit log header (like spec-pipeline's, keyed by master). Then render the
committed tracker:

```bash
bash "$HOME/.claude/skills/spec-loop/scripts/render-progress.sh" \
  --master-key "$master_key" --master-acs "$master_acs_file" \
  --manifest "$children_manifest" --sweeps-used "$sweeps_used" --max-sweeps "$max_sweeps" \
  --audit "$master_audit_path" > "$progress_path"
git -C "$worktree_path" add -- "$progress_path" && git -C "$worktree_path" commit -m "${master_key}: init spec-loop progress tracker" || true
```

All later audit-log writes use `>>` (append), never `>`.

---

## Step 5.5 — Pipeline pre-flight

Before the first sweep, run the shared pre-flight skill to surface drift between the
repo state and the docs the loop trusts.

Apply `[SKILL: ~/.claude/skills/pipeline-preflight/SKILL.md]` (the `pipeline-preflight`
policy skill). It produces signals only; spec-loop owns the user-facing decision. Surface
signals via `AskUserQuestion` (Reconcile / Proceed / Abort) and continue only on
`Pre-flight clean.` or an explicit Proceed. This is the **last** prompt before the loop
runs unattended.

---

## Phase 1 — Sweep loop (sequential, one child at a time)

Repeat **sweeps** until the completion oracle (Phase 2) passes or a stop condition
(Halt Conditions) trips. Each sweep walks the manifest in dependency order:

```
while completion oracle is not satisfied:
    if sweeps_used >= max_sweeps: escalate "max sweeps reached"
    progressed_this_sweep = false
    for child in manifest (dependency order):
        if child.state == done or child.state == parked: continue
        if any dep of child is not committed-on-branch (state != done): continue   # on-branch sequencing
        run INNER PER-CHILD CHAIN for child       # Phase 1a
        update child.state; re-render + commit progress.md
        if child completed or advanced: progressed_this_sweep = true
    sweeps_used += 1
    if not progressed_this_sweep: escalate "stall — no child advanced and no new commits"   # stall detector
```

### Phase 1a — Inner per-child chain (reuses the pipeline contract)

For each child, run **exactly** the spec-pipeline per-child contract — its Steps 6–9
(Phase 1 Spec Distiller → Phase 2 Planner → Phase 3 per-task loop → Phase 4 whole-diff
review of the *child*). spec-pipeline `SKILL.md` is the authority for every gate, parse
rule, retry budget, and `Agent`-dispatch composition; follow it verbatim, dispatching the
same leaf agents (`spec-distiller`, `spec-planner`, `spec-engineer`, `spec-test-writer`,
`spec-concurrency-auditor`, `spec-task-reviewer`, `spec-quality-reviewer`,
`spec-branch-reviewer`) via the `Agent` tool from their definitions under `$agents_dir`.

Apply these spec-loop deltas:
- **Sequencing**: a dependency is satisfied when it is *committed on this branch* (its
  manifest `state == done`), not merged to main.
- **No per-child PR**: do **not** run pipeline Phase 5 for the child. The single PR is
  Phase 3 of spec-loop.
- **Per-child cycle_budget** (`SPEC_PIPELINE_CYCLE_BUDGET`, default 3) is independent and
  **resets per child** (decision 15). It bounds the child's own Phase 4 review loop, as in
  the pipeline.
- **GitHub mode**: distil the child via the `--from-issue` path (frozen AC IDs from the
  sub-issue). **Local mode**: the child spec already exists from Step 2 decomposition —
  distil verbatim / validate, do not re-author.

**Stuck child (decision 9 & 13).** If the child exhausts its `cycle_budget`, OR a leaf
agent returns an unresolvable stop (`⛔️ ENGINEER — STOP: ambiguity`, distiller `BLOCKED on
Open Questions`):
- If **no** other child `depends_on` this child → mark it `parked` (with the reason +
  any open questions), record in the audit log + progress.md, and continue the sweep.
- If **any** child depends on it → **halt** the whole run and escalate (dependents cannot
  proceed). Never prompt mid-loop — questions are *reported*, not asked.

If a dispatched leaf agent returns no usable result at all (crash/drop), apply the
`subagent-reliability` policy skill (recover-in-place / resume / re-spawn) before treating
the child as stuck.

---

## Phase 2 — Completion oracle

The master is **complete** only when **all** hold (re-checked at the top of each sweep
and after the final sweep):

1. Every child in the manifest is `done` (all plan tasks `✅`, task commits on branch).
   Parked children mean the oracle **cannot** be satisfied → the run ends via escalation,
   not success.
2. Per-child traceability passes for each child:
   `check-traceability.sh --spec <child spec> --plan <child plan> --tests-dir <…>`
   (this needs no GitHub — `covers:` comes from the child spec frontmatter, so it works in
   local mode too).
3. Master-AC coverage holds: `check-master-coverage.sh` — every frozen master AC is in some
   child's `covers`.
4. Branch test suite passes and changed-line coverage ≥ `coverage_floor` vs `main`
   (`coverage-gate.sh` over the whole branch diff).
5. **Master whole-diff review PASSes**: dispatch `spec-branch-reviewer` pointed at the
   **master** (master issue body in GitHub mode, master doc in local mode) as the spec
   authority, reviewing the whole branch diff.

### Master review BLOCKED (decision 12)

If (5) returns `VERDICT: BLOCKED`, do not escalate yet:
- Attribute each blocker to the child(ren) whose files it touches.
- Set those children's `state` back to `pending` with the blockers attached (written to a
  tmp file, passed by path to `spec-engineer` on re-run).
- Return to Phase 1 — only the affected children re-run.
- This fix sweep **decrements the same `max_sweeps` ceiling** (decision 15). When the
  ceiling is hit while still BLOCKED → escalate.

---

## Phase 3 — PR (single) or escalation

### On oracle pass — one PR via /git-pr

Invoke the `/git-pr` skill **once** for the whole master branch:

```
Skill(skill: "git-pr")
```

`/git-pr` runs the final test pass + code review, drafts the PR, and requires **human
confirmation** before `gh pr create`. spec-loop never auto-creates or auto-merges
(decision 4). If `/git-pr` surfaces a blocker the whole-diff review missed, **halt** — do
not bypass.

**On PR created — reconcile + final outcome.** In GitHub mode, reconcile the sub-issues
against the single master PR (reuse spec-pipeline Phase 5's `gh issue edit` reconciliation,
applied **once** at the end): tick every child row + per-AC checkbox in the master + child
sub-issues, and comment the PR URL. Then append the master audit log Final Outcome
(✅ SHIPPED, PR URL, commit count, sweeps used, any parked children) and render the final
progress.md.

### On escalation — see Halt Conditions

Append a Final Outcome (⚠️ ESCALATED + reason + sweep at escalation + parked children +
last blockers table) to the master audit log. **Never create a PR. Never discard the
branch or its commits.**

---

## Halt Conditions

spec-loop halts (and writes an escalation Final Outcome instead of a PR) when:

- **Required config missing** — `workspace`/`scheme`/`destination`/`tests_target` absent.
- **Master AC not covered** — `check-master-coverage.sh` fails (incomplete decomposition).
- **Max sweeps reached** — `sweeps_used >= max_sweeps` while the oracle is unsatisfied.
- **Stall** — a full sweep advances no child and adds no commits.
- **Dependent blocked** — a stuck child has a dependent that therefore cannot proceed.
- **Master review BLOCKED past the ceiling** — Phase 2 (5) stays BLOCKED when sweeps run out.
- **/git-pr blocker** — the final gate raises a blocker the whole-diff review missed.
- **Subagent unrecoverable** — a leaf agent returns no usable result and
  `subagent-reliability` recovery fails.

A run that ends with any child `parked` is an **escalation**, not a success — the oracle
requires every child `done`. The escalation report lists each parked child, its reason, and
its open questions for the user to resolve, after which they re-invoke spec-loop on the same
branch to resume from git.

---

## Hard rules

- **Never auto-invoke** — user trigger only. The skill creates branches and commits and
  runs unattended.
- **One source flag** — never accept both `--from-master` and `--from-master-doc`.
- **Stop on missing required config** — never invent `workspace`/`scheme`/`destination`/`tests_target`.
- **One branch, one PR** — the whole master lives on a single branch; exactly one PR, at the end.
- **Never modify spec-pipeline or the spec-* agents** — reuse the inner contract by reference,
  applying only the two documented deltas.
- **Never run directly on the base branch** — always branch first (Step 4).
- **No prompts mid-loop** — after Step 5.5, the loop runs unattended; stuck children are
  reported, never asked about.
- **Never auto-create or auto-merge the PR** — `/git-pr` is human-gated.
- **Git is the resume source of truth** — progress.md and issue checkboxes are rendered from
  it, never the other way around.
- **Sequential children only** — one child at a time on the branch.
- **Audit log is append-only.**

---

## Model & mode

The SKILL runs in the **top-level session** and owns every branching decision. It drives the
master loop inline rather than nesting an orchestrator subagent, because the Agent tool is
gated to top-level sessions in this Claude Code build — subagents cannot dispatch further
subagents.

> Running as: Opus — normal mode (Opus orchestrates the loop and owns all branching; the
> spec-* leaf agents, dispatched from their own definition files under `$agents_dir`, set
> their own models — Sonnet for engineer/test/reviewers, Opus for distiller/concurrency/
> branch-review).
