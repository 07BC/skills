---
name: swift-deep-audit
description: DEPRECATED — capability moved to /audit-codebase. Do not use.
disable-model-invocation: true
user-invocable: false
---

# Swift Deep Audit — DEPRECATED

This skill was deprecated on 2026-06-03.

`swift-deep-audit` performed an exhaustive whole-codebase audit covering Swift 6 concurrency,
separation of concerns (Fowler), state management, domain layering, testability, and test
quality. Its standalone identity as a skill was removed because the same capability already
existed in the `/audit-codebase` orchestrator (per-layer review fan-out → findings, per ADR 0005).
Having both created a third competitor for "audit the codebase" triggers with no capability
advantage.

The unique depth from this skill (Fowler separation-of-concerns, domain layering, and test-suite
quality depth checks) was folded into the **per-layer subagent prompt in `/audit-codebase`
Phase 3** on 2026-06-03.

**Use `/audit-codebase` instead.** Trigger phrases that previously routed here — "audit the
codebase", "architecture review", "deep audit", "full analysis", "what's wrong with this project"
— now route to `/audit-codebase`.

This file is retained only as a tombstone. It lives under `skills/deprecated/`,
so `link-skills.sh` skips it and it is never symlinked or auto-discovered.

See `docs/adr/0008-swift-skill-core4-consolidation.md` for the consolidation rationale.
