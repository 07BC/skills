#!/usr/bin/env python3
"""Append knowledge entries to a target file under a dated heading.

Usage:
    kb_append.py [--dry-run] [--date YYYY-MM-DD] --target <file> <entries-file>

DUPLICATE — canonical at:
    skills/obsidian/obsidian-learn/scripts/kb_append.py
Keep in sync with that file. The full docstring lives there; this copy is
kept identical so session-saver can call its own `scripts/kb_append.py`
without depending on a sibling skill's directory.
"""
from __future__ import annotations
import argparse
import datetime
import sys
from pathlib import Path


def read_entries(source: str) -> list[str]:
    raw = sys.stdin.read() if source == "-" else Path(source).read_text(encoding="utf-8")
    return [line.rstrip() for line in raw.splitlines() if line.strip()]


def existing_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def insert_under_date(content: str, date_iso: str, entries: list[str]) -> str:
    heading = f"## {date_iso}"
    if heading in content:
        lines = content.splitlines()
        for i, line in enumerate(lines):
            if line.strip() == heading:
                j = i + 1
                while j < len(lines) and not lines[j].startswith("## "):
                    j += 1
                insert_at = j
                while insert_at > i + 1 and lines[insert_at - 1].strip() == "":
                    insert_at -= 1
                new_lines = lines[:insert_at] + entries + [""] + lines[insert_at:]
                out = "\n".join(new_lines)
                if content.endswith("\n"):
                    out += "\n"
                return out
    sep = "" if not content or content.endswith("\n") else "\n"
    block = f"\n## {date_iso}\n\n" + "\n".join(entries) + "\n"
    return content + sep + block


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--target", required=True, help="Absolute path to the KB file to append to")
    ap.add_argument("entries", help="Path to newline-separated entries file, or '-' for stdin")
    args = ap.parse_args()

    target = Path(args.target).expanduser()
    target.parent.mkdir(parents=True, exist_ok=True)

    raw = read_entries(args.entries)
    if not raw:
        print("No entries to append.", file=sys.stderr)
        return 0

    current = existing_text(target)
    seen_lines = set(current.splitlines())
    deduped = [e for e in raw if e not in seen_lines]
    skipped = len(raw) - len(deduped)

    if not deduped:
        print(f"All {len(raw)} entries already present in {target}; nothing to append.")
        return 0

    if args.dry_run:
        print(f"Would append {len(deduped)} entry(ies) to {target} under ## {args.date}")
        if skipped:
            print(f"  (dedup skipped: {skipped})")
        for e in deduped:
            print(f"  + {e}")
        return 0

    new_text = insert_under_date(current, args.date, deduped)
    target.write_text(new_text, encoding="utf-8")
    print(f"Appended {len(deduped)} entry(ies) to {target} under ## {args.date}")
    if skipped:
        print(f"(skipped {skipped} duplicate(s))")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
