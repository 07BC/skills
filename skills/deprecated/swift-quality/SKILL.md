---
name: swift-quality
description: DEPRECATED — merged into swift-engineer. Do not use.
disable-model-invocation: true
user-invocable: false
---

# Swift Quality — DEPRECATED

This skill was merged into **`swift-engineer`** on 2026-06-03.

`swift-quality` rewrote Swift code to meet the Google Swift Style Guide and MV architecture
rules, and performed the behaviour-preserving migration of `ObservableObject`/`@Published`
types to `@Observable`. These capabilities are now documented as the
**"Rewrite and migrate (no behaviour change)"** mode in `swift-engineer`.

**Use [`swift-engineer`](../../engineering/swift-engineer/SKILL.md) instead.** Trigger phrases
that previously routed here — "rewrite this", "clean this up", "convert to @Observable",
"migrate this view model" — now route to `swift-engineer`.

The style rules that lived here (naming, method length, vertical whitespace, etc.) are
authoritative in `swift-style`, which `swift-engineer` loads automatically.

This file is retained only as a tombstone. It lives under `skills/deprecated/`,
so `link-skills.sh` skips it and it is never symlinked or auto-discovered.

See `docs/adr/0008-swift-skill-core4-consolidation.md` for the consolidation rationale.
