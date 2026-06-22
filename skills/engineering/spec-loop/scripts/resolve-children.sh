#!/usr/bin/env bash
#
# resolve-children.sh — emit the children manifest spec-loop drives.
#
# Output (stdout), one tab-separated row per child:
#   child_id<TAB>covers<TAB>depends_on<TAB>state
#     child_id    GitHub mode: the sub-issue number.  Local mode: the spec slug.
#     covers      comma-separated frozen AC IDs (from the child's spine)
#     depends_on  comma-separated child ids this child waits on (may be empty)
#     state       always `pending` here — spec-loop re-derives real state from git
#
# Two modes:
#   --mode github --master <GH#> --repo <owner/name>
#       Reads the master's native sub-issues and parses each child body's fenced
#       spine block (`covers: [...]`, `depends_on: [...]`) — the format
#       /spec-decomposition writes.
#   --mode local --spec-dir <dir> --master-key <key>
#       Scans <dir> for child spec files belonging to the master (frontmatter
#       `master: <key>`, or filename prefixed `<key>-`) and parses `covers:` /
#       `depends_on:` from their frontmatter.
#
# Children are emitted in ascending id order; /spec-decomposition creates sub-issues
# in dependency order, and spec-loop's on-branch sequencing predicate enforces
# correctness regardless of emit order.

set -euo pipefail

die() { printf 'resolve-children: %s\n' "$1" >&2; exit 2; }

mode="" master="" repo="" spec_dir="" master_key=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)       mode="${2:-}"; shift 2 ;;
    --master)     master="${2:-}"; shift 2 ;;
    --repo)       repo="${2:-}"; shift 2 ;;
    --spec-dir)   spec_dir="${2:-}"; shift 2 ;;
    --master-key) master_key="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# Pull a list-valued spine field (`covers`/`depends_on`) out of a body/frontmatter
# blob on stdin and normalise to a comma-separated token list. Accepts the inline
# list form `covers: [a, b]` and the bare form `covers: a, b`.
spine_field() {
  local field="$1"
  grep -iE "^[[:space:]]*${field}[[:space:]]*:" \
    | head -1 \
    | sed -E "s/^[^:]*:[[:space:]]*//; s/[][]//g" \
    | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | grep -v '^$' | paste -sd, - || true
}

case "$mode" in
  github)
    [[ -n "$master" ]] || die "--master <GH#> is required in github mode"
    [[ -n "$repo" ]] || die "--repo <owner/name> is required in github mode"
    owner="${repo%%/*}"; name="${repo##*/}"

    # Native sub-issues of the master, in creation (dependency) order.
    nums="$(gh api graphql -H "GraphQL-Features: sub_issues" -f query='
      query($owner:String!,$name:String!,$num:Int!){
        repository(owner:$owner,name:$name){
          issue(number:$num){ subIssues(first:100){ nodes { number } } }
        }
      }' -F owner="$owner" -F name="$name" -F num="$master" \
      --jq '.data.repository.issue.subIssues.nodes[].number' 2>/dev/null | sort -n)" \
      || die "could not read sub-issues for master #$master (is it a sub-issue parent?)"
    [[ -n "$nums" ]] || die "master #$master has no sub-issues — run /spec-decomposition first"

    for n in $nums; do
      body="$(gh issue view "$n" --repo "$repo" --json body -q .body 2>/dev/null || true)"
      covers="$(printf '%s\n' "$body" | spine_field covers)"
      deps="$(printf '%s\n' "$body" | spine_field depends_on)"
      printf '%s\t%s\t%s\tpending\n' "$n" "$covers" "$deps"
    done
    ;;

  local)
    [[ -n "$spec_dir" && -d "$spec_dir" ]] || die "--spec-dir <dir> is required and must exist in local mode"
    [[ -n "$master_key" ]] || die "--master-key <key> is required in local mode"

    # Frontmatter is the first --- … --- block. A child belongs to the master when
    # its frontmatter declares `master: <key>` or its filename is prefixed `<key>-`.
    found=0
    for f in "$spec_dir"/*.md; do
      [[ -e "$f" ]] || continue
      fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$f")"
      slug="$(basename "$f" .md)"
      belongs=0
      printf '%s\n' "$fm" | grep -iqE "^[[:space:]]*master[[:space:]]*:[[:space:]]*${master_key}\b" && belongs=1
      [[ "$slug" == "${master_key}-"* ]] && belongs=1
      [[ "$belongs" == 1 ]] || continue
      covers="$(printf '%s\n' "$fm" | spine_field covers)"
      deps="$(printf '%s\n' "$fm" | spine_field depends_on)"
      printf '%s\t%s\t%s\tpending\n' "$slug" "$covers" "$deps"
      found=1
    done
    [[ "$found" == 1 ]] || die "no child specs for master '$master_key' found under $spec_dir"
    ;;

  *)
    die "--mode must be 'github' or 'local'"
    ;;
esac
