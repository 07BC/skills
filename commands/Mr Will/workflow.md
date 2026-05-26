# Agentic Workflow Coordinator

## Spec / Jira Ticket → Subtasks → Architect → Engineer → Test → Review → PR

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
- Target branch name

---

## Input Detection

Before Phase 1, classify the input:

1. If the argument matches `^[A-Z]+-[0-9]+$` → `mode = jira`
2. Else if the argument is a path to an existing file → `mode = spec`
3. Else → `mode = prompt`

Announce the detected mode to the user before proceeding.

---

## Input normalisation

Before Phase 0 — Preflight, normalise the argument:

- If the argument starts with `@`, strip it (mention-style refs).
- If the spec mode failed because the path was off-by-one (e.g. `docs/spec/`
  vs `docs/stories/`, or a missing `.md`), search the project's likely spec
  directories (`docs/stories/`, `docs/specs/`, plus any path declared in
  `CLAUDE.md`) for the closest match. If exactly one match exists, suggest
  the corrected path and confirm via `AskUserQuestion`. Do NOT auto-resolve
  silently — name the file you found.
- If `mode = prompt` and the prompt itself names a story number that
  resolves to a file under the project's spec dirs, suggest switching to
  `mode = spec` with that file.

This step is best-effort. If nothing close matches, fall back to the
detected mode and let the user re-issue with a corrected path.

---

## Phase 0 — Preflight

### Opus, plan mode

Read and apply `[SKILL: ~/.claude/skills/pipeline-preflight/SKILL.md]` before
any other phase.

The skill produces signals (merged-PR vs progress-doc drift, out-of-scope
story markers, dirty working tree, wrong base branch). The orchestrator owns
the user-facing decision — when a signal fires, ask the user how to proceed
via `AskUserQuestion` and do not continue to Phase 1 until they answer.

When the skill emits `Pre-flight clean.`, proceed to Phase 1 without further
prompting.

---

## Phase 1 — Orientation

### Opus, plan mode

Read the following before doing anything:

1. `CLAUDE.md` — follow every linked doc from it
2. If `mode = jira`: the Jira ticket via Atlassian MCP
3. All acceptance criteria (from the ticket or spec file)

**Derive build targets from CLAUDE.md.** Look for `xcodebuild` commands in the
build commands section and extract:

- `SCHEME` — the value passed to `-scheme`
- `DESTINATION` — the full string passed to `-destination`

If CLAUDE.md contains no build commands, ask the user to supply `SCHEME` and
`DESTINATION` before continuing. Do not invent defaults.

Do not proceed until you have read all of the above.

---

## Phase 2 — Decompose AC → Create Subtasks in Jira

### Opus, plan mode — Jira mode only

> **Skip this phase when `mode = spec` or `mode = prompt`.** Proceed directly to
> Phase 3 using the spec file or free-form input as the subtask definition.

Using the acceptance criteria from the Jira ticket:

1. Decompose the AC into discrete, independently-implementable subtasks
2. Each subtask must:
   - Be completable in a single engineer subagent session
   - Have a clear, testable definition of done
   - Map to one logical unit of work (one service, one view, one actor, etc.)
3. Create each subtask in Jira as a child of the parent ticket via Atlassian MCP
4. Record the subtask keys returned by Jira — you will update them with status
   as the workflow progresses

**Do not begin implementation until all subtasks are created and confirmed in Jira.**

---

## Phase 3 — Architect Discovery

### Opus, plan mode

For the current subtask:

1. Read the following in order before doing anything else:
   - `[SKILL: ~/.claude/skills/swift-architect/SKILL.md]`
   - `CLAUDE.md` and follow all linked architecture docs in `docs/`
2. Read the subtask description and definition of done
3. Discover and document:
   - Which existing types, actors, and services this subtask touches
   - Edge cases introduced by this subtask's requirements
   - Integration constraints (what must not change, what must be preserved)
   - The correct patterns to follow per the target architecture
   - Any concurrency boundaries this subtask crosses
4. Derive the discovery note path:
   ```bash
   project_name="$(basename "$(git rev-parse --show-toplevel)")"
   discovery_note="${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md"
   ```
   Write the discovery note to that path.

The discovery note is the engineer's primary input. It must be precise enough
that the engineer does not need to re-read the full architecture docs.

**Do not write any implementation code in this phase.**

---

## Phase 4 — Engineer Execution

### Spawn Sonnet subagent — normal mode

Spawn a subagent with the following parameters:

```
model: claude-sonnet-4-6
mode: normal
task: (paste the block below as the subagent prompt)
```

> Read the following before writing any code:
>
> 1. `[SKILL: ~/.claude/skills/swift-quality/SKILL.md]`
> 2. `CLAUDE.md`
> 3. `${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md`
> 4. `[SKILL: ~/.claude/skills/swift-concurrency/SKILL.md]` —
>    read only if the subtask involves async work, `Task { }`, or actor boundaries
>
> Do not write any code until you have read items 1–3 (and item 4 if the
> subtask involves async work).
>
> Implement the subtask according to the discovery note. Follow all constraints
> listed there exactly. Apply Swift conventions:
>
> - Architecture: SwiftUI MV — no ViewModels, views bind to `@Observable` services
> - Concurrency: Swift 6 strict, `Mutex` over `NSLock`, `actor` for off-main work
> - Services: `@MainActor @Observable final class`
> - Storage: SwiftData
> - DI: `@Environment` / `AppDependencies`
> - Style: 2-space indentation, write no comments — no doc comments (`///`), no inline comments, no block comments. MARK sections are the only exception where swift-quality requires them.
>
> Build must pass with zero errors and zero warnings. Run:
>
> ```bash
> xcodebuild build -scheme [SCHEME] -destination '[DESTINATION]'
> ```
>
> (Use the SCHEME and DESTINATION derived from CLAUDE.md in Phase 1.)
>
> Report: list of files created or modified, and build result.

**Return control to the orchestrator when the subagent reports completion.**
The orchestrator reads the file list and build result before continuing.

**SourceKit diagnostics:** if `<new-diagnostics>` system reminders fire after
the subagent reports completion (and the subagent's own `xcodebuild build`
ran clean), apply the "Build vs SourceKit truth" rule in
`~/.claude/skills/swift-engineer/SKILL.md`. One ack line, no re-spawn.

---

## Phase 5 — Test Authoring

### Spawn Sonnet subagent — normal mode

Spawn a subagent with the following parameters:

```
model: claude-sonnet-4-6
mode: normal
task: (paste the block below as the subagent prompt)
```

> Read the following before writing any tests:
>
> 1. `[SKILL: ~/.claude/skills/swift-testing/SKILL.md]`
> 2. `CLAUDE.md`
> 3. `${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md`
> 4. Every file created or modified in Phase 4 (use the file list from the
>    Phase 4 subagent report)
>
> Write Swift Testing tests covering:
>
> - The happy path for every public method introduced
> - Every edge case listed in the discovery note
> - Every failure path that can be expressed without a live network
>
> Rules:
>
> - Use Swift Testing exclusively: `@Test`, `#expect`, `@Suite`
> - Never use XCTest for unit tests
> - Never use `XCTestCase` in this phase
> - Never write XCUITests in this phase
> - Tests must not depend on live network or real credentials
> - Use fakes / stubs over mocks where possible
>
> Report: list of test files created and number of test cases written.

**Return control to the orchestrator when the subagent reports completion.**

**SourceKit diagnostics:** same rule as Phase 4 — see
`~/.claude/skills/swift-engineer/SKILL.md` § Build vs SourceKit truth.

---

## Phase 6 — Test Execution Loop

### Opus, plan mode (orchestrator decision point)

Run the tests:

```bash
xcodebuild test -scheme [SCHEME] \
  -destination '[DESTINATION]' \
  -only-testing:[TestTargetName]
```

(Use the SCHEME and DESTINATION derived from Phase 1.)

**If tests pass (exit 0):** proceed to Phase 6.5.

**If tests fail:**

1. Capture the full failure output
2. Spawn a subagent with the following parameters:
   ```
   model: claude-sonnet-4-6
   mode: normal
   task:
   ```
   > The following tests failed. Fix the implementation to make them pass.
   > Do not change the tests. Do not change anything outside the failing scope.
   > Failure output: [full xcodebuild output]
3. Re-run Phase 6
4. **Maximum 3 fix attempts.** If tests still fail after 3 attempts:
   - Write a failure report to:
     ```bash
     ${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-blocked.md
     ```
   - If `mode = jira`: update the Jira subtask status to `Blocked` via Atlassian MCP
     and add a comment with the failure summary
   - **Halt. Do not proceed to Phase 6.5.**

---

## Phase 6.5 — Swift Quality Pass

### Spawn Sonnet subagent — normal mode

Spawn a subagent with the following parameters:

```
model: claude-sonnet-4-6
mode: normal
task: (paste the block below as the subagent prompt)
```

> Read the following before doing anything:
>
> 1. `[SKILL: ~/.claude/skills/swift-quality/SKILL.md]`
> 2. Every file created or modified in Phase 4 (use the file list from the
>    Phase 4 subagent report)
>
> Do not write any code until you have read both.
>
> Apply the full swift-quality ruleset to every implementation file from Phase 4.
> Do NOT touch test files authored in Phase 5.
>
> Rules:
>
> - Apply all MARK ordering, blank line discipline, and method chain formatting rules
> - Replace any abbreviated identifiers with full names
> - Replace any inline comments with well-named extractions or self-documenting code
> - Apply `== false` negation, named constants, and `static func` over `class func` rules
> - Do NOT change behaviour — this is a style pass only
> - Do NOT rewrite logic, restructure control flow, or rename public API surface
>
> After applying changes, confirm the build still passes with zero errors and
> zero warnings:
>
> ```bash
> xcodebuild build -scheme [SCHEME] -destination '[DESTINATION]'
> ```
>
> Report: list of files modified and a summary of the style changes applied.

**Return control to the orchestrator when the subagent reports completion.**
The orchestrator confirms the build result before continuing to Phase 7.

**SourceKit diagnostics:** same rule as Phase 4 — see
`~/.claude/skills/swift-engineer/SKILL.md` § Build vs SourceKit truth.

**If the build is broken after the quality pass:**

- Spawn a targeted fix subagent (`model: claude-sonnet-4-6, mode: normal`) with
  the build output and instruction to revert only the style change that caused
  the regression
- Re-confirm the build before proceeding
- **Maximum 1 fix attempt.** If still broken, halt and write a blocked report

---

## Phase 7 — Code Review

### Opus, plan mode

Read in order:

1. `[SKILL: ~/.claude/skills/swift-code-review/SKILL.md]`
2. `CLAUDE.md`
3. `${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md`
4. All files changed in Phases 4, 5, and 6.5

Review against:

**Architecture conformance**

- No ViewModels introduced
- Views receive services via `@Environment` or init injection only
- Domain logic not placed in views

**Swift 6 concurrency**

- No `DispatchQueue` where actor/async should be used
- `Mutex` used instead of `NSLock`
- No `@unchecked Sendable` without explanatory comment
- No retain cycles in `Task { }` closures

**Scope discipline**

- Only files related to the subtask are touched
- No unrelated changes

**Test coverage**

- All public methods have tests
- All discovery-note edge cases are covered
- No XCTest used for unit tests

**If blocking issues found:**

- Spawn a targeted Sonnet subagent (`model: claude-sonnet-4-6, mode: normal`)
  with the blocking issues listed explicitly as the task
- Re-review the fixed files only before continuing

**If no blocking issues:** proceed to Phase 8.

---

## Phase 8 — PR Preflight + PR Creation

### Opus, plan mode

Run preflight:

1. Read `[SKILL: ~/.claude/skills/swift-pr-gate/SKILL.md]` if it exists, otherwise
   perform the checks below manually
2. Read `CLAUDE.md`
3. Confirm build is clean
4. Confirm all tests pass
5. Confirm no unrelated files are staged
6. Confirm branch is named correctly per convention

Ask the user to confirm before creating the PR. Once confirmed, create via `gh` CLI:

```bash
gh pr create \
  --title "[Subtask title]" \
  --body "$(cat ${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md)" \
  --base main \
  --head [branch-name]
```

After PR is created:

- If `mode = jira`:
  1. Update the Jira subtask status to `In Review` via Atlassian MCP
  2. Add the PR URL as a comment on the Jira subtask
- Report the PR URL to the user

---

## Halt Conditions

The orchestrator must halt and report (never silently continue) if:

- Tests fail after 3 fix attempts
- Build does not pass after Phase 4
- Build does not pass after Phase 6.5 quality pass fix attempt
- `gh pr create` fails
- Any required Jira MCP call fails (Jira mode only)

On halt: write a summary to:

```bash
${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-blocked.md
```

If `mode = jira`: update the Jira subtask to `Blocked` with a comment.

---

## Retry Budget Summary

| Phase                   | Max retries | Halt action                                          |
| ----------------------- | ----------- | ---------------------------------------------------- |
| Phase 4 build           | 2           | Halt + blocked report                                |
| Phase 6 test loop       | 3           | Halt + blocked report + Jira update (Jira mode only) |
| Phase 6.5 quality build | 1           | Halt + blocked report                                |
| Phase 7 review fix      | 1           | Halt + flag for manual review                        |

The budget above counts subagent **failures** (build broken, test failed,
scope violated — anything the subagent reported as a failure). Subagent
**crashes** (no usable result returned, raw API error, socket-closed,
timeout) are a different failure mode — apply
`[SKILL: ~/.claude/skills/subagent-reliability/SKILL.md]` first. A
"recover-in-place" or "resumed" outcome does NOT consume a retry slot; a
"re-spawn fresh" outcome does.

---

**Model & mode:** Opus, plan mode — this is an orchestrator prompt with
branching logic; Opus must own all decisions.
Sonnet subagents handle Phases 4, 5, and 6.5 only.
