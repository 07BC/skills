# The delivery lifecycle

This is the **manual path** — each stage names the skill to reach for and why. The orchestrators (see [Commands](#commands)) automate stages 3–7. For the higher-level mental model (the three altitudes) and project setup, start at the [README](../README.md). For every skill in one place, see [skill-catalogue.md](./skill-catalogue.md).

---

## Stage by stage

### 1. Shape the work — idea/ticket → document

Pin down *what* you're building before any code. These skills each produce a **different document** — the table below is the fast way to pick one:

| I have… | I want… | Skill |
|---|---|---|
| A vague idea | to think it through, no artefact yet | `/grill-me` |
| A plan to pressure-test | the same, **+ `CONTEXT.md`/ADRs updated** as decisions settle | `/grill-with-docs` |
| A ticket / raw idea / rough approach | a **PRD + build-ordered, PR-sized story files** (decompose) | `/product-planning` |
| One story / ticket / prompt | **one structured spec doc** | `/story-to-spec` |
| A whole codebase | a living **architecture document** | `/architecture-doc` |
| One subtask, about to code | a scoped **engineer brief** | `/implementation-brief` |
| A finished plan/spec | a **Jira ticket** | `/discovery-jira` |
| A spec exists (`docs/specs/*.md`) | a device **QA test plan** | `/spec-test-plan` |
| Any doc, before senior review | it **reframed to review standard** | `/mr-j` |

The boundaries that matter most, because they used to blur: **`/product-planning` decomposes** an idea into many stories; **`/story-to-spec` distils** one ticket into one spec; **`/grill-me` interrogates** a plan you already have. `/mr-j` frames a spec, ticket, or PR description so it survives senior review — every claim explains why the work exists, the root cause, rejected alternatives, the simplest version, and how failure recovers. `/jira-bulk` does fix-version and status changes across many tickets at once.

### 2. Establish the architecture — once per project, or before a big feature

`/swift-mv-architecture` scaffolds a new MV app skeleton or audits for drift; `/swift-mvvm-architecture` does the same for modern `@Observable` MVVM. Declare which architecture the project uses in its `CLAUDE.md` (`architecture: MV` or `architecture: MVVM`) — all engineering skills pick it up automatically. `/architecture-doc` reads the whole codebase and produces a living architecture document — the authority every downstream skill reads. Get this right and discovery + engineering have a source of truth to follow.

### 3. Scope the subtask — before touching code

`/implementation-brief` produces a scoped brief for one subtask: which types to touch, which to create, edge cases, patterns to follow, and — crucially — what **not** to touch. It is the engineer's primary input. For multi-subtask stories, `/discovery` (and its `discovery-init` / `discovery-check` / `discovery-audit` skills) maintain a branch-independent architecture-drift store in GitHub issues so the architecture stays coherent across the whole story.

### 4. Build & clean

`/swift-engineering` is **the single entry point for all Swift writing and editing** — think of it as the **Engineer**. Writing any Swift 6 + SwiftUI is one job: new code, SwiftUI views, services, async work, behaviour-preserving rewrites and clean-ups, `@Observable` migrations from `ObservableObject`/`@Published`, and fixing concrete Swift 6 concurrency errors. There is no separate "clean" or "refactor" skill — those all route here.

> **You don't pick a sub-skill when writing Swift.** `/swift-engineering` auto-applies `/swift-style` (style and Swift 6 rules) and pulls in `/swift-concurrency` (async / actor / Sendable work) and `/swiftui-liquid-glass` (iOS 26+ Liquid Glass UI) automatically as the task needs them. Those three are **parts of the Engineer**, not separate skills you invoke — they appear as their own catalogue rows only because each is independently useful as a reference (e.g. asking `/swift-concurrency` to *explain* actor isolation without writing code).

`/swift-tvos` diagnoses Apple TV focus-engine and navigation bugs — always use it rather than guessing.

### 5. Test

`/swift-testing` writes unit tests with Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). `/swift-uitest` writes XCUITest UI tests; `/swift-uitest-debug` fixes failing ones via a Sonnet-then-Opus escalation. `/swift-test-all` runs the suite and reports. `/regression-check` audits in-progress changes for blast radius and behavioural ripples before you commit.

### 6. Review

`/swift-code-review` reviews existing code without changing it — BLOCKER / WARNING / SUGGESTION findings with inline fixes. Standard mode for any commit or PR; deep/adversarial mode for high-stakes branches (new SDK, infrastructure, lifecycle changes). `/audit` audits a whole codebase when you need the big picture across all layers.

### 7. Ship

`/swift-pr-gate` runs the mechanical pre-PR gate — build clean, tests pass, scope tight, branch named correctly, PR description complete. Then the git ladder: `/git-commit` → `/git-push` → `/git-pr` (which runs review and opens the PR with a summary and test plan). `/build-status` tells you whether the in-flight build or CI run finished and passed; `/swift-cidi` debugs CI failures; `/swift-lint` runs SwiftLint from the right directory.

### 8. Close the loop

`/swift-document` adds DocC `///` comments **only when you ask** (the default is no `///`). `/daily-notes` writes up what you did from git history and Jira; `/obsidian-learn` captures durable session learnings into the knowledge base.

---

## Commands

Commands are markdown files under `commands/<bucket>/<name>.md` that Claude Code exposes as slash commands from `~/.claude/commands/`. They are **orchestrators**: an Opus orchestrator owns every branching decision, Sonnet subagents execute the phases, and no subagent branches. Each phase has a retry budget and explicit halt conditions, and large state is passed to subagents by path rather than re-read.

### Mr Will

| Command | What it does | Model · Flow |
|---|---|---|
| `/solve` | Diagnostic + solution-design panel — a bug / architecture problem → understand → fan out competing fixes → converge on one approved approach, ready to feed `/workflow`. Stops at the plan; never writes code. | Opus+Sonnet · Plan → Execute |
| `/workflow` | One subtask → PR — Jira / spec / prompt → discovery → engineer → test → quality → review → PR, with GitHub architecture-drift tracking across the story. | Opus+Sonnet · Plan → Execute |
| `/spec-pipeline` | (skill) Whole ticket → PR, autonomously, in a disposable worktree. Splits tickets too large for one run first. | Opus+Sonnet · Orchestrated |
| `/audit` | Structured codebase audit — per-layer Sonnet subagents apply `swift-code-review`, findings consolidated and prioritised into remediation batches ready to feed `/workflow`. | Opus+Sonnet · Plan → Execute |
| `/uitest` | End-to-end XCUITest pipeline — AC intake → plan → execute → debug → PR artefacts. | Opus+Sonnet · Plan → Execute |
| `/discovery` | Planning front door — Jira / GitHub issue / prompt / file → a Three-Amigos panel (PM + Architect + QA) plans the work, a devil's advocate trims scope creep, then it materialises tracked work items into the project's configured backend (`jira` / `github` / `local`) and hands off to `/workflow` or `/spec-pipeline`. Backend declared in a `discovery:` YAML block in the project `CLAUDE.md`. | Opus+Sonnet · Plan → Execute |

---

## Choosing an orchestrator

Both `/workflow` and `/spec-pipeline` take a Jira ticket, spec, or prompt to a PR, but they are deliberately distinct tools (see [ADR 0003](./adr/0003-workflow-and-spec-pipeline-are-distinct-aligned-tools.md)):

- **`/workflow`** — drives **one subtask** in-place on a branch, wired into GitHub architecture-drift tracking (`/discovery-init` · `/discovery-check` · `/discovery-audit`) and the JIRA subtask lifecycle. Reach for it when implementing a single scoped subtask and you want architecture tracking across the story.
- **`/spec-pipeline`** — ships a **whole spec** of many tasks autonomously in a disposable worktree (an unattended run, ~60–90 min in practice). Reach for it when you want an entire ticket built end-to-end, hands-off.

`/audit` finds the work and emits batches that `/workflow` then implements one at a time. `/solve` sits one step earlier: when you have a single bug or architecture problem but *not yet a fix*, it diagnoses and designs the approach, then hands the approved plan to `/workflow`. `/uitest` is the UI-test specialisation of the same orchestrator shape.

`/discovery` is the **planning front door for a feature** (vs `/solve`, the front door for a *bug*): a ticket / issue / prompt / doc → a Three-Amigos panel (PM + Architect + QA) plans it, a devil's advocate trims scope creep, and the result is materialised as tracked work items in the backend declared by the project's `discovery:` config (`jira` subtasks / `github` sub-issues / `local` docs), then handed to `/workflow` or `/spec-pipeline`. It absorbs the former standalone architecture-tracking entry point — re-running on already-tracked work enters track/reconcile mode (via `discovery-init` · `discovery-check` · `discovery-audit`) instead of re-planning.

---

## When a run fails

The orchestrators are built to **halt and report, not to push through a broken state** — so recovery is always possible.

- **A phase fails** (build broken, tests red, review blocked): the orchestrator retries within that phase's budget, then halts. It does not continue to the next phase on a failure.
- **On halt**: it writes a blocked report to `PLANS_DIR` naming the failing phase and reason. For `/spec-pipeline`, the disposable worktree is **preserved** (never auto-removed) so you can inspect it; resume by re-invoking the same command, which picks up where it left off.
- **A subagent crashes** (no usable result, socket dropped): handled by `subagent-reliability` — recover-in-place, resume, or re-spawn — without burning the phase's retry budget.
- **Install / symlink trouble**: `make install` is idempotent — re-run it. If `~/.claude/skills` was created as a real directory rather than a symlink farm, `make link` reports it; remove the offending entry and re-run.

If a long unattended run appears to stop mid-flight with no message (context growth at a turn boundary), type `continue` — it resumes from the last completed phase.
