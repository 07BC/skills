#!/usr/bin/env python3
"""
Download YouTube audio with yt-dlp and transcribe locally with whisper-cli.

Why: YouTube's /api/timedtext endpoint is IP-rate-limited / blocked from many
networks, so youtube-transcript-api and yt-dlp subtitle downloads fail with
IpBlocked / HTTP 429. Audio downloads via the android_vr / tv_embedded player
clients still work, and whisper-cpp transcribes locally with Metal GPU on
Apple Silicon.

Usage (pipe from fetch_videos.py):
    python3 fetch_videos.py <url> | python3 fetch_transcripts.py --output-dir <path>

Usage (explicit list):
    python3 fetch_transcripts.py --output-dir <path> \
        --videos "id1|||Title One" "id2|||Title Two"
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_MODEL = os.path.expanduser(
    os.environ.get("WHISPER_MODEL", "~/.cache/whisper-models/ggml-base.en.bin")
)


def slugify(title: str, max_len: int = 80) -> str:
    slug = re.sub(r"[^\w\s-]", "", title).strip()
    slug = re.sub(r"\s+", "-", slug)
    return slug[:max_len]


def download_audio(video_id: str, work_dir: str) -> str:
    out_template = os.path.join(work_dir, "%(id)s.%(ext)s")
    cmd = [
        sys.executable, "-m", "yt_dlp",
        "--extractor-args", "youtube:player_client=android_vr,tv_embedded",
        "-x", "--audio-format", "wav",
        "--postprocessor-args", "ExtractAudio:-ar 16000 -ac 1",
        "--no-progress",
        "-o", out_template,
        f"https://www.youtube.com/watch?v={video_id}",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    wav_path = os.path.join(work_dir, f"{video_id}.wav")
    if result.returncode != 0 or not os.path.exists(wav_path):
        stderr = (result.stderr or "").strip().splitlines()
        msg = next(
            (l for l in reversed(stderr) if l.lower().startswith("error")),
            stderr[-1] if stderr else "audio download failed",
        )
        raise RuntimeError(msg[:200])
    return wav_path


def transcribe(wav_path: str, model_path: str) -> str:
    out_prefix = wav_path[:-4]
    cmd = [
        "whisper-cli",
        "-m", model_path,
        "-f", wav_path,
        "--output-txt",
        "--output-file", out_prefix,
        "--no-prints",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    txt_path = out_prefix + ".txt"
    if result.returncode != 0 or not os.path.exists(txt_path):
        raise RuntimeError(
            (result.stderr or "whisper-cli failed").strip().splitlines()[-1][:200]
        )
    with open(txt_path) as f:
        return f.read().strip()


def format_markdown(video_id: str, title: str, transcript: str) -> str:
    paragraphs: list[str] = []
    buf: list[str] = []
    for raw in transcript.splitlines():
        line = raw.strip()
        if not line:
            continue
        buf.append(line)
        if len(buf) >= 6:
            paragraphs.append(" ".join(buf))
            buf = []
    if buf:
        paragraphs.append(" ".join(buf))

    body = "\n\n".join(paragraphs)
    return (
        f"# {title}\n\n"
        f"**Video ID:** {video_id}\n"
        f"**URL:** https://www.youtube.com/watch?v={video_id}\n\n"
        f"## Transcript\n\n"
        f"{body}\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--videos", nargs="*", default=[])
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help="Path to whisper.cpp GGML model file")
    args = parser.parse_args()

    if not os.path.exists(args.model):
        print(f"ERROR: Whisper model not found at {args.model}", file=sys.stderr)
        print("Run scripts/ensure_deps.sh to download it.", file=sys.stderr)
        sys.exit(1)

    os.makedirs(args.output_dir, exist_ok=True)

    lines = args.videos if args.videos else [l.strip() for l in sys.stdin if "|||" in l]
    if not lines:
        print("ERROR: No videos provided", file=sys.stderr)
        sys.exit(1)

    success = failed = 0
    work_root = tempfile.mkdtemp(prefix="yt-research-")
    try:
        for line in lines:
            line = line.strip()
            if "|||" not in line:
                continue
            video_id, title = (s.strip() for s in line.split("|||", 1))

            work_dir = os.path.join(work_root, video_id)
            os.makedirs(work_dir, exist_ok=True)
            try:
                wav_path = download_audio(video_id, work_dir)
                transcript = transcribe(wav_path, args.model)
                md = format_markdown(video_id, title, transcript)
                filepath = os.path.join(args.output_dir, slugify(title) + ".md")
                with open(filepath, "w") as f:
                    f.write(md)
                print(f"OK: {title}")
                success += 1
            except Exception as e:
                print(f"FAIL: {title} — {str(e)[:160]}")
                failed += 1
            finally:
                shutil.rmtree(work_dir, ignore_errors=True)
    finally:
        shutil.rmtree(work_root, ignore_errors=True)

    total = success + failed
    print(f"\n{success}/{total} transcripts saved, {failed} failed")


if __name__ == "__main__":
    main()
