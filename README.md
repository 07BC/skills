# swift-skills

> [!IMPORTANT]
> **This is a personal project.** It reflects my workflow, my opinions, and my tooling — and it will keep changing as those evolve. It suits my purposes and will always be shaped by them first.
>
> Feedback, suggestions, issues, and PRs are welcome. But ultimately this is MY workflow, so I'll take what fits and leave what doesn't.

## Why this exists

Claude Code's skill system lets you encode domain expertise into focused `SKILL.md` files rather than burying everything in a monolithic `CLAUDE.md`. Each skill is a self-contained module that tells Claude exactly how to approach a specific class of task — what to check, what to avoid, which model to reach for, and what a good outcome looks like.

Without skills, Claude pattern-matches on its training data. That works for generic tasks, but it falls apart for domain-specific ones. The `swift-tvos` skill exists because tvOS focus engine bugs are a case where Claude confidently shuffles code around and declares the bug fixed when nothing has changed — the skill enforces the diagnostic discipline that prevents that failure mode. The `swift-engineer` skill locks in the MV (Model-View) pattern rather than defaulting to MVVM. The `swift-audit` skill knows to check Swift 6 concurrency, actor isolation, and `@unchecked Sendable` usage — not just style.

This repo is the source of truth for those skills. It installs via `make install`, which symlinks skills into `~/.claude/skills/` and agents into `~/.claude/agents/`.

## How skills work

Claude Code loads skills from `~/.claude/skills/`. Each skill is a directory containing a `SKILL.md` file with a `name:` and `description:` in its frontmatter. Claude uses the description to decide when to trigger the skill automatically, and you can invoke any skill explicitly with `/<skill-name>`.

## My Workflow

### Model and flow key

| Symbol | Meaning |
|---|---|
| **Opus** | Use Opus 4 (`/model opus`). Better for deep reasoning, architectural judgment, and multi-step synthesis. |
| **Sonnet** | Use Sonnet 4 (default). Faster for well-defined execution tasks. |
| **Plan → Execute** | Enter plan mode first (the ↗ button or `/plan`). Claude proposes an approach before touching any files — essential when the wrong move is expensive. |
| **Direct** | Just invoke it. The task is well-scoped enough to execute without a planning phase. |

---

### Swift development pipeline

The five Swift skills below form a feature-development pipeline. Pick by
**verb**, not by file type.

```
swift:architect ──► swift:engineer ──► swift:quality ──► swift:code-review ──► swift:audit
    (design)           (build)            (clean)             (review)              (audit)
```

## Spec Pipeline

> [!CAUTION]
> This is very much a work in progress and has not been successfull so far.

`/spec-pipeline` is the centrepiece of this repo — a fully agentic
pipeline that takes a Jira ticket, an existing spec, or a free-form
prompt and drives it all the way to a merged-ready PR with zero manual
wiring. Each run lives in its own git worktree and commits as it goes.

### Invoke

```bash
/spec-pipeline --from-jira NAT-1234    # fetch ticket from Jira
/spec-pipeline --from-spec docs/my-spec.md
/spec-pipeline --from-prompt "Add pull-to-refresh to the feed"
/spec-pipeline NAT-1234                # shorthand for --from-jira
```

### Prerequisites

- A `spec_pipeline` YAML block in the project's `CLAUDE.md`
  ([SCHEMA.md](./skills/engineering/spec-pipeline/SCHEMA.md) documents
  every field)
- Atlassian MCP connected (for `--from-jira` input)
- Docs to gitignore inside each worktree:
  ```
  docs/specs/
  docs/plans/
  master-plan.md
  ```

---

### Agentic flow

The pipeline is orchestrated by the `spec-pipeline-orchestrator` agent
(Sonnet), which spawns a chain of specialist agents in sequence. You are
interrupted only at defined gates.

```
SKILL: spec-pipeline
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
├─ Stage 3  ── Per-task loop (repeats until all tasks done)
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
└─ Stage 5  ── /git-pr (Sonnet)
               Push branch, run tests, code review, draft PR body,
               await your confirmation before `gh pr create`.
```

---

### Stage 0 — Scope guardian

The scope guardian runs **before any worktree is created** — making it
cheap to abort on oversized tickets. It is skipped when:

- The ticket already has a parent (it's already a sub-task)
- The ticket already has sub-tasks (the split has already happened)
- A worktree for this spec-id already exists (resume path)

**Threshold — thematic separation only.** The guardian splits only when
ACs cluster around clearly different user-visible outcomes (e.g. model +
UI + analytics bundled into one ticket, or "phase 1 / phase 2" wording).
A focused 8-AC ticket all about one screen stays whole. AC
countable-independence alone is not enough to trigger a split.

When a split is proposed:
1. The guardian writes a YAML proposal to a tmpdir file listing 2+
   sub-tasks, each with a title, summary, rationale, and ACs lifted
   **verbatim** from the parent. Every parent AC lands in exactly one
   child — no orphans, no duplicates. If a clean distribution is
   impossible, it emits `SCOPE: OK` instead.
2. The SKILL shows you the proposed split via `AskUserQuestion`.
3. On approval, the SKILL creates Jira sub-tickets, posts a comment on
   the parent, and halts. You re-invoke `/spec-pipeline` per child.
4. On cancel, nothing is written. You re-scope the parent in Jira and
   re-invoke.

---

### User gates

You are always asked at these points — the pipeline will not proceed
without explicit confirmation:

| Gate | When |
|---|---|
| **Lightweight confirmation** | Before any disk or worktree operation |
| **Scope-split confirmation** | When Stage 0 proposes Jira sub-tasks (may be zero) |
| **Conflict resolution** | Once per conflicting requirement detected in Stage 1 |
| **UI design decisions** | Once per open UI question in Stage 1 (navigation, states, etc.) |
| **PR body review** | Before `gh pr create` in Stage 5 |

---

### Durable artefacts

After a run completes (or is split):

| Artefact | Location | Notes |
|---|---|---|
| Pull request | GitHub | The shipped deliverable |
| Audit log | `$OBSIDIAN_VAULT/AI/plans/<spec-id>.md` | Full spec + plan + stage log. Written even if the worktree is removed. |
| Worktree | `../<repo>-<spec-id>/` | Preserved until you run `git worktree remove` post-merge |

Spec and plan files inside the worktree (`docs/specs/`, `docs/plans/`,
`master-plan.md`) are gitignored by design — the Obsidian audit log is
the only durable copy.

---

### Agents involved

| Agent | Model | Role |
|---|---|---|
| `spec-scope-guardian` | Opus | Stage 0 — thematic scope check for Jira tickets |
| `spec-pipeline-orchestrator` | Sonnet | Driver — coordinates all stages, manages retries, writes audit log |
| `spec-distiller` | Opus | Stage 1 — raw input → canonical spec + implementation plan |
| `planner` | Sonnet | Stage 2 — validates plan fits the codebase (read-only) |
| `engineer` | Sonnet | Stage 3 — implements one task, builds clean |
| `test-writer` | Sonnet | Stage 3 — writes Swift Testing `@Test` / `@Suite` tests per task |
| `concurrency-auditor` | Sonnet | Stage 3 — audits async/actor/Sendable correctness |
| `task-reviewer` | Sonnet | Stage 3 — verifies task against spec slice |
| `swift-spec-review` | Sonnet | Stage 4 — whole-diff review against the full spec |

---

## Install

### Prerequisites

- A [Mac](https://apple.com) - No chance I'm supporting Windows
- [Brew](https://brew.sh)
- [Claude Code](https://claude.ai/code) installed and authenticated

> [!important]
> Python that ships with xcodetools is a POS. Recommend installing Python via brew

### Steps

```bash
git clone git@github.com:07BC/skills.git
cd skills
make install
```

Skills are then available as `/<skill-name>` — e.g. `/swift-engineer`, `/swift-tvos`.
Agents are available automatically; Claude loads them by `name:` from `~/.claude/agents/`.

### Keeping up to date

```bash
git pull
make install
```

## Skills

Model and flow key from the broader skill library:

| Symbol | Meaning |
|---|---|
| **Opus** | Deep reasoning, architectural judgment, multi-step synthesis |
| **Sonnet** | Faster execution for well-defined tasks (default) |
| **Plan → Execute** | Enter plan mode first; Claude proposes an approach before touching files |
| **Direct** | Invoke and go — the task is well-scoped |

### Git workflow

| Skill | What it does | Model · Flow |
|---|---|---|
| [/git-commit](./skills/git/git-commit/SKILL.md) | Stages specific files and commits with a short imperative message. Extracts a ticket prefix from the branch name if present. | Sonnet · Direct |
| [/git-push](./skills/git/git-push/SKILL.md) | Runs the project formatter, commits, then pushes. Builds on git-commit. | Sonnet · Direct |
| [/git-pr](./skills/git/git-pr/SKILL.md) | Commits, pushes, runs tests and code review, then creates a PR with a summary and end-user test plan. Builds on git-push. | Sonnet · Direct |

### End-to-end pipelines

| Skill | What it does | Model · Flow |
|---|---|---|
| [/spec-pipeline](./skills/engineering/spec-pipeline/SKILL.md) | Jira ticket / spec / prompt → PR, fully agentic. Stage 0 checks ticket scope (Jira only) and splits oversized tickets into Jira sub-tasks before any work starts. Then: distil spec → validate plan → per-task `engineer → test-writer → concurrency-auditor → task-reviewer` loop → whole-diff review → PR. Each run gets its own git worktree. Durable audit log in Obsidian. See the [Spec Pipeline](#spec-pipeline) section for the full flow. | Opus (scope + distil) · Sonnet (rest) · Direct |

### Building

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-architect](./skills/engineering/swift-architect/SKILL.md) | Scaffolds a new MV app skeleton, or audits an existing app for MVVM drift. | Opus · Plan → Execute |
| [/swift-engineer](./skills/engineering/swift-engineer/SKILL.md) | Main building skill — writes new Swift 6.2 features, SwiftUI views, services, async work within the MV pattern. | Sonnet · Direct |
| [/swift-quality](./skills/testing/swift-quality/SKILL.md) | Rewrites code to meet the Swift Style Guide and project architecture rules without changing behaviour. | Sonnet · Direct |
| [/swift-style](./skills/engineering/swift-style/SKILL.md) | Code style, quality rules, and Swift 6 essentials for writing clean Swift/SwiftUI from the first line. Loaded by swift-engineer. | Sonnet · Direct |
| [/swiftui-liquid-glass](./skills/engineering/swiftui-liquid-glass/SKILL.md) | Implement, review, or improve SwiftUI features using the iOS 26+ Liquid Glass API. | Sonnet · Direct |
| [/swift-tvos](./skills/engineering/swift-tvos/SKILL.md) | Diagnoses tvOS navigation and focus engine bugs in SwiftUI codebases. Always use this — do not attempt tvOS focus diagnosis ad hoc. | Sonnet · Direct |

### Documenting

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-document](./skills/engineering/swift-document/SKILL.md) | Adds or updates Apple DocC-style `///` documentation comments on Swift symbols. | Sonnet · Direct |
| [/swiftopher-columbus](./skills/engineering/swiftopher-columbus/SKILL.md) | Produces a thorough, living architecture document for an iOS/macOS Swift codebase. | Opus · Plan → Execute |

### Testing

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-testing](./skills/engineering/swift-testing/SKILL.md) | Generates unit tests using Apple's Swift Testing framework (`@Test`, `@Suite`, `#expect`). Not for UI tests. | Sonnet · Direct |
| [/swift-uitest](./skills/testing/swift-uitest/SKILL.md) | Creates XCUITest UI tests for iOS apps. Not for unit tests — runs out-of-process via XCTest. | Sonnet · Direct |
| [/swift-test-all](./skills/testing/swift-test-all/SKILL.md) | Runs the test suite once and reports results. Detects workspace, scheme, and simulator from `CLAUDE.md`. | Sonnet · Direct |

### Reviewing & auditing

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-code-review](./skills/engineering/swift-code-review/SKILL.md) | Performs a Swift code review in-session — BLOCKER / WARNING / SUGGESTION findings with inline fixes. Run before commit/PR. | Opus · Direct |
| [/swift-audit](./skills/engineering/swift-audit/SKILL.md) | Exhaustive audit of a Swift/SwiftUI codebase — Swift 6 concurrency, separation of concerns, state management, test quality. Outputs `AUDIT.md` with linked per-section files. | Opus · Plan → Execute |

### Concurrency

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-concurrency](./skills/engineering/swift-concurrency/SKILL.md) | Conceptual guidance — async/await, actors, Sendable, Swift 6 migration. Use to learn or explain. | Sonnet · Direct |
| [/swift-concurrency-expert](./skills/engineering/swift-concurrency-expert/SKILL.md) | Action-oriented — fix concrete concurrency errors, data races, isolation warnings, and Sendable gaps in existing code. | Sonnet · Direct |

### Tooling & CI

| Skill | What it does | Model · Flow |
|---|---|---|
| [/swift-cidi](./skills/engineering/swift-cidi/SKILL.md) | Debug GitHub Actions CI for Kick iOS/tvOS projects — flaky tests, xcresult artefacts, xctestplan setup. | Sonnet · Direct (Opus for complex failures) |
| [/swift-lint](./skills/engineering/swift-lint/SKILL.md) | Finds the nearest `.swiftlint.yml` and runs SwiftLint from the right directory. | Sonnet · Direct |
| [/xcodebuildmcp-cli](./skills/engineering/xcodebuildmcp-cli/SKILL.md) | Use the XcodeBuildMCP CLI for iOS/macOS/watchOS/tvOS/visionOS work — build, test, run, debug, log, UI automation. | Sonnet · Direct |

### Obsidian

| Skill | What it does | Model · Flow |
|---|---|---|
| [/obsidian-audit](./skills/obsidian/obsidian-audit/SKILL.md) | Vault hygiene sweep — fixes tags, normalises frontmatter, lifts inline fields into YAML properties. | Sonnet · Direct |
| [/obsidian-learn](./skills/obsidian/obsidian-learn/SKILL.md) | Extracts durable knowledge from the current session and writes it to the Obsidian knowledge base. Run at end of session. | Sonnet · Direct |
| [/obsidian-manage](./skills/obsidian/obsidian-manage/SKILL.md) | Read, create, edit, search, and organise notes in the Obsidian vault at `~/raw`. | Sonnet · Direct |
| [/obsidian-rollover](./skills/obsidian/obsidian-rollover/SKILL.md) | Carries incomplete to-do items from recent past daily notes into today's daily note. | Sonnet · Direct |

### Productivity

| Skill | What it does | Model · Flow |
|---|---|---|
| [/plan-to-jira](./skills/productivity/plan-to-jira/SKILL.md) | Converts a plan or spec into a structured Jira ticket. Infers project, labels, and components from context, then asks via `AskUserQuestion` before creating. | Sonnet · Direct |
| [/jira-bulk](./skills/productivity/jira-bulk/SKILL.md) | Bulk Jira operations — set fix version, transition status — across multiple tickets in one invocation. | Sonnet · Direct |
| [/yt-research](./skills/productivity/yt-research/SKILL.md) | Fetches transcripts and extracts prompts from a YouTube channel's recent videos, saving each as markdown. | Sonnet · Direct |
| [/yt-distill](./skills/productivity/yt-distill/SKILL.md) | Distils a folder of YouTube transcript markdown files (output of yt-research) into a structured Obsidian reference library — skills, plugins, prompts, and techniques categories plus a master index. | Sonnet · Direct |

## Layout

```
Makefile                        — install, link, agents, hook, unlink, unagent targets
scripts/link-skills.sh          — symlinks skills into ~/.claude/skills/
agents/                         — Claude Code agents (symlinked into ~/.claude/agents/)
skills/engineering/             — Swift / iOS / Xcode / CI skills
skills/git/                     — generic git workflow skills
skills/obsidian/                — Obsidian vault management skills
skills/productivity/            — cross-project productivity skills (Jira, planning, YouTube research, etc.)
skills/in-progress/             — drafts; not auto-discovered
skills/deprecated/              — retired skills; skipped by link-skills.sh
```

## Adding a skill

1. Create `skills/<bucket>/<name>/SKILL.md` with `name:` and `description:` frontmatter.
2. Add a row to the table above using the `/<name>` format.
3. Run `make link` to expose it locally, or `make unlink` to remove the symlinks.

See [`CLAUDE.md`](./CLAUDE.md) for the full bucket convention and the `in-progress` / `deprecated` lifecycle.
