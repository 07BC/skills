# Recipe: rough idea → PRD → one PR, unattended

Start from a rough idea with no ticket, plan it properly, then drive the whole feature to a
**single** PR with [`/spec-loop`](../../skills/engineering/spec-loop/SKILL.md), unattended.

## When to use

- There's **no ticket yet**, and you want full upstream planning before code.
- You want the whole feature built end to end **without babysitting**, landing as **one** PR.

For independently reviewable PRs from the same start, use
[prd-to-prs-via-spec-pipeline](./prd-to-prs-via-spec-pipeline.md).

## Prerequisites

- Project `CLAUDE.md` with a `spec_pipeline:` block (+ optional `spec_loop_max_sweeps`) **and** a
  `discovery: { backend: jira }` block.
- **Atlassian MCP**, **`gh` CLI**, **Obsidian CLI + vault**.

## Steps

1. **Stage 0 — plan it.** Run the shared upstream once:
   [Stage 0 in the index](./README.md#stage-0--shared-upstream-planning-greenfield-only) —
   `/product-planning` → `/architecture-doc` → `/discovery <idea>` with the jira backend. You now
   have a **Jira parent ticket + subtasks**.

2. **Bridge to a spec master.** `/spec-loop` cannot consume Jira subtasks — it needs a GitHub spec
   master (see [Which "master" does what](./README.md#which-master-does-what)). Mint one from the
   parent:

   ```
   /spec-decomposition --from-jira NAT-1234
   ```

   This freezes AC IDs and creates the GitHub **master issue** + child sub-issues. Note the master
   number. *(The Jira subtasks from Stage 0 remain the product-tracking tree; the spec tree is the
   technical one the loop drives — they run in parallel.)*

3. **Drive the whole master to one PR:**

   ```
   /spec-loop --from-master 408
   ```

   The loop sweeps children sequentially on one branch (engineer → test → concurrency → dual
   review → commit), with no prompts mid-loop, finishing only when every master AC is covered,
   tested, passing, and the whole-diff review passes.

4. **Confirm the single PR.** It opens one PR with `gh` and stops for your confirmation.

> Prefer to skip Jira entirely? You can hand `/spec-loop` a local master doc with
> `--from-master-doc <path>` — but the doc must carry frozen AC IDs in `master_acs:` frontmatter.
> A plain `docs/PRD.md` or story file does **not** have that shape, so the `/spec-decomposition`
> bridge in step 2 is the reliable route.

## What you get

- Stage 0 artefacts (PRD, stories, architecture doc) + Jira parent/subtasks.
- A GitHub spec master with frozen AC IDs, and **one** PR for the whole feature.

## If it stalls

`/spec-loop` has a sweep ceiling, stall detector, and parking for unresolvable ambiguity; resume
by re-invoking on the same branch. See
[delivery-lifecycle.md → When a run fails](../delivery-lifecycle.md#when-a-run-fails).

## Variant

- Independently reviewable PRs per subtask → [prd-to-prs-via-spec-pipeline](./prd-to-prs-via-spec-pipeline.md).
