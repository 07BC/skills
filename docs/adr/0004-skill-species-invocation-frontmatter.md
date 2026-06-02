---
status: accepted
---

# Skill species are distinguished by invocation frontmatter

Skills in this library fall into three species — **executor** (does work,
auto-fires on its description; the default), **policy** (cited by orchestrators
via the Skill tool, must not auto-fire on user messages), and **dependency**
(loaded by another skill, not a user action). We mark the non-default species
with Claude Code invocation frontmatter so policy skills stop being candidates to
auto-fire on a human message (the problem named in
[[0001-canonical-agent-orchestration-architecture]]): policy skills set
`disable-model-invocation: true`; dependency skills set both
`user-invocable: false` and `disable-model-invocation: true`. Executors carry
neither field.

The two fields are **not** interchangeable, which is why the convention names
both:

- `disable-model-invocation: true` — Claude will not auto-trigger the skill from
  its description, but explicit invocation still works (the Skill tool from an
  orchestrator, or a user `/command`). This is exactly what a policy skill needs.
- `user-invocable: false` — hides the skill from the user's `/` menu but does
  **not** stop Claude auto-firing it. Right for reference knowledge that should
  still surface on relevant questions (e.g. `swift-concurrency`, which keeps this
  field alone).

## Considered options

- **Reuse `user-invocable: false` for everything non-user-facing** (the field
  already present on `swift-concurrency`). Rejected: it does not stop auto-fire,
  so a policy skill marked only this way would still fire on user messages — the
  exact behaviour we are trying to prevent.
- **A documentation-only `audience:` marker, no behaviour change.** Rejected: it
  would label the species without fixing the auto-fire problem. The functional
  fields already exist; use them.
- **A bucket per species.** Rejected: buckets are presentation and a skill's
  species can change without moving it; frontmatter travels with the skill and is
  machine-checkable.

## Consequences

- Applied: `disable-model-invocation: true` on `pipeline-preflight` and
  `subagent-reliability`; both fields on `swift-style`. `swift-concurrency` keeps
  `user-invocable: false` alone. All orchestrator/skill references to these are
  explicit (`Apply skill …` / `Read skill …`), so disabling auto-invocation does
  not break how they are loaded.
- `tests/python/test_skill_taxonomy.py` enforces the policy/dependency markers so
  the convention cannot silently regress.
- The species table and field semantics are documented in the repo `CLAUDE.md`
  under "Skill species".
