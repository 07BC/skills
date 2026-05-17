#!/usr/bin/env python3
"""
Extract candidate snippets from yt-research transcript .md files into JSONL.

Each candidate is a single chunk of text that's potentially useful for a
distilled reference library — verbatim prompts, blockquotes, fenced code
blocks, slash-command mentions, or keyword-bearing paragraphs.

Usage:
    extract_candidates.py file1.md [file2.md ...]   > candidates.jsonl

stderr emits one progress line per input file: "OK: <file> — N candidates".
"""

from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import dataclass, asdict
from typing import Iterable

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
FENCE_RE = re.compile(r"^(```|~~~)")
SLASH_RE = re.compile(r"(?<![\w/])/(?!\d)[a-z][a-z0-9\-:_]{1,40}")
PROMPT_LABEL_RE = re.compile(r"^\s*(prompt|prompts)\s*(#?\d*)\s*[:\-]", re.I)
HEADER_PROMPT_RE = re.compile(r"prompts?\s+from\s+this\s+video", re.I)

# Topical keywords used to classify free-form paragraphs.
SKILL_TERMS = (
    "skill", "slash command", "slash-command", "subagent", "sub-agent",
    "agent", "hook", "claude code skill",
)
PLUGIN_TERMS = (
    "plugin", "plug-in", "mcp", "mcp server", "connector", "integration",
    "extension", "marketplace", "tool server",
)
PROMPT_TERMS = (
    "prompt", "instructions", "system prompt", "user prompt", "tell claude",
    "ask claude", "you are", "your job", "your role",
)
TECHNIQUE_TERMS = (
    "workflow", "pattern", "technique", "approach", "principle", "rule",
    "tip", "best practice", "strategy", "method", "mental model",
    "framework", "system", "process",
)


@dataclass
class Candidate:
    source_file: str
    source_kind: str  # "prompts_file" | "transcript"
    line: int
    heading_path: list[str]
    type: str        # "verbatim_prompt" | "blockquote" | "code_block" |
                     # "slash_command" | "keyword_paragraph"
    category_hint: str  # "skills" | "plugins" | "prompts" | "techniques" | "?"
    text: str


def classify(text: str, kind: str) -> str:
    low = text.lower()

    if kind in ("verbatim_prompt", "blockquote") and (
        '"' in text or PROMPT_LABEL_RE.search(text)
    ):
        return "prompts"

    if any(term in low for term in PLUGIN_TERMS):
        return "plugins"
    if any(term in low for term in SKILL_TERMS):
        return "skills"
    if kind == "slash_command":
        return "skills"
    if any(term in low for term in PROMPT_TERMS):
        return "prompts"
    if any(term in low for term in TECHNIQUE_TERMS):
        return "techniques"
    return "?"


def update_heading_path(stack: list[tuple[int, str]], level: int, text: str) -> list[str]:
    while stack and stack[-1][0] >= level:
        stack.pop()
    stack.append((level, text))
    return [h for _, h in stack]


def is_quoted_sentence(text: str) -> bool:
    s = text.strip()
    if len(s) < 8:
        return False
    return (s.startswith('"') and s.rstrip('.').endswith('"')) or (
        s.startswith("“") and s.rstrip(".").endswith("”")
    )


def flush_paragraph(buf: list[str]) -> str:
    return " ".join(line.strip() for line in buf).strip()


def emit(c: Candidate) -> None:
    sys.stdout.write(json.dumps(asdict(c), ensure_ascii=False) + "\n")


def process_file(path: str) -> int:
    base = os.path.basename(path)
    kind = "prompts_file" if base.endswith("-prompts.md") else "transcript"

    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
    except OSError as exc:
        sys.stderr.write(f"FAIL: {base} — {exc}\n")
        return 0

    heading_stack: list[tuple[int, str]] = []
    in_fence = False
    fence_buf: list[str] = []
    fence_start = 0
    fence_under_prompt_header = False

    blockquote_buf: list[str] = []
    blockquote_start = 0

    paragraph_buf: list[str] = []
    paragraph_start = 0

    under_prompt_header = False
    count = 0

    def flush_blockquote() -> None:
        nonlocal count
        if not blockquote_buf:
            return
        text = "\n".join(blockquote_buf).strip()
        if not text:
            return
        ctype = "verbatim_prompt" if (under_prompt_header or is_quoted_sentence(text)) else "blockquote"
        c = Candidate(
            source_file=base,
            source_kind=kind,
            line=blockquote_start,
            heading_path=[h for _, h in heading_stack],
            type=ctype,
            category_hint=classify(text, ctype),
            text=text,
        )
        emit(c)
        count += 1

    def flush_paragraph_buf() -> None:
        nonlocal count
        if not paragraph_buf:
            return
        text = flush_paragraph(paragraph_buf)
        if len(text) < 40:
            return

        low = text.lower()
        slash_hit = SLASH_RE.search(text)
        keyword_hit = any(
            t in low for t in (SKILL_TERMS + PLUGIN_TERMS + PROMPT_TERMS + TECHNIQUE_TERMS)
        )
        prompt_label = PROMPT_LABEL_RE.search(text)

        if slash_hit:
            c = Candidate(
                source_file=base,
                source_kind=kind,
                line=paragraph_start,
                heading_path=[h for _, h in heading_stack],
                type="slash_command",
                category_hint="skills",
                text=text,
            )
            emit(c)
            count += 1
            return

        if prompt_label or under_prompt_header:
            c = Candidate(
                source_file=base,
                source_kind=kind,
                line=paragraph_start,
                heading_path=[h for _, h in heading_stack],
                type="verbatim_prompt",
                category_hint="prompts",
                text=text,
            )
            emit(c)
            count += 1
            return

        if keyword_hit:
            c = Candidate(
                source_file=base,
                source_kind=kind,
                line=paragraph_start,
                heading_path=[h for _, h in heading_stack],
                type="keyword_paragraph",
                category_hint=classify(text, "keyword_paragraph"),
                text=text,
            )
            emit(c)
            count += 1

    for idx, raw in enumerate(lines, start=1):
        line = raw.rstrip("\n")

        # Fenced code blocks.
        m_fence = FENCE_RE.match(line.strip())
        if m_fence:
            if not in_fence:
                in_fence = True
                fence_buf = []
                fence_start = idx
                fence_under_prompt_header = under_prompt_header
            else:
                in_fence = False
                text = "\n".join(fence_buf).strip()
                if text:
                    ctype = "verbatim_prompt" if fence_under_prompt_header else "code_block"
                    c = Candidate(
                        source_file=base,
                        source_kind=kind,
                        line=fence_start,
                        heading_path=[h for _, h in heading_stack],
                        type=ctype,
                        category_hint=classify(text, ctype),
                        text=text,
                    )
                    emit(c)
                    count += 1
                fence_buf = []
            continue
        if in_fence:
            fence_buf.append(line)
            continue

        # Headings — flush any in-flight buffers first.
        m_head = HEADING_RE.match(line)
        if m_head:
            flush_blockquote()
            blockquote_buf = []
            flush_paragraph_buf()
            paragraph_buf = []

            level = len(m_head.group(1))
            text = m_head.group(2).strip()
            update_heading_path(heading_stack, level, text)
            under_prompt_header = bool(HEADER_PROMPT_RE.search(text))
            continue

        # Blockquotes.
        if line.lstrip().startswith(">"):
            if not blockquote_buf:
                blockquote_start = idx
            blockquote_buf.append(line.lstrip()[1:].lstrip())
            continue
        else:
            if blockquote_buf:
                flush_blockquote()
                blockquote_buf = []

        # Paragraph accumulation.
        if line.strip():
            if not paragraph_buf:
                paragraph_start = idx
            paragraph_buf.append(line)
        else:
            flush_paragraph_buf()
            paragraph_buf = []

    # Final flush.
    if blockquote_buf:
        flush_blockquote()
    if paragraph_buf:
        flush_paragraph_buf()
    if in_fence and fence_buf:
        text = "\n".join(fence_buf).strip()
        if text:
            c = Candidate(
                source_file=base,
                source_kind=kind,
                line=fence_start,
                heading_path=[h for _, h in heading_stack],
                type="code_block",
                category_hint=classify(text, "code_block"),
                text=text,
            )
            emit(c)
            count += 1

    sys.stderr.write(f"OK: {base} — {count} candidates\n")
    return count


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write("usage: extract_candidates.py FILE [FILE ...]\n")
        return 2

    total = 0
    files = 0
    for path in argv[1:]:
        if not os.path.isfile(path):
            sys.stderr.write(f"SKIP: {path} — not a file\n")
            continue
        total += process_file(path)
        files += 1

    sys.stderr.write(f"=== {files} file(s), {total} candidate(s) ===\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
