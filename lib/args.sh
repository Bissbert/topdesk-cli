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

# Shared state populated by args_take_param for consumers to read.
ARGS_PARAM_KEY=""
ARGS_PARAM_VAL=""
ARGS_PARAM_SHIFT=0

args_take_param() {
  arg=${1-}
  next=${2-}
  opt=${3:---param}
  case ${arg-} in
    *=*)
      ARGS_PARAM_KEY=${arg%%=*}
      ARGS_PARAM_VAL=${arg#*=}
      ARGS_PARAM_SHIFT=0
      ;;
    *)
      [ -n "${next-}" ] || { printf 'missing value for %s\n' "$opt" >&2; exit 2; }
      ARGS_PARAM_KEY=$arg
      ARGS_PARAM_VAL=${next-}
      ARGS_PARAM_SHIFT=1
      ;;
  esac
}

args_params_append() {
  var=$1 key=$2 val=$3
  current=$(eval "printf '%s' \"\${$var-}\"")
  if [ -n "$current" ]; then
    current=$(printf '%s\n%s=%s' "$current" "$key" "$val")
  else
    current=$(printf '%s=%s' "$key" "$val")
  fi
  current_escaped=$(printf "%s" "$current" | sed "s/'/'\\''/g")
  eval "$var='$current_escaped'"
}

