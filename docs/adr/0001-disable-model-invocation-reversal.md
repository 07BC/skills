---
status: reversed
date: 2026-05-20
tags: [adr, frontmatter, visibility]
---

# 0001 — Disable-model-invocation flag reversed across six skills

## Context

On 2026-05-16, commit [`35931390`](https://github.com/) ("audit: add visibility flags to mutating + reference skills") set `disable-model-invocation: true` on four skills that mutate state visible beyond the local working tree:

- `skills/git/git-commit`
- `skills/git/git-push`
- `skills/git/git-pr`
- `skills/productivity/plan-to-jira`

The rationale, recorded in [`AUDIT.md`](../../AUDIT.md) under the 2026-05-16 section, was that these skills must be explicitly user-invoked — no auto-fire from casual mentions of "commit", "push", or "ticket" — because the side effects are visible to teammates (remote pushes, GitHub PRs, Jira issues) and undo is manual.

Two additional skills were authored with the same flag set as a default for new mutating skills, without an explicit decision moment:

- `skills/productivity/jira-bulk` — created with the flag set in commit [`33e3043`](https://github.com/) ("audit: shared obsidian-path lib + jira-bulk skill"), since it performs bulk Jira mutations.
- `skills/engineering/spec-pipeline` — created with the flag set in commit [`c815231`](https://github.com/) ("add spec-pipeline skill and inner-loop agents"), since it opens PRs and creates worktrees.

By the time of the reversal, six skills carried the flag in total.

Between 2026-05-18 and 2026-05-20, attempts to invoke these skills via user-typed slash commands began failing on the Sonnet harness. Diagnosis in [`session-ab8c101f-2026-05-20`](../../../obsidian/AI/sessions/session-ab8c101f-2026-05-20.md) (continued the next day in `session-ab8c101f-2026-05-21.md`) showed that Sonnet's harness enforces `disable-model-invocation: true` as a hard block on **all** Skill tool invocations — including user-typed slash commands like `/spec-pipeline`. This is a stricter interpretation than the Opus harness applies, and made all six skills completely unusable on Sonnet. The flag's intended semantics (block auto-fire, allow explicit invocation) only hold on Opus.

On 2026-05-20, commit [`9431d38`](https://github.com/) ("Remove disable-model-invocation from six skills") removed the flag from all six skills in a single diff.

## Decision

`disable-model-invocation: true` is **reversed** on all six skills (`git-commit`, `git-push`, `git-pr`, `plan-to-jira`, `jira-bulk`, `spec-pipeline`). The flag is not safe to use as a visibility-control mechanism while Sonnet is in active use, because Sonnet's harness blocks user-typed slash commands as well as auto-invocation. The flag does not have the cross-harness semantics that the 2026-05-16 decision assumed.

In place of the flag, mutating skills must rely on:

- A `description` that requires explicit user phrasing as a trigger (which all six already had).
- The skill body asking for confirmation before executing the mutating action where appropriate (e.g. `git-pr` already confirms before pushing).
- User habit. Until a per-harness conditional mechanism exists, no metadata flag is enforced.

## Consequences

- The six skills are auto-invocable again on both Sonnet and Opus. Risk of false-positive auto-fire from casual phrasing returns to its pre-2026-05-16 level. This risk is judged tolerable because: (a) it had been the status quo for months without issue, and (b) all six skills' descriptions already require explicit user phrasing as the trigger.
- The `## Visibility` section of [`AUDIT.md`](../../AUDIT.md) (dated 2026-05-16) is now stale for the four skills it lists. It is preserved as historical record; this ADR supersedes its visibility decisions.
- Future visibility decisions on mutating skills must be tested on **both** Sonnet and Opus before being committed across multiple skills at once. The cost of a six-skill round trip was four days of friction and a multi-session debugging arc.
- Lesson: per-harness skill metadata is a separate concern from skill identity. Toggling six skills at once was the wrong granularity — the change should have landed on one skill first, been verified on both harnesses, then expanded.

## Alternatives considered

None explicitly considered in commit history or in the original 2026-05-16 `AUDIT.md` entry. Plausible alternatives that *could* have been weighed but were not surfaced anywhere in the session data, commit messages, or daily-note handovers:

- **Per-skill conditional via a hook check.** A `PreToolUse` hook that inspects the model name and short-circuits the skill invocation only on Opus would emulate the intended semantics. Not attempted.
- **Harness-level filtering.** Defer the decision to the harness configuration instead of skill frontmatter. Not attempted.
- **Lower-friction default.** Replace the flag with a leading confirmation step inside each skill body. Partially in place (e.g. `git-pr` confirms before pushing) but not adopted uniformly.

Flagged as a gap: alternatives should be enumerated in the original ADR, not the reversal. Future skill-metadata decisions should pass through this ADR template before commit.

## Reversal / Update history

- Originally set 2026-05-16 in commit [`35931390`](https://github.com/) (four skills) and inherited as a default for new mutating skills in commits [`33e3043`](https://github.com/) (`jira-bulk`) and [`c815231`](https://github.com/) (`spec-pipeline`).
- Reversed 2026-05-20 in commit [`9431d38`](https://github.com/) after debugging on the Sonnet harness showed the flag blocked user-typed slash commands, making the six skills unusable on Sonnet.
- This ADR was authored 2026-05-23, retrospectively, after the weekly audit at [`AI/audit/2026-05-W21/reviewer-c-workflow-macro.md`](../../../obsidian/AI/audit/2026-05-W21/reviewer-c-workflow-macro.md) (finding C-2) flagged that a four-day reversal had occurred with no durable record beyond a daily-note handover. The reversal commit message itself (`9431d38`) did not capture the Sonnet-vs-Opus rationale; that detail is reconstructed here from the audit report and the [`session-ab8c101f-2026-05-20`](../../../obsidian/AI/sessions/session-ab8c101f-2026-05-20.md) debugging session.

**Provenance note.** This is a retrospective ADR. The original 2026-05-16 decision's rationale is well captured in `AUDIT.md`. The 2026-05-20 reversal's rationale is reconstructed from the W21 audit report and the debugging session, **not** from the original reversal commit message. Future reversals must capture rationale in the commit message and in a follow-up ADR within the same working day.
