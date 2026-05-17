#!/usr/bin/env bash
# Emit the daily-note path inside the Obsidian vault for today or a given date.
# Usage: daily_note_path.sh [YYYY-MM-DD]
#
# Path format: $VAULT/daily/YYYY/MM-MMM/YY-MM-D.md
# VAULT resolved via _lib/obsidian-path.sh
#   skills/obsidian/obsidian-manage/scripts/daily_note_path.sh

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
