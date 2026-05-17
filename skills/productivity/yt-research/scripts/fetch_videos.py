#!/usr/bin/env python3
"""
Fetch video IDs and titles from a YouTube channel.

Usage:
    python3 fetch_videos.py <channel_url> [--count N]

Output (stdout):
    One line per video: <video_id>|||<title>
"""
import argparse
import subprocess
import sys
import warnings

warnings.filterwarnings("ignore")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("channel_url", help="YouTube channel URL (e.g. https://www.youtube.com/@handle/videos)")
    parser.add_argument("--count", type=int, default=16, help="Number of recent videos to fetch")
    args = parser.parse_args()

    result = subprocess.run(
        [
            "yt-dlp",
            "--flat-playlist",
            "--playlist-end", str(args.count),
            "--print", "%(id)s|||%(title)s",
            args.channel_url,
        ],
        capture_output=True,
        text=True,
        timeout=60,
    )

    if result.returncode != 0:
        print(f"ERROR: yt-dlp failed: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)

    lines = [l for l in result.stdout.splitlines() if "|||" in l]
    if not lines:
        print("ERROR: No videos found", file=sys.stderr)
        sys.exit(1)

    for line in lines:
        print(line)


if __name__ == "__main__":
    main()
