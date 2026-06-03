---
name: swiftui-liquid-glass-prototype
description: DEPRECATED — name-collision duplicate of engineering/swiftui-liquid-glass. Do not use.
disable-model-invocation: true
user-invocable: false
---

# SwiftUI Liquid Glass (Prototype) — DEPRECATED

This directory was the prototype copy of `swiftui-liquid-glass`. Both it and
`skills/engineering/swiftui-liquid-glass/` declared `name: swiftui-liquid-glass`
in their frontmatter, causing `link-skills.sh` to create a name collision where
whichever was found last would overwrite the other's symlink.

The survivor is the shipped copy at
**[`skills/engineering/swiftui-liquid-glass/`](../../engineering/swiftui-liquid-glass/SKILL.md)**.
That copy is listed in `README.md` and is the one to use.

This tombstone lives under `skills/deprecated/`, which `link-skills.sh` skips,
so it is never symlinked or auto-discovered.

See `docs/adr/0008-swift-skill-core4-consolidation.md` for the consolidation rationale.
