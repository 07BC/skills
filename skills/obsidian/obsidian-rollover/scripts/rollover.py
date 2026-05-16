#!/usr/bin/env python3
"""Roll incomplete to-do items from recent past daily notes into today's note.

Usage:
    rollover.py [--dry-run] [--days N] [--vault PATH]

Walks back N days (default 7) from today, collects every `- [ ]` line from
the daily notes it finds, filters out:
  - empty placeholders (`- [ ]` with no text after)
  - items already present in today's `## To-Do` section (case-insensitive,
    markdown links stripped)
  - items that appear as `- [x] ...` anywhere in the scanned window

then inserts the survivors into today's `## To-Do` section, just before the
section's terminator (a `---` divider or the next `## ` heading), with a
blank line separating new items from existing ones.

`--dry-run` reports the plan without modifying anything.

VAULT defaults to $HOME/raw (matches the obsidian-rollover SKILL.md prose),
overridable via the VAULT env var or --vault.
"""
from __future__ import annotations
import argparse
import datetime
import os
import re
import sys
from pathlib import Path


def daily_path(vault: Path, date: datetime.date) -> Path:
    return (
        vault
        / "daily"
        / f"{date.year}"
        / f"{date.month:02d}-{date.strftime('%b')}"
        / f"{date.strftime('%y')}-{date.month:02d}-{date.day}.md"
    )


_OPEN_TODO_RE = re.compile(r"^\s*-\s\[\s\]\s+(\S.*)$")
_DONE_TODO_RE = re.compile(r"^\s*-\s\[[xX]\]\s+(\S.*)$")


def extract_open_todos(text: str) -> list[str]:
    return [m.group(1).strip() for line in text.splitlines() if (m := _OPEN_TODO_RE.match(line))]


def extract_done_todos(text: str) -> set[str]:
    return {
        _normalise(m.group(1))
        for line in text.splitlines()
        if (m := _DONE_TODO_RE.match(line))
    }


def _normalise(s: str) -> str:
    s = re.sub(r"\[(.*?)\]\([^)]+\)", r"\1", s)
    s = re.sub(r"\s+", " ", s).strip().lower()
    return s


def insert_into_todo_section(content: str, new_items: list[str]) -> str:
    lines = content.splitlines()
    start: int | None = None
    for i, line in enumerate(lines):
        if line.strip().lower() == "## to-do":
            start = i
            break
    if start is None:
        block = ["", "## To-Do", ""] + new_items + ["", "---", ""]
        return content.rstrip("\n") + "\n" + "\n".join(block) + "\n"

    end = len(lines)
    for j in range(start + 1, len(lines)):
        if lines[j].strip() == "---" or lines[j].startswith("## "):
            end = j
            break

    prefix = lines[:end]
    suffix = lines[end:]
    if prefix and prefix[-1].strip() != "":
        prefix.append("")
    prefix.extend(new_items)
    out = "\n".join(prefix + suffix)
    if content.endswith("\n"):
        out += "\n"
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument(
        "--vault",
        default=os.environ.get("VAULT", str(Path.home() / "raw")),
    )
    args = ap.parse_args()

    vault = Path(args.vault)
    today = datetime.date.today()

    today_path = daily_path(vault, today)
    if not today_path.exists():
        print(f"Today's note not found at {today_path}", file=sys.stderr)
        print("Create today's note first, then re-run.", file=sys.stderr)
        return 2

    today_text = today_path.read_text(encoding="utf-8")
    already_open = {_normalise(t) for t in extract_open_todos(today_text)}
    completed_anywhere: set[str] = set(extract_done_todos(today_text))

    candidates: list[tuple[datetime.date, str]] = []
    for offset in range(1, args.days + 1):
        d = today - datetime.timedelta(days=offset)
        p = daily_path(vault, d)
        if not p.exists():
            continue
        t = p.read_text(encoding="utf-8")
        completed_anywhere.update(extract_done_todos(t))
        for todo in extract_open_todos(t):
            candidates.append((d, todo))

    seen: set[str] = set(already_open)
    to_add: list[str] = []
    sources: list[tuple[datetime.date, str]] = []
    for d, text in candidates:
        norm = _normalise(text)
        if not norm or norm in seen or norm in completed_anywhere:
            continue
        seen.add(norm)
        to_add.append(f"- [ ] {text}")
        sources.append((d, text))

    if not to_add:
        print("Nothing new to roll over.")
        return 0

    if args.dry_run:
        print(f"Would roll over {len(to_add)} task(s) into {today_path}:")
        for d, text in sources:
            print(f"  - [{d.isoformat()}] {text}")
        return 0

    new_text = insert_into_todo_section(today_text, to_add)
    today_path.write_text(new_text, encoding="utf-8")
    print(f"Rolled over {len(to_add)} task(s):")
    for _, text in sources:
        print(f"  - {text}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
