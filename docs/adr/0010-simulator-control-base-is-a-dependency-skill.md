---
status: accepted
---

# The shared simulator-control base loop is a dependency skill, not an agent

The base XcodeBuildMCP loop — discover the booted simulator, set session
defaults, build/run the scheme, drive the UI, capture logs — lives as a
**dependency skill** at `skills/engineering/ios-simulator-control/SKILL.md`
(`user-invocable: false` + `disable-model-invocation: true`). It is referenced
by the `swift-debugger-agent` and `ios-runtime-diagnostics` agents, and paired
by the `ios-ettrace-performance` and `ios-memgraph-leaks` skills via a
`../ios-simulator-control/SKILL.md` relative path. This base loop was previously
the `ios-debugger-agent` skill; an in-progress migration had deleted it and
copied its body verbatim into a new `swift-debugger-agent` agent, which both
broke the two skills that paired with it by file path and duplicated the loop.

The decision: the base loop stays a **skill** because in this repo skills
compose with sibling skills by reading `../sibling/SKILL.md` (the swift-style
pattern), but **a skill cannot cleanly depend on an agent** — agents are spawned
by the main loop, not read by skills. So the shared loop must be a skill for the
two consuming skills to keep composing with it. The focused debugger stays a
separate *agent* (`swift-debugger-agent`) that reads the skill rather than
embedding it.

## Considered options

- **Agent-owned base loop** — `swift-debugger-agent` is the canonical home of the
  loop and the skill stays deleted. Rejected: `ios-ettrace-performance` and
  `ios-memgraph-leaks` would lose their file-path pairing and have to inline the
  build/launch/UI steps themselves (re-duplicating the content) or be rewritten
  to delegate to an agent. The skill-composition pattern only works skill→skill.
- **Keep the `ios-debugger-agent` skill name** — restore the skill under its old
  name. Rejected: a *skill* named `…-agent` sitting beside an actual
  `swift-debugger-agent` *agent* is its own rot trap; renamed to
  `ios-simulator-control`, which names the shared capability.

## Consequences

- `swift-debugger-agent` and `ios-runtime-diagnostics` now overlap (both are
  simulator agents that read the same base skill); they are deliberately kept
  separate — `swift-debugger-agent` is the focused debugger behind `/debug-sim`,
  `ios-runtime-diagnostics` is the multi-mode agent (debugger + ETTrace +
  memgraph) behind `/ettrace` and `/leak-hunt`. Consolidating them was explicitly
  out of scope.
- Registered in `DEPENDENCY_SKILLS` in `tests/python/test_skill_taxonomy.py` so
  its `user-invocable: false` + `disable-model-invocation: true` markers can't
  silently regress (see [[0004-skill-species-invocation-frontmatter]]).
- The skill→skill file-path pairing (`../ios-simulator-control/SKILL.md`) is a
  dependency edge that no test currently guards — the command-reference guard
  added alongside this work only covers the command layer. A follow-up could
  extend it to validate relative-path `../*/SKILL.md` references between skills.
- `docs/adr/0008-swift-skill-core4-consolidation.md` still names the old
  `ios-debugger-agent` skill; that ADR is immutable and describes the state at
  the time it was written, so it is left unchanged.
