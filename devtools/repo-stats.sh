#!/bin/sh
# Print source-shape numbers quoted in README.md and docs/.
#
#   sh devtools/repo-stats.sh
#
# SOURCE_ROOT may point at a clean source snapshot. No estimates are used.
set -eu

script_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_root=${SOURCE_ROOT:-$script_root}
cd "$source_root"

section() { printf '\n== %s ==\n' "$1"; }

section 'Shell source (bin, lib, tools)'
printf '%-28s %8s %10s\n' component lines bytes
for group in bin lib tools; do
  case "$group" in
    bin) set -- bin/topdesk ;;
    lib) set -- lib/*.sh ;;
    tools) set -- tools/* ;;
  esac
  lines=$(cat "$@" | wc -l | tr -d ' ')
  bytes=$(cat "$@" | wc -c | tr -d ' ')
  files=$#
  printf '%-28s %8s %10s  (%s files)\n' \
    "$group" "$lines" "$bytes" "$files"
done

section 'Totals'
all=$(printf '%s\n' bin/topdesk lib/*.sh tools/*)
printf 'shell files            %s\n' "$(printf '%s\n' "$all" | wc -l | tr -d ' ')"
printf 'shell lines            %s\n' "$(cat $all | wc -l | tr -d ' ')"
printf 'shell bytes            %s\n' "$(cat $all | wc -c | tr -d ' ')"
printf 'subcommands            %s\n' \
  "$(find tools -mindepth 1 -maxdepth 1 -type f -perm +111 | wc -l | tr -d ' ')"
printf 'version                %s\n' "$(sed -n 1p VERSION)"

section 'Distinct API paths reached'
grep -ho '/tas/api/[A-Za-z/$]*' tools/* \
  | sed 's/\$ID/{id}/g; s/\$AID/{attachmentId}/g; s#/*$##' \
  | grep -v '^$' \
  | sort -u

section 'TDX_* configuration variables read'
grep -hoE 'TDX_[A-Z_]+' bin/topdesk lib/*.sh tools/* \
  | sort -u | tr '\n' ' '
printf '\n'

section 'Exit codes reachable from tools/call'
grep -oE 'exit [0-9]+' tools/call | sort -u | tr '\n' ' '
printf '\n'

section 'Exit codes reachable from tools/ping'
grep -oE 'exit [0-9]+' tools/ping | sort -u | tr '\n' ' '
printf '\n'

section 'Scripts that invoke curl directly'
grep -lE '(^ *curl |=\$\(curl )' tools/* | sed 's#^#  #'
