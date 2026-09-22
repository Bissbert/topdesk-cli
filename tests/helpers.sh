#!/bin/sh
set -eu

TEST_DIR=${TEST_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}
ROOT_DIR=${ROOT_DIR:-${TEST_DIR%/tests}}
PATH="$ROOT_DIR/bin:$TEST_DIR/bin:$PATH"

if [ "$(command -v curl)" != "$TEST_DIR/bin/curl" ] ||
   [ "$(command -v editor)" != "$TEST_DIR/bin/editor" ]; then
  printf 'test setup error: test shims are not resolving from %s/bin\n' "$TEST_DIR" >&2
  exit 1
fi

export TOOLBOX_CONFIG_DIR=${TOOLBOX_CONFIG_DIR:-"$TEST_DIR/config"}
rm -rf "$TOOLBOX_CONFIG_DIR" 2>/dev/null || :

export TDX_BASE_URL=${TDX_BASE_URL:-http://mock.local}
export TDX_VERIFY_TLS=${TDX_VERIFY_TLS:-1}
export TEST_CURL_LOG=${TEST_CURL_LOG:-"$TEST_DIR/.curl.log"}
rm -f "$TEST_CURL_LOG" 2>/dev/null || :

TEST_FAILURES=0

ok() { n=$1; shift; printf 'ok %s - %s\n' "$n" "$*"; }
not_ok() {
  n=$1
  shift
  TEST_FAILURES=$((TEST_FAILURES + 1))
  printf 'not ok %s - %s\n' "$n" "$*"
}
diag() { printf '# %s\n' "$*"; }

run_cmd() { "$@"; }

contains() { hay=$1; needle=$2; printf '%s' "$hay" | grep -F -- "$needle" >/dev/null 2>&1; }

have_jq() { command -v jq >/dev/null 2>&1; }
