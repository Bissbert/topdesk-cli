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

query_apply_params() {
  _qap_base=${1-}
  _qap_params=${2-}
  [ -n "${_qap_params}" ] || { printf '%s' "${_qap_base}"; return; }
  _qap_result=${_qap_base}
  while IFS= read -r _qap_pair; do
    [ -n "${_qap_pair}" ] || continue
    _qap_key=${_qap_pair%%=*}
    _qap_val=${_qap_pair#*=}
    _qap_result=$(query_add "${_qap_result}" "${_qap_key}" "${_qap_val}")
  done <<EOF
${_qap_params}
EOF
  printf '%s' "${_qap_result}"
}

# Validate URL format
validate_url() {
  _vu_url=${1:-}
  [ -n "$_vu_url" ] || return 1

  case "$_vu_url" in
    http://*|https://*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Check for required dependencies
check_deps() {
  _cd_missing=""
  for _cd_dep in "$@"; do
    if ! command_exists "$_cd_dep"; then
      _cd_missing="$_cd_missing $_cd_dep"
    fi
  done

  if [ -n "$_cd_missing" ]; then
    err "missing required dependencies:%s" "$_cd_missing"
    return 1
  fi
  return 0
}

# Trap handler for cleanup
cleanup() {
  _cl_code=$?
  if [ -n "${CLEANUP_FILES:-}" ]; then
    for _cl_file in $CLEANUP_FILES; do
      rm -f "$_cl_file" 2>/dev/null || true
    done
  fi
  exit $_cl_code
}

# Setup cleanup trap
setup_cleanup() {
  trap cleanup EXIT INT TERM
}

# Add file to cleanup list
add_cleanup() {
  CLEANUP_FILES="${CLEANUP_FILES:-} $1"
}

# Safe temporary file creation
make_temp() {
  _mt_template=${1:-tmp.XXXXXX}
  _mt_dir=${TMPDIR:-/tmp}

  # Try mktemp if available
  if command_exists mktemp; then
    mktemp "$_mt_dir/$_mt_template"
  else
    # Fallback to manual creation
    _mt_file="$_mt_dir/$_mt_template.$$"
    touch "$_mt_file" || return 1
    chmod 600 "$_mt_file" || return 1
    printf '%s\n' "$_mt_file"
  fi
}

# Check if running in debug mode
is_debug() {
  case "${LOG_LEVEL:-info}" in
    debug|trace)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
