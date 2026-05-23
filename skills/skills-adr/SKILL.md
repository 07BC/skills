---
name: skills-adr
description: >
  Scaffolds a new ADR (Architecture Decision Record) under
  `~/Developer/Personal/skills/docs/adr/`. Use when the user says "write an
  ADR", "log this decision", "ADR for <thing>", "record this skill change",
  or wants to capture a non-obvious decision about the skills repo (skill
  creation, retirement, metadata toggle, routing decision, reversal). Always
  use this skill rather than writing ADRs ad hoc — it ensures consistent
  numbering and frontmatter.
---

# skills-adr

Author an ADR for a decision about the `Personal/skills` repository. The
conventions and template live in
[`docs/adr/README.md`](../../docs/adr/README.md) and
[`docs/adr/TEMPLATE.md`](../../docs/adr/TEMPLATE.md). This skill is a
structured author — it does not invent decisions.

## Steps

1. **Find the next ADR number.** List `~/Developer/Personal/skills/docs/adr/`
   and look at filenames matching `NNNN-*.md`. Take the highest `NNNN`, add 1,
   zero-pad to four digits. If no ADRs exist yet, start at `0001`.

2. **Pick a slug.** Kebab-case, lowercase, no trailing words like "decision"
   or "adr". Australian spelling.

3. **Copy the template.** `cp ~/Developer/Personal/skills/docs/adr/TEMPLATE.md`
   to `~/Developer/Personal/skills/docs/adr/NNNN-<slug>.md`.

4. **Fill the frontmatter.**
   - `status: accepted` (default for a fresh decision). Use `proposed` only if
     the user explicitly asks. Use `reversed` only when authoring an ADR that
     reverses a previous one.
   - `date:` today's date in `YYYY-MM-DD`.
   - `tags: [adr]` — extend with topical tags if the user asks (e.g.
     `[adr, frontmatter]`).

5. **Fill the body** from the user's input:
   - `## Context` — situation, problem, trigger. Cite specific commits, files,
     audit reports, or session paths where relevant.
   - `## Decision` — one or two paragraphs of what was decided.
   - `## Consequences` — positive and negative downstream effects.
   - `## Alternatives considered` — other options evaluated and why rejected.
     If none were considered, say so explicitly; do not fabricate alternatives.
   - `## Reversal / Update history` — start with one line: `Accepted YYYY-MM-DD.`

6. **If this ADR provenance is reconstructed** (i.e. the rationale is being
   inferred from session data, daily notes, or audit reports rather than from
   the original commit message), state that explicitly in the body so future
   readers know how solid the recall is.

## Reversal ADRs

When the user is authoring an ADR that reverses a previous decision:

1. Author the new ADR as above with `status: accepted` and a `## Context`
   section that names the prior ADR (markdown link, e.g.
   `[ADR 0003](0003-foo.md)`).

2. Open the prior ADR. Edit two things only:
   - Change its frontmatter `status:` to `reversed`.
   - Append a one-line entry to its `## Reversal / Update history` section:
     `Reversed YYYY-MM-DD by [ADR NNNN](NNNN-<slug>.md).`

3. Do not edit any other section of the prior ADR. ADRs are immutable once
   accepted; the status and the history section are the only mutable parts.

## Output

Report the path of the new ADR (and the prior ADR if a reversal updated it).
Do not commit — the user reviews and commits manually.
