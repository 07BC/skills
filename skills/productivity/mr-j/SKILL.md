---
name: mr-j
description: >
  Frames a PR description, Jira ticket, spec, or any other document to meet Mr J
  review standard — every claim explains why the work exists, how it
  solves the root cause, which alternatives were rejected, what the simplest version
  looks like, and how failure is recovered. Use whenever the user is about to send
  content to Mr J, raise a PR he will review, write a spec for the Device
  Experiences squad, draft release notes, or asks "what would Mr J say about
  this". Trigger phrases include "frame this for Mr J", "Mr J-proof this",
  "make this pass Mr J's review", "write this how Mr J would", or
  "mr-j". Always use this skill instead of paraphrasing Mr J's
  expectations from memory.
---

# mr-j

Frame any document or PR to match the structure and standard Mr J
models in his own writing. Source profile lives at
`~/Developer/obsidian/wiki/entities/mr-j.md`. This skill is
self-contained — do not require reading the entity page at runtime.

The bar Mr J applies, in his own words:

> "It appears to me like there are some assumptions in the PR description… Please
> do not merge this PR unless we can **fully quantify those claims**."

> "I am not sure that this is an exception that should be managed but more of an
> **unwanted execution path**. If a session is started, we shouldn't be try to
> start another. We could capture the exception but **how do we recover?**"

> "**API degradation and fallback should be a responsibility of the API. Moving
> this responsibility to the client app is fixing a problem with a problem.**"

> "To increase the quota limit is **false economy**. We need to fix the root cause
> of the problem…"

## When to fire

Fire on:

- "frame this for Mr J", "Mr J-proof this", "what would Mr J ask"
- "write a spec / PR / release notes Mr J will pass"
- the user is drafting content the user said is going to Mr J for review
- the user is on the Device Experiences squad (Devices / DEP) and is drafting
  anything more substantial than a chat message
- "/mr-j"

Do not fire on Jira comments under one paragraph or any informal
asynchronous reply where the user is just acknowledging something. Mr J's
documentation bar applies to *documents and PRs*, not chat.

**Slack engineering debate is the exception.** When the user is drafting a
Slack post that proposes a technical change, pushes back on another team's
approach, or asks the team to defend cost vs benefit, fire on it. Use the
"Slack engineering" skeleton below — the shorter form, not the full document
skeleton.

## Inputs the skill accepts

1. A draft PR description — improve it in place.
2. A draft Jira ticket — improve it in place.
3. A draft spec / Confluence page — improve it in place.
4. A free-form description of a change — write the document from scratch.
5. A request to review existing content for Mr J-readiness — output a punch
   list of gaps with line references, no rewrite.

If the input is ambiguous, ask which of (1)–(5) before generating anything.

## The five questions every output must answer

Every output produced by this skill must explicitly answer all five questions
below. Surface the question headings in the output — do not bury answers in
prose. If a question has no answer in the input, mark the section **TODO** and
flag it in the final summary as a blocker for Mr J's review.

1. **Why did this need to change?** — root cause, not symptom. If the answer is
   "the symptom is X", keep asking why until you reach a cause that lives in a
   system, a contract, or a constraint.
2. **What does this change do?** — mechanism, not outcome. Name the types,
   files, services, and protocols touched. Reference line numbers where useful.
3. **How does this change solve the root cause?** — causal link. The reader
   should be able to draw a line from the change to the cause without guessing.
4. **What alternatives were considered, and why were they rejected?** — at
   least one alternative must be considered. "We didn't think about
   alternatives" is a blocker. If the alternative was "do nothing", state why
   doing nothing was rejected.
5. **What is the simplest version of this change? If this is more complex, why?**
   — name the simpler version explicitly. If the current scope is larger, the
   justification ladders back to a constraint Mr J would accept (compliance,
   contract, blocker on another team, release-train timing).

In addition, every output must include:

- **Failure modes and recovery.** What can fail, what does failure look like,
  how do we detect it, how do we recover? Exception-catching is not recovery.
  "We catch the error and log it" is not recovery — what happens to the user
  state?
- **Quantified claims.** Any claim about another system's behaviour (SDK
  internals, API response shapes, third-party limits) must cite the doc, the
  header file, the test, or the empirical observation that grounds it. No
  speculative claims about SDK behaviour.
- **Explicit out-of-scope.** Out-of-scope is mandatory. Never implicit.
- **Dependencies with owners.** Every dependency names a person, team, or
  contract — never anonymous "the backend".

## Document skeleton — use for specs, Confluence pages, large PR descriptions

This is the structure Mr J uses on every document he writes. Mirror it.

```markdown
# <title>

## Overview / Context

<1–2 paragraphs framing *why this work exists*, written for a reader with zero
prior context. The reader must not need to ask "what problem is this solving?">

## Problem / Root Cause

<State the problem plainly. For incidents, separate "What happened?" from
"Why did it happen?". List any known risks that were ignored.>

## Goal

<What success looks like.>

## Out of Scope

<Enumerated bullet list. Never empty. Never implicit.>

## Proposed Solution

### Architecture / System Design

<Name each component and its job. For cross-system flows, include a Mermaid
sequence diagram (```mermaid sequenceDiagram …```).>

### Flow

<Numbered list of the end-to-end happy path.>

## Functional Requirements

- FR-01: …
- FR-02: …

## Non-Functional Requirements

- NFR-01: …
- NFR-02: …

## Acceptance Criteria

- AC-01: Given … When … Then …
- AC-02: …

<Group with prefixes when the surface area is large: AC-N1 navigation, AC-T1
toggle interaction, AC-P1 persistence, AC-F1 filtering, etc.>

## Dependencies

| Dependency | Owner | Status |
|---|---|---|
| <name> | <person or team> | <state> |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| <risk> | <high/medium/low> | <mitigation> |

## Open Questions

| Question | Owner | Due Date |
|---|---|---|
| <question> | <person> | <date> |
```

## PR description skeleton — use for any PR Jordan will review

```markdown
## Why

<Root cause this PR addresses. One paragraph.>

## What changed

<Mechanism. Files / types / protocols / services touched. Bullet points.>

## How it solves the root cause

<Causal link from the change to the cause stated above.>

## Alternatives considered

- **<Alternative 1>**: <why rejected>
- **<Alternative 2>**: <why rejected>
- **Do nothing**: <why rejected>

## Simplest version

<The simplest version of this change. If the PR scope is larger, the next
paragraph explains what justifies the extra scope.>

## Out of scope

- <Explicit list of related work this PR does not do.>

## Failure modes and recovery

- **<Failure mode 1>**: <how detected, how recovered>
- **<Failure mode 2>**: <how detected, how recovered>

## Quantified claims

- "<claim about SDK / API / framework>" — source: <doc URL, header file, test, or empirical evidence>

## Testing evidence

- <What was tested, on which device / simulator / configuration, with what result>
```

## Slack engineering-debate skeleton — for substantive Slack posts

Mr J writes these in 1–3 short paragraphs. The shape:

```
@<owner-or-team>, here is what I am seeing / what we could do.

<Option A> would <expected outcome>, but <side effect / category of cost>.
<That is/is not a good idea for X reason>. It would also <second-order
consequence — version drift, ongoing maintenance, etc>.

<Option B> would also <expected outcome> but <risk / effort cost>.

Are we confident that the effort of <doing the work> is worth the end result?
```

Rules:

- Address the owner by name. No anonymous posts.
- Name both options before recommending. Cost vs benefit is the framing.
- End with a question that asks the team to defend the value, not assert it.
- Lowercase casual, no headings, no bullet lists unless three or more items.
- No hedging filler ("just my thoughts", "happy to discuss"). The post is
  itself the request to discuss.

## Slack team-coordination skeleton — for releases, rollouts, ops messages

```
<@here or specific @people>, <what is happening, in plain English>.

<who needs to do what — name the action and the owner>.

<what happens if there is an issue — who to ping, what to do>.

<closing one-liner, often a single phrase like "Any issues, shout out." or
"Cheers all">.
```

Rules:

- Always name the action *and* the owner.
- Always name the escalation path ("speak to X immediately").
- Sign off with the single-phrase closing.

## Process

When the skill fires:

1. **Identify the input type.** Ask if ambiguous.
2. **Extract or draft the five answers.** For each of the five questions, either
   pull the answer from the user's draft or mark it **TODO** and ask the user
   for it before generating final output.
3. **Choose the skeleton.** Document skeleton for specs / Confluence pages /
   large PR descriptions. PR skeleton for PRs and shorter Jira tickets.
4. **Fill the skeleton.** Use numbered enumeration (FR-01, AC-01) for any
   requirement-style content. Use Mermaid for any cross-system flow.
5. **Run the final checks.** Each must pass before output is delivered:
   - Every claim about another system's behaviour cites a source.
   - Out-of-scope is enumerated and non-empty.
   - Every dependency names an owner.
   - Failure modes name detection + recovery.
   - At least one alternative is documented as rejected, with reason.
   - No section is silently empty.
6. **Output the final document.** Lead with a short summary of what is **TODO**
   and which sections Jordan will push back on if shipped as-is.

## Voice and tone

Mirror Jordan's voice in section bodies:

- Short imperative sentences. "State the problem. State the goal. List the
  constraints. Number the acceptance criteria."
- Lowercase, conversational in inline comments and replies — "would be good
  to…", "can you please…", "not sure that this is X but more of Y".
- No hedging. Either the claim is grounded ("Source: Mux iOS SDK Integration
  Guide §3.2") or it is flagged as an open question.
- No marketing language. "raises the bar", "engine of the team" are Jordan's
  voice in role-description prose — do not use them in technical documents.
- Australian spelling: colour, behaviour, organisation, capitalisation.

## What Jordan will push back on (so you can pre-empt)

- Unquantified claims about SDK or third-party API internals — he will block
  merge.
- "We catch the exception" without "and here is how we recover."
- API client-side fallbacks for upstream gaps — he treats this as a category
  error.
- Scaling-up-the-broken-thing fixes (raise the quota, add a retry) without
  fixing the root cause — he calls this "false economy."
- Implicit scope. Missing out-of-scope. Missing dependency owners.
- Tests that only exercise the mock. Tests that codify a bug. The presence
  of tests is not the same as the tests asserting the right invariant.
- Vague responses to "what does failure look like" — for any external API
  the response shapes (success and error) must be enumerated.

## What earns his approval

- Explicit acknowledgement that the author personally tested the change, with
  device and result ("Tested thoroughly on all use cases. Performed regression
  at the same time. Good to go." — his words on an approval he authored).
- Documents that name the simplest version of the work and justify any extra
  complexity against a real constraint.
- Risks listed with mitigations, in a table.
- Open questions tracked, not buried.
