# Legacy agents

These three agents (`junior-developer`, `senior-developer`, `tester`) were
the first cut at orchestrating Swift implementation work via specialist
sub-agents. They were never wired into the README or any skill — they sat
in `agents/` at the repo root as orphans.

They are kept here for reference because the role decomposition (spec-bound
implementer, architecture/concurrency reviewer, Swift Testing author) influenced
the design of the spec-pipeline inner-loop agents. The current pipeline uses
a fresh four-agent inner loop (`engineer`, `test-writer`, `concurrency-auditor`,
`task-reviewer`) plus a whole-diff `swift-spec-review` outer gate — these
files were not migrated; they were superseded.

Deprecated: 2026-05-19. Replaced by:

- `agents/engineer.md`            (was: junior-developer)
- `agents/test-writer.md`         (was: tester)
- `agents/task-reviewer.md`       (was: aspects of senior-developer)
- `agents/concurrency-auditor.md` (was: concurrency mode of senior-developer)
- `agents/swift-spec-review.md`   (was: review mode of senior-developer; whole-diff)

See `AUDIT.md` for the design rationale.
