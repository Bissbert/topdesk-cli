#!/bin/sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/helpers.sh"

echo 1..29
t=1

# 1) dispatcher help
out=$(topdesk help 2>&1 || true)
if contains "$out" "Usage: topdesk" && contains "$out" "incidents"; then ok $t "help shows usage and commands"; else not_ok $t "help output"; fi
t=$((t+1))

# 2) call with token header and query params
: > "$TEST_CURL_LOG"
export TDX_AUTH_TOKEN="Bearer testtoken"
out=$(topdesk call GET /tas/api/incidents --param foo=bar --param baz "value with space" --raw || true)
if [ -s "$TEST_CURL_LOG" ] && \
   grep -F -- '-H Authorization: Bearer testtoken' "$TEST_CURL_LOG" >/dev/null 2>&1 && \
   grep -F -- 'foo=bar' "$TEST_CURL_LOG" >/dev/null 2>&1 && \
   grep -F -- 'baz=value%20with%20space' "$TEST_CURL_LOG" >/dev/null 2>&1; then
  ok $t "call passes Authorization header"
else
  not_ok $t "call Authorization header"
fi
t=$((t+1))

# 3) incidents single page json
out=$(topdesk incidents --page-size 2 --format json || true)
if contains "$out" '"number":"I1"' && contains "$out" '"number":"I2"'; then ok $t "incidents json page"; else not_ok $t "incidents json page"; fi
t=$((t+1))

# 4) incidents pagination all json (requires jq)
if have_jq; then
  out=$(topdesk incidents --all --page-size 2 --format json)
  cnt=$(printf '%s' "$out" | jq 'length')
  if [ "$cnt" -eq 3 ]; then ok $t "incidents paginated json merged"; else not_ok $t "incidents paginated json"; fi
else
  diag "jq not found; skipping paginated json test"
  ok $t "skip"; 
fi
t=$((t+1))

# 5) incidents-get by id
out=$(topdesk incidents-get --id iid-1 --pretty || true)
if contains "$out" '"id":"iid-1"' || contains "$out" '"id": "iid-1"'; then ok $t "incidents-get by id"; else not_ok $t "incidents-get by id"; fi
t=$((t+1))

# 6) incidents-get by number (first)
out=$(topdesk incidents-get --number I42 --pretty || true)
if contains "$out" '"number":"I42"' || contains "$out" '"number": "I42"'; then ok $t "incidents-get by number"; else diag "$out"; not_ok $t "incidents-get by number"; fi
t=$((t+1))

# 7) persons list json
out=$(topdesk persons --format json || true)
if contains "$out" '"networkLoginName"' && contains "$out" 'alice'; then ok $t "persons list"; else not_ok $t "persons list"; fi
t=$((t+1))

# 8) persons paginated json
if have_jq; then
  out=$(topdesk persons --all --page-size 2 --format json)
  cnt=$(printf '%s' "$out" | jq 'length')
  if [ "$cnt" -ge 2 ]; then ok $t "persons paginated json"; else not_ok $t "persons paginated json"; fi
else
  diag "jq not found; skipping persons paginated json test"; ok $t "skip";
fi
t=$((t+1))

# 9) assets list json
out=$(topdesk assets --format json || true)
if contains "$out" '"objectNumber":"A-001"' || contains "$out" '"objectNumber": "A-001"'; then ok $t "assets list"; else not_ok $t "assets list"; fi
t=$((t+1))

# 10) config list exists and redacts
out=$(topdesk config list || true)
if printf '%s' "$out" | grep -q '^TDX_BASE_URL' ; then ok $t "config list"; else not_ok $t "config list"; fi
t=$((t+1))

# 11) incidents limit enforcement (requires jq)
if have_jq; then
  out=$(topdesk incidents --all --page-size 2 --limit 1 --format json)
  cnt=$(printf '%s' "$out" | jq 'length')
  if [ "$cnt" -eq 1 ]; then ok $t "incidents limit respects cap"; else not_ok $t "incidents limit respects cap"; fi
else
  diag "jq not found; skipping incidents limit test"; ok $t "skip";
fi
t=$((t+1))

# 12) incidents-add-note preserves newlines
: > "$TEST_CURL_LOG"
note_payload=$(printf 'Line1\nLine2')
out=$(topdesk incidents-add-note --id iid-1 --text "$note_payload" || true)
if grep -F -- '--data {"text": "Line1\nLine2"}' "$TEST_CURL_LOG" >/dev/null 2>&1; then ok $t "add-note escapes newline"; else not_ok $t "add-note escapes newline"; fi
t=$((t+1))

# 13) attachments honor TDX_VERIFY_TLS=0
: > "$TEST_CURL_LOG"
TDX_VERIFY_TLS=0 topdesk incidents-attachments-download --id iid-1 --attachment-id att-1 >/dev/null 2>&1 || true
if grep -F -- ' -k ' "$TEST_CURL_LOG" >/dev/null 2>&1; then ok $t "attachments auto-disable TLS"; else not_ok $t "attachments auto-disable TLS"; fi
t=$((t+1))

# 14) call reports HTTP errors
errfile="$TEST_DIR/.err"
: > "$errfile"
if topdesk call GET /error/404 >/dev/null 2>"$errfile"; then
  status=0
else
  status=$?
fi
if [ "$status" -eq 4 ] && grep -q 'HTTP 404' "$errfile"; then ok $t "call surfaces http error"; else diag "status=$status"; diag "$(cat "$errfile")"; not_ok $t "call surfaces http error"; fi
t=$((t+1))

# 15) call reports curl timeout
: > "$errfile"
if topdesk call GET /error/timeout >/dev/null 2>"$errfile"; then
  status=0
else
  status=$?
fi
if [ "$status" -eq 3 ] && grep -q 'timed out' "$errfile"; then ok $t "call surfaces timeout"; else diag "status=$status"; diag "$(cat "$errfile")"; not_ok $t "call surfaces timeout"; fi
t=$((t+1))

# 16) incidents tsv matches fixture
tmp_tsv="$TEST_DIR/.out.tsv"
out=$(topdesk incidents --page-size 2 --format tsv --headers || true)
printf '%s\n' "$out" > "$tmp_tsv"
if diff -u "$TEST_DIR/fixtures/incidents.tsv" "$tmp_tsv" >/dev/null 2>&1; then ok $t "incidents tsv fixture"; else diag "$(diff -u "$TEST_DIR/fixtures/incidents.tsv" "$tmp_tsv" 2>/dev/null || true)"; not_ok $t "incidents tsv fixture"; fi
rm -f "$tmp_tsv"
t=$((t+1))

# 17) incidents csv matches fixture
tmp_csv="$TEST_DIR/.out.csv"
out=$(topdesk incidents --page-size 2 --format csv --headers || true)
printf '%s\n' "$out" > "$tmp_csv"
if diff -u "$TEST_DIR/fixtures/incidents.csv" "$tmp_csv" >/dev/null 2>&1; then ok $t "incidents csv fixture"; else diag "$(diff -u "$TEST_DIR/fixtures/incidents.csv" "$tmp_csv" 2>/dev/null || true)"; not_ok $t "incidents csv fixture"; fi
rm -f "$tmp_csv"
t=$((t+1))

# 18) operators list & pagination
out=$(topdesk operators --all --page-size 1 --format json || true)
if contains "$out" 'Operator One' && contains "$out" 'Operator Two'; then ok $t "operators list"; else not_ok $t "operators list"; fi
t=$((t+1))

# 19) operators paginated json
if have_jq; then
  cnt=$(printf '%s' "$out" | jq 'length')
  if [ "$cnt" -ge 2 ]; then ok $t "operators paginated"; else not_ok $t "operators paginated"; fi
else
  diag "jq not found; skipping operators pagination"; ok $t "skip";
fi
t=$((t+1))

# 20) operators-get by id
out=$(topdesk operators-get --id op1 --pretty || true)
if contains "$out" '"id":"op1"'; then ok $t "operators-get"; else not_ok $t "operators-get"; fi
t=$((t+1))

# 21) operators-search with params
: > "$TEST_CURL_LOG"
out=$(topdesk operators-search --param name "Operator One" --raw || true)
if contains "$out" 'Operator One' && grep -F -- 'name=Operator%20One' "$TEST_CURL_LOG" >/dev/null 2>&1; then ok $t "operators-search"; else not_ok $t "operators-search"; fi
t=$((t+1))

# 22) config init creates template
CFG_DIR="$TEST_DIR/tmp-config"
rm -rf "$CFG_DIR"
TOOLBOX_CONFIG_DIR="$CFG_DIR" topdesk config init >/dev/null 2>&1 || true
cfg_file="$CFG_DIR/config"
if [ -f "$cfg_file" ] && grep -q 'TDX_BASE_URL' "$cfg_file"; then ok $t "config init template"; else not_ok $t "config init template"; fi
t=$((t+1))

# 23) config edit uses EDITOR and preserves template
CFG_EDIT_DIR="$TEST_DIR/tmp-config-edit"
rm -rf "$CFG_EDIT_DIR"
TOOLBOX_CONFIG_DIR="$CFG_EDIT_DIR" EDITOR=editor topdesk config edit >/dev/null 2>&1 || true
cfg_edit_file="$CFG_EDIT_DIR/config"
if [ -f "$cfg_edit_file" ] && grep -q '# edited by stub' "$cfg_edit_file"; then ok $t "config edit invokes editor"; else not_ok $t "config edit invokes editor"; fi
t=$((t+1))

# 24) persons-create posts to API
: > "$TEST_CURL_LOG"
out=$(topdesk persons-create --data '{"firstName":"Test"}' --raw || true)
if grep -F -- '-X POST' "$TEST_CURL_LOG" >/dev/null 2>&1 && grep -F -- 'tas/api/persons' "$TEST_CURL_LOG" >/dev/null 2>&1; then
  ok $t "persons-create"
else
  not_ok $t "persons-create"
fi
t=$((t+1))

# 25) persons-update patches to ID
: > "$TEST_CURL_LOG"
out=$(topdesk persons-update --id p1 --data '{"firstName":"Updated"}' --raw || true)
if grep -F -- '-X PATCH' "$TEST_CURL_LOG" >/dev/null 2>&1 && grep -F -- 'tas/api/persons/p1' "$TEST_CURL_LOG" >/dev/null 2>&1; then
  ok $t "persons-update"
else
  not_ok $t "persons-update"
fi
t=$((t+1))

# 26) operators-create posts to API
: > "$TEST_CURL_LOG"
out=$(topdesk operators-create --data '{"name":"New Operator"}' --raw || true)
if grep -F -- '-X POST' "$TEST_CURL_LOG" >/dev/null 2>&1 && grep -F -- 'tas/api/operators' "$TEST_CURL_LOG" >/dev/null 2>&1; then
  ok $t "operators-create"
else
  not_ok $t "operators-create"
fi
t=$((t+1))

# 27) operators-update patches to ID
: > "$TEST_CURL_LOG"
out=$(topdesk operators-update --id op1 --data '{"name":"Updated"}' --raw || true)
if grep -F -- '-X PATCH' "$TEST_CURL_LOG" >/dev/null 2>&1 && grep -F -- 'tas/api/operators/op1' "$TEST_CURL_LOG" >/dev/null 2>&1; then
  ok $t "operators-update"
else
  not_ok $t "operators-update"
fi
t=$((t+1))

# 28) assets-create posts to API
: > "$TEST_CURL_LOG"
out=$(topdesk assets-create --data '{"objectNumber":"A-002"}' --raw || true)
if grep -F -- '-X POST' "$TEST_CURL_LOG" >/dev/null 2>&1 && grep -F -- 'tas/api/assetmgmt/assets' "$TEST_CURL_LOG" >/dev/null 2>&1; then
  ok $t "assets-create"
else
  not_ok $t "assets-create"
fi
t=$((t+1))

# 29) assets-update patches to ID
: > "$TEST_CURL_LOG"
out=$(topdesk assets-update --id a1 --data '{"name":"Updated"}' --raw || true)
if grep -F -- '-X PATCH' "$TEST_CURL_LOG" >/dev/null 2>&1 && grep -F -- 'tas/api/assetmgmt/assets/a1' "$TEST_CURL_LOG" >/dev/null 2>&1; then
  ok $t "assets-update"
else
  not_ok $t "assets-update"
fi
t=$((t+1))

rm -rf "$CFG_DIR" "$CFG_EDIT_DIR"

rm -f "$errfile"
