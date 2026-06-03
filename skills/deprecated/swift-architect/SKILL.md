---
name: swift-architect
description: DEPRECATED — merged into swift-mv-guardian. Do not use.
disable-model-invocation: true
user-invocable: false
---

# Swift Architect — DEPRECATED

This skill was merged into **`swift-mv-guardian`** on 2026-06-03.

`swift-architect` and `swift-mv-guardian` had near-identical descriptions and
overlapping bodies — two skills auto-firing on the same triggers, with
non-deterministic selection. They are now one skill.

**Use [`swift-mv-guardian`](../../engineering/swift-mv-guardian/SKILL.md)
instead.** It covers both modes:

- **setup** — scaffold a new MV app skeleton
- **audit** — scan an existing app and report MVVM drift

The unique content that lived here (the MCP-based `View.body` audit and the
`swift-discovery` handoff) was folded into `swift-mv-guardian`.

This file is retained only as a tombstone. It lives under `skills/deprecated/`,
so `link-skills.sh` skips it and it is never symlinked or auto-discovered.

See `docs/adr/` for the merge rationale.
