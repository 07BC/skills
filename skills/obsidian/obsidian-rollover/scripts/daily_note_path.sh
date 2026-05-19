#!/usr/bin/env bash
# Emit the absolute daily-note path for today (no arg) or a given date (YYYY-MM-DD).
set -euo pipefail

VAULT=$(obsidian vault info=path)

if [ -n "${1:-}" ]; then
  ISO="$1"
  YEAR=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%Y)
  MM=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%m)
  MMM=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%b)
  YY=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%y)
  D=$(/bin/date -j -f "%Y-%m-%d" "$ISO" +%-d)
  echo "$VAULT/daily/$YEAR/$MM-$MMM/$YY-$MM-$D.md"
else
  echo "$VAULT/$(obsidian daily:path)"
fi
