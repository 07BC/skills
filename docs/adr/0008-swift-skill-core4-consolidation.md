# Swift skill core-4 consolidation and deterministic engineering-chain load

## Context

When writing Swift, the engineering skills (`swift-engineer`, `swift-style`,
`swift-mv-guardian`) were not reliably picked up — roughly 25 Swift skills
scattered across the trigger space, and quality/review/test/refactor skills
won the auto-fire competition instead of the writing skill. The output then
failed to match the project's MV architecture and swift-style rules.

Two root causes were identified:

1. **No deterministic load** — `swift-engineer` loaded companions via passive
   prose ("Read skill `swift-style`"), which only fires if swift-engineer
   itself was selected. With no hook wired to Swift file edits, the chain
   was reachable only when the auto-fire lottery landed on the right skill.
2. **Crowded trigger surface** — `swift-quality`, `swift-concurrency-expert`,
   `swift-pre-pr-review`, `swift-deep-audit`, `swiftui-view-refactor`, and
   `swiftui-ui-patterns` all competed for write/refactor/review trigger phrases.

The fix is two-pronged: a deterministic hook that fires on every `.swift` file
edit, and aggressive consolidation of the genuine competitors.

## Decision

### Part A — Deterministic hook

`hooks/swift-engineer-loader.sh` was created (mirrors `git-commit-reminder.sh`).
It is registered as a `PreToolUse` hook on `Edit|Write|MultiEdit|…XcodeWrite|…XcodeUpdate`.
It reads stdin JSON, extracts `tool_input.file_path`, and — if the path ends in
`.swift` — emits an `additionalContext` message forcing the engineering chain
(swift-engineer + swift-style + swift-mv-guardian) to be loaded and applied
before the edit proceeds.

This makes chain pickup independent of how the request was phrased, and fires
on the concrete action (editing a `.swift` file), not on description matching.

### Part B — Core-4 consolidation

Organising rule: **overlapping trigger + same work-type → fold as a documented
mode inside the survivor; disjoint trigger + distinct capability → keep.**

**Core 4 (rewritten, de-conflicted descriptions):**

| Role | Skill |
|---|---|
| write / edit / rewrite | `swift-engineer` |
| review existing code | `swift-code-review` |
| unit tests | `swift-testing` |
| architecture setup/audit | `swift-mv-guardian` |

**Folds (7 skills removed):**

- `swift-quality` → folded into `swift-engineer` as the "Rewrite and migrate
  (no behaviour change)" mode. Includes the full `ObservableObject → @Observable`
  migration procedure. The style rules that already lived in `swift-style` were
  not duplicated — `swift-style` remains the authority and is loaded by
  swift-engineer automatically. Deprecated and removed from README.

- `swift-concurrency-expert` → folded into `swift-engineer` as the "Fix
  concurrency in existing code" mode. Includes the triage-and-fix diagnostic
  loop. `swift-concurrency` remains unchanged as a Reference (conceptual only,
  `user-invocable: false`). Deprecated and removed from README.

- `swift-pre-pr-review` → folded into `swift-code-review` as the "Deep /
  Adversarial mode" section. Includes the 8-section adversarial checklist
  and the Critical/High/Medium/Low findings document format. Standard diff
  review is the default; deep mode is explicitly triggered. Deprecated.

- `swift-deep-audit` → the standalone skill was deprecated. Its unique depth
  (Fowler separation-of-concerns, domain layering, test-suite quality checks)
  was folded into the per-layer subagent prompt in `/audit-codebase` Phase 3.
  The capability already existed in the `/audit-codebase` orchestrator (ADR 0005);
  having a competing standalone skill only added a third auto-fire target for
  "audit" triggers.

- `swiftui-view-refactor` → folded into `swift-engineer` as the "SwiftUI View
  Structure" mode (view ordering, subview extraction, stable-tree rules, large-view
  handling). Zero cross-refs; was not in README.

- `swiftui-ui-patterns` → folded into `swift-engineer` (state ownership table,
  sheets guidance). Zero cross-refs; was not in README.

- `swiftui-liquid-glass` (prototype copy) → deprecated. Name-collision: both
  `skills/engineering/swiftui-liquid-glass/` and `skills/prototype/swiftui-liquid-glass/`
  declared the same `name: swiftui-liquid-glass`, causing `link-skills.sh` to
  collide. The engineering copy (listed in README) survives; the prototype copy
  is deprecated as `swiftui-liquid-glass-prototype`.

**Promoted:**

- `swiftui-performance-audit` → promoted from `skills/prototype/` to
  `skills/engineering/` and added to README. Distinct Instruments/runtime-perf
  workflow — not a code-review or write subset.

**In-progress migration:**

- `ios-app-intents`, `ios-debugger-agent`, `ios-ettrace-performance`,
  `ios-memgraph-leaks` → moved from `skills/prototype/` to `skills/in-progress/`.
  Not part of the core-4 consolidation. `link-skills.sh` does NOT exclude
  `in-progress/` — these skills are still auto-discovered. They are not listed
  in README. A separate pass is needed to decide ship-vs-consolidate for each.

## Considered Options

- **"Describe only" approach** — tighten descriptions without folding skills.
  Rejected: descriptions are parsed by the auto-fire heuristic from training
  data and do not provide the same guarantee as a hook. Crowded descriptions
  also drift back toward overlap over time.
- **Role-agents** — introduce dedicated agents for write/review/test rather
  than folding. Rejected: delegation does not fix inline output quality and
  splits context; agents are the wrong tool for the stated pain (write-time
  consistency). "Agents-first" was explicitly discussed and dismissed.
- **Keep `swift-quality` separate** — argument: rewrite-mode is a mood-shift
  task (ruthless about existing structure vs greenfield). Rejected: the trigger
  overlap ("refactor/clean up") is exactly the non-determinism being paid to
  remove. Capability preserved as a clearly-delimited mode with a "no behaviour
  change" guardrail.
- **Fold `swift-uitest`/`swift-uitest-debug` into `swift-testing`** — rejected:
  XCUITest IS XCTest, runs out-of-process, cannot import app code. Folding would
  directly contradict swift-testing's own body ("NOT for XCTest"). Kept as niche.

## Consequences

- AUDIT.md was deliberately left untouched — it is an append-only historical
  record (per ADR 0007). Any references to deprecated skills there are historical
  records, not stale pointers.
- `docs/adr/0004`, `0005`, `0006`, `0007` were not edited — historical records.
- `swift-style` frontmatter markers (`user-invocable: false` +
  `disable-model-invocation: true`) were not changed — pinned by
  `tests/python/test_skill_taxonomy.py`.
- Runtime-critical rewrites: `commands/Mr Will/workflow.md` Phase 6 (swift-quality
  → swift-engineer rewrite mode) and Phase 3 (swift-concurrency-expert →
  swift-engineer fix-concurrency mode); plus cross-refs in swift-mv-guardian,
  swift-style, swift-code-review, swift-tvos, swift-concurrency, regression-check.
- Verification gate in force: `grep -rn "swift-quality|swift-concurrency-expert|swift-pre-pr-review|swift-deep-audit|swiftui-view-refactor|swiftui-ui-patterns" commands/ skills/ README.md | grep -v deprecated | grep -v docs/adr` must return empty after all phases.
- 7 skills removed from auto-discovery; 0 distinct capabilities lost.
- Hook registered idempotently: running `make hook` twice leaves exactly one
  `PreToolUse` entry for `swift-engineer-loader.sh`.
