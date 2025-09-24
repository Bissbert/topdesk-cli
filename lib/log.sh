#!/bin/sh
set -eu

_color_reset=''
_color_debug=''
_color_info=''
_color_warn=''
_color_error=''

_lvl_to_num() {
  case ${1:-info} in
    debug) echo 10;;
    info)  echo 20;;
    warn)  echo 30;;
    error) echo 40;;
    *) echo 20;;
  esac
}

setup_colors() {
  local mode=${1:-auto}
  if [ "$mode" = always ] || { [ "$mode" = auto ] && [ -t 2 ]; }; then
    _color_reset='\033[0m'
    _color_debug='\033[36m'
    _color_info='\033[32m'
    _color_warn='\033[33m'
    _color_error='\033[31m'
  fi
}

_LOG_LEVEL_NUM=$(_lvl_to_num "${LOG_LEVEL:-info}")

_log() {
  local lvl=$1; shift
  local fmt=$1; shift || true
  local lvl_num=$(_lvl_to_num "$lvl")
  [ "$lvl_num" -ge "$_LOG_LEVEL_NUM" ] || return 0
  case "$lvl" in
    debug) printf "${_color_debug}%s: ${fmt}${_color_reset}\n" "$TOOLBOX_NAME" "$@" >&2 ;;
    info)  printf "${_color_info}%s: ${fmt}${_color_reset}\n" "$TOOLBOX_NAME" "$@" >&2 ;;
    warn)  printf "${_color_warn}%s: ${fmt}${_color_reset}\n" "$TOOLBOX_NAME" "$@" >&2 ;;
    error) printf "${_color_error}%s: ${fmt}${_color_reset}\n" "$TOOLBOX_NAME" "$@" >&2 ;;
  esac
}

dbg() { _log debug "$@"; }
inf() { _log info  "$@"; }
wrn() { _log warn  "$@"; }
err() { _log error "$@"; }
note() { printf '%s\n' "$(printf "$@")" >&2; }

