# Split architecture rules into two parallel architect skills

> **Naming note (ADR 0016):** the skills introduced here were renamed
> `swift-mv-architect` → `swift-mv-architecture` and `swift-mvvm-architect` →
> `swift-mvvm-architecture` to comply with the part-of-speech naming convention.
> The decision below stands; only the slugs changed.

Architecture rules were previously hardcoded inline across ~13 agents and ~8 skills,
all assuming MV (Model-View). To support both MV and MVVM, we extracted the rules
into two parallel, dedicated skills — `swift-mv-architect` (renamed from
`swift-mv-guardian`) and `swift-mvvm-architect` (new) — and made the generic
engineering layer architecture-aware.

## Decision

Every agent and skill that previously contained an inline MV checklist now instead
reads the consuming project's `CLAUDE.md` for `architecture: MV | MVVM | mixed`,
then loads the matching architect skill. Mixed, absent, or code-contradicting-declaration
triggers a stop-and-ask (preserving the behaviour from the former `swift-architect`
agent). The architect skills are Executors and auto-fire on "set up / audit" requests.

The MVVM canonical shape is `@Observable @MainActor` ViewModels + stateless
`Sendable` Repositories. The templates in `docs/MVVM target architecture/templates/`
are the living authority; `swift-mvvm-architect` quotes and references them.

## Considered Options

**Single two-mode guardian skill** — rejected. One file handling both architectures
means branching throughout, making the rules for each harder to read in isolation
and harder to extend independently.

**Auto-detect from code** — rejected. Fragile on mixed or mid-migration codebases
where both shapes coexist; produces unpredictable results exactly when correctness
matters most.

**Explicit invocation only (no default)** — rejected. Too manual; users would need
to invoke the right skill on every session. The `architecture:` key in `CLAUDE.md`
provides a project-level default that flows through automatically.

## Consequences

- Every consumed project must declare `architecture: MV` or `architecture: MVVM`
  in its `CLAUDE.md` for the auto-selection to work; absent declaration falls
  back to the stop-and-ask path.
- `swift-mv-guardian` is deprecated (tombstone under `skills/deprecated/`) and
  replaced by `swift-mv-architect`. ADR-0007 recorded the original guardian
  consolidation; this ADR records the rename and MVVM addition.
- `test_skill_taxonomy.py` is unaffected — both architect skills are Executors
  (no species frontmatter) matching the former guardian.
