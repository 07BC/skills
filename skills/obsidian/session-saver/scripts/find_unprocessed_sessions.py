#!/usr/bin/env python3
"""List Claude Code session transcripts that have not yet been processed.

Usage:
    find_unprocessed_sessions.py [--vault PATH]

Scans $VAULT/sessions/*.md for files whose YAML frontmatter lacks
`processed: true`. Where multiple snapshots exist for the same session
(filename suffixes like `-t1`, `-t2`), prefers the final save (no suffix);
if no final save exists yet, falls back to the latest snapshot by filename
sort.

Emits one absolute path per line. Read-only — does not mutate frontmatter
or any session file. Intended as the first step of the session-saver
workflow.

VAULT env defaults to $HOME/Developer/obsidian.
"""
from __future__ import annotations
import argparse
import os
import re
import sys
from pathlib import Path


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
_TICK_SUFFIX_RE = re.compile(r"-t\d+(?=\.md$)")
_PROCESSED_RE = re.compile(r"^processed:\s*true\b", re.MULTILINE)


def is_processed(text: str) -> bool:
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return False
    return bool(_PROCESSED_RE.search(m.group(1)))


def base_name(path: Path) -> str:
    return _TICK_SUFFIX_RE.sub("", path.name)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--vault",
        default=os.environ.get("VAULT", str(Path.home() / "Developer" / "obsidian")),
    )
    args = ap.parse_args()

    sessions_dir = Path(args.vault) / "sessions"
    if not sessions_dir.is_dir():
        print(f"Sessions dir not found: {sessions_dir}", file=sys.stderr)
        return 1

    by_base: dict[str, list[Path]] = {}
    for p in sessions_dir.glob("*.md"):
        by_base.setdefault(base_name(p), []).append(p)

    selected: list[Path] = []
    for _, candidates in by_base.items():
        final = next((p for p in candidates if not _TICK_SUFFIX_RE.search(p.name)), None)
        selected.append(final if final is not None else sorted(candidates)[-1])

    for p in sorted(selected):
        try:
            text = p.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if not is_processed(text):
            print(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
