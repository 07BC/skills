# Workflow Recommendations

> **Status: applied.** All BLOCKER, IMPROVEMENT, and POLISH items below
> were fixed in a follow-up pass. The affected files are
> `commands/Mr Will/workflow.md` (full rewrite) plus the nine skill files
> (`pipeline-preflight`, `swift-architect`, `swift-engineer`,
> `swift-quality`, `swift-concurrency`, `swift-testing`,
> `swift-code-review`, `swift-pr-gate`, `subagent-reliability`) and
> `swift-discovery` (updated to align with Phase 3's actual usage).
> See `git diff` for the exact changes. One correction worth noting:
> BLOCKER 2 below misattributed the doc-comment contradiction — the real
> contradiction was between `swift-engineer` and `swift-code-review`, not
> between workflow.md and `swift-engineer`. `swift-code-review` was the
> file fixed.

Review of `commands/Mr Will/workflow.md` and the nine skills it depends on
(`pipeline-preflight`, `swift-architect`, `swift-engineer`, `swift-quality`,
`swift-concurrency`, `swift-testing`, `swift-code-review`, `swift-pr-gate`,
`subagent-reliability`).

Findings are prioritised:

- **BLOCKER** — the workflow does the wrong thing today; ship a fix before
  next run.
- **IMPROVEMENT** — measurable speed, accuracy, or robustness win.
- **POLISH** — coherence / readability; safe to defer.

Every entry follows: **Where → Problem → Fix → Why it matters.**

---

## 1. Correctness bugs

### [BLOCKER] Engineer subagent reads the wrong skill

- **Where:** `workflow.md` Phase 4, subagent prompt item 1.
- **Problem:** The prompt tells the engineer to read
  `~/.claude/skills/swift-quality/SKILL.md`. `swift-quality` is the
  **post-hoc rewriter** for existing code — its rules assume a file already
  exists and that public API must be preserved. The skill that documents
  *how to write new Swift code in this codebase* is `swift-engineer`, which
  the prompt never references.
- **Fix:** Replace item 1 with `~/.claude/skills/swift-engineer/SKILL.md`.
  Keep `swift-quality` for Phase 6.5 only.
- **Why it matters:** The engineer is reading rewrite rules while writing
  greenfield code. Every divergence between the two skills produces an
  incorrect first draft that Phase 6.5 then has to repair. Reading the
  correct skill cuts a full rewrite pass.

### [BLOCKER] Doc-comment rule contradicts `swift-engineer` (corrected)

- **Where:** `swift-code-review` "Documentation" checklist — NOT
  `workflow.md` as originally claimed.
- **Problem (corrected):** `swift-engineer` Core Principle #1 explicitly
  forbids `///` doc comments. `workflow.md` Phase 4 prompt agrees and
  also forbids them. The actual contradiction was `swift-code-review`,
  which required `///` docs on every public method — directly opposing
  `swift-engineer`.
- **Fix applied:** `swift-code-review`'s "Documentation" section replaced
  with "Comments and documentation" that mirrors `swift-engineer`'s
  no-`///` rule.
- **Why it matters:** Sonnet running the engineer phase would strip
  `///` per `swift-engineer`, then the review phase would flag the
  absence as a failure per `swift-code-review`. Infinite loop, until
  one or the other was edited by hand each time.

### [BLOCKER] `[TestTargetName]` is undefined

- **Where:** `workflow.md` Phase 6, test execution command.
- **Problem:** The Phase 6 command is
  `xcodebuild test -only-testing:[TestTargetName]`. Phase 1 only derives
  `SCHEME` and `DESTINATION` from `CLAUDE.md`. No phase derives, asks for,
  or documents how to obtain `TestTargetName`. Pipeline halts on first run
  in any new project.
- **Fix:** In Phase 1, also extract a `TEST_TARGET` from CLAUDE.md's
  `xcodebuild test` commands (or ask if absent). Reference `TEST_TARGET`
  in Phase 6 instead of the bare placeholder.
- **Why it matters:** Without this, every fresh project fails Phase 6 on
  the first attempt and burns retries on a config error, not a real
  failure.

### [BLOCKER] Phase 6.5 verifies build only, not tests

- **Where:** `workflow.md` Phase 6.5 verification step.
- **Problem:** The quality pass re-runs `xcodebuild build`. But
  `swift-quality` extracts helpers, names constants, and reorders MARK
  sections — refactors that *can* alter behaviour (e.g. a captured value
  that becomes a parameter, an extracted helper with subtly different
  semantics). Tests must be re-run after the quality pass; today they are
  not.
- **Fix:** After build passes in Phase 6.5, re-run the same `xcodebuild
  test` command as Phase 6. If failure, route to Phase 6's fix loop
  (consuming Phase 6's budget, not 6.5's).
- **Why it matters:** Silent behaviour regressions introduced by a "style
  pass" reach the reviewer (Phase 7) or the PR.

### [BLOCKER] Phase 4 has no retry loop in its body

- **Where:** `workflow.md` Phase 4 (body) vs Retry Budget Summary table.
- **Problem:** The summary table says Phase 4 build has 2 retries; the
  Phase 4 body never mentions what happens when build fails. Sonnet has
  to infer the loop from the table.
- **Fix:** Add an explicit *"If build fails: capture output, spawn fix
  subagent (max 2 attempts). If still failing → halt + blocked report"*
  block at the end of Phase 4, mirroring Phase 6's structure.
- **Why it matters:** Right now Phase 4 either silently succeeds or
  silently halts — the retry semantics live in a table the engineer
  doesn't read.

### [BLOCKER] Phase 0 resolution paths are undefined

- **Where:** `workflow.md` Phase 0 — Preflight.
- **Problem:** "Ask the user how to proceed via `AskUserQuestion`" — but
  the workflow never lists the answer options or what each one does.
  `pipeline-preflight` returns signals in three resolution buckets
  (Reconcile / Proceed anyway / Abort) and the orchestrator owns the
  branching; the workflow doesn't document the branches.
- **Fix:** Add an explicit mini-table to Phase 0:
  - *Reconcile* → orchestrator reconciles drift (update progress doc /
    fix base / stash dirty tree) then re-runs preflight.
  - *Proceed anyway* → orchestrator records the override in the
    discovery note's "Risks" section and continues.
  - *Abort* → halt with no blocked report (this is a user choice, not a
    failure).
- **Why it matters:** Today the orchestrator decides ad-hoc. Different
  runs treat the same signal differently.

### [BLOCKER] PR body is the raw discovery note

- **Where:** `workflow.md` Phase 8, `gh pr create` command:
  `--body "$(cat …/[SUBTASK-KEY]-discovery.md)"`.
- **Problem:** Discovery notes are engineer-facing — they list every type
  touched, every pattern constraint, every edge case. PR bodies need a
  *summary* (problem → solution → files → testing). `swift-pr-gate` even
  documents the correct PR template and explicitly says "never verbatim
  from discovery note".
- **Fix:** Use `swift-pr-gate`'s PR template. Spawn a Sonnet subagent
  with `(discovery.md, git diff)` → produces the PR body. The
  orchestrator passes it via `--body-file`.
- **Why it matters:** Reviewers currently get a 600-line internal brief;
  comprehension drops, drive-by reviewers stop reviewing, and merge
  velocity falls.

### [BLOCKER] Phase 8 conditionally reads `swift-pr-gate`

- **Where:** `workflow.md` Phase 8, item 1: *"if it exists, otherwise
  perform the checks below manually."*
- **Problem:** `swift-pr-gate` is in the available-skills list and is the
  canonical PR gate. The conditional implies it might be absent, which
  forks the workflow into a second, less-strict path.
- **Fix:** Remove the conditional. Phase 8 always runs the
  `swift-pr-gate` skill. The "manual checks" fallback is the gate's
  job to express.
- **Why it matters:** Branching on skill presence means two code paths
  are maintained and the manual one drifts.

---

## 2. Missing semantics

### [IMPROVEMENT] No escalation path from engineer back to architect

- **Where:** `workflow.md` Phase 4.
- **Problem:** If the engineer finds the discovery note is wrong (a
  service doesn't exist where the architect said it would, a constraint
  is impossible), the engineer has no documented escape. Today they
  either implement around it (scope creep) or fail (burning retries).
- **Fix:** Add a "Bounce-back" rule: *"If the discovery note is
  inconsistent with the codebase, the engineer halts and emits a
  one-line `BOUNCE: [reason]` report. Orchestrator returns to Phase 3
  with the bounce reason; the architect rewrites the note."* Cap at one
  bounce per subtask.
- **Why it matters:** Catches discovery-note errors at minute 5 instead
  of minute 50.

### [IMPROVEMENT] Retry budgets restated only in summary table

- **Where:** `workflow.md` Retry Budget Summary (bottom).
- **Problem:** Each phase has its own implicit budget but the body
  rarely names it. The table is correct but easy to miss.
- **Fix:** Each phase that has a retry loop should restate its budget
  in one sentence at the top of the phase, e.g. *"Retry budget: 3
  attempts. On exhaustion → blocked report."*
- **Why it matters:** Phase bodies become self-contained; readers don't
  scroll to the bottom of the file.

### [IMPROVEMENT] No validation of discovery note quality

- **Where:** `workflow.md` Phase 3 → Phase 4 handoff.
- **Problem:** The whole pipeline trusts the discovery note. There is no
  shape-check between Phase 3 (write) and Phase 4 (read).
- **Fix:** Phase 3 writes a `discovery.md` that must include these
  sections (templated): *Types in scope, Types out of scope, Edge cases,
  Concurrency boundaries, Definition of done.* Orchestrator greps for
  each header before spawning Phase 4. If any is missing → bounce to
  Phase 3.
- **Why it matters:** Phase 4 + 5 + 7 all reference these sections by
  name. Today none of them are enforced.

### [IMPROVEMENT] Definition of done is never verified

- **Where:** `workflow.md` Phase 2 mentions a "clear, testable definition
  of done" per subtask. No later phase verifies it.
- **Fix:** Phase 7 (review) takes the definition of done from the
  discovery note and confirms each criterion is observable in the diff
  or in a passing test.
- **Why it matters:** "Done" is the only thing that matters and nobody
  checks it.

### [IMPROVEMENT] Phase 2 Jira subtasks have no out-of-scope marker

- **Where:** `workflow.md` Phase 2 decomposition.
- **Problem:** Jira subtasks created here become the basis of Phase 3
  discovery. There's no convention for "these subtasks are explicit
  non-goals" — the AC could imply "do not touch the legacy module" and
  it would be lost.
- **Fix:** Phase 2 also writes a one-line *Non-goals* list to the parent
  ticket as a comment; Phase 3 reads it.
- **Why it matters:** Stops scope creep at the planning layer.

---

## 3. Skill / workflow drift

### [IMPROVEMENT] `swift-concurrency` is read-only, used as build-time reading

- **Where:** `workflow.md` Phase 4 prompt item 4.
- **Problem:** `swift-concurrency` declares itself a *conceptual,
  read-only reference*. For hands-on concurrency fixes it defers to
  `swift-concurrency-expert`. Phase 4 reads it as if it were prescriptive.
- **Fix:** Keep `swift-concurrency` as background reading for the
  engineer's mental model. Add a separate trigger: *"If the engineer
  encounters a Swift 6 isolation error, spawn `swift-concurrency-expert`
  on the affected file rather than guessing."*
- **Why it matters:** Concurrency errors today get heuristic patches
  (slap `@MainActor`, slap `@unchecked Sendable`). The expert skill
  exists for a reason.

### [IMPROVEMENT] `swift-architect` has no "discovery for a subtask" mode

- **Where:** `workflow.md` Phase 3 references `swift-architect`, but the
  skill itself only documents two modes: *setup* (scaffold) and *audit*
  (drift report). The workflow uses it as a per-subtask discovery
  generator.
- **Fix:** Either (a) add a third "discovery" mode to `swift-architect`
  (more disciplined), or (b) extract the discovery-writing rules into a
  new `swift-discovery` skill (cleaner separation). Reference whichever
  one from Phase 3.
- **Why it matters:** Right now Phase 3 invents the format. A new
  contributor reading `swift-architect` won't find anything that
  describes the discovery note shape.

### [POLISH] Phase 4 inline rules duplicate `swift-engineer`

- **Where:** `workflow.md` Phase 4 prompt — *"Architecture: SwiftUI MV /
  Concurrency: Swift 6 / Services: @MainActor @Observable / Storage:
  SwiftData / DI: @Environment / Style: 2-space …"*
- **Problem:** Every one of these bullets is already in `swift-engineer`.
  Duplication = drift risk.
- **Fix:** Replace the bullet list with one line: *"Apply all
  `swift-engineer` rules verbatim — do not paraphrase."*
- **Why it matters:** When `swift-engineer` changes, the workflow must
  change too. The two will silently diverge.

---

## 4. Efficiency wins

### [IMPROVEMENT] Use MCP `xcode` and `ios-simulator` tools over Bash

- **Where:** Every `xcodebuild build` / `xcodebuild test` call in
  Phases 4, 5, 6, 6.5, 8.
- **Problem:** Raw `xcodebuild` via Bash is slow (cold-start, full log
  parse, no incremental cache) and produces 10× the noise that the
  orchestrator has to read. The available MCP toolset includes
  `mcp__xcode__BuildProject`, `mcp__xcode__RunSomeTests`,
  `mcp__xcode__RunAllTests`, `mcp__xcode__GetBuildLog`, and
  `mcp__xcode__XcodeListNavigatorIssues`.
- **Fix:** Replace `xcodebuild build` with `mcp__xcode__BuildProject` and
  `xcodebuild test -only-testing:…` with `mcp__xcode__RunSomeTests`.
  Use `XcodeListNavigatorIssues` for the SourceKit reconciliation step
  in Phase 4.
- **Why it matters:** MCP calls return structured diagnostics and avoid
  reading the entire xcodebuild log into the orchestrator's context.
  Expect ~30–60 % wall-clock saving on the build/test phases and a
  large context win.

### [IMPROVEMENT] Cache `CLAUDE.md` + discovery note across subagents

- **Where:** Phases 4, 5, 6.5 — each spawns a fresh Sonnet subagent and
  the first task is *"Read CLAUDE.md and discovery note."*
- **Problem:** The same two files are re-read three times. With Sonnet
  context window and per-spawn prompt-cache cost, this is wasteful.
- **Fix:** The orchestrator builds a single *Subagent Context Bundle*
  string (CLAUDE.md excerpt + discovery note + file list) once per
  subtask, and passes it inline in every subagent prompt. Subagents
  don't re-read; they trust the bundle.
- **Why it matters:** Removes 3× redundant Read tool calls and 3×
  prompt-cache misses per subtask.

### [IMPROVEMENT] Spawn Phase 7 review as a subagent

- **Where:** `workflow.md` Phase 7 — Code Review (Opus, plan mode).
- **Problem:** Opus reads "all files changed in Phases 4, 5, and 6.5"
  into the orchestrator's context. For a 12-file subtask, this is a
  meaningful context burn that the orchestrator carries through Phase 8.
- **Fix:** Spawn a Sonnet subagent with the `swift-code-review` skill;
  it returns a structured findings list (BLOCKER / WARNING / SUGGESTION).
  Opus only reads the findings, not the files.
- **Why it matters:** Keeps the orchestrator lean for Phase 8 and any
  retries. Sonnet 4.6 with `swift-code-review` is competent at a
  structured checklist.

### [IMPROVEMENT] Run Phase 5 (test authoring) partially in parallel with Phase 4

- **Where:** `workflow.md` Phases 4 → 5 (strictly serial today).
- **Problem:** The test author needs the *public surface* of the
  engineer's work, not the internals. If the discovery note pins the
  public interface (Phase 3 already documents "types in scope"), the
  test subagent can author skeleton tests against that interface in
  parallel with the engineer writing the body.
- **Fix:** When the discovery note includes a clearly-defined public
  interface, spawn Phase 4 and Phase 5 in parallel. Reconcile any
  signature drift in Phase 6 fix loop. When the interface isn't
  pinnable (research / spike work), stay serial.
- **Why it matters:** ~25 % wall-clock saving on subtasks with a stable
  public interface. Cost: a few extra fix-loop iterations when the
  engineer's signature differs from the discovery note's.

### [POLISH] Stop re-reading skills inside subagent prompts

- **Where:** Phase 4, 5, 6.5 prompts all start with *"Read the
  following before…"* and list one or more skill paths.
- **Problem:** Sonnet subagents already have the skill index. They can
  invoke skills directly via the `Skill` tool when needed. Listing skill
  paths and asking the subagent to `Read` them is the slow path.
- **Fix:** Change *"Read `[SKILL: …/swift-engineer/SKILL.md]`"* to
  *"Apply `swift-engineer`"* and let the subagent decide whether it
  needs the skill loaded.
- **Why it matters:** Saves an extra Read for skills the subagent
  already has in its training (most of them).

---

## 5. Robustness gaps

### [IMPROVEMENT] No branch-creation step

- **Where:** `workflow.md` "Input required" lists a target branch name,
  but no phase creates it. Phase 8 just `gh pr create --head [branch]`
  and assumes it exists.
- **Fix:** Phase 0.5 (or end of Phase 1) creates the branch from `main`
  if absent. If it exists with unrelated commits → halt.
- **Why it matters:** Today the user is expected to have created the
  branch externally; if they didn't, Phase 8 fails after the entire
  pipeline ran.

### [IMPROVEMENT] No SPM-only project path

- **Where:** `workflow.md` Phase 1 derives Xcode `SCHEME` /
  `DESTINATION`.
- **Problem:** SPM-only libraries don't have a scheme. `swift build` /
  `swift test` are the correct calls.
- **Fix:** Phase 1 detects project type (`.xcodeproj` /
  `.xcworkspace` / `Package.swift`) and selects build/test commands
  accordingly. Document both in CLAUDE.md.
- **Why it matters:** Workflow currently only runs in app projects.
  Tooling / library work is unreachable.

### [IMPROVEMENT] No post-PR comment loop

- **Where:** Workflow ends at Phase 8.
- **Problem:** Reviewers leave comments. Today there's no Phase 9 for
  triaging and addressing them.
- **Fix:** Reference the existing `pr-comment-review` skill at the end
  of Phase 8: *"To address reviewer comments, run `pr-comment-review`."*
- **Why it matters:** The skill already exists; the workflow doesn't
  hand off to it.

### [IMPROVEMENT] No simulator / UI verification for UI-affecting subtasks

- **Where:** Workflow has no manual-verification phase.
- **Problem:** Build + unit tests miss visual regressions, navigation
  bugs, focus engine errors on tvOS, layout breakage. The `verify`
  skill, `swift-uitest`, and `swift-uitest-debug` skills exist
  precisely for this.
- **Fix:** Optional Phase 7.5: if any modified file is a SwiftUI View,
  spawn `verify` (or `swift-uitest` for tvOS) to run the app and
  screenshot the changed screens.
- **Why it matters:** Production bugs in UI code routinely make it
  through this pipeline.

### [POLISH] Hardcoded path repeated five times

- **Where:** `workflow.md` Phases 3, 4, 5, 6, 6.5, 7, 8 all reference
  `${HOME}/Developer/obsidian/${project_name}/plans/…`.
- **Fix:** Define `PLANS_DIR` once in Phase 1 and reference it
  thereafter.
- **Why it matters:** When the global plan-storage rule changes, one
  edit instead of seven.

---

## 6. Coherence / polish

### [POLISH] Phase numbering: 6 / 6.5 is awkward

- **Where:** `workflow.md` Phase 6 (test loop) and Phase 6.5 (quality).
- **Fix:** Either renumber to 6 / 7 / 8 / 9 (and shift downstream) or
  rename Phase 6.5 to "Phase 7 — Quality Pass". The current "6.5"
  signals "patch added later" and makes the retry-budget table harder
  to read.

### [POLISH] Mode detection and Mode normalisation overlap

- **Where:** `workflow.md` "Input Detection" and "Input normalisation"
  sections.
- **Problem:** Both classify the input. The order — detect, then
  normalise, then potentially re-detect — is confusing.
- **Fix:** Collapse them into one section: *"Normalise input (strip
  `@`, resolve story numbers, suggest closest match), then classify
  into one of `jira | spec | prompt`."*

### [POLISH] Two preflights with overlapping responsibilities

- **Where:** `pipeline-preflight` (Phase 0) and `swift-pr-gate`
  (Phase 8 preflight).
- **Problem:** Both check working-tree cleanliness and base-branch
  position. Naming is similar enough that it's not always clear which
  is which.
- **Fix:** Rename `swift-pr-gate`'s preflight to "PR gate" exclusively
  and ensure its checks don't repeat `pipeline-preflight`'s.

### [POLISH] Model identifier hardcoded

- **Where:** `workflow.md` every subagent spawn block:
  `model: claude-sonnet-4-6`.
- **Problem:** When a new Sonnet ships, every spawn needs updating.
- **Fix:** Define `SUBAGENT_MODEL = claude-sonnet-4-6` once in the
  preamble.

---

## 7. Per-skill recommendations

### `pipeline-preflight`

- **[IMPROVEMENT] Stop-list schema undefined.** The skill mentions a
  "stop list" in CLAUDE.md but never specifies the format. Define a
  small YAML schema (`stop_list: [V1.1, V2, "do not start"]`) so
  detection is deterministic rather than substring-matching free text.
- **[IMPROVEMENT] Progress-doc matching is brittle.** Matches on PR
  number or merge-commit SHA. If a PR is squash-merged into a different
  SHA than recorded, detection misses. Match on PR title or branch name
  too.

### `swift-architect`

- **[IMPROVEMENT] Audit mode's grep is false-positive prone.** Pattern
  `try await | URLSession | JSONDecoder` inside `View.body` fires on
  string literals, comments, and unrelated files. Use AST-style
  matching via `XcodeListNavigatorIssues` for "logic in body" instead
  of grep.
- **[IMPROVEMENT] No subtask-discovery mode.** Workflow Phase 3 uses
  the skill in a mode the skill doesn't document. Add a "discovery"
  mode (or extract to `swift-discovery`).

### `swift-engineer`

- **[POLISH] "No god method" rule stated twice with slightly different
  wording** (around lines 89 and 235 per the explorer). Pick one.
- **[IMPROVEMENT] Build vs SourceKit rule has no slow-build escape
  hatch.** "Trust the build" is the right answer in a 20s incremental
  build, but a 4-minute cold build during a fast iteration becomes a
  trap. Add: *"if build > 60s, accept a single SourceKit diagnostic
  pass before the build completes — but never commit on SourceKit
  alone."*

### `swift-quality`

- **[IMPROVEMENT] Sendable placement unspecified.** The struct-order
  rule (Constants → State → Init → Protocol → Private helpers) doesn't
  say where Sendable conformances go. Add explicit guidance.
- **[IMPROVEMENT] No path when public API must change.** Skill says
  "preserve public API surface" unconditionally. Add: *"if a rule
  requires a public rename, halt and surface the API change as a
  finding — do not perform it."*

### `swift-concurrency`

- **[IMPROVEMENT] Defers to `swift-concurrency-expert` but doesn't
  cross-link with concrete triggers.** The two skills need a one-line
  decision rule: *"questions / explanations → swift-concurrency; fix
  an isolation error → swift-concurrency-expert."*

### `swift-testing`

- **[IMPROVEMENT] `.serialized` ban has no legacy-state fallback.**
  When production code requires `UserDefaults.standard` and refactor
  is out of scope, the skill leaves the test author stuck. Add:
  *"document the global-state dependency in a TODO; write the test
  against an injected fake; if no fake exists, surface as a BLOCKER
  rather than weakening with `.serialized`."*
- **[IMPROVEMENT] Sendable annotation guidance absent.** Skill assumes
  mocks are `actor` or `final class` but doesn't say when each fits.

### `swift-code-review`

- **[IMPROVEMENT] Checklist is binary; output is graduated.** Reconcile.
  Map each checklist item to a severity ladder explicitly: *"violation
  of [strict concurrency] → BLOCKER; method length > 20 → WARNING;
  missing preview → SUGGESTION."*
- **[IMPROVEMENT] Wire `XcodeListNavigatorIssues` automatically.** The
  skill mentions it but the workflow runs the skill via Bash
  `xcodebuild`. Use the MCP tool for navigator issues; it's the
  authoritative source.

### `swift-pr-gate`

- **[IMPROVEMENT] Gate 3 scope check is manual.** The skill cross-
  references "Types in scope" / "Must NOT touch" from the discovery
  note against the diff by reading. Add a programmatic check: `git
  diff --name-only main… | grep -vF -f <(in-scope list)` should be
  empty.
- **[IMPROVEMENT] Branch naming assumes `nat-` prefix.** Make the
  prefix configurable from CLAUDE.md so non-NAT projects can reuse the
  gate.

### `subagent-reliability`

- **[IMPROVEMENT] "Consistent with brief" is subjective.** Provide a
  heuristic: *"Recover in place only if the subagent touched ≥ 80 %
  of the files it was supposed to touch, AND build passes, AND no
  files outside the brief were modified. Otherwise re-spawn."*
- **[IMPROVEMENT] No fallback if `agentId` is missing.** Today the
  resume path depends on the continuation token being in the output.
  Document a fallback: *"if `agentId` is missing, treat as crash and
  re-spawn fresh from the latest committed state."*

---

## Top 10 fixes ranked by impact

If only ten changes ship, these in this order:

1. **Phase 4 reads `swift-engineer`, not `swift-quality`** (BLOCKER).
2. **Define `TEST_TARGET` in Phase 1** (BLOCKER — pipeline is
   currently broken on first run for any new project).
3. **Phase 6.5 re-runs tests, not just build** (BLOCKER — silent
   regressions today).
4. **PR body becomes a synthesised summary, not `cat discovery.md`**
   (BLOCKER — reviewer experience).
5. **Reconcile doc-comment rule with `swift-engineer`** (BLOCKER —
   non-deterministic output).
6. **Phase 4 body explicitly documents its retry loop** (BLOCKER —
   table-only retry semantics).
7. **Phase 0 documents Reconcile / Proceed / Abort branches**
   (BLOCKER — ad-hoc orchestration).
8. **Swap raw `xcodebuild` for MCP `xcode` tools** (IMPROVEMENT —
   large speed + context win).
9. **Build a subagent context bundle once per subtask, pass inline**
   (IMPROVEMENT — removes 3× redundant reads).
10. **Add bounce-back from engineer to architect when discovery is
    wrong** (IMPROVEMENT — saves wasted Phase 4 cycles).

---

## What this review did NOT touch

- The Jira mode flow itself (assumes Atlassian MCP works; doesn't
  audit the MCP calls).
- The detail of how `gh pr create` formats trailers / labels.
- Whether the Opus-vs-Sonnet split is optimal (model tiering could be
  its own review).
- The `~/Developer/obsidian/<project>/plans/` storage convention — the
  global CLAUDE.md mandates it and is out of scope here.
