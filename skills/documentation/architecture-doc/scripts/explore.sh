#!/usr/bin/env bash
# Phase 1 exploration for architecture-doc: emit raw observations about a
# Swift codebase before any prose synthesis. Read-only.
# Usage: explore.sh
#
# Outputs newline-separated sections:
#   - top-level swift files (depth 3)
#   - directory listing
#   - package graph (Package.swift if present)
#   - xcode project settings (Swift version, deployment targets, bundle id)
#   - entry-point candidates (*App.swift, AppDelegate.swift)
#   - local packages (LocalPackages/, Packages/, or none)
#
# Errors on missing files are silenced — the script may be run in any Swift
# project shape (SwiftPM, Xcode workspace, or a hybrid).

set -euo pipefail

section() { echo; echo "=== $1 ==="; }

section "top-level swift files (depth 3)"
/usr/bin/find . -maxdepth 3 -name "*.swift" 2>/dev/null | /usr/bin/head -60 || true

section "directory listing"
/bin/ls -la

section "package graph"
if [ -f Package.swift ]; then
  /bin/cat Package.swift
else
  echo "(no Package.swift)"
fi

section "xcode project settings"
PBXPROJ=$(/usr/bin/find . -name "project.pbxproj" 2>/dev/null | /usr/bin/head -1 || true)
if [ -n "$PBXPROJ" ] && [ -f "$PBXPROJ" ]; then
  /usr/bin/grep -E "SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|PRODUCT_BUNDLE_IDENTIFIER|MACOSX_DEPLOYMENT_TARGET|TVOS_DEPLOYMENT_TARGET" "$PBXPROJ" 2>/dev/null | /usr/bin/sort -u || true
else
  echo "(no project.pbxproj)"
fi

section "entry-point candidates"
/usr/bin/find . \( -name "*App.swift" -o -name "AppDelegate.swift" \) 2>/dev/null | /usr/bin/head -5 || true

section "local packages"
if [ -d LocalPackages ]; then
  /bin/ls LocalPackages/
elif [ -d Packages ]; then
  /bin/ls Packages/
else
  echo "(no LocalPackages/ or Packages/)"
fi
