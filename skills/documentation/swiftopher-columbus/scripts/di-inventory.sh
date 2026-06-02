#!/usr/bin/env bash
# Inventories the dependency-injection patterns used across a Swift codebase.
# Reports modern @Entry vs legacy EnvironmentKey, ownership wrappers,
# singletons, DI containers, and property-wrapper-based injection.
# Read-only. Usage: di-inventory.sh

set -euo pipefail

section() { echo; echo "=== $1 ==="; }

EXCL_DIRS="--exclude-dir=.build --exclude-dir=.git --exclude-dir=DerivedData --exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=node_modules --exclude-dir=.swiftpm"

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

count_only() {
  # shellcheck disable=SC2086
  /usr/bin/grep -rEn --include="*.swift" $EXCL_DIRS "$1" . 2>/dev/null | /usr/bin/grep -c . || true
}

section "Environment plumbing — modern (iOS 17+)"
report '@Entry\b' '@Entry-based EnvironmentValues'

section "Environment plumbing — legacy"
report ':[[:space:]]*EnvironmentKey\b' 'EnvironmentKey conformances'
report 'extension EnvironmentValues' 'EnvironmentValues extensions'

section "Environment injection sites"
report '\.environment\(' '.environment(_:) call sites'
report '\.environmentObject\(' '.environmentObject(_:) call sites'

section "Environment consumption"
report '@Environment\(' '@Environment(...) reads'

section "View-VM ownership"
report '@StateObject\b' '@StateObject declarations'
report '@ObservedObject\b' '@ObservedObject declarations'
report '@EnvironmentObject\b' '@EnvironmentObject declarations'
report 'StateObject\(wrappedValue:' '@StateObject custom-init usages'

section "Singletons"
report 'static[[:space:]]+(let|var)[[:space:]]+shared\b' 'static shared declarations'
report '\.shared\.' '.shared.* usages'

section "DI containers / property wrappers"
report '\bAppDependencies\b' 'AppDependencies references'
report '@Inject\b' '@Inject usages'
report 'protocol[[:space:]]+[A-Z][A-Za-z0-9]*Container\b' '*Container protocols'
report 'protocol[[:space:]]+[A-Z][A-Za-z0-9]*Resolver\b' '*Resolver protocols'

section "Verdict"
ENTRY=$(count_only '@Entry\b')
ENVKEY=$(count_only ':[[:space:]]*EnvironmentKey\b')
APPDEP=$(count_only '\bAppDependencies\b')
INJ=$(count_only '@Inject\b')
echo "@Entry=$ENTRY  EnvironmentKey=$ENVKEY  AppDependencies=$APPDEP  @Inject=$INJ"
if [ "$ENTRY" -eq 0 ] && [ "$ENVKEY" -gt 0 ]; then
  echo "Pattern: legacy EnvironmentKey only — no @Entry adoption"
elif [ "$ENTRY" -gt 0 ] && [ "$ENVKEY" -eq 0 ]; then
  echo "Pattern: modern @Entry only — fully migrated"
elif [ "$ENTRY" -gt 0 ] && [ "$ENVKEY" -gt 0 ]; then
  echo "Pattern: mixed @Entry + EnvironmentKey — migration in progress"
else
  echo "Pattern: no custom environment plumbing detected"
fi
if [ "$APPDEP" -gt 0 ] || [ "$INJ" -gt 0 ]; then
  echo "Container: yes (AppDependencies=$APPDEP, @Inject=$INJ)"
else
  echo "Container: none (manual init-parameter injection)"
fi
