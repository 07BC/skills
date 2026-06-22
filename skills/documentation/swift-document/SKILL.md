---
name: swift-document
description: "Adds or updates Apple DocC-style /// documentation comments on Swift symbols — functions, methods, properties, types, enums, and protocols. Use when the user asks to document Swift code, add comments, update existing documentation, or document a specific file, type, or function. Triggers on 'document this', 'add comments', 'add docs', 'update the comments', '/swift-document'."
---

# swift-document

Adds or updates `///` DocC documentation on Swift symbols following Apple's official style.

Read [apple-doc-conventions.md](references/apple-doc-conventions.md) before starting.

## Opt-in only — explicit user request required

**Default Swift authoring in this codebase forbids `///`.** Per
`swift-engineering` Core Principle #1, doc comments are off by default —
well-named identifiers replace them. This skill is the deliberate
exception: only run it when the user has explicitly asked for DocC
documentation on a specific file, type, or scope.

Triggers that count as explicit:

- "document this file" / "add DocC docs" / "/swift-document"
- "the user has asked me to add `///` here" (in a pasted prompt)

Triggers that do **NOT** count as explicit:

- A passing mention of "comments" in an unrelated request
- A code-review subagent asking for documentation
- `swift-engineering` or `swift-code-review` invoking this skill on their
  own (neither does, and neither should)

If a downstream skill needs documentation, it should add a TODO and
ask the user to invoke `swift-document` directly. This skill never
runs as a dependency of another skill.

## Process

1. **Read** the target file(s) in full before writing anything
2. **Identify** every public and internal symbol that lacks a `///` comment, or has one that is vague or incomplete
3. **Write or update** each comment following the conventions in the reference file
4. **Edit** the file in place — do not reformat or change any non-comment code

## Scope Rules

- Document: `func`, `var`, `let` (non-trivial), `class`, `struct`, `enum`, `protocol`, `typealias`, `extension` (when it adds meaningful context)
- Skip: private helpers that are self-evident from their name alone, generated/synthesised code, test files unless explicitly asked
- When the user specifies a symbol or scope (e.g. "document `fetchUser`"), limit changes to that symbol only

### SwiftUI Files

A file is a SwiftUI file if it imports SwiftUI and its primary type conforms to `View`.

**Skip entirely** in SwiftUI files:
- `var body: some View` and any nested view builder expressions inside `body`
- Stored properties (e.g. `@State`, `@Binding`, `@Environment`, plain `let`/`var` declarations)
- The type declaration itself (`struct MyView: View`)

**Document as normal** in SwiftUI files:
- Computed properties (non-`body` `var` with a `get` block or implicit getter that returns a derived value)
- `@ViewBuilder` properties and functions
- Private or internal helper `func` that perform logic, formatting, or data transformation

## Comment Quality Rules

- Summary is one sentence — what the symbol **does**, not how it is implemented
- Include `- Parameter` / `- Returns` / `- Throws` whenever the signature has parameters, a return value, or can throw
- Add callouts (`- Note:`, `- Warning:`, `- Important:`) only when genuinely non-obvious to a reader
- No padding — if there is nothing useful to say beyond the summary, stop there
- Use Australian spelling throughout

## Update Behaviour

When a `///` comment already exists:
- Keep the summary if accurate; improve it if vague
- Add missing sections (`- Parameter`, `- Returns`, `- Throws`)
- Never remove accurate content — only refine or extend
- Preserve existing formatting style

## Output

Edit the file(s) directly using the Edit tool. Do not output the commented code as a code block in chat unless the user asks to see it first.
