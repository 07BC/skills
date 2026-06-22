---
name: engineer-brief
description: >
  Reads the existing target architecture docs and produces a scoped brief for a
  single subtask — the engineer's primary input, written before any code is
  touched. Use in Phase 3 of ticket-to-pr, immediately before handing off to the
  engineer subagent. Triggers when a subtask is ready for implementation and the
  engineer needs to know exactly which types to touch, which edge cases to
  handle, and which patterns to follow — without re-reading the full architecture
  docs themselves. Do NOT use this skill for full codebase audits or architecture
  adherence checks (use swift-mv-architect or swift-mvvm-architect) or to author
  the architecture document itself (use architecture-doc).
---

# Swift Discovery Skill

Produces a scoped discovery note for a single subtask. The output is the
engineer's primary input — it must be precise enough that the engineer does
not need to re-read the full architecture docs themselves.

**Read first. Write second. Never guess from filenames or type names alone.**

---

## What this skill does NOT do

- Does not write implementation code
- Does not produce a full architecture document (use `architecture-doc` for that)
- Does not audit the codebase (use `audit` for that)
- Does not make implementation decisions — it surfaces constraints and edge
  cases so the engineer can make informed decisions

---

## Phase 1 — Read the Target Architecture

Read the following in order before looking at any code:

1. `CLAUDE.md` — follow every linked doc from it
2. All files in `docs/` — these define what correct looks like
3. The subtask description and its definition of done

Do not open any Swift files yet. Understand the target first.

Produce a one-sentence baseline:
> "This subtask must conform to [pattern] as defined in [doc]."

---

## Phase 2 — Locate the Subtask in the Codebase

Run targeted searches to find what this subtask actually touches.
Do not browse the whole codebase — find only what is relevant.

```bash
# Find types named in the subtask description
grep -r "[TypeName]" . --include="*.swift" -l

# Find the layer this subtask belongs to
find . -path "*/Services/*" -name "*.swift" | head -20
find . -path "*/Views/*" -name "*.swift" | head -20
find . -path "*/Actors/*" -name "*.swift" | head -20
find . -path "*/Models/*" -name "*.swift" | head -20

# Find existing protocol definitions the subtask must conform to
grep -r "protocol [Name]" . --include="*.swift"

# Find injection points for this type
grep -r "AppDependencies\|@Entry\|@Environment" . --include="*.swift" -l
```

Read every file you find above. Do not skip this step.

---

## Phase 3 — Identify What the Subtask Touches

For each type or file the subtask involves, record:

**Existing types touched**
- Type name, file path, current responsibility
- Whether it is a service, actor, view, or model
- Its isolation domain (`@MainActor`, `actor`, unspecified)
- Its current protocol conformances

**New types required**
- What needs to be created (service, actor, model, view)
- Which layer it belongs to
- What protocol it must conform to

**Injection points**
- Where does the new or modified type get injected?
- Is it registered in `AppDependencies`?
- Is it passed via `@Environment`, `@Entry`, or init?

**Concurrency boundaries**
- Does this subtask cross an actor boundary?
- Is `await` required at the call site?
- Is there a `@MainActor` ↔ `actor` boundary to manage?
- Does any value cross a concurrency boundary that must be `Sendable`?

---

## Phase 4 — Discover Edge Cases

Based on the subtask requirements and the architecture docs, identify:

**Failure paths**
- What can fail at the network layer? (`KickError` variants)
- What can fail at the persistence layer? (SwiftData errors)
- What should the service expose on failure? (`self.error`, `isLoading`)

**State edge cases**
- What does the state look like on fresh install?
- What happens if the subtask is triggered before data is loaded?
- What happens if the subtask is triggered twice concurrently?

**Concurrency edge cases**
- Is there a risk of a retain cycle in a `Task { }` closure?
- Does any `async` call need a `Task.detached` or should it be structured?
- Is there an `AsyncStream` that needs cancellation handling?

**Scope edge cases**
- Which files must NOT be touched by this subtask?
- Which public API surfaces must remain unchanged?
- Which protocol conformances must not be broken?

---

## Phase 5 — Write the Discovery Note

Derive the output path:

```bash
project_name="$(basename "$(git rev-parse --show-toplevel)")"
discovery_note="${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md"
```

Write the discovery note to `$discovery_note`. This location matches the
global plan-storage rule (plans live in the Obsidian vault, never inside
the repo) and is what the orchestrator's PR gate reads from.

Use this format exactly — every section header below must be present.
Pipeline orchestrators grep for these headers to validate the note before
handing off to the engineer.

```markdown
# Discovery: [SUBTASK-KEY] — [Subtask title]

## Baseline
[One sentence: what pattern/doc this subtask must conform to]

## Types in scope

### Existing
| Type | File | Isolation | Role in this subtask |
|---|---|---|---|
| FooService | Services/FooService.swift | @MainActor | Add fetchBar() method |

### New
| Type | Layer | File path | Conforms to |
|---|---|---|---|
| BarModel | Models | Models/BarModel.swift | Sendable, Decodable |

## Injection
[Where the new/modified type is injected and how]

## Patterns to follow
- [Pattern 1 — with doc reference]
- [Pattern 2 — with doc reference]

## Concurrency notes
[Any actor boundaries, Sendable requirements, or Task management concerns]

## Edge cases to handle
1. [Edge case — what correct behaviour looks like]
2. [Edge case — what correct behaviour looks like]

## Failure paths to handle
1. [Failure — how the service should surface it]
2. [Failure — how the service should surface it]

## Must NOT touch
- [File or type that is out of scope]
- [Protocol conformance that must not change]

## Definition of done
[One sentence from the subtask, restated as a verifiable condition]
```

---

## Phase 6 — Validate Before Handing Off

Before writing the file, check:

- [ ] Every type listed in "Types in scope" actually exists in the codebase
- [ ] Every file path listed is correct and confirmed via `find` or `cat`
- [ ] Every pattern reference points to an actual doc in `docs/`
- [ ] Edge cases are specific to this subtask — not generic Swift advice
- [ ] "Must NOT touch" list is complete — scope creep starts here

If any check fails, go back to Phase 2 and search more carefully.
Do not produce a discovery note with unverified type names or file paths.

---

## Output

A single file at `${HOME}/Developer/obsidian/${project_name}/plans/[SUBTASK-KEY]-discovery.md`.

The engineer reads this file first — before `CLAUDE.md`, before any other
architecture doc. It must stand alone as a complete brief.

Every required section header below must appear verbatim, so orchestrators
can grep for them:

- `## Baseline`
- `## Types in scope`
- `## Injection`
- `## Patterns to follow`
- `## Concurrency notes`
- `## Edge cases to handle`
- `## Failure paths to handle`
- `## Must NOT touch`
- `## Definition of done`

If a section truly has nothing to record for a given subtask, write
`None for this subtask.` underneath the header rather than omitting the
header.
