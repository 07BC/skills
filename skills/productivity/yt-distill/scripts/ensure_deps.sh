#!/usr/bin/env bash
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 not found — install Python 3.8+" >&2
  exit 1
fi

py_ver=$(python3 -c 'import sys; v=sys.version_info; print(f"{v.major}.{v.minor}")')
major=${py_ver%%.*}
minor=${py_ver#*.}

if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 8 ]; }; then
  echo "error: Python 3.8+ required, found $(python3 --version)" >&2
  exit 1
fi

echo "OK: python${py_ver} — stdlib only, no pip install needed"
