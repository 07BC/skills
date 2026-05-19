#!/usr/bin/env python3
"""Roll incomplete to-do items from recent past daily notes into today's note.

Uses the Obsidian CLI (obsidian) for all vault and task queries.
Writes the result directly to today's note, inserting into the ## To-Do section.

Usage:
    rollover.py [--dry-run] [--days N]
"""
from __future__ import annotations
import argparse
import datetime
import json
import re
import subprocess
import sys
from pathlib import Path


def _obsidian(*args: str) -> str:
    result = subprocess.run(["obsidian", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"obsidian {args[0]} failed")
    return result.stdout.strip()


def _vault() -> Path:
    return Path(_obsidian("vault", "info=path"))


def _daily_rel(date: datetime.date) -> str:
    return (
        f"daily/{date.year}"
        f"/{date.month:02d}-{date.strftime('%b')}"
        f"/{date.strftime('%y')}-{date.month:02d}-{date.day}.md"
    )


def _tasks(path_arg: str, done: bool = False) -> list[str]:
    """Return full task lines (`- [ ] …` or `- [x] …`) from the vault CLI."""
    cmd = "done" if done else "todo"
    try:
        out = _obsidian("tasks", cmd, path_arg, "format=json")
    except RuntimeError:
        return []
    if not out or out.startswith("No tasks"):
        return []
    return [item["text"] for item in json.loads(out)]


_OPEN_RE = re.compile(r"^\s*-\s\[\s\]\s+(\S.*)$")
_DONE_RE = re.compile(r"^\s*-\s\[[xX]\]\s+(\S.*)$")


def _text(line: str, done: bool = False) -> str | None:
    m = (_DONE_RE if done else _OPEN_RE).match(line)
    return m.group(1).strip() if m else None


def _norm(s: str) -> str:
    s = re.sub(r"\[(.*?)\]\([^)]+\)", r"\1", s)
    return re.sub(r"\s+", " ", s).strip().lower()


def _insert(content: str, new_items: list[str]) -> str:
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
    args = ap.parse_args()

    vault = _vault()
    today = datetime.date.today()
    today_path = vault / _daily_rel(today)

    if not today_path.exists():
        print(f"Today's note not found at {today_path}", file=sys.stderr)
        print("Create today's note first, then re-run.", file=sys.stderr)
        return 2

    today_text = today_path.read_text(encoding="utf-8")

    already_open: set[str] = set()
    for line in _tasks("daily"):
        t = _text(line)
        if t:
            already_open.add(_norm(t))

    completed_anywhere: set[str] = set()
    for line in _tasks("daily", done=True):
        t = _text(line, done=True)
        if t:
            completed_anywhere.add(_norm(t))

    candidates: list[tuple[datetime.date, str]] = []
    for offset in range(1, args.days + 1):
        d = today - datetime.timedelta(days=offset)
        rel = _daily_rel(d)
        if not (vault / rel).exists():
            continue
        for line in _tasks(f"path={rel}", done=True):
            t = _text(line, done=True)
            if t:
                completed_anywhere.add(_norm(t))
        for line in _tasks(f"path={rel}"):
            t = _text(line)
            if t:
                candidates.append((d, t))

    seen = set(already_open)
    to_add: list[str] = []
    sources: list[tuple[datetime.date, str]] = []
    for d, text in candidates:
        norm = _norm(text)
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

    today_path.write_text(_insert(today_text, to_add), encoding="utf-8")
    print(f"Rolled over {len(to_add)} task(s):")
    for _, text in sources:
        print(f"  - {text}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
