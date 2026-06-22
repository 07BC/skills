# Recipe: rough idea → PRD → per-child PRs

Start from a rough idea with no ticket, plan it properly, materialise Jira work items, then ship
each subtask as its own PR with [`/spec-pipeline`](../../skills/engineering/spec-pipeline/SKILL.md).

## When to use

- There's **no ticket yet** — you're starting from an idea or a loose feature request.
- You want full upstream planning (PRD + architecture authority + reviewed scope) before code.
- You want **independently reviewable PRs**, one per planned subtask.

For one unattended PR from the same starting point, use
[prd-to-single-pr-via-spec-loop](./prd-to-single-pr-via-spec-loop.md).

## Prerequisites

- Project `CLAUDE.md` with a `spec_pipeline:` block **and** a `discovery: { backend: jira }`
  block. See [SCHEMA.md](../../skills/engineering/spec-pipeline/SCHEMA.md) and the
  [`discovery:` config](../../commands/Mr%20Will/discovery.md).
- **Atlassian MCP**, **`gh` CLI**, and **Obsidian CLI + vault** (for plans/PRD artefacts).

## Steps

1. **Stage 0 — plan it.** Run the shared upstream once:
   [Stage 0 in the index](./README.md#stage-0--shared-upstream-planning-greenfield-only) —
   `/product-planning` → `/architecture-doc` → `/discovery <idea>` with the jira backend. This
   leaves you with a **Jira parent ticket + one subtask per story** (plus the GitHub
   architecture-tracking tree).

2. **(Optional) Author a spec per subtask.** If a subtask's spec needs sharpening before
   implementation:

   ```
   /story-to-spec --from-jira NAT-1240
   ```

   [`/story-to-spec`](../../skills/documentation/story-to-spec/SKILL.md) writes one structured
   spec doc you can feed in the next step with `--from-spec`.

3. **Ship each subtask.** For each Jira subtask, run one of:

   ```
   /spec-pipeline --from-jira NAT-1240            # straight from the Jira subtask
   /spec-pipeline --from-spec docs/specs/nat-1240.md   # if you authored a spec in step 2
   ```

   These inputs have **no sequencing/drift gates** (there's no spec-tree master to gate against),
   so order them yourself per the build order from Stage 0. Each run does distil → plan → per-task
   engineer → test → concurrency → dual review → commit → whole-diff review → PR.

4. **Confirm each PR.** The final phase opens the PR with `gh` and waits for confirmation.

## What you get

- `docs/PRD.md`, `docs/stories/NN-*.md`, `docs/architecture.md` from Stage 0.
- A Jira parent + subtasks, and one PR per subtask.

## If it stalls

See [delivery-lifecycle.md → When a run fails](../delivery-lifecycle.md#when-a-run-fails).

## Variant

- One unattended PR for the whole feature → [prd-to-single-pr-via-spec-loop](./prd-to-single-pr-via-spec-loop.md).
  Note that route does **not** feed Jira subtasks to the loop — it decomposes the parent into a
  GitHub spec master first, because `/spec-loop` only consumes a master
  ([why](./README.md#which-master-does-what)).
