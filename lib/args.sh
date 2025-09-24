#!/bin/sh
set -eu

req_arg() { [ "$#" -ge 2 ] || { printf 'missing argument for %s\n' "$1" >&2; exit 2; }; }

bool_to_yn() { [ "${1:-}" = "1" ] && echo y || echo n; }

parse_flag() {
  var=$1; arg=$2; long=$3; short=${4:-}
  if [ "$arg" = "$long" ] || [ -n "$short" ] && [ "$arg" = "$short" ]; then
    eval "$var=1"; return 0
  fi
  return 1
}

