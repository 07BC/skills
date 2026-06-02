---
name: prompt:review
description: >
  **Generates a prompt** for another Claude Code session to perform a Swift/iOS
  PR review — it does NOT do the review itself. Use when the user says
  "prompt:review", "write a review prompt", "create a PR review prompt", or
  wants a reusable review brief to hand off. If the user instead wants this
  session to actually perform the review now, use swift-code-review. Encodes
  the project-specific orientation, verdict format, and story-point estimate
  that make iOS PR reviews reliable. The checklist itself is delegated to
  swift-code-review (single source of truth).
---

# prompt:review

Generates a Claude Code prompt for reviewing a Swift/iOS pull request.
The generated prompt tells the reviewing session to apply
`swift-code-review` for the actual checklist — this skill adds the
value-added bits on top:

- Project-specific orientation (which architecture docs to read for the
  PR's changed files).
- A required verdict format the checklist itself doesn't enforce.
- A story-point estimate.

Every prompt is saved as a `.md` file in the Obsidian plans directory.

---

## Variables

| Variable | Source |
| --- | --- |
| `PROJECT_NAME` | `basename $(git rev-parse --show-toplevel)` |
| `PLANS_DIR` | `${HOME}/Developer/obsidian/${PROJECT_NAME}/plans` |
| `SLUG` | derived from the Jira key, PR number, or one-line description |

---

## Step 1 — Gather context

Establish before writing:

1. What is the PR doing? Feature, bug fix, refactor, test addition?
2. Which files are changing? Use the diff or file list if provided.
3. Is there a Jira ticket? Include the key (e.g. `PROJ-123`) if so.
4. Known constraints or risks? e.g. "must not break ReplayKit".

Extract from context rather than asking when a diff or description is
already provided.

---

## Step 2 — Decide what extra docs the reviewer needs to read

`swift-code-review` already handles the universal Swift / SwiftUI / MV /
concurrency / testing checks. This skill adds project-specific reading
on top — only the docs that match the PR's changed files.

| Changed area | Doc to read |
|---|---|
| Any SwiftUI view | `docs/audit-report/05-ui-architecture.md` |
| Domain models / API types | `docs/audit-report/04-domain-layering.md` |
| Services / actors | `docs/audit-report/03-concurrency.md` |
| Tests | `docs/audit-report/07-testability.md` |
| Networking / real-time | `docs/engineering/networking-architecture.md` |
| ReplayKit | `docs/engineering/replaykit-notes.md` |

Drop rows that don't match. Add rows from the project's own `CLAUDE.md`
if it lists architecture docs for areas the PR touches.

---

## Step 3 — Assemble the generated prompt

The generated prompt has four sections. The wording below is what you
write *into the prompt file* — it's what the reviewing session will
read.

### Section A — Orientation

```
Read in order, before forming any opinions:

1. CLAUDE.md.
2. [Project-specific docs from Step 2 — list each path on its own line].
3. The PR diff or the list of changed files supplied below.

Do not form opinions until you have read all of the above.
```

### Section B — Checklist

```
Apply skill `swift-code-review`. Use its severity mapping
(BLOCKER / WARNING / SUGGESTION) end-to-end. Do not re-derive the
checklist from memory — the skill is the source of truth.

Layer extra project-specific checks from the docs you read in
Section A on top of the swift-code-review checklist.
```

This delegates the architecture, concurrency, scope, and test checks
to `swift-code-review` rather than restating them here. When that skill
changes, every generated prompt picks up the change for free.

### Section C — Verdict format (required)

`swift-code-review` produces structured findings but doesn't impose a
verdict shape. The generated prompt does:

```
## Verdict

**Decision:** APPROVE / REQUEST CHANGES / NEEDS DISCUSSION

**Blocking issues (BLOCKER from swift-code-review):**
- [issue] — [file:line]

**Non-blocking suggestions (WARNING / SUGGESTION):**
- [suggestion]

**Story point estimate:** [N] point(s) — [one-line rationale]
  (1 point = 1 day of effort; round to nearest whole number)
```

### Section D — Reviewer model + mode

Always append:

```
**Model & mode:** Sonnet, normal mode — code review is reading + pattern
matching, not architecture planning.
```

---

## Step 4 — Save and report

Save the generated prompt to `${PLANS_DIR}/pr-review-${SLUG}.md`.
Examples:

- `${PLANS_DIR}/pr-review-PROJ-123.md`
- `${PLANS_DIR}/pr-review-story-02-loan-input-screen.md`

Report the path to the user. Do not paste the prompt inline — the
calling session opens the file when it's ready to run the review.

---

## What this skill does NOT do

- It does not perform the review (that's `swift-code-review`).
- It does not encode the BLOCKER / WARNING / SUGGESTION checklist
  (also `swift-code-review`).
- It does not run the build or query Xcode (the reviewer does that).
