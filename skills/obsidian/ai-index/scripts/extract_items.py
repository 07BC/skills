#!/usr/bin/env python3
"""
extract_items.py — scan yt-distill output directories and emit H2 items as JSONL.

Usage:
    python3 extract_items.py <ai_root> > /tmp/ai-index-items.jsonl

Scans <ai_root>/<channel>/{skills,prompts,techniques,plugins}/*.md
Skips: index/, plans/, Plans/, sessions/, knowledge/, audit/, and dotfiles.

Output (stdout): one JSON object per H2 item:
  { "channel": "...", "type": "skills|prompts|techniques|plugins",
    "source_file": "<channel>/<type>/<file>.md",
    "h2_title": "...", "content": "..." }
"""

import json
import sys
from pathlib import Path

SKIP_DIRS = {"index", "plans", "Plans", "sessions", "knowledge", "audit"}
TYPES = ("skills", "prompts", "techniques", "plugins")


def extract_h2_blocks(text):
    blocks = []
    current_title = None
    current_lines = []

    for line in text.splitlines():
        if line.startswith("## "):
            if current_title is not None:
                blocks.append((current_title, "\n".join(current_lines).strip()))
            current_title = line[3:].strip()
            current_lines = []
        elif current_title is not None:
            current_lines.append(line)

    if current_title is not None:
        blocks.append((current_title, "\n".join(current_lines).strip()))

    return blocks


def main():
    if len(sys.argv) < 2:
        print("Usage: extract_items.py <ai_root>", file=sys.stderr)
        sys.exit(1)

    ai_root = Path(sys.argv[1]).expanduser().resolve()
    if not ai_root.is_dir():
        print(f"ERROR: {ai_root} is not a directory", file=sys.stderr)
        sys.exit(1)

    total = 0
    for channel_dir in sorted(ai_root.iterdir()):
        if not channel_dir.is_dir():
            continue
        if channel_dir.name in SKIP_DIRS or channel_dir.name.startswith("."):
            continue

        channel_count = 0
        for type_name in TYPES:
            type_dir = channel_dir / type_name
            if not type_dir.is_dir():
                continue

            for md_file in sorted(type_dir.glob("*.md")):
                text = md_file.read_text(encoding="utf-8")
                blocks = extract_h2_blocks(text)

                for h2_title, content in blocks:
                    if not content:
                        continue
                    record = {
                        "channel": channel_dir.name,
                        "type": type_name,
                        "source_file": f"{channel_dir.name}/{type_name}/{md_file.name}",
                        "h2_title": h2_title,
                        "content": content,
                    }
                    print(json.dumps(record, ensure_ascii=False))
                    channel_count += 1

        if channel_count:
            print(f"OK: {channel_dir.name} — {channel_count} items", file=sys.stderr)
        total += channel_count

    print(f"=== {total} item(s) total ===", file=sys.stderr)


if __name__ == "__main__":
    main()
