#!/usr/bin/env bash
# scan-ripples.sh — locate behavioural-ripple hotspots in a Swift codebase.
#
# Usage:
#   scan-ripples.sh [<root-or-file>]
#
# Examples:
#   scan-ripples.sh                  # scan current directory
#   scan-ripples.sh Chagi            # scan a subdirectory
#   scan-ripples.sh Chagi/Shared/Player/VODPlayerViewModel.swift
#
# Output: categorised list of matches. Categories are the classes of behaviour
# that most commonly cause invisible side effects when adjacent code changes.
#
# Categories scanned:
#   KVO              — .observe / observe(_: ... ) / addObserver:forKeyPath:
#   Combine          — .sink, .assign, @Published, PassthroughSubject, CurrentValueSubject
#   NotificationCtr  — NotificationCenter.default.{post,addObserver,publisher}
#   ScenePhase       — .onChange(of: scenePhase), @Environment(\.scenePhase)
#   Lifecycle        — viewWillAppear/Disappear, viewDidLoad, applicationDidEnter*,
#                      willResignActive, didBecomeActive, willTerminate, deinit
#   AppStorage       — @AppStorage, UserDefaults.standard
#   Singletons       — \.shared, static let .* = ... (heuristic)
#   SwiftUI state    — @StateObject, @ObservedObject, @EnvironmentObject,
#                      @Environment, @Binding, @State (last two are noisier)
#
# Heuristic. False positives expected — these are categories worth a human (or
# Claude) pass, not authoritative findings.

set -euo pipefail

TARGET="${1:-.}"
[[ ! -e "$TARGET" ]] && { echo "error: $TARGET does not exist" >&2; exit 2; }

# Pick search tool.
if command -v rg >/dev/null 2>&1; then
  HAVE_RG=1
else
  HAVE_RG=0
fi

scan() {
  local label="$1"
  local pattern="$2"
  local hits

  if [[ "$HAVE_RG" -eq 1 ]]; then
    hits=$(rg --line-number --no-heading --color=never \
              --glob '*.swift' -e "$pattern" "$TARGET" 2>/dev/null || true)
  else
    if [[ -d "$TARGET" ]]; then
      hits=$(grep -rn --include='*.swift' -E "$pattern" "$TARGET" 2>/dev/null || true)
    else
      hits=$(grep -nE "$pattern" "$TARGET" 2>/dev/null || true)
    fi
  fi

  if [[ -z "$hits" ]]; then
    return
  fi

  echo "### $label"
  echo "$hits" | sed 's/^/  /'
  echo
}

echo "# Ripple scan: $TARGET"
echo

scan "KVO"              '\.observe\(|addObserver:[[:space:]]*[^,]+forKeyPath'
scan "Combine"          '\.sink[[:space:]]*\{|\.sink\(|\.assign\(to:|PassthroughSubject|CurrentValueSubject|@Published'
scan "NotificationCtr"  'NotificationCenter\.default\.(post|addObserver|publisher)'
scan "ScenePhase"       'scenePhase|onChange\(of:[[:space:]]*scenePhase'
scan "Lifecycle"        'viewWillAppear|viewDidAppear|viewWillDisappear|viewDidDisappear|viewDidLoad|applicationDidEnter|applicationWillEnter|applicationWillResignActive|applicationDidBecomeActive|applicationWillTerminate|deinit[[:space:]]*\{'
scan "AppStorage"       '@AppStorage|UserDefaults\.standard'
scan "Singletons"       '\.shared\b|^[[:space:]]*static[[:space:]]+let[[:space:]]+[a-zA-Z_]+[[:space:]]*='
scan "SwiftUI state"    '@StateObject|@ObservedObject|@EnvironmentObject|@Environment\('
