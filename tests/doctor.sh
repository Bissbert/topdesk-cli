#!/bin/sh
# doctor: every section runs, exit status, and entries 1, 3, 6 and 7 of
# docs/BUGS-FOUND.md.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/helpers.sh"
unset TDX_BASE_URL TDX_AUTH_TOKEN TDX_VERIFY_TLS
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

rc=0; out=$(topdesk doctor 2>&1 | strip) || rc=$?
check "doctor reaches the summary with an empty config (entry 1)" contains "$out" 'Checks failed:'
check "doctor reports the missing base URL" contains "$out" 'TDX_BASE_URL is not configured'
tools=$(find "$ROOT_DIR/tools" -type f | wc -l | tr -d ' ')
check "doctor counts every tool as executable (entry 6)" contains "$out" "All $tools tools have executable permissions"

rc=0; out=$(topdesk doctor --quiet 2>&1 | strip) || rc=$?
check "doctor --quiet prints failures and the summary (entry 3)" \
  sh -c 'printf "%s" "$1" | grep -q "No configuration file found" && printf "%s" "$1" | grep -q "Checks failed"' _ "$out"
check "doctor --quiet hides passing checks" sh -c '! printf "%s" "$1" | grep -qF "✓"' _ "$out"

rc=0; env -u SHELL "$ROOT_DIR/bin/topdesk" doctor --verbose >"$TEST_HOME/doc.log" 2>&1 || rc=$?
check "doctor runs with SHELL unset (entry 7)" sh -c '[ "$1" -ne 2 ] && grep -q "Shell: unknown" "$2"' _ "$rc" "$TEST_HOME/doc.log"

# A complete configuration against the mock API passes the config checks.
mkdir -p "$XDG_CONFIG_HOME/topdesk"
cat > "$XDG_CONFIG_HOME/topdesk/config" <<CFG
TDX_BASE_URL=http://mock.local
TDX_AUTH_TOKEN="Bearer t"
CFG
out=$(topdesk doctor 2>&1 | strip || :)
check "doctor finds the user config" contains "$out" "$XDG_CONFIG_HOME/topdesk/config"
check "doctor reports no missing variables with a full config" sh -c '! printf "%s" "$1" | grep -qF "is not configured"' _ "$out"

# --fix restores a missing executable bit, on a copy of the tree.
cp -R "$ROOT_DIR" "$TEST_HOME/tree"
chmod -x "$TEST_HOME/tree/tools/ping"
out=$("$TEST_HOME/tree/bin/topdesk" doctor 2>&1 | strip || :)
check "doctor warns about one non-executable tool" contains "$out" "$((tools - 1)) of $tools tools are executable"
"$TEST_HOME/tree/bin/topdesk" doctor --fix >/dev/null 2>&1 || :
check "doctor --fix sets the executable bit" [ -x "$TEST_HOME/tree/tools/ping" ]

finish
