# Tag Rules

## Defaults

- **Closed taxonomy by default.** Use tags that already exist in the vault.
- Get the existing tag set with: `/usr/local/bin/obsidian tags counts sort=count vault=obsidian 2>/dev/null | tail -n +2 | awk -F'\t' '{ print $1 }' | sed 's/^#//'`
- A new tag may be proposed during Pass 1, but is only committed in Pass 2 if **at least 2 candidate files** in this run propose the same new tag.
- Tag values are kebab-case, lowercase, no `#` prefix in frontmatter (the `#` is only the inline syntax).

## Per-file pruning (Pass 1)

For each existing tag on the file:
1. **Keep** if the tag is clearly relevant to the note's content (matches a topic, project, type, or platform discussed in the body).
2. **Drop** if both:
   - The tag does not match the note's content, AND
   - The tag appears on **no more than 1 other note** in the vault (a vault-wide single-occurrence tag is more likely a mis-tag than a genuine niche topic).
3. **Keep but flag** in the changelog if the tag is broadly used in the vault (≥ 5 occurrences) but doesn't seem to match this note. Do NOT auto-drop heavily-used tags — log a "review suggested" entry.

When in doubt, **keep**. Pruning is conservative.

## Suggesting tags from existing taxonomy

Read the note's title, headings, and body. Match against the existing tag set:
- **Project tags** (e.g., `kick`, `chagi`, `nat-550`) — add if the note discusses that project.
- **Platform tags** (e.g., `ios`, `tvos`, `swiftui`) — add if the note discusses that platform.
- **Type tags** (e.g., `spec`, `prd`, `roadmap`, `research`, `plan`) — add if the note's structure matches that type. Pair with the `type` property (see property-schema.md).
- **Folder-implied tags** — daily notes get `daily`, project notes get `project`, reference notes get `reference`.

Avoid double-tagging when the property already conveys the same info. If the file has `type: daily`, the `daily` tag is redundant — pick one. Convention: use the property; drop the tag.

Exception: tags that map to a property value get dropped from `tags`. Tags that don't map to any property stay as tags.

## Proposing new tags

A new tag may be proposed if:
- A clear topic appears in the note that no existing tag covers.
- The proposed tag follows kebab-case, lowercase rules.
- The proposed tag is not synonym-adjacent to an existing tag (don't propose `streaming` if `kick-streaming` already exists; don't propose `live` if `go-live` exists).

Each proposed tag is added to the run's `new_tag_candidates` map. The 2+ threshold runs after Pass 1.

## Examples

| Note content excerpt | Existing tags | Proposed change |
|---|---|---|
| "Plan for the broadcast configuration refactor on iOS" | `[ios, kick]` | Add `streaming`, `plan`. Keep both existing. |
| Daily note from 2026-03-04 | `[]` | Add `daily`. Set `type: daily`. |
| Note titled "ReplayKit screen sharing investigation" | `[replaykit, ios]` | Keep both. Propose `screen-streaming` (already exists). |
| Single-occurrence tag `xyz-123` on a note about login flow | `[xyz-123, login, ios]` | Drop `xyz-123` (irrelevant + low frequency). Keep others. |
| Inline title mentions "Quarterly review" but tags include `kick`, `chagi`, `streaming` | `[kick, chagi, streaming]` | Keep all (high-frequency tags). Flag in changelog: "consider `quarterly-review` if 2+ similar notes exist". |

## What NOT to do

- Do not strip tags below the per-file pruning rules just to "tidy up".
- Do not add tags speculatively. Each tag must be defensible from the note's content.
- Do not normalise tag spelling automatically (e.g., `chagi-tv` → `chagi`). Flag rename candidates in the changelog instead — a rename is a vault-wide operation that needs explicit user approval.
