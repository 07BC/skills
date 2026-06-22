# Recipes

Task-shaped, copy-paste walkthroughs that chain the commands in this library end to end. Where
[skill-catalogue.md](../skill-catalogue.md) tells you *what* each skill is and
[delivery-lifecycle.md](../delivery-lifecycle.md) walks the manual path stage by stage, a recipe
answers one question: **"I have X, I want a PR — what do I run, in what order?"**

Each recipe names the **exact command and input flag** at every step, so there's no guessing
which of `--from-issue`, `--from-jira`, `--from-spec`, `--from-master`, or `--from-master-doc`
applies. Pick your starting point below.

---

## Which recipe?

| I have… | I want… | Recipe |
|---|---|---|
| One story or subtask (`NAT-1234`) | One PR | [single-story-to-pr](./single-story-to-pr.md) |
| A scoped ticket with many ACs | One PR **per child**, reviewable in sequence | [ticket-to-per-child-prs](./ticket-to-per-child-prs.md) |
| A scoped ticket with many ACs | **One** PR for the whole thing, unattended | [ticket-to-single-pr-autonomous](./ticket-to-single-pr-autonomous.md) |
| A rough idea / no ticket yet | Per-child PRs, with full upstream planning | [prd-to-prs-via-spec-pipeline](./prd-to-prs-via-spec-pipeline.md) |
| A rough idea / no ticket yet | One PR, unattended, with full upstream planning | [prd-to-single-pr-via-spec-loop](./prd-to-single-pr-via-spec-loop.md) |

**Rule of thumb:** `/workflow` drives **one subtask**; `/spec-pipeline` drives **one spec**
(per-child PRs); `/spec-loop` drives a **whole master** to **one** PR, unattended.

---

## Which "master" does what

Three independent trees turn up across these recipes. They are easy to conflate, so this is the
one place the distinction is spelled out — recipes link here rather than re-explaining.

| Tree | Created by | Consumed by | Why it exists |
|---|---|---|---|
| **Jira hierarchy** — parent ticket + Jira subtasks | [`/discovery`](../../commands/Mr%20Will/discovery.md) (jira backend) or [`/workflow`](../../commands/Mr%20Will/workflow.md) Phase 2 | `/spec-pipeline --from-jira <subtask>`, `/workflow <KEY>` | Product tracking — the *what* and *why*, team burndown |
| **GitHub architecture-tracking tree** — master issue + sub-issues | [`discovery-init`](../../skills/discovery/discovery-init/SKILL.md) | [`discovery-check`](../../skills/discovery/discovery-check/SKILL.md) · [`discovery-audit`](../../skills/discovery/discovery-audit/SKILL.md) | Architecture drift detection across a story |
| **GitHub spec tree** — master + child sub-issues, frozen AC IDs | [`spec-decomposition`](../../skills/engineering/spec-decomposition/SKILL.md) | `/spec-pipeline --from-issue <#>`, `/spec-loop --from-master <#>` | The technical *how* — the only tree the spec orchestrators consume |

> **Key gap to know:** `/spec-loop` consumes **only** the GitHub spec tree (or a local master
> doc with `master_acs:` frontmatter). It **cannot** ingest a Jira subtask. Any journey ending
> in `/spec-loop` therefore mints a spec master with `/spec-decomposition` first. `/spec-pipeline`
> is more flexible — it takes a spec-tree child (`--from-issue`), a Jira subtask (`--from-jira`),
> a local spec (`--from-spec`), or a prompt.

---

## Stage 0 — shared upstream planning (greenfield only)

The two `prd-to-…` recipes both start from a rough idea and share this upstream. It's written
once here; those recipes reference it and then diverge.

1. **`/product-planning`** ([skill](../../skills/documentation/product-planning/SKILL.md)) —
   decompose the idea into `docs/PRD.md` + build-ordered `docs/stories/NN-*.md`.
2. **`/architecture-doc`** ([skill](../../skills/documentation/architecture-doc/SKILL.md)) —
   produce `docs/architecture.md`, the architecture authority the spec orchestrators read
   (`target_architecture_doc` in config).
3. **`/discovery <input>`** ([command](../../commands/Mr%20Will/discovery.md)) with
   `discovery: { backend: jira }` in the project `CLAUDE.md` — Three-Amigos planning + scope
   trim, then materialises a **Jira parent + one subtask per story** and the GitHub
   architecture-tracking tree via `discovery-init`.

After Stage 0 you have a Jira parent with subtasks. The two recipes diverge there: one feeds the
subtasks straight to `/spec-pipeline`; the other decomposes the parent into a spec master for
`/spec-loop`.

---

## Conventions

- Every recipe: **When to use · Prerequisites · Steps · What you get · If it stalls · Variant.**
- Config lives in the project's `CLAUDE.md` — `spec_pipeline:` block (see
  [SCHEMA.md](../../skills/engineering/spec-pipeline/SCHEMA.md)) and, for `/discovery`, a
  `discovery:` block.
- When a run halts, see
  [delivery-lifecycle.md → When a run fails](../delivery-lifecycle.md#when-a-run-fails).
