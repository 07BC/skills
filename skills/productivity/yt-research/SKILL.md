---
name: yt-research
description: >
  Downloads transcripts and extracts prompts from a YouTube channel's recent
  videos, saving each as a markdown file. Use when the user says "get transcripts
  from", "download YouTube transcripts", "scrape this YouTube channel",
  "save transcripts from YouTube", "yt-research", or wants to research a
  creator's content from a YouTube channel URL. Always use this skill — do not
  attempt YouTube transcript extraction ad hoc without it.
---

# yt-research

Fetches the last N videos from a YouTube channel, saves each transcript as
a markdown file, then checks each video description for embedded prompts and
saves those separately.

**Dependencies:** `yt-dlp` (Python), `ffmpeg`, and `whisper-cli` (from
`whisper-cpp`) must be installed. A GGML Whisper model file (default:
`ggml-base.en.bin`) is also required. Run `scripts/ensure_deps.sh` first —
it installs the Python package, verifies the binaries, and downloads the
default model on first run.

**Why audio + Whisper, not the transcript API?** YouTube IP-rate-limits the
`/api/timedtext` endpoint, so `youtube-transcript-api` and yt-dlp subtitle
downloads return `IpBlocked` / HTTP 429 from many networks. Audio downloads
via the `android_vr` / `tv_embedded` player clients still work, and
`whisper.cpp` transcribes locally with Metal GPU on Apple Silicon (~10s per
5-minute video on M1 with `base.en`).

---

## Step 0 — Resolve inputs

From the user's message, extract:

- **Channel URL** — e.g. `https://www.youtube.com/@handle/videos` or a single video URL.
- **Video count** — how many recent videos to fetch (default: 16).

If the channel URL is missing, ask for it via `AskUserQuestion` before
proceeding. Do not guess a URL.

### Resolve output directory (always Obsidian vault)

This skill always writes output to the user's Obsidian vault — that
choice is intentional, not configurable. The transcript folder lives
under `<vault_path>/AI/<channel-slug>/transcript` so all research
artefacts collect in one place. If you need to save elsewhere, copy
the folder manually after the run.

1. Confirm the Obsidian CLI is installed:

   ```bash
   if ! command -v obsidian >/dev/null 2>&1; then
     echo "Obsidian CLI not found. Install with 'brew install obsidian-cli' or set OBSIDIAN_VAULT_PATH and re-run." >&2
     exit 1
   fi
   ```

   If `$OBSIDIAN_VAULT_PATH` is set as an env override, skip the
   `obsidian vault` lookup and use that path directly.

2. Get the vault path:
   ```
   obsidian vault
   ```
   Parse the `path` field from the output (tab-separated `name<TAB>path<TAB>...`).

3. Get the channel/uploader name from the URL using yt-dlp:
   ```
   yt-dlp --print "%(uploader)s" --playlist-end 1 <url>
   ```
   Slugify it: lowercase, spaces → hyphens, strip non-alphanumeric characters except hyphens.

4. Set output directory:
   ```
   <vault_path>/AI/<channel-slug>/transcript
   ```
   Create it with `mkdir -p` before running scripts.

Do not ask the user for an output directory — always use this Obsidian path.

---

## Step 1 — Install dependencies

Run `scripts/ensure_deps.sh`. It exits 0 when `yt_dlp`, `ffmpeg`,
`whisper-cli`, and the Whisper model file are all present (downloading the
model if missing). If it exits non-zero, report the error and stop —
typically the user needs to `brew install ffmpeg whisper-cpp`.

Override the model with environment variables:

- `WHISPER_MODEL_NAME` — e.g. `ggml-small.en.bin` for better accuracy
- `WHISPER_MODEL_DIR` — directory holding the model (default `~/.cache/whisper-models`)

---

## Step 2 — Fetch video list

Run `scripts/fetch_videos.py` with the channel URL and count:

```
python3 scripts/fetch_videos.py <channel_url> --count <n>
```

Output is one line per video: `<video_id>|||<title>`. Capture stdout.

If the script fails (network error, private channel, bad URL), report the
error and stop.

---

## Step 3 — Fetch transcripts

Run `scripts/fetch_transcripts.py` with the video list and output directory:

```
python3 scripts/fetch_transcripts.py \
  --videos "<id>|||<title>" "<id>|||<title>" ... \
  --output-dir <path>
```

Or pass the video list via stdin:

```
python3 scripts/fetch_videos.py <channel_url> --count <n> | \
  python3 scripts/fetch_transcripts.py --output-dir <path>
```

For each video, the script downloads the audio track (~5–10 MB WAV at 16 kHz
mono) to a temp dir, runs `whisper-cli` to transcribe it, formats the output
as markdown, and writes `<Slugified-Title>.md` to the output directory. Temp
files are cleaned up after each video. Override the model path with
`--model <path>` or the `WHISPER_MODEL` env var.

Output format:

```
OK: <title>
FAIL: <title> — <error>
```

Expect ~10–30 seconds per 5-minute video on Apple Silicon with `base.en`.
Watch the progress live — there is no per-video timeout to worry about for
typical videos, but very long talks (>1 hour) can take several minutes
each.

---

## Step 4 — Extract prompts from descriptions

Run `scripts/fetch_prompts.py` with the same video list and output directory:

```
python3 scripts/fetch_videos.py <channel_url> --count <n> | \
  python3 scripts/fetch_prompts.py --output-dir <path>
```

The script fetches each video's description via `yt-dlp`, detects any prompt
blocks (heuristic: lines labelled "prompt", quoted instructions, numbered
prompt lists), and writes a `<Slug>-prompts.md` **only when prompts are found**.
Videos with no prompts in their description produce no output file.

Output format:

```
PROMPTS: <title> — <n> prompts saved → <filepath>
NONE:    <title>
```

---

## Step 5 — Report summary

After all three scripts complete, print a summary:

```
=== yt-research: @handle ===
Transcripts: 15/16 saved (1 failed)
Prompts:      1 video had prompts in the description
Output:       <output_dir>
===
```

List any FAILs with their error messages below the summary block.

---

## Filename convention

Titles are slugified: non-word characters stripped, spaces replaced with `-`,
truncated to 80 chars, `.md` appended.

| Type | Filename |
|---|---|
| Transcript | `How-I-Built-a-481k-App.md` |
| Prompts | `How-I-Built-a-481k-App-prompts.md` |

---

## Prompt detection heuristic

A description contains prompts if it has any of:

- A line matching `PROMPTS FROM THIS VIDEO` (case-insensitive)
- A numbered list where items begin with a quoted string (`"…"`)
- A line beginning with `Prompt:` or `Prompt #`

When detected, extract the full prompt text (quoted strings, numbered items,
or everything under the header) and write them as an H3 per prompt in the
output file.

---

## What to avoid

- Do not hardcode video IDs — always derive them from the channel URL.
- Do not fail the whole batch if one video errors — log FAIL and continue.
- Do not create empty prompt files — only write if prompts were actually found.
- Do not assume `python3` is on PATH without checking via `ensure_deps.sh`.
- Do not pass `--cookies-from-browser` to yt-dlp for audio extraction — the
  `android_vr` / `tv_embedded` clients required to bypass SABR don't accept
  cookies and yt-dlp will skip them with a warning if cookies are present.
