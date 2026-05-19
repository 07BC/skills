#!/usr/bin/env bash
# Inventories networking patterns — protocol boundaries, HTTP transport,
# async API shapes, and layering violations (URLSession in the main target).
# Read-only. Usage: networking-inventory.sh

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

section "Protocol-typed network boundaries"
report 'protocol [A-Z][A-Za-z0-9]*ClientProtocol' '*ClientProtocol declarations'
report 'protocol [A-Z][A-Za-z0-9]*APIProtocol' '*APIProtocol declarations'
report 'protocol [A-Z][A-Za-z0-9]*Fetcher\b' '*Fetcher protocols'
report 'protocol [A-Z][A-Za-z0-9]*Repository\b' '*Repository protocols'

section "HTTP transport"
report '\bURLSession\b' 'URLSession references'
report '\bURLRequest\(' 'URLRequest constructions'
report '\bAsyncHTTPClient\b' 'AsyncHTTPClient references'
report '\bAlamofire\b' 'Alamofire references'

section "Layering check — URLSession outside dedicated network paths"
echo "URLSession references outside *Client*, *API*, or */Networking/ paths:"
# shellcheck disable=SC2086
/usr/bin/grep -rEln --include="*.swift" $EXCL_DIRS '\bURLSession\b' . 2>/dev/null \
  | /usr/bin/grep -vE '(Client|API|Network)' \
  | /usr/bin/head -10 \
  | /usr/bin/sed 's/^/  /' || true

section "Decoding"
report '\bJSONDecoder\(' 'JSONDecoder constructions'
report '\bJSONSerialization\b' 'JSONSerialization references'
report '\.decode\(' 'decode(...) call sites'

section "Async API shape"
report '\bAsyncThrowingStream<' 'AsyncThrowingStream declarations'
report '\bAsyncStream<' 'AsyncStream declarations'
report 'async throws ->' 'async throws return signatures'

section "WebSocket transport"
report '\bURLSessionWebSocketTask\b' 'URLSessionWebSocketTask references'
report '\bPusherSwift\b' 'PusherSwift references'
report '\bStarscream\b' 'Starscream references'
report '\bSocket\b' 'Socket references'

section "Auth"
report 'Authorization' 'Authorization header references'
report 'Bearer ' 'Bearer-token references'
report 'X-CLIENT-TOKEN' 'X-CLIENT-TOKEN hardcoded values'
