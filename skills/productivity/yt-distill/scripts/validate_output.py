#!/usr/bin/env python3
"""
Validate a yt-distill output directory.

Checks:
- Top-level index.md exists with H1.
- All [text](path) links in index.md resolve to real files in <dest>.
- Each .md inside skills/, plugins/, prompts/, techniques/ has:
    * exactly one H1 at the top,
    * at least one source citation line "**Source:**",
    * no duplicate H2 titles (case-insensitive),
    * no YAML frontmatter (no leading "---" block).
- Reports counts per category.

Usage:
    validate_output.py <dest>

Exits 0 if no ERROR lines. Prints "OK: …" for passing checks and
"ERROR: …" for failures.
"""

from __future__ import annotations

import os
import re
import sys

CATEGORIES = ("skills", "plugins", "prompts", "techniques")
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
H1_RE = re.compile(r"^#\s+\S")
H2_RE = re.compile(r"^##\s+(.+?)\s*$")


def read(path: str) -> list[str]:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read().splitlines()


def validate_index(dest: str, errors: list[str]) -> None:
    idx = os.path.join(dest, "index.md")
    if not os.path.isfile(idx):
        errors.append(f"ERROR: missing index.md at {idx}")
        return

    lines = read(idx)
    non_empty = [l for l in lines if l.strip()]
    if not non_empty or not H1_RE.match(non_empty[0]):
        errors.append("ERROR: index.md is missing an H1 on the first non-empty line")

    for ln_no, line in enumerate(lines, start=1):
        for label, target in LINK_RE.findall(line):
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target_path = os.path.normpath(os.path.join(dest, target))
            if not os.path.isfile(target_path):
                errors.append(
                    f"ERROR: index.md:{ln_no} broken link [{label}]({target}) → {target_path}"
                )


def validate_md(path: str, errors: list[str]) -> None:
    rel = os.path.relpath(path)
    lines = read(path)

    if lines and lines[0].strip() == "---":
        errors.append(f"ERROR: {rel} has YAML frontmatter (not allowed)")

    non_empty = [l for l in lines if l.strip()]
    if not non_empty or not H1_RE.match(non_empty[0]):
        errors.append(f"ERROR: {rel} is missing an H1 on the first non-empty line")

    body = "\n".join(lines)
    if "**Source:**" not in body and "**Sources:**" not in body:
        errors.append(f"ERROR: {rel} has no '**Source:**' citation")

    seen: dict[str, int] = {}
    for ln_no, line in enumerate(lines, start=1):
        m = H2_RE.match(line)
        if not m:
            continue
        title = m.group(1).strip().lower()
        if title in seen:
            errors.append(
                f"ERROR: {rel}:{ln_no} duplicate H2 '{m.group(1)}' (first seen at line {seen[title]})"
            )
        else:
            seen[title] = ln_no


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        sys.stderr.write("usage: validate_output.py <dest>\n")
        return 2

    dest = argv[1]
    if not os.path.isdir(dest):
        sys.stderr.write(f"ERROR: {dest} is not a directory\n")
        return 2

    errors: list[str] = []
    counts: dict[str, int] = {c: 0 for c in CATEGORIES}

    validate_index(dest, errors)

    for category in CATEGORIES:
        cat_dir = os.path.join(dest, category)
        if not os.path.isdir(cat_dir):
            continue
        for name in sorted(os.listdir(cat_dir)):
            if not name.endswith(".md"):
                continue
            counts[category] += 1
            validate_md(os.path.join(cat_dir, name), errors)

    for line in errors:
        print(line)

    print()
    print("=== validate_output ===")
    for cat in CATEGORIES:
        print(f"{cat:<11} {counts[cat]} file(s)")
    print(f"errors:     {len(errors)}")
    print(f"output:     {dest}")
    print("=======================")

    if errors:
        return 1
    print("OK: validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
