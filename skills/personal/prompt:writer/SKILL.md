---
name: prompt:writer
description: >
  Writes Claude Code prompts for iOS/Swift development tasks. Use this skill
  whenever the user says "prompt:writer", "write a prompt for Claude Code",
  "craft a Claude Code prompt", "create a prompt to", "I need a prompt to",
  or wants to prepare instructions for a Claude Code session. Always use this
  skill rather than writing prompts ad hoc — it encodes the conventions that
  make Claude Code prompts reliable.
---

# prompt:writer

Produces a Claude Code prompt for an iOS/Swift task. Every prompt is saved
as a `.md` file and presented via `present_files` — never pasted inline.

---

## Step 1 — Understand the task

Establish before writing:
1. What is the task? Bug fix, feature, refactor, audit, test authoring?
2. Which project / files are in scope?
3. Hard scope constraints — files that must not be touched, patterns that must not change?
4. Does this need a plan phase? (See decision table below.)
5. Is this XCUITest work? If yes, apply XCUITest rules — no exceptions.

Extract answers from context rather than asking when the request is clear.

---

## Step 2 — Plan vs. execute decision

| Task type | Session structure |
|---|---|
| Unknown scope / complex refactor / architecture change | Two sessions: plan first, execute second |
| Clear spec, mechanical implementation | One session: execute directly |
| Bug fix with identified root cause | One session: regular mode |
| Any XCUITest authoring | Two sessions: always split |

Never combine plan and execute into a single prompt.

---

## Step 3 — Prompt structure

**Preamble (required)**
Files to read before doing anything, in order. "Do not write any code until
you have read [X]."

Include a **repository check** as the first action when working in a
multi-repo environment: confirm `git remote -v` or `pwd` matches the expected
repo before writing any file.

**Task statement (required)**
One paragraph: what is being built or fixed and why.

**Constraints (required if any exist)**
Explicit list of what must NOT change, be touched, or be introduced.

```
## Constraints
- Touch only [file or folder]
- Do NOT refactor, rename, or move any existing code
- Do NOT introduce new protocols, managers, or abstractions
- Do NOT change anything outside the scope of this fix
```

**Implementation steps (required for features/refactors)**
Ordered steps in dependency order, each small enough to verify independently.

**Verification (required)**
Build command, tests, grep/search to confirm completion.

Verification order is always:
1. Build — `xcodebuild build …` must produce zero errors and zero warnings
2. Test — run the relevant test suite only after a clean build
3. Grep / diff — confirm expected files changed, unexpected files did not

SourceKit "No such module" and cross-module diagnostics are **not**
authoritative. Always use `xcodebuild` as the build truth.

**Model & mode recommendation (required — always last)**
Format: `**Model & mode:** [Sonnet|Opus], [plan mode|normal mode] — [one-line reason]`

| Task | Model | Mode |
|---|---|---|
| Audit / architecture / root cause | Opus | plan |
| Feature build from clear spec | Sonnet | normal |
| Bug fix with known location | Sonnet | normal |
| Ambiguous scope / broad refactor | Opus | plan |
| Mechanical execution from approved plan | Sonnet | normal |

---

## Step 4 — XCUITest rules

When any UI test work is involved, add this block verbatim at the top of the
prompt, before the preamble:

```
CRITICAL — READ THIS BEFORE ANYTHING ELSE:

You are NOT writing unit tests.
You are NOT using Swift Testing.
You are NOT writing @Test functions.
You are NOT using #expect.

If you find yourself typing `import Testing` or `@Test`, stop immediately —
you are doing the wrong thing.

XCUITests:
- Import XCTest only
- Subclass XCTestCase
- Use XCUIApplication() to drive a real simulator
- Use XCTAssert* functions
- Cannot import or reference any app module code
```

The skill file must be the first thing the agent reads — before CLAUDE.md,
before any other file. State this explicitly in the preamble.

Split into two separate prompts — plan session and execute session. Never
combine them.

Credentials: never hardcode. Always inject via `UITestCredentials.inject(into: app)`
before `app.launch()`.

---

## Step 5 — Swift project conventions

Apply to every prompt unless the user's request contradicts them:

- Architecture: SwiftUI MV — no ViewModels, views bind directly to `@Observable` services
- Concurrency: Swift 6 strict; `actor` for any type with mutating shared state; locks (`Mutex`, `NSLock`, `os_unfair_lock`, `DispatchSemaphore`) are not approved
- Unit testing: Swift Testing (`@Test`, `#expect`) — never XCTest for unit tests
- UI testing: XCUITest / XCTestCase only — never Swift Testing
- Storage: SwiftData
- Style: 2-space indentation, no inline comments
- DI: `@Inject` / `AppDependencies` / `@Environment`
- Services: `@MainActor @Observable final class`

---

## Step 6 — Session hygiene rules

Include these guards in prompts wherever they are relevant. They are drawn
from recurring failure patterns across real sessions.

### Build before test
Always instruct the agent to build before running any test suite. Compile
errors discovered mid-suite produce misleading failure counts. The correct
sequence is always: build → fix all errors → test.

### Advisor call on plans
For any plan-phase prompt, instruct the agent to call the advisor (another
Opus instance) before beginning execution. Advisor calls reliably catch
Optional mismatches, wrong scope, and incorrect API assumptions before any
code is written.

### Subagent output verification
When the prompt involves subagents writing files, split views, or `.pbxproj`
edits, instruct the agent to verify subagent output before committing:
- Confirm expected files exist and are non-empty
- Confirm no unrelated files were staged (`git status` before `git add`)
- Confirm naming conventions match the project (`+` suffix for split files, etc.)

### Atomic commits
Instruct the agent to stage files explicitly by path — never `git add -u` or
`git add .` unless the entire working tree is the intended change. Each
commit should contain one logical change.

### Pre-commit hook false positives
Pre-commit hooks sometimes fire on read-only git commands (`git log`,
`git status`). Instruct the agent to treat hook output as a real commit only
when `git log -1` confirms a new commit hash.

### Stale session state
If a session may resume from an earlier log or plan, instruct the agent to
cross-reference log timestamps against `git log` before treating the log as
current state. When in doubt, run a fresh build and test to establish ground
truth.

### Test gap estimates
First-pass gap estimates from automated tools are frequently wrong. Instruct
the agent to verify by grepping the actual branch diff before authoring new
tests, and to confirm that reported-missing tests do not already exist under
a different file name.

### Repository guard
When working in an environment with multiple clones or workspaces, instruct
the agent to confirm the active repository (`git remote -v` or `pwd`) before
writing any file. Wrong-repository edits require a full revert session to undo.

---

## Step 7 — Output

Save the prompt as a markdown file directly to the vault. The vault is a
plain folder on disk — do **not** use the Obsidian CLI (it is flaky and
silently fails on path resolution).

Vault root: `$HOME/Developer/obsidian`

Steps:
1. Use the `Write` tool to save the prompt to:
   `$HOME/Developer/obsidian/AI/plans/<kebab-slug>.md`
2. Confirm success by printing the absolute path.

Do not paste the prompt inline. Do not save to `/mnt/user-data/outputs/`.
Do not use `Bash` + `Obsidian.app …`. The `Write` tool is the only correct
mechanism.

---

## Common shapes

**Bug fix:**
```
Confirm the active repository with `git remote -v` before doing anything.
Read CLAUDE.md before writing any code.

## Task
[What is broken and what correct behaviour looks like]

## Investigation
1. Find [specific thing] in [area of codebase]
2. Trace whether [condition A] or [condition B] is true
3. [What a correct fix looks like — not how to implement it]

## Constraints
- Fix ONLY [the specific regression]
- Touch the MINIMUM number of files — ideally one
- Do NOT refactor, rename, or change architecture

## Verification
1. `xcodebuild build …` — zero errors, zero warnings (SourceKit is not authoritative)
2. `xcodebuild test …` — all existing tests pass
3. [Specific grep confirming the fix]

**Model & mode:** Sonnet, normal mode — targeted fix, known location
```

**Feature build (execute phase):**
```
Confirm the active repository with `git remote -v` before doing anything.
Read the following files in order before writing any code:
1. [skill file path]
2. CLAUDE.md
3. [plan or architecture doc]

Do not write any code until you have read all three.

## Task
[What is being built]

## Implementation
[Ordered steps in dependency order]

## Constraints
[What must not change]

## Verification
1. Build must pass with zero errors and zero warnings
2. [Test suite command] — all tests pass
3. [Grep / diff confirming expected files changed]

Stage files explicitly by path before each commit. Do not use `git add -u`.

**Model & mode:** Sonnet, normal mode — clear spec, mechanical execution
```

---

## Correction Detection

During any Claude Code session, if Claude has to self-correct — retries a tool
call, backtracks on an approach, fixes its own output, or recovers from a
misunderstanding — it must record the correction before continuing.

### What counts as a correction

- A tool call fails and Claude tries a different approach
- Claude writes code then revises it because it misread a file or API
- Claude misidentifies a type, property path, or file and has to re-read
- Claude applies a pattern that violates project conventions and catches itself
- Claude produces output the user rejects and has to redo

### What does NOT count

- Normal iterative refinement the user requested
- Adding to or expanding output the user asked to extend
- Fixing a typo or formatting issue in the response

### How to record a correction

Append to a `## Corrections` section in the active plan file or session
scratchpad immediately at the moment of self-correction:

```markdown
## Corrections

### {Short title of mistake}
- **What I did**: {one sentence — the wrong thing}
- **Why it was wrong**: {one sentence — root cause}
- **What I did instead**: {one sentence — the fix}
- **Rule to remember**: {one sentence — generalised lesson}
```

### Example

```markdown
## Corrections

### Used stream.channelId instead of channel.chatroom.id for subscription
- **What I did**: Passed `stream.channelId` as the chatroom ID to `joinChatroom()`
- **Why it was wrong**: channelId and chatroomId are different values; Stream does not carry chatroomId
- **What I did instead**: Read `channel.chatroom.id` from the full Channel model
- **Rule to remember**: Always read the Channel model before assuming Stream carries channel metadata
```