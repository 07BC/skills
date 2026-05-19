#!/usr/bin/env bash
# Composite architecture report — runs every inventory script and synthesises
# a single recommendation: ratify MV / ratify MVVM / migration in progress /
# unknown. Use this when you need the architecture verdict in one glance, for
# example before writing docs/engineering/target-architecture.md.
# Read-only. Usage: drift-report.sh

set -euo pipefail

SCRIPT_DIR="$( /usr/bin/dirname "${BASH_SOURCE[0]}" )"

EXCL_DIRS="--exclude-dir=.build --exclude-dir=.git --exclude-dir=DerivedData --exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=node_modules --exclude-dir=.swiftpm"

bigsection() {
  echo
  echo "##############################"
  echo "# $1"
  echo "##############################"
}

count_only() {
  # shellcheck disable=SC2086
  /usr/bin/grep -rEn --include="*.swift" $EXCL_DIRS "$1" . 2>/dev/null | /usr/bin/grep -c . || true
}

bigsection "PROJECT OVERVIEW"
"$SCRIPT_DIR/explore.sh"

bigsection "PATTERN INVENTORY"
"$SCRIPT_DIR/pattern-inventory.sh"

bigsection "DI INVENTORY"
"$SCRIPT_DIR/di-inventory.sh"

bigsection "PERSISTENCE INVENTORY"
"$SCRIPT_DIR/persistence-inventory.sh"

bigsection "NETWORKING INVENTORY"
"$SCRIPT_DIR/networking-inventory.sh"

bigsection "COMPOSITION ROOT"
"$SCRIPT_DIR/composition-root.sh"

bigsection "DRIFT SUMMARY"

OBS=$(count_only '@Observable')
OO=$(count_only '\bObservableObject\b')
PUB=$(count_only '@Published')
ACT=$(count_only '(^|[[:space:]])actor [A-Z]')
VM=$(count_only 'class [A-Z][A-Za-z0-9]*ViewModel\b')
ENTRY=$(count_only '@Entry\b')
ENVKEY=$(count_only ':[[:space:]]*EnvironmentKey\b')
SD=$(count_only '@Model\b|import SwiftData')
CD=$(count_only '\bNSManagedObject\b|\bNSPersistentContainer\b')
MTX=$(count_only '\bMutex<')
NSL=$(count_only '\bNSLock\(')
UNCK=$(count_only '@unchecked Sendable')

echo "Pattern:        @Observable=$OBS  ObservableObject=$OO  @Published=$PUB  ViewModel=$VM  actor=$ACT"
echo "Environment:    @Entry=$ENTRY  EnvironmentKey=$ENVKEY"
echo "Persistence:    SwiftData=$SD  CoreData=$CD"
echo "Concurrency:    Mutex<=$MTX  NSLock=$NSL  @unchecked Sendable=$UNCK"
echo

# Recommendation logic — opinionated. The skill body explains why.
echo "RECOMMENDATION"
if [ "$OBS" -eq 0 ] && [ "$OO" -gt 0 ]; then
  echo "  Codify MVVM as the target architecture."
  echo "  - 0 @Observable, $OO ObservableObject — no MV adoption"
  echo "  - target-architecture.md should describe ObservableObject + @Published conventions"
  echo "  - if other docs describe an MV migration, mark them superseded"
elif [ "$OBS" -gt 0 ] && [ "$OO" -eq 0 ]; then
  echo "  Codify MV as the target architecture."
  echo "  - $OBS @Observable, 0 ObservableObject — pure MV"
  echo "  - target-architecture.md should describe @Observable services and direct view binding"
elif [ "$OBS" -gt 0 ] && [ "$OO" -gt 0 ]; then
  echo "  Mid-migration: take a stance."
  echo "  - $OBS @Observable vs $OO ObservableObject in the same codebase"
  echo "  - target-architecture.md MUST decide: continue migrating, or ratify current mixed state"
  echo "  - ask the user before writing — do not infer the target direction"
else
  echo "  No observable state pattern detected."
  echo "  - read entry-point manually before drafting target-architecture.md"
fi

if [ "$UNCK" -gt 0 ]; then
  echo "  Flag: $UNCK @unchecked Sendable conformance(s) need a concurrency audit."
fi
if [ "$NSL" -gt 0 ] && [ "$MTX" -eq 0 ]; then
  echo "  Flag: $NSL NSLock usage(s) and no Mutex — pre-Swift-6 synchronisation only."
fi
