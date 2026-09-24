#!/bin/sh
# The suite must not depend on or change the caller's config (entry 5), and a
# failing check must fail the run (entry 4).
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/helpers.sh"

# A developer HOME with a real-looking config, outside the sandbox the suite makes.
dev=$(mktemp -d "${TMPDIR:-/tmp}/topdesk-dev.XXXXXX")
mkdir -p "$dev/.config/topdesk"
printf 'TDX_BASE_URL=https://tenant.example.com\n' > "$dev/.config/topdesk/config"
before=$(cksum < "$dev/.config/topdesk/config")

run_suite() { HOME="$dev" XDG_CONFIG_HOME= TOOLBOX_CONFIG_DIR= bash "$DIR/run.sh" >"$TEST_HOME/suite.log" 2>&1; }

rc=0; run_suite || rc=$?
check "run.sh passes with a user config in HOME" [ "$rc" -eq 0 ]
rc=0; run_suite || rc=$?
check "run.sh passes a second time" [ "$rc" -eq 0 ]
check "the user config is unchanged" [ "$(cksum < "$dev/.config/topdesk/config")" = "$before" ]
check "nothing else is written to HOME" [ "$(find "$dev" -type f | wc -l | tr -d ' ')" -eq 1 ]
rm -rf "$dev"

# Entry 4: one check forced to fail gives a non-zero exit.
sed 's/"Usage: topdesk"/"NO SUCH TEXT"/' "$DIR/run.sh" > "$DIR/.run-broken.sh"
rc=0; bash "$DIR/.run-broken.sh" >"$TEST_HOME/broken.log" 2>&1 || rc=$?
rm -f "$DIR/.run-broken.sh"
check "a failing check fails the run" sh -c '[ "$1" -ne 0 ] && grep -q "^not ok 1 " "$2"' _ "$rc" "$TEST_HOME/broken.log"

# Entry 2: the shims are committed executable.
check "tests/bin shims are executable" [ -x "$DIR/bin/curl" ] && [ -x "$DIR/bin/editor" ]

finish
