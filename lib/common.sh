#!/bin/sh
set -eu

PROG=${TOOLBOX_NAME:-topdesk}
is_tty() { [ -t 1 ]; }

die() { printf '%s\n' "$*" >&2; exit 1; }

req_arg() { [ "$#" -ge 2 ] || die "missing argument for $1"; }

command_exists() { command -v -- "$1" >/dev/null 2>&1; }

resolve_command() {
  local name path
  name=$1
  path="$TOOLS_DIR/$name"
  if [ -f "$path" ] && [ -x "$path" ]; then
    printf '%s\n' "$path"; return 0
  fi
  if command_exists "${PROG}-${name}"; then
    command -v -- "${PROG}-${name}"; return 0
  fi
  return 1
}

run() {
  printf '+ %s\n' "$*" >&2
  "$@"
}

urlencode() {
  _ue_input=${1-}
  [ -n "${_ue_input+x}" ] || { printf ''; return; }
  [ -n "$_ue_input" ] || { printf ''; return; }
  _ue_output=''
  while IFS= read -r _ue_byte; do
      _ue_oct=$(printf '%03o' "$_ue_byte")
      _ue_char=$(printf '%b' "\\$_ue_oct")
      case "$_ue_char" in
        [A-Za-z0-9._~-])
          _ue_output="$_ue_output$_ue_char" ;;
        ' ')
          _ue_output="$_ue_output%20" ;;
        *)
          _ue_output="$_ue_output$(printf '%%%02X' "$_ue_byte")" ;;
      esac
  done <<EOF
$(LC_ALL=C printf '%s' "$_ue_input" | od -An -t u1 | awk '{for(i=1;i<=NF;i++) print $i}')
EOF
  printf '%s' "$_ue_output"
}

query_add() {
  _qa_existing=${1-}
  _qa_key=${2-}
  _qa_val=${3-}
  [ -n "${_qa_key}" ] || { printf '%s' "${_qa_existing:-}"; return; }
  _qa_key_enc=$(urlencode "$_qa_key")
  _qa_val_enc=$(urlencode "$_qa_val")
  if [ -z "${_qa_existing:-}" ]; then
    printf '%s=%s' "$_qa_key_enc" "$_qa_val_enc"
  else
    printf '%s&%s=%s' "$_qa_existing" "$_qa_key_enc" "$_qa_val_enc"
  fi
}
