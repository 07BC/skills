#!/usr/bin/env bash
# Apply a JSON change set to one markdown file's frontmatter and body.
# Usage: apply_changes.sh <file> <changes-json-path>
#
# Change-set JSON shape:
#   {
#     "set_properties":     { "type": "plan", "status": "active", "jira": "NAT-1234" },
#     "remove_properties":  ["legacy_field"],
#     "set_tags":           ["ios", "kick", "plan"],     # full replacement of the tags array
#     "remove_bullets":     ["- **Status:** In Progress", "- **Jira:** NAT-1234"]
#   }
#
# Idempotent: running with the same change set twice produces the same file.
# Requires: /usr/bin/python3 (system python on macOS is fine).

set -euo pipefail

FILE="${1:?file path required}"
CHANGES="${2:?changes JSON path required}"

if [ ! -f "$FILE" ]; then
  echo "Target file not found: $FILE" >&2
  exit 1
fi
if [ ! -f "$CHANGES" ]; then
  echo "Changes JSON not found: $CHANGES" >&2
  exit 1
fi

/usr/bin/python3 - "$FILE" "$CHANGES" <<'PY'
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

target = Path(sys.argv[1])
changes = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

text = target.read_text(encoding="utf-8")

fm_match = re.match(r"^---\n(.*?)\n---\n?", text, flags=re.DOTALL)
if fm_match:
    fm_block = fm_match.group(1)
    body = text[fm_match.end():]
else:
    fm_block = ""
    body = text

# Parse frontmatter as an ordered list of (key, raw_value_lines).
# Avoids PyYAML so the script is dependency-free and preserves original formatting.
entries = []
current_key = None
current_lines = []
KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$")

for line in fm_block.split("\n"):
    m = KEY_RE.match(line)
    if m and not line.startswith(" ") and not line.startswith("\t"):
        if current_key is not None:
            entries.append((current_key, current_lines))
        current_key = m.group(1)
        current_lines = [line]
    else:
        current_lines.append(line)
if current_key is not None:
    entries.append((current_key, current_lines))

def render_scalar(key, value):
    if isinstance(value, bool):
        return [f"{key}: {'true' if value else 'false'}"]
    if value is None:
        return [f"{key}:"]
    return [f"{key}: {value}"]

def render_list(key, items):
    out = [f"{key}:"]
    for item in items:
        out.append(f"- {item}")
    return out

remove_keys = set(changes.get("remove_properties", []) or [])
entries = [(k, v) for (k, v) in entries if k not in remove_keys]

set_props = changes.get("set_properties", {}) or {}
key_to_index = {k: i for i, (k, _) in enumerate(entries)}
for key, value in set_props.items():
    new_lines = render_scalar(key, value)
    if key in key_to_index:
        entries[key_to_index[key]] = (key, new_lines)
    else:
        entries.append((key, new_lines))
        key_to_index[key] = len(entries) - 1

if "set_tags" in changes:
    tags = changes["set_tags"] or []
    new_lines = render_list("tags", tags)
    if "tags" in key_to_index:
        entries[key_to_index["tags"]] = ("tags", new_lines)
    else:
        entries.insert(0, ("tags", new_lines))

# Stable ordering: tags, type, status, created, updated, then everything else.
priority = {"tags": 0, "type": 1, "status": 2, "created": 3, "updated": 4}
indexed = list(enumerate(entries))
indexed.sort(key=lambda pair: (priority.get(pair[1][0], 99), pair[0]))
entries = [item for _, item in indexed]

new_fm_lines = []
for _, lines in entries:
    new_fm_lines.extend(lines)
new_fm_block = "\n".join(new_fm_lines).rstrip()

remove_bullets = changes.get("remove_bullets", []) or []
if remove_bullets:
    body_lines = body.split("\n")
    removal_set = {b.strip() for b in remove_bullets}
    body = "\n".join(line for line in body_lines if line.strip() not in removal_set)

if new_fm_block:
    body_clean = body.lstrip("\n")
    final = f"---\n{new_fm_block}\n---\n\n{body_clean}"
else:
    final = body

original_bytes = Path(sys.argv[1]).read_bytes()
if final.encode("utf-8") != original_bytes:
    target.write_text(final, encoding="utf-8")
    print(f"updated: {target}")
else:
    print(f"unchanged: {target}")
PY
