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
> 1. `[SKILL: ~/.claude/skills/swift-quality/SKILL.md]`
> 2. `CLAUDE.md`
> 3. `${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md`
>
> Do not write any code until you have read all three.
>
> Implement the subtask according to the discovery note. Follow all constraints
> listed there exactly. Apply Swift conventions:
>
> - Architecture: SwiftUI MV — no ViewModels, views bind to `@Observable` services
> - Concurrency: Swift 6 strict, `Mutex` over `NSLock`, `actor` for off-main work
> - Services: `@MainActor @Observable final class`
> - Storage: SwiftData
> - DI: `@Environment` / `AppDependencies`
> - Style: 2-space indentation, no inline comments
>
> Build must pass with zero errors and zero warnings. Run:
> ```bash
> xcodebuild build -scheme [SCHEME] -destination '[DESTINATION]'
> ```
> (Use the SCHEME and DESTINATION derived from CLAUDE.md in Phase 1.)
>
> Report: list of files created or modified, and build result.

**Return control to the orchestrator when the subagent reports completion.**
The orchestrator reads the file list and build result before continuing.

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
> 1. `[SKILL: ~/.claude/skills/swift-testing/SKILL.md]`
> 2. `CLAUDE.md`
> 3. `${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md`
> 4. Every file created or modified in Phase 4 (use the file list from the
>    Phase 4 subagent report)
>
> Write Swift Testing tests covering:
> - The happy path for every public method introduced
> - Every edge case listed in the discovery note
> - Every failure path that can be expressed without a live network
>
> Rules:
> - Use Swift Testing exclusively: `@Test`, `#expect`, `@Suite`
> - Never use XCTest for unit tests
> - Never use `XCTestCase` in this phase
> - Never write XCUITests in this phase
> - Tests must not depend on live network or real credentials
> - Use fakes / stubs over mocks where possible
>
> Report: list of test files created and number of test cases written.

**Return control to the orchestrator when the subagent reports completion.**

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

**If tests pass (exit 0):** proceed to Phase 7.

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
   - **Halt. Do not proceed to Phase 7.**

---

## Phase 7 — Code Review
### Opus, plan mode

Read in order:
1. `[SKILL: ~/.claude/skills/swift-code-review/SKILL.md]`
2. `CLAUDE.md`
3. `${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md`
4. All files changed in Phases 4 and 5

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
- `gh pr create` fails
- Any required Jira MCP call fails (Jira mode only)

On halt: write a summary to:
```bash
${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-blocked.md
```
If `mode = jira`: update the Jira subtask to `Blocked` with a comment.

---

## Retry Budget Summary

| Phase | Max retries | Halt action |
|---|---|---|
| Phase 4 build | 2 | Halt + blocked report |
| Phase 6 test loop | 3 | Halt + blocked report + Jira update (Jira mode only) |
| Phase 7 review fix | 1 | Halt + flag for manual review |

---

**Model & mode:** Opus, plan mode — this is an orchestrator prompt with
branching logic; Opus must own all decisions.
Sonnet subagents handle Phases 4 and 5 only.
