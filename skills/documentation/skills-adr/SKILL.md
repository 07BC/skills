---
name: skills-adr
description: >
  Records an Architecture Decision Record (ADR) for a skill-library decision —
  a change to how skills, commands, buckets, orchestrators, or shared conventions
  are structured. Writes a sequentially-numbered file to docs/adr/ in the skills
  repo. Use when a skill-library decision is hard to reverse, surprising without
  context, and the result of a real trade-off (e.g. "we standardised on one
  orchestrator architecture", "executor and policy skills are separated by
  bucket", "ADRs live in docs/adr/"). Triggers on "write an ADR", "record this
  decision", "skills-adr", or after a grilling/design session that settled a
  structural decision about the library itself. Do NOT use for project/code ADRs
  inside a product repo — grill-with-docs owns those.
---

# skills-adr

Records a decision about **the skill library itself** as an ADR under
`docs/adr/` in this repo (`~/Developer/Personal/skills/`). Use it when a
structural choice about skills, commands, buckets, orchestrators, or shared
conventions is worth remembering — so a future reader doesn't undo it without
knowing why.

This is the skill-library counterpart to the project-level ADR flow in
`grill-with-docs`. Same format; different scope. If the decision is about a
product codebase rather than this repo, stop and use `grill-with-docs` instead.

---

## When to write one

All three must be true — the same bar as any ADR:

1. **Hard to reverse** — undoing it later carries real cost (a bucket reshuffle,
   a convention every skill now follows, an orchestrator contract others cite).
2. **Surprising without context** — a future reader will look at the layout or a
   skill and wonder "why is it done this way?"
3. **The result of a real trade-off** — there were genuine alternatives and one
   was chosen for specific reasons.

If a decision is easy to reverse, skip it — you'll just reverse it. If it isn't
surprising, nobody will wonder. If there was no real alternative, there's
nothing to record.

### What qualifies for a skill-library ADR

- **Library shape.** "Skills are flat, invoked by name; buckets are presentation
  only." "Orchestrators are Opus-decides / Sonnet-executes, never nested."
- **Bucket and boundary decisions.** "Documentation-authoring skills live in
  `documentation/`, not `engineering/`." The explicit no-s matter as much as the
  yes-s.
- **Shared-convention choices.** "Policy skills are cited by orchestrators, never
  inlined." "Durable cross-agent state lives in <X>."
- **Deliberate deviations from the obvious path.** Anything where a reasonable
  reader would assume the opposite and try to "fix" it.
- **Rejected alternatives when the rejection is non-obvious.** e.g. "we did not
  migrate the markdown orchestrators to the Workflow primitive because …" — so
  the question doesn't get re-litigated in six months.

---

## How to write one

### 1. Find the next number

```bash
ls docs/adr/ 2>/dev/null
```

ADRs use sequential four-digit numbering: `0001-slug.md`, `0002-slug.md`, …
Scan for the highest existing number and increment by one. Create `docs/adr/`
lazily if it does not exist — only when the first ADR is needed.

### 2. Write the file

Path: `docs/adr/NNNN-short-kebab-slug.md`. The slug names the decision, not the
session.

Minimum viable ADR — a single paragraph is fine:

```md
# {Short title of the decision}

{1–3 sentences: what's the context, what did we decide, and why.}
```

The value is in recording *that* a decision was made and *why* — not in filling
out sections.

### 3. Add optional sections only when they earn their place

Most ADRs won't need these. Include one only when it adds genuine value:

- **`status` frontmatter** (`proposed | accepted | deprecated | superseded by ADR-NNNN`)
  — useful when a decision is provisional or may be revisited. When the decision
  is a recognition/direction the user hasn't fully committed to, prefer
  `proposed` and say so.
- **Considered Options** — only when the rejected alternatives are worth
  remembering.
- **Consequences** — only when non-obvious downstream effects (follow-up work,
  things that now rot if changed) need calling out.

---

## Conventions and guardrails

- **One decision per ADR.** If a session settled several, write several files.
- **ADRs are immutable once accepted.** To change a decision, write a new ADR and
  set the old one's `status` to `superseded by ADR-NNNN`. Don't rewrite history.
- **No emojis** (global rule), Australian spelling, no AI attribution.
- **Do not auto-commit.** Write the file; leave committing to the user.
- **Don't fabricate a decision.** If the user has only surfaced options and not
  chosen, either capture it as `status: proposed` and say so explicitly, or ask
  before writing. An ADR asserts a decision was made.

---

## Verification

After writing:

- The file exists at `docs/adr/NNNN-slug.md` with a number exactly one above the
  previous highest.
- It opens with a `# Title` line and states the decision and its reason in the
  first paragraph.
- Optional sections, if present, each earn their place (a rejected alternative or
  a non-obvious consequence) rather than padding.
