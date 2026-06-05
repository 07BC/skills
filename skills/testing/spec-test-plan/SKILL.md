---
name: spec-test-plan
description: >
  Generates a device-testable QA test plan for a PR based on its spec. Use ONLY
  when docs/specs/*.md exists for the feature being tested. Only includes steps
  navigable on device — skips unwired views, internal error handling, and
  analytics. Outputs as a PR comment or console output. Triggers on "test plan
  from the spec", "device test plan", "QA steps for this spec". Do NOT use when
  no spec file exists: use pr-test-plan (PR exists, no spec) or claude-regression
  (no PR, no spec) instead.
---

# Spec Test Plan

Generate a device test plan for a PR based on its spec. This is the
spec-anchored member of the test-plan trio:

| You have… | Use |
|---|---|
| A spec file (`docs/specs/*.md`) | **`spec-test-plan`** (this skill) |
| A PR but no spec | `pr-test-plan` |
| No PR and no spec, just a codebase | `claude-regression` |

**Usage**: `/spec-test-plan docs/specs/[feature]-NN.md`

On start, output: `📱 TEST PLAN — Reading spec and codebase, generating device test plan...`

---

## Process

### 1. Read the Spec
- Read all requirements and acceptance criteria
- Identify what is user-visible vs internal

### 2. Explore the Codebase (use subagents to preserve context)
- Find all new views and verify they are wired into navigation
- Check coordinators, tab bars, sheets, and navigation stacks
- **If a view has no navigation path it is untestable on device — exclude it**
- Find related existing flows that may be affected

### 3. Map to Testable Steps
- Each acceptance criterion that is user-visible becomes a test step
- Each new navigation path gets a verification step
- Unit test pass/fail is always the first item

---

## Test Plan Format

```markdown
## Test Plan: [Feature Name] — Spec NN

- [x] Unit tests pass
- [ ] [Action the tester performs] and verify [observable outcome]
- [ ] [Action the tester performs] and verify [observable outcome]
- [ ] [Action the tester performs] and verify [observable outcome]
```

Steps must be:
- **Imperative** — start with a verb ("Tap", "Navigate to", "Enter", "Scroll")
- **Observable** — the outcome must be visible on screen
- **Specific** — no ambiguous steps like "verify it works"

---

## Rules

- Only include steps testable on a physical device or simulator
- Always verify navigation is wired before writing steps for a view
- Do NOT include error handling unless it is presented to the user as UI
- Do NOT include analytics unless observable via debug console
- Do NOT include edge cases
- Do NOT include internal implementation details
- Unit tests pass is always the first item and always checked

---

## Output

Write the test plan as a comment on the current branch's PR.
If unable to access the PR, output the test plan to the console for copy/paste.

On completion, output:
```
✅ TEST PLAN COMPLETE — [N] device test steps generated
```
