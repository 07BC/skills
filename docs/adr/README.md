# Skills Repository — Architecture Decision Records

This folder records non-obvious decisions made about the `Personal/skills` repository: which skills exist, why they're shaped the way they are, what was tried and reversed, and what's been deliberately ruled out.

## When to write an ADR

- A skill is created, retired, or significantly restructured.
- A skill's metadata (e.g. `disable-model-invocation`) is toggled across multiple skills at once.
- A decision is made about routing, precedence, or hook integration that future-Jamie would otherwise re-litigate.
- A decision is reversed — the reversal gets its own ADR pointing back at the original.

## Conventions

- Filename: `NNNN-kebab-title.md` where NNNN is a zero-padded 4-digit sequence.
- Frontmatter: `status` (proposed | accepted | reversed | superseded), `date` (YYYY-MM-DD), `tags`.
- Sections: `## Context`, `## Decision`, `## Consequences`, `## Reversal/Update history` (if applicable).
- Reversals do not edit the original ADR — they create a new one and link back. The original gets its `status` updated to `reversed` with a one-line pointer to the new ADR.
- ADRs are immutable once accepted; only `status` and the `Reversal/Update history` section may be appended.

## Authoring

Use the `skills-adr` skill (in `skills/skills-adr/`) to scaffold a new ADR, or copy `TEMPLATE.md`.
