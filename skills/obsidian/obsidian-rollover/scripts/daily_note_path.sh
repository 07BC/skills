#!/usr/bin/env bash
# Emit the daily-note path inside the Obsidian vault for today or a given date.
# Usage: daily_note_path.sh [YYYY-MM-DD]
#
# Path format: $VAULT/daily/YYYY/MM-MMM/YY-MM-D.md
#   YYYY  4-digit year       (e.g. 2026)
#   MM    2-digit month      (e.g. 05)
#   MMM   3-letter month     (e.g. May)
#   YY    2-digit year       (e.g. 26)
#   D     day, NO zero-pad   (e.g. 1, 16, 31)
#
# VAULT resolved via _lib/obsidian-path.sh

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../.." && pwd)/_lib"
VAULT=$(bash "$LIB_DIR/obsidian-path.sh")

if [ -n "${1:-}" ]; then
  ISO="$1"
  YEAR=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%Y)
  MM=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%m)
  MMM=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%b)
  YY=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%y)
  D=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%-d)
else
  YEAR=$(/bin/date +%Y)
  MM=$(/bin/date +%m)
  MMM=$(/bin/date +%b)
  YY=$(/bin/date +%y)
  D=$(/bin/date +%-d)
fi

echo "$VAULT/daily/$YEAR/$MM-$MMM/$YY-$MM-$D.md"
