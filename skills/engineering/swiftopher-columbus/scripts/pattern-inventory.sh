#!/usr/bin/env bash
# Reports MV vs MVVM adoption, observable patterns, actor usage, and
# concurrency primitives across a Swift codebase. Read-only.
# Usage: pattern-inventory.sh
#
# Outputs counts and sample hits for each detected pattern, then a one-line
# verdict ("Pattern: MV" / "MVVM" / "mixed" / "no observable types found").

set -euo pipefail

section() { echo; echo "=== $1 ==="; }

EXCL_DIRS="--exclude-dir=.build --exclude-dir=.git --exclude-dir=DerivedData --exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=node_modules --exclude-dir=.swiftpm"

# Print a count and up to 5 sample lines for a pattern. Safe under pipefail.
report() {
  local pattern="$1"
  local label="$2"
  local hits count
  # shellcheck disable=SC2086
  hits=$(/usr/bin/grep -rEn --include="*.swift" $EXCL_DIRS "$pattern" . 2>/dev/null || true)
  count=$(echo "$hits" | /usr/bin/grep -c . || true)
  echo "$label: $count"
  if [ "$count" -gt 0 ]; then
    echo "$hits" | /usr/bin/head -5 | /usr/bin/sed 's/^/  /'
  fi
}

# Count-only helper used by the Verdict block.
count_only() {
  # shellcheck disable=SC2086
  /usr/bin/grep -rEn --include="*.swift" $EXCL_DIRS "$1" . 2>/dev/null | /usr/bin/grep -c . || true
}

section "MV adoption"
report '@Observable' '@Observable usages'

section "MVVM drift"
report '\bObservableObject\b' 'ObservableObject references'
report '@Published' '@Published properties'

section "Named ViewModel types"
report 'class [A-Z][A-Za-z0-9]*ViewModel\b' '*ViewModel classes'
report 'class [A-Z][A-Za-z0-9]*VM[[:space:]:]' '*VM-suffixed classes'

section "Actor isolation"
report '(^|[[:space:]])actor [A-Z]' 'actor declarations'
report '@MainActor' '@MainActor annotations (any position)'
report '@MainActor[[:space:]]+(final[[:space:]]+)?class' '@MainActor class-level annotations'

section "Lock-primitive drift (non-actor synchronisation — all flagged)"
report '\bMutex<' 'Mutex<...> generic usages (drift)'
report '\bNSLock\(' 'NSLock() instances (drift)'
report '\bNSRecursiveLock\b' 'NSRecursiveLock usages (drift)'
report '\bos_unfair_lock\b' 'os_unfair_lock usages (drift)'
report '\bOSAllocatedUnfairLock\b' 'OSAllocatedUnfairLock usages (drift)'
report '\bDispatchSemaphore\b' 'DispatchSemaphore usages (drift)'
report '@synchronized' '@synchronized blocks (drift)'

section "Sendable audit flags"
report '@unchecked Sendable' '@unchecked Sendable conformances'

section "Verdict"
OBS=$(count_only '@Observable')
OO=$(count_only '\bObservableObject\b')
ACT=$(count_only '(^|[[:space:]])actor [A-Z]')
if [ "$OBS" -gt 0 ] && [ "$OO" -gt 0 ]; then
  echo "Pattern: mixed MV + MVVM ($OBS @Observable, $OO ObservableObject, $ACT actor)"
elif [ "$OBS" -gt 0 ]; then
  echo "Pattern: MV ($OBS @Observable, 0 ObservableObject, $ACT actor)"
elif [ "$OO" -gt 0 ]; then
  echo "Pattern: MVVM ($OO ObservableObject, 0 @Observable, $ACT actor)"
else
  echo "Pattern: no observable types found"
fi
