#!/bin/sh
# Configuration loading system for Topdesk toolkit
set -eu

# Default configuration paths
DEFAULT_SYSTEM_CONFIG="/etc/topdesk/config"
DEFAULT_USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/topdesk/config"
TOOLBOX_CONFIG_DIR="${TOOLBOX_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/topdesk}"

# Find configuration file
find_config_file() {
  _fcf_explicit=${1:-}

  # 1. Explicit config file from command line
  if [ -n "$_fcf_explicit" ]; then
    if [ -f "$_fcf_explicit" ]; then
      printf '%s\n' "$_fcf_explicit"
      return 0
    else
      err "config file not found: %s" "$_fcf_explicit"
      return 1
    fi
  fi

  # 2. Environment variable
  if [ -n "${TOPDESK_CONFIG:-}" ]; then
    if [ -f "$TOPDESK_CONFIG" ]; then
      printf '%s\n' "$TOPDESK_CONFIG"
      return 0
    fi
  fi

  # 3. User config
  if [ -f "$DEFAULT_USER_CONFIG" ]; then
    printf '%s\n' "$DEFAULT_USER_CONFIG"
    return 0
  fi

  # 4. Legacy location for backward compatibility
  if [ -f "$TOOLBOX_CONFIG_DIR/config" ]; then
    printf '%s\n' "$TOOLBOX_CONFIG_DIR/config"
    return 0
  fi

  # 5. System config
  if [ -f "$DEFAULT_SYSTEM_CONFIG" ]; then
    printf '%s\n' "$DEFAULT_SYSTEM_CONFIG"
    return 0
  fi

  # No config file found (not an error - env vars may be sufficient)
  return 0
}

# Safely source configuration file
source_config_file() {
  _scf_file=${1:-}
  [ -n "$_scf_file" ] || return 0
  [ -f "$_scf_file" ] || return 0

  # Check readability
  if [ ! -r "$_scf_file" ]; then
    err "config file not readable: %s" "$_scf_file"
    return 1
  fi

  # Source the file
  debug "loading config from: %s" "$_scf_file"
  . "$_scf_file"
}

# Mask sensitive values for display
mask_sensitive() {
  _ms_key=${1:-}
  _ms_val=${2:-}

  case "$_ms_key" in
    *PASS*|*PASSWORD*|*TOKEN*|*SECRET*|*KEY*|*AUTH*)
      if [ -n "$_ms_val" ]; then
        printf '<redacted>'
      else
        printf '<unset>'
      fi
      ;;
    *)
      printf '%s' "$_ms_val"
      ;;
  esac
}

# Validate required configuration
validate_config() {
  _vc_errors=0

  # Check base URL
  if [ -z "${TDX_BASE_URL:-}" ]; then
    debug "TDX_BASE_URL not configured"
    _vc_errors=$((_vc_errors + 1))
  fi

  # Check authentication (at least one method should be configured)
  if [ -z "${TDX_AUTH_TOKEN:-}" ] && \
     [ -z "${TDX_AUTH_HEADER:-}" ] && \
     [ -z "${TDX_USER:-}" ]; then
    debug "No authentication method configured"
    _vc_errors=$((_vc_errors + 1))
  fi

  return $_vc_errors
}

# Main configuration loader
load_config() {
  _lc_explicit=${1:-}

  # Find config file
  _lc_config_file=$(find_config_file "$_lc_explicit") || return 1

  # Load config file if found
  if [ -n "$_lc_config_file" ]; then
    source_config_file "$_lc_config_file" || return 1
    export TOPDESK_CONFIG_FILE="$_lc_config_file"
  fi

  # Apply defaults for pagination
  : ${TDX_PAGE_SIZE:=100}
  : ${TDX_PAGE_PARAM:=pageSize}
  : ${TDX_OFFSET_PARAM:=start}
  : ${TDX_OFFSET_START:=0}

  # Apply defaults for timeouts and retries
  : ${TDX_TIMEOUT:=30}
  : ${TDX_RETRY:=0}
  : ${TDX_RETRY_DELAY:=0}

  # Apply defaults for TLS
  : ${TDX_VERIFY_TLS:=1}

  # Export all TDX_ variables
  export TDX_BASE_URL TDX_USER TDX_PASS TDX_AUTH_TOKEN TDX_AUTH_HEADER
  export TDX_VERIFY_TLS TDX_TIMEOUT TDX_RETRY TDX_RETRY_DELAY
  export TDX_PAGE_SIZE TDX_PAGE_PARAM TDX_OFFSET_PARAM TDX_OFFSET_START
  export TDX_DEFAULT_FIELDS TDX_PERSON_FIELDS TDX_OPERATOR_FIELDS TDX_ASSET_FIELDS

  return 0
}

# List current configuration (with redaction)
list_config() {
  printf '# Current configuration\n'

  # Show config file source
  if [ -n "${TOPDESK_CONFIG_FILE:-}" ]; then
    printf '# Source: %s\n\n' "$TOPDESK_CONFIG_FILE"
  else
    printf '# Source: environment/defaults\n\n'
  fi

  # Core settings
  printf 'TDX_BASE_URL=%s\n' "${TDX_BASE_URL:-<unset>}"

  # Authentication
  if [ -n "${TDX_AUTH_TOKEN:-}" ]; then
    printf 'TDX_AUTH_TOKEN=%s\n' "$(mask_sensitive TDX_AUTH_TOKEN "$TDX_AUTH_TOKEN")"
  fi
  if [ -n "${TDX_AUTH_HEADER:-}" ]; then
    printf 'TDX_AUTH_HEADER=%s\n' "$(mask_sensitive TDX_AUTH_HEADER "$TDX_AUTH_HEADER")"
  fi
  if [ -n "${TDX_USER:-}" ]; then
    printf 'TDX_USER=%s\n' "${TDX_USER}"
    printf 'TDX_PASS=%s\n' "$(mask_sensitive TDX_PASS "$TDX_PASS")"
  fi

  # TLS and network
  printf 'TDX_VERIFY_TLS=%s\n' "${TDX_VERIFY_TLS:-1}"
  printf 'TDX_TIMEOUT=%s\n' "${TDX_TIMEOUT:-30}"
  printf 'TDX_RETRY=%s\n' "${TDX_RETRY:-0}"
  printf 'TDX_RETRY_DELAY=%s\n' "${TDX_RETRY_DELAY:-0}"

  # Pagination
  printf '\n# Pagination settings\n'
  printf 'TDX_PAGE_SIZE=%s\n' "${TDX_PAGE_SIZE:-100}"
  printf 'TDX_PAGE_PARAM=%s\n' "${TDX_PAGE_PARAM:-pageSize}"
  printf 'TDX_OFFSET_PARAM=%s\n' "${TDX_OFFSET_PARAM:-start}"
  printf 'TDX_OFFSET_START=%s\n' "${TDX_OFFSET_START:-0}"

  # Field defaults
  if [ -n "${TDX_DEFAULT_FIELDS:-}" ]; then
    printf '\n# Field defaults\n'
    printf 'TDX_DEFAULT_FIELDS=%s\n' "${TDX_DEFAULT_FIELDS}"
  fi
  if [ -n "${TDX_PERSON_FIELDS:-}" ]; then
    printf 'TDX_PERSON_FIELDS=%s\n' "${TDX_PERSON_FIELDS}"
  fi
  if [ -n "${TDX_OPERATOR_FIELDS:-}" ]; then
    printf 'TDX_OPERATOR_FIELDS=%s\n' "${TDX_OPERATOR_FIELDS}"
  fi
  if [ -n "${TDX_ASSET_FIELDS:-}" ]; then
    printf 'TDX_ASSET_FIELDS=%s\n' "${TDX_ASSET_FIELDS}"
  fi
}

# Create config template
create_config_template() {
  _cct_file=${1:-$DEFAULT_USER_CONFIG}
  _cct_dir=${_cct_file%/*}

  # Create directory if needed
  if [ ! -d "$_cct_dir" ]; then
    mkdir -p "$_cct_dir" || {
      err "failed to create config directory: %s" "$_cct_dir"
      return 1
    }
  fi

  # Don't overwrite existing config
  if [ -f "$_cct_file" ]; then
    warn "config file already exists: %s" "$_cct_file"
    return 0
  fi

  # Create template
  cat > "$_cct_file" <<'EOF'
# Topdesk CLI Configuration
# Place this file at ~/.config/topdesk/config or set TOPDESK_CONFIG environment variable

# Required: Base URL for your Topdesk instance
TDX_BASE_URL="https://topdesk.example.com"

# Authentication (choose one method):

# Option 1: Token authentication (recommended)
# Full Authorization header value including "Bearer" prefix
#TDX_AUTH_TOKEN="Bearer eyJ..."

# Option 2: Custom authentication header
#TDX_AUTH_HEADER="Authorization: Bearer <token>"

# Option 3: Basic authentication (username/password)
#TDX_USER="apiuser"
#TDX_PASS="apipass"

# TLS and network settings
TDX_VERIFY_TLS=1         # Set to 0 to skip TLS verification (insecure)
TDX_TIMEOUT=30           # Request timeout in seconds
TDX_RETRY=0              # Number of retries for failed requests
TDX_RETRY_DELAY=0        # Delay between retries in seconds

# Pagination defaults (adjust if your instance uses different parameters)
TDX_PAGE_SIZE=100        # Default items per page
TDX_PAGE_PARAM=pageSize  # Query parameter for page size
TDX_OFFSET_PARAM=start   # Query parameter for offset
TDX_OFFSET_START=0       # Starting offset value

# Optional: Default fields for list outputs
#TDX_DEFAULT_FIELDS=number,id,briefDescription
#TDX_PERSON_FIELDS=id,networkLoginName,firstName,lastName
#TDX_OPERATOR_FIELDS=id,name,networkLoginName
#TDX_ASSET_FIELDS=id,objectNumber,name
EOF

  info "created config template: %s" "$_cct_file"
  info "edit this file and configure your Topdesk settings"
  return 0
}