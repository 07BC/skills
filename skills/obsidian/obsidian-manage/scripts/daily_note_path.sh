#!/usr/bin/env bash
# Emit the daily-note path inside the Obsidian vault for today or a given date.
# Usage: daily_note_path.sh [YYYY-MM-DD]
#
# Path format: $VAULT/daily/YYYY/MM-MMM/YY-MM-D.md
# VAULT env defaults to "$HOME/raw" (matches the SKILL.md prose).
#
# DUPLICATE — canonical at:
#   skills/obsidian/obsidian-rollover/scripts/daily_note_path.sh
# Keep in sync with that file and with:
#   skills/obsidian/daily-notes/scripts/daily_note_path.sh

set -euo pipefail

VAULT="${VAULT:-$HOME/raw}"

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
