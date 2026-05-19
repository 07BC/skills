#!/usr/bin/env bash
# Inventories persistence mechanisms — SwiftData, Core Data, UserDefaults,
# Keychain, NSCoding, and image caches. Read-only.
# Usage: persistence-inventory.sh

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

section "SwiftData (iOS 17+)"
report 'import SwiftData' 'SwiftData imports'
report '@Model\b' '@Model declarations'
report '\bModelContainer\(' 'ModelContainer instances'
report '\bModelContext\b' 'ModelContext references'
report '@Query\b' '@Query property wrappers'

section "Core Data (legacy)"
report 'import CoreData' 'CoreData imports'
report '\bNSManagedObject\b' 'NSManagedObject usages'
report '\bNSPersistentContainer\b' 'NSPersistentContainer usages'

section "UserDefaults"
report '\bUserDefaults\b' 'UserDefaults references'
report '@AppStorage\b' '@AppStorage property wrappers'

section "Keychain"
report '\bKeychainProtocol\b' 'KeychainProtocol references'
report '\bKeychain\b' 'Keychain references (any)'

section "Archival (legacy)"
report '\bNSCoding\b' 'NSCoding conformances'
report '\bNSKeyedArchiver\b' 'NSKeyedArchiver usages'
report '\bNSKeyedUnarchiver\b' 'NSKeyedUnarchiver usages'

section "File system"
report '\bFileManager\b' 'FileManager references'

section "Image cache"
report '\bSDWebImage\b' 'SDWebImage references'
report '\bKingfisher\b' 'Kingfisher references'
report '\bNSCache<' 'NSCache<...> usages'

section "Verdict"
SD=$(count_only '@Model\b|import SwiftData')
CD=$(count_only '\bNSManagedObject\b|\bNSPersistentContainer\b')
UD=$(count_only '\bUserDefaults\b|@AppStorage\b')
KC=$(count_only '\bKeychain\b')
echo "SwiftData=$SD  CoreData=$CD  UserDefaults=$UD  Keychain=$KC"
if [ "$SD" -gt 0 ] && [ "$CD" -gt 0 ]; then
  echo "Pattern: mixed SwiftData + Core Data — migration likely in progress"
elif [ "$SD" -gt 0 ]; then
  echo "Pattern: SwiftData primary store"
elif [ "$CD" -gt 0 ]; then
  echo "Pattern: Core Data primary store"
elif [ "$UD" -gt 0 ] || [ "$KC" -gt 0 ]; then
  echo "Pattern: lightweight only (no SwiftData/Core Data; Keychain/UserDefaults)"
else
  echo "Pattern: no persistence detected"
fi
