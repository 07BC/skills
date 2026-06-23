---
name: pr-comment-review
description: >
  Triages, fixes, and responds to GitHub PR review comments. Use this skill
  whenever the user says "pr-comment-review", "handle my PR comments",
  "review my PR comments", "triage PR comments", "reply to PR review feedback",
  or wants to process reviewer feedback on a pull request. Reads all open
  inline review comments via `gh`, validates each on its technical merits
  (correct, wrong, or debatable — with evidence, never reflexively defending
  the code or accepting the comment), proposes fixes for the user to approve,
  then applies the approved fixes and replies to every thread. Always use this
  skill — do not attempt to triage or respond to PR comments ad hoc without it.
---

# pr-comment-review

Reads all open inline review comments on the current branch's PR, validates
each one on its technical merits, proposes fixes for the user to approve, then
applies the approved fixes and replies to all of them via `gh`.

---

## Step 0 — Prerequisites

Before doing anything, verify:

1. `gh` is available: `gh --version`
2. The current directory is a git repo with a remote PR open on the current branch
3. Identify the PR: `gh pr view --json number,headRefName,url`

If no open PR is found, stop and tell the user.

---

## Step 1 — Fetch all open inline review comments

```bash
gh pr view --json reviews,reviewThreads \
  --jq '.reviewThreads[] | select(.isResolved == false) | {
    id: .id,
    path: .path,
    line: .line,
    startLine: .startLine,
    diffHunk: .diffHunk,
    comments: [.comments[] | {author: .author.login, body: .body, id: .id, databaseId: .databaseId}]
  }'
```

Collect all threads where `isResolved == false`. Group by `path` for
efficient file loading.

---

## Step 2 — Load each affected file

For each unique `path` from the threads, read the file from disk. You need the
current on-disk content — not the diff — to validate the comment against the
real code and, later, to edit it.

---

## Step 3 — Validate each thread

This is the heart of the skill. The question is **not** "is this worth the
effort" — it is **"is the reviewer technically right?"** You neither defend the
code by reflex nor accept the comment by reflex. You validate, with evidence.

**Ground the validation first.** Invoke the `swift-code-review` skill (via the
Skill tool) before judging — it loads swift-engineering, swift-style,
swift-testing and swift-concurrency, which are the best-practice rules you
validate against. Then read `CLAUDE.md` for project-specific overrides. Judge
each comment against those rules and the actual code on disk — not against
"what we usually do."

### Separate the concern from the prescription

Most feedback that *feels* wrong has a **valid concern** wrapped in a **wrong
prescription**. Do not dismiss the whole thread on the prescription. Split it:

- **Is the underlying concern real?** (e.g. "this view holds too much logic")
- **Is the proposed fix the right one?** (e.g. "extract a ViewModel" — which
  violates MV)

If the concern is real but the prescription is wrong, the comment is **CORRECT
in substance** — propose the *right* fix (the MV-correct refactor), not the
reviewer's exact one, and say so.

### Three verdicts — each needs evidence

- **CORRECT** — the concern is real (a genuine bug, race, leak, force-unwrap
  risk, missing test, over-engineering, best-practice violation, or API
  misuse). Cite the rule or reasoning. Decide the right fix (which may differ
  from the reviewer's prescription).
- **WRONG** — the feedback is technically mistaken. You may only land here by
  **showing why**: cite the specific skill rule, or demonstrate the code is
  already correct/better. **Citing a project convention is not enough** — a
  convention does not make wrong code right. If you cannot produce evidence the
  feedback is wrong, it is not WRONG.
- **DEBATABLE** — a genuine judgement call, or you have a better alternative
  than the reviewer's. Frame the trade-off for the user.

"Over-engineered" and "not best practice" cut both ways: apply them to the
reviewer's suggestion *and* to the existing code. The simpler, correct solution
wins regardless of who proposed it.

### Three questions for every comment

Do not just explain what the code does — that is how you end up defending it.
For each thread, answer all three before picking a verdict:

1. **Is it correct?** Does the code actually do the right thing here?
2. **Is it over-engineered?** Could a simpler construct (or none) do the same
   job? A hand-rolled mechanism that re-implements a language feature, a guard
   for a state that cannot occur, an abstraction with one caller — all CORRECT
   verdicts against the existing code.
3. **Is there an easier path to success?** If a smaller, more idiomatic
   solution exists, that is the fix — even when the current code "works".

### A reviewer asking "why" is a signal, not a knowledge gap

When a reviewer asks "why do we have X?", "what is this for?", or "why pass
this back?" — treat it as evidence the design is unclear or wrong, not as a
question to answer by describing the code. **Clustered "why" comments in one
area almost always mark a real design smell.** Investigate the code against the
three questions above and the actual call sites before replying. If it turns
out genuinely correct, reply in kind — confirm it, explain the reasoning, and
acknowledge the question was fair. If it does not, fix it.

### Second opinion before any WRONG verdict

Dismissals are the dangerous move — they tell a reviewer they were wrong. Never
finalise a **WRONG** verdict from your own judgement alone. For each WRONG
candidate, get an independent second opinion via the `swift-pr-reviewer` agent
(Agent tool), prompted adversarially:

> Here is a code excerpt and a PR review comment on it. I believe the comment
> is technically mistaken. Argue the strongest case that the **reviewer is
> right** — find any bug, race, leak, over-engineering, or best-practice issue
> the comment points at. Cite specific Swift rules. If after a genuine attempt
> the comment really is wrong, say so plainly.
>
> Code: <the relevant code + surrounding context>
> Comment: <the reviewer's comment, verbatim>

Then reconcile:

- Agent finds real merit → the verdict is **not** WRONG. Reclassify as CORRECT
  or DEBATABLE and carry the agent's reasoning into the proposal.
- Agent agrees the comment is mistaken → the WRONG verdict stands; cite the
  agent's reasoning alongside your own in the reply.

Send only WRONG candidates to the agent. CORRECT and DEBATABLE verdicts are
handled inline — no agent round-trip.

---

## Step 4 — Propose, don't apply

**Do not edit any files yet.** Present the full triage to the user and wait for
their decision. For each thread, show:

```
[path:line] — VERDICT
Reviewer: <one-line paraphrase of the comment>
Reasoning: <why CORRECT / WRONG / DEBATABLE — cite the rule or evidence>
→ Proposed fix: <the diff or change you'd make, or "none">
```

- **CORRECT** threads: show the proposed change as a diff. The fix you propose
  may differ from the reviewer's prescription — say so when it does.
- **DEBATABLE** threads: present both options and your recommendation.
- **WRONG** threads: state the evidence; no fix.

Then ask the user which proposed fixes to apply (e.g. "apply all", "apply 1,3",
"skip 2"). **Wait for their go-ahead before touching any file.**

Once approved, apply each agreed change on disk: the minimal edit that satisfies
the concern, no incidental refactoring. Then run `swift build` (or `xcodebuild
build` if a workspace is present) to confirm it compiles.

---

## Step 5 — Reply to every thread

Only after the user has approved the fixes and they are applied, reply to each
thread using `gh`.

**For threads you fixed:**

```bash
gh api graphql -f query='
  mutation {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: "THREAD_ID",
      body: "REPLY_BODY"
    }) {
      comment { id }
    }
  }'
```

Reply body format:
```
Fixed. [One sentence describing what was changed and why.]
```

**For threads you did NOT fix (WRONG, or DEBATABLE the user declined):**

Use the same mutation to reply, then resolve the thread.

Lead with the reasoning, never a dismissive opener. **Do not write "Not
addressing this one" or any variant** — it reads as passive-aggressive and
tells the reviewer nothing. State the technical finding plainly:

```
[What the code does and why it is correct as-is, or why the concern does not
apply here.] [Cite the skill rule or show the evidence — a bare convention is
not a reason.]
```

If the reviewer was right (a CORRECT verdict you are replying to in kind),
agree directly and own it: `Good catch — [what changed and why].` Never defend
a point the reviewer has won on the merits.

Then resolve:
```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "THREAD_ID"}) {
      thread { id isResolved }
    }
  }'
```

Resolve threads you are NOT fixing. Leave fixed threads unresolved — the
reviewer should confirm the fix and resolve themselves.

---

## Step 6 — Summary report

After processing all threads, print a summary in this format:

```
## PR comment triage — [PR number]

### Fixed ([N])
- [path:line] — [brief description of fix]

### Not addressed ([N])
- [path:line] — [reason, one line]

### Skipped ([N])
- [path:line] — [reason: already resolved, duplicate, etc.]

Build: ✅ passes  (or ❌ [error summary])
```

---

## Project conventions (apply when triaging and fixing)

| Area | Rule |
|---|---|
| Architecture | SwiftUI MV — no ViewModels, views bind directly to `@Observable` services |
| Concurrency | Swift 6 strict; `Mutex` over `NSLock`; `actor` for off-main work; no `@unchecked Sendable` without comment |
| Unit tests | Swift Testing (`@Test`, `#expect`) — never XCTest |
| UI tests | XCUITest / XCTestCase only — never Swift Testing |
| Storage | SwiftData |
| Style | 2-space indentation, no inline comments, no force cast/try without comment |
| DI | `@Inject` / `AppDependencies` / `@Environment` |
| Services | `@MainActor @Observable final class` |

If `CLAUDE.md` exists in the repo root, read it before triaging — it overrides
this table for project-specific rules.

---

## Error handling

| Problem | Action |
|---|---|
| `gh` not authenticated | Stop. Tell the user to run `gh auth login`. |
| PR not found for current branch | Stop. Tell the user which branch is checked out and that no PR was found. |
| Build fails after a fix | Revert that specific change, mark the thread as "Fix attempted but caused build failure — needs manual review", and reply with that message. |
| Thread ID not resolvable via GraphQL | Fall back to `gh pr comment` on the PR (not the thread) noting the path and line. |
| No open review threads | Tell the user: "No open inline review comments found on PR #N." |

---

## Model & mode

Run on **Opus**. Validation (Step 3) is the whole point and needs the strongest
judgement — do not delegate it to a weaker model. Steps 0–3 are read-only and
produce the triage; Step 4 presents it and waits for the user; Steps 4 (apply)
–5 run only after approval. No plan-mode split is needed — the user-approval
gate in Step 4 is the safety boundary.
