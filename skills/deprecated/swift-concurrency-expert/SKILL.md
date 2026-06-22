---
name: swift-concurrency-expert
description: DEPRECATED — merged into swift-engineering. Do not use.
disable-model-invocation: true
user-invocable: false
---

# Swift Concurrency Expert — DEPRECATED

This skill was merged into **`swift-engineering`** on 2026-06-03.

`swift-concurrency-expert` handled action-oriented review and fixing of Swift Concurrency
issues in existing code — Swift 6 concurrency compiler errors, data race diagnostics,
actor isolation warnings, Sendable conformance gaps, and completion-handler → async/await
migration. These capabilities are now documented as the
**"Fix concurrency in existing code"** mode in `swift-engineering`.

**Use [`swift-engineering`](../../engineering/swift-engineering/SKILL.md) instead.** Trigger phrases
that previously routed here — "fix this isolation error", "resolve this Sendable warning",
"migrate this to async/await" — now route to `swift-engineering`.

For **conceptual** Swift Concurrency questions (what is Sendable, how does @MainActor work,
etc.), use `swift-concurrency` (which remains a Reference skill and is unchanged).

This file is retained only as a tombstone. It lives under `skills/deprecated/`,
so `link-skills.sh` skips it and it is never symlinked or auto-discovered.

See `docs/adr/0008-swift-skill-core4-consolidation.md` for the consolidation rationale.
