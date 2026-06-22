# Skill and agent naming convention

The skill/agent namespace had drifted: skills and agents shared names with no
signal of which was which (`swift-engineer` skill vs `swift-developer` /
`senior-swift-engineer` agents), role words were used as interchangeable
synonyms (developer/engineer, reviewer/auditor), the `swift-` prefix was applied
unevenly, and the `swift-mv-architect` / `swift-mvvm-architect` skills collided
semantically with the `swift-architect` agent. We adopted one convention and
applied it across all skills and agents.

## Decision

1. **Part of speech encodes type.** Agents are **role nouns** (developer,
   reviewer, auditor, writer, debugger, profiler, planner, distiller, guardian,
   manager, cartographer, architect). Skills are **activity/domain nouns or
   imperative commands** — never a role noun. A role does work (agent); an
   activity is applied (skill).
2. **Part of speech disambiguates collisions.** Skill `-architecture` (the
   knowledge/rules) vs agent `-architect` (the worker). Skill `swift-engineering`
   (the discipline) vs agents `*-developer` (the workers).
3. **reviewer vs auditor is a kept distinction.** reviewer = bounded gate on a
   diff/PR (pass-fail); auditor = broad sweep of a file set for a class of finding.
4. **Prefix = namespace/bucket purpose:** `swift-` (Swift/general), `swiftui-`
   (SwiftUI view-layer), `spec-` (spec-pipeline agents), `ios-` (iOS
   runtime/device), plus `obsidian-`, `git-`, `discovery-`, `yt-`.
5. **Swift-writing agents standardise on "developer"; the discipline skill is
   "engineering".**

## Renames applied

Skills: `swift-engineer`→`swift-engineering`, `swift-mv-architect`→
`swift-mv-architecture`, `swift-mvvm-architect`→`swift-mvvm-architecture`,
`pm`→`product-planning`, `engineer-brief`→`implementation-brief`,
`spec-master`→`spec-decomposition`.

Agents: `senior-swift-engineer`→`senior-swift-developer` (**`senior-swift-developer` subsequently deprecated in favour of `swift-developer` / `swift-tvos-developer` — see ADR 0017**),
`ios-runtime-diagnostics`→`ios-runtime-profiler`, and the spec-pipeline set into
the `spec-` namespace — `engineer`→`spec-engineer`, `planner`→`spec-planner`,
`test-writer`→`spec-test-writer`, `quality-reviewer`→`spec-quality-reviewer`,
`task-reviewer`→`spec-task-reviewer`, `concurrency-auditor`→
`spec-concurrency-auditor`, `drift-auditor`→`spec-drift-auditor`,
`swift-spec-review`→`spec-branch-reviewer`.

## Consequences

- Renames the slugs introduced in ADR 0015 (see its naming note).
- `subagent_type` invocation strings and `$agents_dir/*.md` paths in the
  spec-pipeline orchestrator were updated to the `spec-` names; the agents'
  frontmatter `name:` fields match.
- Historical records (`docs/adr/*` except this file's note on 0015, `AUDIT.md`)
  were left untouched — they record what was true when written.
- Flagged but out of scope (function decides, not naming): `swift-debugger` vs
  `ios-runtime-profiler` overlap; `swift-developer` vs `senior-swift-developer`
  overlap. Both were consolidation candidates. **Superseded: `senior-swift-developer`
  has since been deprecated and moved to `agents/deprecated/` (see ADR 0017);
  `swift-debugger` was renamed `swift-debugger-agent` to match its `name:` frontmatter.**
