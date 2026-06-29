#!/usr/bin/env bash
# PreToolUse on the Write tool. If the write targets a .swift file whose content
# declares more than one top-level type (struct/class/enum/actor), deny the write
# before it lands and tell the model to split it one-type-per-file.
#
# Heuristic: top-level declarations sit at column 0; nested/indented/private-inside
# types do not. We count lines that begin (no leading whitespace) with an optional
# attribute, optional modifiers, then a declaration keyword + a type name.
# `extension` is intentionally excluded, so extension-on-primary-type files pass.
# ponytail: column-0 regex heuristic; upgrade to a Swift parser only if false positives bite.

DECL_RE='^(@[A-Za-z0-9_().,: ]+[[:space:]]+)?((public|private|internal|fileprivate|open|final|indirect)[[:space:]]+)*(struct|class|enum|actor)[[:space:]]+[A-Za-z_]'

count_types() {
  # stdin: swift source. stdout: number of top-level type declarations.
  grep -cE "$DECL_RE" || true
}

run_self_test() {
  local fails=0

  local multi='import SwiftUI

struct NamedColour: Identifiable {
    let name: String
}

enum GalleryCatalog {
    static let x = 1
}'
  local n
  n=$(printf '%s' "$multi" | count_types)
  if [[ "$n" -ne 2 ]]; then echo "FAIL: multi-type expected 2 got $n" >&2; fails=1; fi

  local single='import SwiftUI

struct Single: Identifiable {
    let name: String
}

extension Single {
    var id: String { name }
}'
  n=$(printf '%s' "$single" | count_types)
  if [[ "$n" -ne 1 ]]; then echo "FAIL: single+extension expected 1 got $n" >&2; fails=1; fi

  local nested='struct Outer {
    private struct Inner { let a: Int }
    enum Mode { case on, off }
}'
  n=$(printf '%s' "$nested" | count_types)
  if [[ "$n" -ne 1 ]]; then echo "FAIL: nested expected 1 got $n" >&2; fails=1; fi

  local attributed='import SwiftUI

@MainActor
final class Service {
    var x = 0
}'
  n=$(printf '%s' "$attributed" | count_types)
  if [[ "$n" -ne 1 ]]; then echo "FAIL: attributed class expected 1 got $n" >&2; fails=1; fi

  if [[ "$fails" -eq 0 ]]; then echo "self-test: OK"; else echo "self-test: FAILED" >&2; fi
  return "$fails"
}

if [[ "${1:-}" == "--self-test" ]]; then
  run_self_test
  exit $?
fi

input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')
case "$path" in
  *.swift) ;;
  *) exit 0 ;;
esac

content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty')
[[ -z "$content" ]] && exit 0

count=$(printf '%s' "$content" | count_types)
if [[ "$count" -gt 1 ]]; then
  file=$(basename "$path")
  reason="$file declares $count top-level types. One type per file is a hard rule. Write each struct/class/enum/actor to its own file named after it (e.g. ColourRole.swift), with extensions on the primary type as the only exception."
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
fi
