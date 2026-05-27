# Agentic Workflow Coordinator

## Spec / Jira Ticket → Subtasks → Discovery → Engineer → Test → Quality → Review → PR

---

## Overview

This coordinator manages a single subtask end-to-end. It is launched once per
subtask. The orchestrator (Opus) owns all branching decisions. Subagents
(Sonnet) handle all execution. No subagent makes a branching decision.

**Input required before launching:**

- One of:
  - A Jira ticket key (e.g. `NAT-1234`) — auto-detected via `^[A-Z]+-[0-9]+$`
  - A spec file path (e.g. `docs/stories/01-project-setup.md`) — auto-detected by file existence
  - A free-form description — fallback when neither of the above matches
- The specific subtask to work on (by title or subtask key, if applicable)

The target branch is **derived**, not supplied — see Phase 0.5.

---

## Variables

Define these once. Every later phase references them rather than restating
the paths or values.

| Variable | Source | Example |
| --- | --- | --- |
| `SUBAGENT_MODEL` | constant | `claude-sonnet-4-6` |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` | `kick-tvos` |
| `PLANS_DIR` | `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans` | per global plan-storage rule |
| `SCHEME`, `DESTINATION`, `TEST_TARGET` | derived in Phase 1 from `CLAUDE.md` | — |
| `PROJECT_KIND` | detected in Phase 1 (`xcode` or `spm`) | — |
| `BASE_BRANCH` | declared in `CLAUDE.md`, fall back to `main` | — |
| `BRANCH_PREFIX` | declared in `CLAUDE.md`, fall back to project Jira key | `nat-` |

When a phase says "spawn a Sonnet subagent" it always means
`model: SUBAGENT_MODEL, mode: normal`.

---

## Input — detect and normalise

Run as a single step:

1. **Normalise.** Strip a leading `@` if present (mention-style refs). If the
   argument names a story number and the project's spec dirs contain a
   matching file, suggest the resolved path via `AskUserQuestion`.
2. **Classify** the normalised argument:
   - Matches `^[A-Z]+-[0-9]+$` → `mode = jira`
   - Is a path to an existing file → `mode = spec`
   - Otherwise → `mode = prompt`
3. **Resolve near-misses.** If the file does not exist but a single close
   match exists under `docs/stories/` / `docs/specs/` / any spec dir
   declared in `CLAUDE.md`, name the file and confirm via `AskUserQuestion`.
   Never auto-resolve silently.

Announce the resolved mode and argument before proceeding.

---

## Model Confirmation

State on a single line:

> Running as: [model name and version] — [plan mode / normal mode]

Do not proceed to Phase 0 until this line has been output.

---

## Phase 0 — Preflight

### Opus, plan mode

Apply skill `pipeline-preflight`.

The skill produces signals (merged-PR vs progress-doc drift, out-of-scope
story markers, dirty working tree, wrong base branch). When any signal
fires, the orchestrator asks the user via `AskUserQuestion` with three
options. The orchestrator owns what each option does:

| Option | Orchestrator action |
| --- | --- |
| **Reconcile first** | Update progress doc / pick a different story / clean the tree, then re-run pipeline-preflight. Do not proceed to Phase 0.5 until preflight emits `Pre-flight clean.` |
| **Proceed anyway** | Record the override in the discovery note's "Open issues" section (Phase 3). Continue to Phase 0.5. |
| **Abort** | Halt with no blocked report. This is a user choice, not a failure. |

When preflight emits `Pre-flight clean.`, continue to Phase 0.5 without
further prompting.

---

## Phase 0.5 — Branch

### Opus, plan mode

Derive the branch name: `${BRANCH_PREFIX}${ticket-number}-${kebab-title}`.

- If on `BASE_BRANCH` and the derived branch does not exist → create it from
  `BASE_BRANCH`.
- If already on the derived branch with prior commits from this pipeline →
  resume.
- If on an unrelated branch → halt and ask the user.

Do not proceed to Phase 1 until `HEAD` is on the derived branch and the
working tree is clean.

---

## Phase 1 — Orientation

### Opus, plan mode

Read the following before doing anything:

1. `CLAUDE.md` — follow every linked doc from it
2. If `mode = jira`: the Jira ticket via Atlassian MCP
3. All acceptance criteria (from the ticket or spec file)

**Derive build targets from CLAUDE.md.** Look for build / test commands and
extract:

- `PROJECT_KIND` — `xcode` if the commands use `xcodebuild`, `spm` if they
  use `swift build` / `swift test`.
- `SCHEME` — the value passed to `-scheme` (xcode only).
- `DESTINATION` — the full string passed to `-destination` (xcode only).
- `TEST_TARGET` — the value passed to `-only-testing:` in any
  `xcodebuild test` command. If multiple test targets exist, prefer the
  one named like `*UnitTests` / `*Tests` and ignore UI test targets.
- `BASE_BRANCH` — declared base branch; fall back to `main`.
- `BRANCH_PREFIX` — declared branch prefix; fall back to the project's
  Jira key (lowercased) plus `-`.

If any of these cannot be derived, ask the user before continuing. Do not
invent defaults.

Do not proceed until you have read all of the above.

---

## Phase 2 — Decompose AC → Create Subtasks in Jira

### Opus, plan mode — Jira mode only

> Skip this phase when `mode = spec` or `mode = prompt`. Proceed to Phase 3
> using the spec file or free-form input as the subtask definition.

Using the acceptance criteria from the Jira ticket:

1. Decompose the AC into discrete, independently-implementable subtasks.
2. Each subtask must:
   - Be completable in a single engineer subagent session
   - Have a clear, testable definition of done
   - Map to one logical unit of work (one service, one view, one actor, etc.)
3. Create each subtask in Jira as a child of the parent ticket via Atlassian MCP.
4. **Add a `Non-goals` comment** to the parent ticket listing AC items
   that are explicitly out of scope for this round — Phase 3 will read this
   list when writing the discovery note.
5. Record the subtask keys returned by Jira — you will update them with
   status as the workflow progresses.

Do not begin implementation until all subtasks are created and confirmed in Jira.

---

## Phase 3 — Discovery

### Opus, plan mode

Apply skill `swift-discovery` for the current subtask. The skill produces a
discovery note at `${PLANS_DIR}/[SUBTASK-KEY]-discovery.md` with the
required sections:

- Baseline
- Types in scope (Existing / New)
- Injection
- Patterns to follow
- Concurrency notes
- Edge cases to handle
- Failure paths to handle
- Must NOT touch
- Definition of done

If `mode = jira`, include the `Non-goals` list from Phase 2 in the
"Must NOT touch" section.

**Validate before handing off.** After the skill runs, grep the discovery
note for each required section header. If any is missing → re-run
`swift-discovery` with a `MISSING_SECTIONS:` note. Do not spawn Phase 4
against an incomplete discovery note.

Do not write any implementation code in this phase.

---

## Subagent Context Bundle

Build the bundle once per subtask after Phase 3 succeeds. Pass it inline in
every later subagent prompt so subagents never re-read `CLAUDE.md` or the
discovery note from disk.

```
SUBTASK: [SUBTASK-KEY] — [Title]
DISCOVERY: <full contents of ${PLANS_DIR}/[SUBTASK-KEY]-discovery.md>
CLAUDE_MD: <full contents of ./CLAUDE.md>
SCHEME: [SCHEME]
DESTINATION: [DESTINATION]
TEST_TARGET: [TEST_TARGET]
PROJECT_KIND: [PROJECT_KIND]
```

References to "the context bundle" below mean this block.

---

## Phase 4 — Engineer Execution

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below.

> Apply skill `swift-engineer`. The bundle below contains everything you
> need — do not re-read these files from disk.
>
> [context bundle]
>
> Implement the subtask according to the discovery note. Follow every
> constraint listed under "Must NOT touch". The discovery note is the
> source of truth — apply `swift-engineer` rules to *how* you build,
> but follow the discovery note for *what* to build.
>
> If the discovery note is inconsistent with the codebase (a service
> doesn't exist where claimed, a constraint is impossible, types
> contradict), **halt and emit `BOUNCE: [one-line reason]`**. Do not
> implement around it.
>
> For Swift 6 isolation errors that aren't trivially resolvable inline,
> apply skill `swift-concurrency-expert` on the affected file.
>
> Build must pass with zero errors and zero warnings. Prefer the MCP Xcode
> tools when Xcode is open:
>
> ```
> ToolSearch("select:mcp__xcode__BuildProject,mcp__xcode__GetBuildLog,mcp__xcode__XcodeListNavigatorIssues")
> ```
>
> Fall back to Bash when Xcode is not open:
>
> ```bash
> xcodebuild build -scheme [SCHEME] -destination '[DESTINATION]'    # PROJECT_KIND=xcode
> swift build                                                       # PROJECT_KIND=spm
> ```
>
> Report: list of files created or modified, build result, and the
> `BOUNCE:` line if applicable.

**Retry budget: 2 build-fix attempts.** If the subagent reports build
failure, spawn a fix subagent with the build output. On the second build
failure → halt + blocked report (see Halt Conditions).

**Bounce-back: 1 attempt per subtask.** If the subagent reports
`BOUNCE:`, return to Phase 3 with the bounce reason and re-spawn
`swift-discovery`. If the re-bounce → halt + blocked report.

**SourceKit diagnostics.** When `<new-diagnostics>` fire after the
subagent reports completion but the subagent's own build was clean, apply
the "Build vs SourceKit truth" rule in skill `swift-engineer`. One ack
line, no re-spawn.

**Crash recovery.** If the subagent returns no usable result (raw API
error, timeout, socket-closed), apply skill `subagent-reliability` before
consuming a retry slot.

Return control to the orchestrator when the subagent reports completion.
The orchestrator reads the file list and build result before continuing.

---

## Phase 5 — Test Authoring

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below.

> Apply skill `swift-testing`. The bundle below contains everything you
> need — do not re-read these files from disk.
>
> [context bundle]
> PHASE_4_FILES: <list of files created or modified in Phase 4>
>
> Write Swift Testing tests covering:
>
> - The happy path for every public method introduced in Phase 4
> - Every edge case listed in the discovery note
> - Every failure path that can be expressed without a live network
>
> Apply every `swift-testing` rule verbatim — including the `.serialized`
> ban, the actor-mock rule, and the no-process-global-state rule. Do not
> weaken any rule to make a test pass.
>
> Report: list of test files created and number of test cases written.

**Retry budget: 1 attempt to recover from a subagent-reported failure.**
Crash recovery applies skill `subagent-reliability` first.

Return control to the orchestrator when the subagent reports completion.

---

## Phase 6 — Test Execution Loop

### Opus, plan mode (orchestrator decision point)

Run the tests. Prefer MCP Xcode tools when available:

```
ToolSearch("select:mcp__xcode__RunSomeTests,mcp__xcode__RunAllTests")
```

Fall back to Bash:

```bash
# PROJECT_KIND=xcode
xcodebuild test -scheme [SCHEME] -destination '[DESTINATION]' -only-testing:[TEST_TARGET]

# PROJECT_KIND=spm
swift test
```

**Retry budget: 3 fix attempts.**

If tests pass (exit 0): proceed to Phase 6.5.

If tests fail:

1. Capture the full failure output.
2. Spawn `model: SUBAGENT_MODEL, mode: normal`:
   > The following tests failed. Fix the implementation to make them pass.
   > Do not change the tests. Do not change anything outside the failing scope.
   > Failure output: [full output]
3. Re-run the tests.
4. After 3 failed attempts → write a blocked report to
   `${PLANS_DIR}/[SUBTASK-KEY]-blocked.md`. If `mode = jira`, transition
   the subtask to `Blocked` via Atlassian MCP with the failure summary.
   Halt; do not proceed to Phase 6.5.

---

## Phase 6.5 — Swift Quality Pass

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below.

> Apply skill `swift-quality` to every implementation file from Phase 4.
> Do NOT touch test files authored in Phase 5.
>
> [context bundle]
> PHASE_4_FILES: <list of files created or modified in Phase 4>
>
> This is a style and structure pass. Do NOT change behaviour. Do NOT
> rename public API. Do NOT restructure control flow. If a rule requires
> a public API rename, halt and surface it — do not perform it.
>
> Confirm the build passes with zero errors and zero warnings, then
> re-run the tests using the Phase 6 command (`xcodebuild test
> -only-testing:[TEST_TARGET]` or `swift test`). Both must pass.
>
> Report: list of files modified, summary of style changes, build result,
> and test result.

**Retry budget: 1 fix attempt for build/test regressions introduced by
the quality pass.** Spawn a targeted fix subagent with the failure output
and instruction to revert only the style change that caused the regression.

If still broken after the fix attempt → halt + blocked report.

The orchestrator confirms both build and test results before continuing
to Phase 7.

---

## Phase 7 — Code Review

### Spawn Sonnet subagent — normal mode

Spawn `model: SUBAGENT_MODEL, mode: normal` with the prompt below. Code
review runs as a subagent so the orchestrator doesn't burn context
reading every changed file.

> Apply skill `swift-code-review`.
>
> [context bundle]
> PHASE_4_FILES: <list>
> PHASE_5_FILES: <list>
> PHASE_6_5_FILES: <list>
>
> Review every file in PHASE_4_FILES, PHASE_5_FILES, and PHASE_6_5_FILES.
> Apply the full BLOCKER / WARNING / SUGGESTION checklist.
>
> Verify the **Definition of done** from the discovery note is observable
> in the diff or in a passing test. List each DoD criterion and which
> file/test demonstrates it.
>
> Report: structured findings list, DoD verification, and a
> PASS / FAIL verdict.

**Retry budget: 1 review-fix attempt.** If the reviewer returns FAIL:

1. Spawn a targeted Sonnet fix subagent with the BLOCKER findings listed
   explicitly as the task.
2. Re-spawn `swift-code-review` on the fixed files only.
3. If still FAIL → halt + flag for manual review.

If no BLOCKERs and DoD verified → proceed to Phase 7.5.

---

## Phase 7.5 — UI Verification (optional)

### Opus, plan mode

Trigger when any file in PHASE_4_FILES or PHASE_6_5_FILES is a SwiftUI
`View`. Otherwise skip.

Apply skill `verify` (or `swift-uitest` for tvOS) to launch the app on
simulator and confirm the affected screens render and navigate without
regressions. For unwired views or pure component changes, an automated
preview snapshot is sufficient.

If the manual verification surfaces a regression → spawn a Sonnet fix
subagent with the regression description. Cap at 1 attempt; on failure,
halt + flag for manual review.

---

## Phase 8 — PR Gate + PR Creation

### Opus, plan mode

Apply skill `swift-pr-gate`. The skill runs every gate (build, tests,
scope, branch name, PR description, Jira status) and produces the gate
summary.

If any gate fails → halt + report. Do not raise a PR from a broken state.

Once all gates pass:

1. Use the gate's synthesised PR description (template-conformant, not the
   raw discovery note).
2. Create the PR:

   ```bash
   gh pr create \
     --title "[SUBTASK-KEY]: [Subtask title]" \
     --body-file [body-file from gate] \
     --base [BASE_BRANCH] \
     --head [branch-name]
   ```

3. If `mode = jira`:
   - Transition the Jira subtask to `In Review` via Atlassian MCP.
   - Add the PR URL as a comment on the Jira subtask.
4. Report the PR URL to the user.

---

## Phase 9 — Post-PR Comment Loop (optional)

### Opus, plan mode

When the user returns with reviewer feedback on the PR, apply skill
`pr-comment-review`. The skill triages each comment, applies fixes via
Sonnet subagents, and posts replies.

This phase is user-triggered — the orchestrator does not poll for review
comments on its own.

---

## Halt Conditions

The orchestrator must halt and report (never silently continue) if:

- Phase 4 build fails after 2 attempts
- Phase 4 bounce-back exhausted (1 attempt)
- Phase 6 tests fail after 3 attempts
- Phase 6.5 build or tests fail after 1 fix attempt
- Phase 7 code review fails after 1 fix attempt
- Phase 7.5 UI verification surfaces a regression after 1 fix attempt
- Any `swift-pr-gate` gate fails
- `gh pr create` fails
- Any required Jira MCP call fails (Jira mode only)

On halt: write a summary to `${PLANS_DIR}/[SUBTASK-KEY]-blocked.md`.

If `mode = jira`: transition the Jira subtask to `Blocked` with a comment.

---

## Retry Budget Summary

| Phase | Retry budget | Halt action |
| --- | --- | --- |
| Phase 4 build | 2 attempts | Halt + blocked report |
| Phase 4 bounce-back | 1 attempt | Halt + blocked report |
| Phase 5 test authoring | 1 attempt | Halt + blocked report |
| Phase 6 test loop | 3 attempts | Halt + blocked report + Jira update (Jira mode only) |
| Phase 6.5 quality build/test | 1 attempt | Halt + blocked report |
| Phase 7 review fix | 1 attempt | Halt + flag for manual review |
| Phase 7.5 UI verify fix | 1 attempt | Halt + flag for manual review |

The budget counts subagent **failures** (build broken, test failed, scope
violated — anything the subagent reported as a failure). Subagent
**crashes** (no usable result returned, raw API error, socket-closed,
timeout) are a different failure mode — apply skill `subagent-reliability`
first. A "recover-in-place" or "resumed" outcome does NOT consume a retry
slot; a "re-spawn fresh" outcome does.

---

**Model & mode:** Opus, plan mode — this is an orchestrator prompt with
branching logic; Opus must own all decisions.
Sonnet subagents handle Phases 4, 5, 6.5, and 7 only.
