# Architecture & conventions

How the library is structured, the conventions it enforces, and how to extend it. For day-to-day usage start at the [README](../README.md); for the full skill list see [skill-catalogue.md](./skill-catalogue.md).

---

## Conventions

The library follows a few documented conventions, all enforced or recorded:

- **Orchestrator contract** — every orchestrator (`workflow`, `uitest`, `audit`, `solve`, `spec-pipeline`) shares one structure: variables block, model declaration, preflight, phase gates, halt conditions, and a state-placement convention. See [`orchestrator-contract.md`](./orchestrator-contract.md). `tests/python/test_orchestrator_conformance.py` enforces it.
- **Skill species** — skills are **executor** (default; auto-fires), **policy** (cited by orchestrators, never auto-fires — `disable-model-invocation: true`), or **dependency** (loaded by another skill — `user-invocable: false`). See the "Skill species" section in [`CLAUDE.md`](../CLAUDE.md); `tests/python/test_skill_taxonomy.py` enforces the markers.
- **State placement** — each kind of cross-agent state has a designated home (GitHub issues / JIRA / Obsidian audit log / `PLANS_DIR` / tmp-by-path). See the "State placement" table in the orchestrator contract.
- **Decision records** — structural decisions about the library live as ADRs in [`adr/`](./adr/), written with the `/skills-adr` skill.

Run the test suite that backs these conventions with `make test`.

---

## Layout

```
Makefile                        — install, link, commands, hook, test targets
scripts/link-skills.sh          — symlinks skills into ~/.claude/skills/ (flattens by name, skips deprecated/)
scripts/link-commands.sh        — symlinks commands into ~/.claude/commands/
commands/                       — slash-command orchestrators
agents/                         — specialist subagents (symlinked into ~/.claude/agents/)
docs/orchestrator-contract.md   — the shared orchestrator structure + state-placement convention
docs/adr/                       — architecture decision records for the library
tests/python/                   — conformance + script tests (make test)
skills/discovery/               — architecture master-issue tracking (init, check, audit, jira)
skills/documentation/           — spec, PRD/stories (product-planning), implementation-brief, DocC, architecture-doc, and skills-ADR authoring
skills/engineering/             — Swift / iOS / Xcode / CI / concurrency skills + spec-pipeline
skills/git/                     — generic git workflow skills
skills/obsidian/                — Obsidian vault management skills
skills/personal/                — personal setup skills (not listed here; symlinked locally)
skills/pipelines/               — orchestration policy helpers (preflight, subagent reliability)
skills/productivity/            — Jira, framing, YouTube research
skills/testing/                 — Swift testing, quality, UI testing, regression auditing
skills/in-progress/             — drafts; not auto-discovered
skills/deprecated/              — retired skills; skipped by link-skills.sh
```

---

## Adding a skill

1. Create `skills/<bucket>/<name>/SKILL.md` with `name:` and `description:` frontmatter.
2. Add a row to the relevant table in [skill-catalogue.md](./skill-catalogue.md) using the `/<name>` format.
3. Run `make link` to expose it locally.

## Adding a command

1. Create `commands/<bucket>/<name>.md` with the command definition.
2. If it is an orchestrator, follow [`orchestrator-contract.md`](./orchestrator-contract.md) and add it to the `ORCHESTRATORS` list in `tests/python/test_orchestrator_conformance.py`.
3. Add a row to the Commands table in [delivery-lifecycle.md](./delivery-lifecycle.md) and run `make commands`.

See [`CLAUDE.md`](../CLAUDE.md) for the full bucket convention, the skill-species taxonomy, and the `in-progress` / `deprecated` lifecycle.
