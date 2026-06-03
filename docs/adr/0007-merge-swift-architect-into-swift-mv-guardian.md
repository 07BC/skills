# Merge swift-architect into swift-mv-guardian

`swift-architect` and `swift-mv-guardian` carried near-identical descriptions —
the same two modes (setup/scaffold and MVVM-drift audit) and the same trigger
phrases ("set up a new app", "audit MV adherence", "architect this", …). Both
auto-fired on the same user messages, so which one Claude selected was
non-deterministic. We merged them into a single skill, **`swift-mv-guardian`**,
folding architect's unique content (the MCP-based `XcodeListNavigatorIssues`
`View.body` audit and the `swift-discovery` handoff) into the survivor. The old
skill moves to `skills/deprecated/swift-architect/` as a tombstone redirect;
`link-skills.sh` skips `deprecated/`, so it de-registers from auto-discovery and
can no longer compete for auto-fire.

## Considered Options

- **Keep both, differentiate descriptions** (architect = initial scaffold +
  one-time audit; guardian = ongoing post-change drift verification). Rejected:
  the two skills were ~90% the same body, and the conceptual split was too thin
  to keep them reliably distinct — the descriptions would have drifted back into
  overlap, reintroducing the same non-deterministic auto-fire.
- **Merge into `swift-architect`** (the more textually-referenced name).
  Rejected in favour of guardian because `swift-engineer`'s runtime
  companion-skill list already loaded `swift-mv-guardian`, not architect — so the
  most important *runtime* dependency already pointed at guardian, making it the
  natural survivor despite architect having more prose references.

## Consequences

- All live references were repointed to `swift-mv-guardian`: `README.md`, the
  `audit-codebase` command, `swiftopher-columbus`, `swift-discovery`, both
  `coding-standards.md` docs, and `swift-engineer`.
- `AUDIT.md` was deliberately left untouched — it is an append-only historical
  record ("old sections are not rewritten"), so its `swift-architect` mentions
  stay as written.
- The dangling `swift-architect` MVVM-scaffold handoff inside guardian's
  deployment-target flow was rewritten to point at the MVVM target-architecture
  docs, since no skill scaffolds MVVM.
- `/swift-architect` is no longer a valid invocation. Anyone reaching the
  tombstone is redirected to `swift-mv-guardian`.
