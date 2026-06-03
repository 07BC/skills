---
name: swift-pre-pr-review
description: DEPRECATED — merged into swift-code-review (deep mode). Do not use.
disable-model-invocation: true
user-invocable: false
---

# Swift Pre-PR Review — DEPRECATED

This skill was merged into **`swift-code-review`** on 2026-06-03.

`swift-pre-pr-review` performed a ruthless senior-engineer pre-PR review for high-stakes
branches (new SDK, infrastructure, lifecycle changes), producing a prioritised
Critical/High/Medium/Low findings document. This capability is now documented as the
**"Deep / Adversarial Mode"** in `swift-code-review`.

**Use [`swift-code-review`](../../engineering/swift-code-review/SKILL.md) instead.** Trigger
phrases that previously routed here — "deep PR review", "senior PR review", "ruthless review",
"pre-PR audit", "find every defect" — now route to `swift-code-review` (deep mode).

This file is retained only as a tombstone. It lives under `skills/deprecated/`,
so `link-skills.sh` skips it and it is never symlinked or auto-discovered.

See `docs/adr/0008-swift-skill-core4-consolidation.md` for the consolidation rationale.
