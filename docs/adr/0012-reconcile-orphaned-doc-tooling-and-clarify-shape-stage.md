---
status: accepted
---

# Reconcile orphaned document-authoring tooling and clarify the Shape stage

The "Shape the work" stage had become ambiguous — "what do I use to make a
document from a Jira ticket?" had no clear answer — because two generations of
tooling were live at once. Four artefacts existed in `~/.claude/` as **real
files, not symlinks into this repo**, so they auto-fired alongside their
canonical equivalents but were invisible to `README.md`, `make link`, and the
conformance tests:

- `skills/pm/` — a PM skill that decomposes an idea/ticket into a PRD + story
  files. It auto-fired ("Always use this skill") on the *same* triggers as
  `story-to-spec` and `grill-me`, so two skills fired for one request.
- `agents/swift-spec-driven.md` — a doc→`engineering-doc.md`+`specs/*`+`plans/*`
  pipeline that predated and overlapped the staged lifecycle
  (`story-to-spec` → `architecture-doc` → `engineer-brief` → `spec-pipeline`).
- `agents/swift-spec-test-plan.md` — spec→device test plan, the missing
  "spec exists" member of the test-plan trio.
- `agents/swift-test-all.md` — a duplicate of the `swift-test-all` skill.

The decision, in two workstreams:

**Reconcile drift.** `swift-spec-driven` and the `swift-test-all` agent are
deleted (superseded / duplicate). `swift-spec-test-plan` is migrated into the
repo as `skills/testing/spec-test-plan/`, completing the trio
(`claude-regression` → no PR/no spec; `pr-test-plan` → PR/no spec;
`spec-test-plan` → spec exists). `pm` is migrated into
`skills/documentation/pm/` with a **de-conflicted description**: `pm`
decomposes into many stories, `story-to-spec` distils one ticket into one spec,
`grill-me` interrogates an already-formed plan — so exactly one fires per
request. Auto-fire is governed by a skill's *description*, so de-conflicting
descriptions (not renaming) is what resolves the trigger ambiguity.

**Clarity layer.** A "Shape & Document" decision table (I have X → I want Y →
use Z) is added to `README.md`. Two opaque skills are renamed by output:
`swiftopher-columbus` → `architecture-doc`, and `swift-discovery` →
`engineer-brief` (the latter also removes the third meaning of the overloaded
word "discovery", which already names the `discovery/` bucket and the
`/discovery` command).

## Considered options

- **Rename to fix triggering** — rejected as the *primary* lever: a skill's
  name does not drive auto-fire, its description does. Renames were done only
  for reader clarity, and treated as the expensive part (they ripple through
  orchestrators, README, and ADRs).
- **Delete `pm`, fold story-breakdown into `story-to-spec`** — rejected:
  decomposition (PRD + many stories) and distillation (one spec) are genuinely
  different jobs; collapsing them would re-blur the boundary this work draws.
- **Resurrect `swift-spec-driven` as an "architect" router** — rejected: it is
  superseded legacy, and the staged lifecycle this repo already documents is the
  deliberate decomposition of its job.
- **Rename the `discovery/` bucket and `/discovery` command too** — deferred:
  larger ripple (4 skills + a command), out of scope for this pass.

## Consequences

- `spec-test-plan`'s description, and `claude-regression`'s (a non-repo,
  plugin-provided skill), still reference the old agent name `swift-spec-test-plan`
  in their "do NOT use, use X instead" cross-links. The repo-side reference is
  fixed; `claude-regression` cannot be corrected from this canonical repo and is
  left as a known cross-skill staleness.
- An earlier in-flight rename of two command files (`audit-codebase.md` → `audit.md`,
  `uitest-pipeline.md` → `uitest.md`) was left half-done: the files were renamed on
  disk but every reference still used the old names. Since this restructure adds a
  clarity layer to the same README, the command-rename prose sweep was completed
  here too — `ORCHESTRATORS` in `tests/python/test_orchestrator_conformance.py`,
  command bodies, `docs/orchestrator-contract.md`, the project `CLAUDE.md`, the
  README, and skill cross-refs now all use `/audit` and `/uitest`. ADRs and
  `AUDIT.md` keep the old names as frozen history. `make test` is green (134 passing).
- `AUDIT.md` and `docs/adr/0007-merge-swift-architect-into-swift-mv-guardian.md`
  name `swiftopher-columbus` and `swift-discovery`; both are immutable historical
  records (AUDIT.md states "old sections are not rewritten") and are left
  unchanged, consistent with the immutability convention reaffirmed in
  [[0010-simulator-control-base-is-a-dependency-skill]].
- `pm` writes PRD/stories to the project's `docs/`, not the Obsidian vault that
  `story-to-spec` uses — an inconsistency in document home left as-is for now.
