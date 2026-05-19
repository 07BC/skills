#!/usr/bin/env bash
# Locates the composition root: @main entry, WindowGroup contents, and the
# View struct that owns the most @StateObject declarations (likely the
# implicit DI root in MVVM apps). Read-only.
# Usage: composition-root.sh

set -euo pipefail

section() { echo; echo "=== $1 ==="; }

EXCL_DIRS="--exclude-dir=.build --exclude-dir=.git --exclude-dir=DerivedData --exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=node_modules --exclude-dir=.swiftpm"

section "Entry-point candidate files"
/usr/bin/find . -maxdepth 5 \
  \( -name "*App.swift" -o -name "AppDelegate.swift" -o -name "SceneDelegate.swift" \) \
  -not -path "*/.build/*" -not -path "*/.git/*" -not -path "*/Pods/*" \
  2>/dev/null | /usr/bin/head -10 || true

section "@main declarations"
# shellcheck disable=SC2086
/usr/bin/grep -rEln --include="*.swift" $EXCL_DIRS '^@main\b' . 2>/dev/null \
  | /usr/bin/head -5 | /usr/bin/sed 's/^/  /' || true

section "WindowGroup roots — the first View rendered"
# shellcheck disable=SC2086
/usr/bin/grep -rEn --include="*.swift" $EXCL_DIRS -A 3 '\bWindowGroup[[:space:]]*\{?' . 2>/dev/null \
  | /usr/bin/head -25 | /usr/bin/sed 's/^/  /' || true

section "Files containing 3+ @StateObject (likely composition roots)"
# shellcheck disable=SC2086
candidates=$(/usr/bin/grep -rEl --include="*.swift" $EXCL_DIRS '@StateObject\b' . 2>/dev/null || true)
if [ -n "$candidates" ]; then
  echo "$candidates" | while read -r f; do
    [ -z "$f" ] && continue
    c=$(/usr/bin/grep -c '@StateObject' "$f" 2>/dev/null || echo 0)
    if [ "$c" -ge 3 ]; then
      printf "  %3d  %s\n" "$c" "$f"
    fi
  done | /usr/bin/sort -rn | /usr/bin/head -10
fi

section "Top composition-root candidate — declarations"
if [ -n "$candidates" ]; then
  top=$(echo "$candidates" | while read -r f; do
    [ -z "$f" ] && continue
    c=$(/usr/bin/grep -c '@StateObject' "$f" 2>/dev/null || echo 0)
    printf "%d %s\n" "$c" "$f"
  done | /usr/bin/sort -rn | /usr/bin/head -1 | /usr/bin/awk '{print $2}')
  if [ -n "$top" ] && [ -f "$top" ]; then
    echo "File: $top"
    /usr/bin/grep -En '@StateObject|@StateObject\(|@State[[:space:]]+var|@Environment[(\\.]|@EnvironmentObject' "$top" 2>/dev/null \
      | /usr/bin/head -20 | /usr/bin/sed 's/^/  /' || true
  fi
fi

section "AppDelegate (UIKit lifecycle, if any)"
# shellcheck disable=SC2086
/usr/bin/grep -rEln --include="*.swift" $EXCL_DIRS 'class[[:space:]]+AppDelegate\b' . 2>/dev/null \
  | /usr/bin/head -3 | /usr/bin/sed 's/^/  /' || true
