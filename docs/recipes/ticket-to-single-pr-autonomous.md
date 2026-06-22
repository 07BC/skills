# Recipe: ticket with many ACs → one PR, unattended

Take a scoped Jira ticket with many ACs and drive the **whole thing** to a **single** PR with
[`/spec-loop`](../../skills/engineering/spec-loop/SKILL.md), running unattended on one branch.

## When to use

- You want the entire ticket built end to end **without babysitting** — no per-child stops.
- One PR for the whole master is acceptable (you'll review it as a unit).
- The pieces have clear dependencies that can be satisfied **on one branch**.

For independently reviewable PRs per piece, use
[ticket-to-per-child-prs](./ticket-to-per-child-prs.md) instead.

## Prerequisites

- Project `CLAUDE.md` with a `spec_pipeline:` block (+ optional `spec_loop_max_sweeps`). See
  [SCHEMA.md](../../skills/engineering/spec-pipeline/SCHEMA.md).
- **Atlassian MCP** (to read the ticket) and **`gh` CLI** (for the spec tree + PR).
- See [Which "master" does what](./README.md#which-master-does-what) — `/spec-loop` consumes the
  **GitHub spec tree**, so you must mint one first.

## Steps

1. **Decompose the ticket into a spec tree** (the bridge `/spec-loop` requires — it cannot take a
   Jira ticket or subtask directly):

   ```
   /spec-decomposition --from-jira NAT-1234
   ```

   This creates the GitHub **master issue** + child sub-issues with frozen AC IDs, `covers:`, and
   `depends_on:`. Note the **master issue number**.

2. **Drive the whole master to one PR:**

   ```
   /spec-loop --from-master 408
   ```

   [`/spec-loop`](../../skills/engineering/spec-loop/SKILL.md) resolves the children, creates one
   fresh branch, and **sweeps them sequentially** in dependency order — each child runs the same
   inner chain `/spec-pipeline` uses (engineer → test → concurrency → dual review → commit). Here a
   dependency is satisfied once it's **committed on this branch** (not merged to main), because it
   all lives on one branch. It runs **with no prompts mid-loop**.

3. **Confirm the single PR.** The loop finishes only when every master AC is covered, tested,
   passing, and a whole-diff review against the master passes — then it opens **one** PR with `gh`
   and stops for your confirmation.

> No GitHub issue? Use `/spec-loop --from-master-doc <path>` instead — but the doc must carry
> frozen AC IDs in `master_acs:` frontmatter; `/spec-loop` then decomposes it itself. A plain PRD
> or story file will **not** work (see the greenfield recipe below).

## What you get

- One branch, one PR for the entire master.
- A committed `progress.md` tracker (rendered from git, the source of truth on resume).
- Parked children + open questions reported at the end if anything couldn't be resolved.

## If it stalls

`/spec-loop` has finite termination guarantees — a sweep ceiling (`spec_loop_max_sweeps`), a stall
detector, and parking for unresolvable ambiguity. On halt it writes a report; re-invoke on the same
branch to resume (done children are skipped). See
[delivery-lifecycle.md → When a run fails](../delivery-lifecycle.md#when-a-run-fails).

## Variant

- Want each piece as its own PR → [ticket-to-per-child-prs](./ticket-to-per-child-prs.md).
- Starting from a rough idea, no ticket → [prd-to-single-pr-via-spec-loop](./prd-to-single-pr-via-spec-loop.md).
