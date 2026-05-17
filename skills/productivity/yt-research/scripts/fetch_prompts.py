#!/usr/bin/env python3
"""
Fetch video descriptions and extract any embedded prompts, saving them as
<slug>-prompts.md alongside the transcript files. Skips videos with no prompts.

Usage (pipe from fetch_videos.py):
    python3 fetch_videos.py <url> | python3 fetch_prompts.py --output-dir <path>

Usage (explicit list):
    python3 fetch_prompts.py --output-dir <path> \
        --videos "id1|||Title One" "id2|||Title Two"
"""
import argparse
import os
import re
import subprocess
import sys
import warnings

warnings.filterwarnings("ignore")


def slugify(title: str, max_len: int = 80) -> str:
    slug = re.sub(r"[^\w\s-]", "", title).strip()
    slug = re.sub(r"\s+", "-", slug)
    return slug[:max_len]


def fetch_description(video_id: str) -> str:
    result = subprocess.run(
        [sys.executable, "-m", "yt_dlp", "--skip-download", "--print", "%(description)s",
         f"https://www.youtube.com/watch?v={video_id}"],
        capture_output=True, text=True, timeout=30,
    )
    return result.stdout.strip()


# Patterns that signal a prompts section in a description
_HEADER_RE = re.compile(r"PROMPTS?\s+FROM\s+THIS\s+VIDEO", re.IGNORECASE)
_PROMPT_LABEL_RE = re.compile(r"^Prompt\s*[#:]", re.IGNORECASE | re.MULTILINE)
_NUMBERED_QUOTED_RE = re.compile(r"^\d+\)\s+\"", re.MULTILINE)


def has_prompts(description: str) -> bool:
    return bool(
        _HEADER_RE.search(description)
        or _PROMPT_LABEL_RE.search(description)
        or _NUMBERED_QUOTED_RE.search(description)
    )


def extract_prompts(description: str) -> list[tuple[str, str]]:
    """Return list of (label, prompt_text) tuples."""
    prompts: list[tuple[str, str]] = []

    # Strategy 1: find a "PROMPTS FROM THIS VIDEO" header and parse numbered items below it
    header_match = _HEADER_RE.search(description)
    if header_match:
        after_header = description[header_match.end():]
        # Match numbered entries: "1) Label:\n"text"" or "1) Label (context):\n"text""
        item_re = re.compile(
            r"(\d+)\)\s+(.+?)(?=\n\d+\)|$)", re.DOTALL
        )
        for m in item_re.finditer(after_header):
            raw = m.group(2).strip()
            lines = raw.splitlines()
            label = lines[0].rstrip(":").strip()
            body_lines = [l.strip().strip('"') for l in lines[1:] if l.strip()]
            body = " ".join(body_lines).strip().strip('"')
            if body:
                prompts.append((label, body))
        if prompts:
            return prompts

    # Strategy 2: find numbered lines where the content is a quoted string
    for m in _NUMBERED_QUOTED_RE.finditer(description):
        start = m.start()
        # grab until next blank line or next numbered item
        chunk = description[start:]
        end = re.search(r"\n\n|\n\d+\)", chunk)
        raw = chunk[: end.start()].strip() if end else chunk.strip()
        # strip the leading "N) "
        raw = re.sub(r"^\d+\)\s*", "", raw).strip().strip('"')
        if raw:
            prompts.append((f"Prompt {len(prompts) + 1}", raw))

    return prompts


def format_prompts_file(video_id: str, title: str, prompts: list[tuple[str, str]]) -> str:
    out = f"# Prompts: {title}\n\n"
    out += f"**Video ID:** {video_id}\n"
    out += f"**URL:** https://www.youtube.com/watch?v={video_id}\n\n"
    out += "## Prompts From This Video\n\n"
    for label, text in prompts:
        out += f"### {label}\n\n"
        out += f'"{text}"\n\n'
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--videos", nargs="*", default=[])
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    lines = args.videos if args.videos else [l.strip() for l in sys.stdin if "|||" in l]
    if not lines:
        print("ERROR: No videos provided", file=sys.stderr)
        sys.exit(1)

    found_count = 0

    for line in lines:
        line = line.strip()
        if "|||" not in line:
            continue
        video_id, title = line.split("|||", 1)
        video_id = video_id.strip()
        title = title.strip()

        try:
            description = fetch_description(video_id)
            if not has_prompts(description):
                print(f"NONE:    {title}")
                continue

            prompts = extract_prompts(description)
            if not prompts:
                print(f"NONE:    {title}")
                continue

            content = format_prompts_file(video_id, title, prompts)
            filepath = os.path.join(args.output_dir, slugify(title) + "-prompts.md")
            with open(filepath, "w") as f:
                f.write(content)
            print(f"PROMPTS: {title} — {len(prompts)} prompts → {filepath}")
            found_count += 1

        except Exception as e:
            print(f"FAIL:    {title} — {e}")

    print(f"\n{found_count} video(s) had prompts in their description")


if __name__ == "__main__":
    main()
