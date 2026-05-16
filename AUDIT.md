# Skills Audit

A running record of audit passes against this skill library. Each dated section captures one audit's findings: which skills changed, what changed, and why. New audits append fresh sections; old sections are not rewritten.

---

## 2026-05-16

Three-sweep audit across all 27 shipped skills: visibility flags, deterministic-script extractions, composability/prose fixes. See the `audit/skills-2026-05-16` branch for the change set; this section is the changelog.

### Visibility

Two new YAML frontmatter fields added selectively.

| Skill | Field added | Why |
|---|---|---|
| `git/git-commit` | `disable-model-invocation: true` | Mutates repo state. Must be explicitly user-invoked — no auto-fire from casual mentions of "commit". |
| `git/git-push` | `disable-model-invocation: true` | Pushes to remote. Auto-fire risk includes pushing in-progress work to a shared branch. |
| `git/git-pr` | `disable-model-invocation: true` | Pushes + opens a GitHub PR. Side effect is visible to teammates. |
| `productivity/plan-to-jira` | `disable-model-invocation: true` | Creates Jira issues via the Atlassian MCP. Tickets are visible to the wider team; undo is manual. |
| `engineering/swift-concurrency` | `user-invocable: false` | Pure-reference skill with a `references/` library. Pairs with the action skill `swift-concurrency-expert`. The user has no reason to type `/j:swift-concurrency` — Claude auto-loads it when concurrency questions come up. Hidden from `/menu` to keep that surface focused on action-shaped skills. |

Skills considered but **not** flagged:

- `obsidian-audit`, `daily-notes`, `obsidian-learn`, `obsidian-rollover`, `session-saver` — all mutate the Obsidian vault, but the vault is git-backed, the writes are local-only, and each skill's description already requires explicit user phrasing ("rollover", "run learn", "process my sessions"). Auto-fire risk is annoying-but-recoverable rather than high-risk.
- `swift-engineer`, `swift-testing`, `swift-cidi`, `swift-architect` — knowledge-heavy but action-shaped. Users actually do type these to start work; hiding them from `/menu` would obscure the library.

### Determinism

(populated in commit 2)

### Composability + prose

(populated in commit 3)
