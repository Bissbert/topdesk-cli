#!/bin/sh
set -eu

TEST_DIR=${TEST_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}
ROOT_DIR=${ROOT_DIR:-${TEST_DIR%/tests}}
PATH="$ROOT_DIR/bin:$TEST_DIR/bin:$PATH"

export TOOLBOX_CONFIG_DIR=${TOOLBOX_CONFIG_DIR:-"$TEST_DIR/config"}
rm -rf "$TOOLBOX_CONFIG_DIR" 2>/dev/null || :

export TDX_BASE_URL=${TDX_BASE_URL:-http://mock.local}
export TDX_VERIFY_TLS=${TDX_VERIFY_TLS:-1}
export TEST_CURL_LOG=${TEST_CURL_LOG:-"$TEST_DIR/.curl.log"}
rm -f "$TEST_CURL_LOG" 2>/dev/null || :

ok() { n=$1; shift; printf 'ok %s - %s\n' "$n" "$*"; }
not_ok() { n=$1; shift; printf 'not ok %s - %s\n' "$n" "$*"; }
diag() { printf '# %s\n' "$*"; }

run_cmd() { "$@"; }

contains() { hay=$1; needle=$2; printf '%s' "$hay" | grep -F -- "$needle" >/dev/null 2>&1; }

have_jq() { command -v jq >/dev/null 2>&1; }
