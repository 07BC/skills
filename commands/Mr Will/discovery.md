# Mr Will: Discovery

## Input → Understand → Three Amigos plan → Challenge scope → Materialise into the tracking backend → Hand off

---

## Overview

This command is the **planning front door**: it runs **shape → architect →
discover** on a single piece of work, then writes that plan into the project's
configured tracking backend and hands off to implementation.

A panel of subagents reads the input and produces one plan from three
complementary roles — **PM** (scope), **Architect** (approach), **QA** (test
bar) — while a standing **devil's advocate** attacks the merged plan for scope
creep. The orchestrator then **materialises** the plan as tracked work items in
the backend declared by the project's `discovery:` config, and offers handoff:

```
/discovery   →  approved plan + tracked work items  →  /workflow      →  PR
(read + plan)   (in jira | github | local backend)     /spec-pipeline
```

Use `/discovery` when you have a ticket, issue, prompt, or doc and need it read,
planned, and broken into tracked next steps before any code is written. It never
writes implementation code or opens a PR — the handoff is the boundary.

The orchestrator (Opus) owns every branching decision — the panel shape, the
synthesis, the loop-or-ship call, the backend dispatch. Subagents (Sonnet)
explore, contribute a role, and attack; no subagent makes a branching decision.

This command **absorbs** the former standalone architecture-tracking entry
point: if the work is already tracked, it re-enters in **track mode** (reconcile
/ import) instead of re-planning. See Phase 0.

**Input required before launching:**

- One of (auto-detected, positional):
  - A Jira key (e.g. `NAT-123`) — `^[A-Z]+-[0-9]+$`
  - A GitHub issue ref (`owner/repo#NN`, `#NN`, or an issue URL)
  - A file path (a spec, a brief, a doc) — by file existence
  - A free-form description — the default

---

## Variables

Define once; later phases reference these rather than restating paths.

| Variable | Source | Example |
| --- | --- | --- |
| `SUBAGENT_MODEL` | constant | `claude-sonnet-4-6` |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` | `myapp` |
| `PLANS_DIR` | `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans` | per global plan-storage rule |
| `DISCOVERY_DOC` | `${PLANS_DIR}/discovery/${slug}.md` | the single durable artefact this command produces |
| `slug` | kebab-cased work title | `livestream-language-filter` |

When a phase says "spawn a Sonnet subagent" it means
`model: SUBAGENT_MODEL, mode: normal`.

---

## Discovery Config — hard precondition

This command is **backend-driven**. It reads a fenced YAML block from the
project's `CLAUDE.md` (the same convention `spec-pipeline` uses). Read
`./CLAUDE.md`, find the first ```` ```yaml ```` fence containing a top-level
`discovery:` key, and parse it:

````markdown
## Discovery Config

```yaml
discovery:
  backend: jira            # jira | github | local   (REQUIRED)
  ticket_prefix: NAT       # jira: branch/commit prefix
  jira_project: NAT        # jira: project key for a new parent ticket
  github_repo: owner/repo  # github: defaults to the `origin` remote if omitted
  target_architecture_doc: docs/engineering/target-architecture.md
  context_docs: [CONTEXT.md]
  plan_dir: docs/plans     # local backend + plan artefacts
  spec_dir: docs/specs     # local backend story files
  scope_budget: 2          # devil's-advocate ↔ synthesis rounds
```
````

| Key | Required | Default | Meaning |
|---|---|---|---|
| `backend` | **yes** | — | `jira`, `github`, or `local` — which Phase 4 dispatch runs |
| `ticket_prefix` | jira | (none) | branch/commit prefix on handoff |
| `jira_project` | jira | `ticket_prefix` | project key when creating a new parent |
| `github_repo` | github | `origin` remote | where issues/sub-issues land |
| `target_architecture_doc` | recommended | (none) | architecture authority read in Phase 1 |
| `context_docs` | optional | `[]` | extra docs read on start |
| `plan_dir` / `spec_dir` | local | `docs/plans` / `docs/specs` | where local artefacts are written |
| `scope_budget` | optional | `2` | max Phase 3 synthesis↔challenge rounds |

**If the `discovery:` block is absent or has no `backend`: halt and guide.**
Print the block above and instruct the user to add it to `CLAUDE.md`. Do not
guess a backend — the backend determines where real work items are created.

---

## Input — detect and normalise

Run as a single step:

1. **Normalise.** Strip a leading `@` if present.
2. **Classify** the normalised argument:
   - `^[A-Z]+-[0-9]+$` → `mode = jira` (read the ticket via Atlassian MCP)
   - `owner/repo#NN`, `#NN`, or a GitHub issue URL → `mode = ghissue` (read via `gh issue view`)
   - an existing file path → `mode = file` (read it as the work source)
   - otherwise → `mode = prompt`
3. Derive a provisional `slug`; finalise once the work is understood.

Announce the resolved input mode and the config `backend` before proceeding.
(Input mode and backend are independent: a `prompt` input can target a `jira`
backend — the parent ticket is created in Phase 4.)

---

## Model Confirmation

State on a single line, then stop until it has been output:

> Running as: [model name and version] — [plan mode / normal mode]

---

## Phase 0 — Preflight, config & re-entry check

### Opus, plan mode

1. Apply skill `pipeline-preflight`. When any signal fires (dirty tree, drift,
   wrong base branch), ask via `AskUserQuestion`:

   | Option | Orchestrator action |
   | --- | --- |
   | **Reconcile first** | Resolve the signal, then re-run `pipeline-preflight`. Proceed only on `Pre-flight clean.` |
   | **Proceed anyway** | Record the override in the brief (Phase 1, "Open issues"). Continue. |
   | **Abort** | Halt with no blocked report — a user choice, not a failure. |

2. Load and validate the **Discovery Config**. If absent → halt and guide (above).
3. Confirm the repository with `git remote -v` — backend writes must land in the
   **project repo**, never the skills repo. If it does not match, halt and ask.
4. **Re-entry check.** Only applies when the input names existing work — a
   `jira` key, a `ghissue` ref, or a `local` backend with a master plan already
   on disk. A `prompt` or `file` input is new work with no tracking key: skip
   this check and go straight to Phase 1. Otherwise determine whether the work
   is already tracked:
   - `backend: jira`/`github` → `gh issue list --search "[<KEY>] Architecture in:title" --label architecture --limit 5`
   - `backend: local` → check for an existing master plan under `plan_dir`
   - `mode: jira` → also read the parent's `subtasks` array via Atlassian MCP

   **If already tracked**, ask via `AskUserQuestion`:

   | Option | Action |
   | --- | --- |
   | **Track / reconcile** | Skip Phases 1–3. Go to Phase 4 in **track mode** — apply skill `discovery-check` (jira/github) or reconcile the local master plan. Import an existing architecture doc via `discovery-init` if subtasks exist but no master issue does. |
   | **Re-plan** | Continue to Phase 1; the new plan supersedes (note the existing items in the brief). |

`/discovery` does not edit source or open a PR. Preflight is a hygiene gate.

---

## Phase 1 — Intake & Understand

### Opus, plan mode

Ends with a **brief** the panel reasons over.

1. **Read the work.** Read `CLAUDE.md` and every linked doc, the `context_docs`,
   and the `target_architecture_doc` if configured. Read the work source (the
   prompt, the Jira ticket, the GitHub issue, or the named file).
2. **Map the blast radius.** When the affected area is wider than the
   orchestrator can hold, spawn one or more `code-explorer` subagents
   (`agentType: feature-dev:code-explorer`) with narrow questions — never "read
   the whole module." Apply skill `subagent-reliability` if any returns no
   usable result.
3. **Clarify with the user.** Surface genuine unknowns via `AskUserQuestion` —
   the goal, hard constraints, what "done" must mean. Do not guess answers a
   one-line question would settle.

Write the brief to `DISCOVERY_DOC`:

- **Goal** — the outcome in one or two sentences
- **Background** — why now; what the input says
- **Constraints & invariants** — what must not change (public API, behaviour, architecture)
- **Blast radius** — files / types / call sites in scope
- **Open issues** — any preflight override or unresolved unknown

Do not propose an approach or write code in this phase.

---

## Brief Context Bundle

Build once, after the brief is written. Pass inline to every amigo and the
devil's advocate so subagents never re-read `CLAUDE.md` or `DISCOVERY_DOC`:

```
BRIEF: <full contents of DISCOVERY_DOC at end of Phase 1>
CLAUDE_MD: <full contents of ./CLAUDE.md>
ARCHITECTURE: <contents of target_architecture_doc, or "none configured">
CONSTRAINTS: <the Constraints & invariants section, verbatim>
```

---

## Phase 2 — Three Amigos

### Spawn 3 Sonnet subagents — normal mode, in parallel

These are **complementary roles**, not competing proposals — and they are
**advisory**: each RETURNS its contribution inline. No amigo writes to disk,
edits source, or creates work items — materialisation is Phase 4's job alone.
This is why the roles below describe the *shape* of output (the kind of artefact
`pm` / `spec-test-plan` produce) rather than applying those skills, whose bodies
write files. Each gets the same Brief Context Bundle plus its role charge; the
orchestrator reads all three before Phase 3.

- **PM amigo** — produces the planning view a `pm` run would, **returned inline,
  never written to disk**. Charge: *"Scope this work and return: the problem, the
  goal, explicit out-of-scope, acceptance criteria, and a build-ordered breakdown
  of PR-sized stories — the smallest version that delivers value, flagging
  anything that smells like gold-plating. Return the breakdown as text; do not
  write `docs/PRD.md`, story files, or any file."*
- **Architect amigo** — `agentType: feature-dev:code-architect`, applying the
  `architecture-doc` lens. Charge: *"Design the technical approach in terms of
  types / services / data flow / concurrency. Show how it conforms to
  ARCHITECTURE and honours every item in CONSTRAINTS. Name the touch points per
  story. Return the design; do not write files."*
- **QA amigo** — produces the device-testable acceptance bar that
  `spec-test-plan` describes, **returned inline** (the spec surface does not
  exist yet, so that skill is not applied). Charge: *"For each story define what
  proves it done as imperative, observable steps, plus the edge cases and the
  regression surface this work threatens. Return it as text; do not write
  files."*

**Retry budget: 1 attempt per amigo** to recover from a subagent-reported
failure. Crash recovery (raw API error, timeout, socket-closed) applies skill
`subagent-reliability` first, before consuming the retry slot.

---

## Phase 3 — Synthesise & challenge scope

### Opus, plan mode — with Sonnet devil's advocate

1. **Synthesise.** Merge the three contributions into ONE coherent plan — PM's
   stories, Architect's approach per story, QA's bar per story. This is a
   synthesis, **never** a pick-one-amigo. Resolve contradictions between roles
   explicitly (e.g. a story QA can't test, or an approach that exceeds PM's
   scope).
2. **Challenge.** Spawn 1–2 Sonnet **devil's-advocate** subagents in parallel,
   each prompted to attack the merged plan — defaulting to flag-when-uncertain:

   > [brief context bundle]
   > PLAN: <the synthesised plan>
   >
   > You are the scope-creep watchdog. Attack this plan: name every story,
   > component, or acceptance criterion that exceeds the minimal solution to the
   > stated Goal, is not justified by the input, gold-plates, or smuggles in
   > unrelated work. Also flag any story with no clear acceptance bar. Default to
   > flagging when uncertain. Return `{ creep: [ {item, why} ], incoherence: [ … ] }`.

   Apply skill `subagent-reliability` for any advocate that returns no usable
   result.
3. **Decide.** For each flagged item, the orchestrator either **trims** it from
   the plan or **records an explicit justification** in `DISCOVERY_DOC`. If
   trimming materially changes the plan, **loop back to step 1**.

**Cycle budget: `scope_budget` rounds (default 2).** If the plan still carries
unjustified creep after the budget → halt + blocked report.

Append to `DISCOVERY_DOC`:

- **Plan** — the synthesised stories, each with approach + acceptance bar
- **Out of scope** — PM's exclusions plus everything the advocate trimmed
- **Scope challenges** — each flagged item and its trim-or-justify verdict

---

## Phase 4 — Materialise & hand off

### Opus, plan mode

Dispatch by the config `backend`. Each path creates the parent + child work
items and establishes the tracking store, then reports the created items.

**`backend: jira`**
1. If `mode != jira` (no parent yet): create a parent ticket from the brief —
   apply skill `discovery-jira` (project = `jira_project`).
2. Create one JIRA subtask per story under the parent (`createJiraIssue` with
   the parent link), titles from the PM breakdown.
3. Apply skill `discovery-init` to create the GitHub architecture master issue +
   per-subtask sub-issues for drift tracking (pass `ARCH_DOC_PATH` if a
   `target_architecture_doc` exists, else let it synthesise from the brief).

**`backend: github`** (no JIRA)
1. Ensure labels exist (`architecture`, `arch:${slug}`) with `gh label create --force`.
2. Create a master issue (`[${slug}] Plan — <title>`, `architecture` label),
   post the synthesised plan as its first comment, and create one labelled
   sub-issue per story (`Part of #<master>`). Mirror `discovery-init`'s gh
   patterns and partial-failure handling (list created, ask Retry / Accept
   partial / Abort — never auto-rollback).
3. Edit the master body to a checklist of the sub-issues.

**`backend: local`**
1. Write the plan to `plan_dir` (a master plan with a build-ordered story
   checklist — the `pm` layout) and one story file per story to `spec_dir`
   (the `story-to-spec` shape).
2. The master plan checklist is the local tracking store.

**Track mode** (re-entry from Phase 0): skip creation. Apply skill
`discovery-check` (jira/github) to reconcile completed items and flag drift, or
reconcile the local master plan. Report what changed.

Then present via `AskUserQuestion`:

| Option | Action |
| --- | --- |
| **Hand to /workflow** | Offer to launch `/workflow` against the first tracked item. |
| **Hand to /spec-pipeline** | Offer to launch `/spec-pipeline` for the whole set. |
| **Stop here** | Leave the tracked items + `DISCOVERY_DOC` as the deliverable. |

`/discovery` never edits source or opens a PR.

---

## Halt Conditions

Halt and write a blocked report (never silently continue) if:

- The `discovery:` config block is absent or missing `backend` (halt and guide)
- The repository is the skills repo, or does not match the project (Phase 0)
- A required clarifying answer for the brief is not provided (Phase 1)
- Every amigo fails after its retry slot (Phase 2)
- The `scope_budget` is exhausted with unjustified creep still in the plan (Phase 3)
- A backend write fails unrecoverably — `createJiraIssue`, `gh issue create`,
  or local file write (Phase 4); on partial creation, surface and ask, never
  auto-rollback
- A required Jira/GitHub MCP or CLI call fails for the configured backend

On halt: write the brief, the plan state, and the failure to
`${PLANS_DIR}/discovery/${slug}-blocked.md`. If `mode = jira`, add a comment to
the ticket linking the blocked report; do not transition the ticket.

---

## Model & mode

**Opus orchestrates** in plan mode and owns all branching — the re-entry
decision, the panel synthesis, the scope-trim verdicts, the backend dispatch.
**Sonnet subagents** explore (`code-explorer`), contribute one amigo role (`pm`
/ `code-architect` / `spec-test-plan`), and attack (devil's advocate); none
makes a branching decision. State lives in the single `DISCOVERY_DOC` under
`PLANS_DIR` and is passed to subagents by the inline Brief Context Bundle, never
re-read from disk. Durable work-item state lives in the configured backend
(JIRA / GitHub issues / local plan docs), per the orchestrator-contract
state-placement convention.
