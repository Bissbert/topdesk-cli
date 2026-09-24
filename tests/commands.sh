#!/bin/sh
# Request shape and exit codes of the commands tests/run.sh does not cover.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/helpers.sh"
export TDX_AUTH_TOKEN="Bearer testtoken"

# incidents-create / incidents-update
: > "$TEST_CURL_LOG"
topdesk incidents-create --data '{"briefDescription":"x"}' --raw >/dev/null 2>&1 || :
check "incidents-create POSTs to /tas/api/incidents" \
  sh -c 'grep -qF -- "-X POST" "$1" && grep -qF "mock.local/tas/api/incidents" "$1"' _ "$TEST_CURL_LOG"

printf '{"briefDescription":"from file"}' > "$TEST_HOME/payload.json"
: > "$TEST_CURL_LOG"
topdesk incidents-create --data "@$TEST_HOME/payload.json" --raw >/dev/null 2>&1 || :
check "incidents-create passes --data @file to curl as a file" logged "--data-binary @$TEST_HOME/payload.json"

: > "$TEST_CURL_LOG"
topdesk incidents-update --id iid-1 --data '{"status":"x"}' --raw >/dev/null 2>&1 || :
check "incidents-update PATCHes by default" \
  sh -c 'grep -qF -- "-X PATCH" "$1" && grep -qF "tas/api/incidents/iid-1" "$1"' _ "$TEST_CURL_LOG"

: > "$TEST_CURL_LOG"
topdesk incidents-update --id iid-1 --method PUT --data '{}' --raw >/dev/null 2>&1 || :
check "incidents-update --method PUT" logged '-X PUT'

rc=0; topdesk incidents-update --data '{}' >/dev/null 2>&1 || rc=$?
check "incidents-update without --id is a usage error" [ "$rc" -ne 0 ]

# attachments upload
printf 'hello' > "$TEST_HOME/note.txt"
: > "$TEST_CURL_LOG"
rc=0; topdesk incidents-attachments-upload --id iid-1 --file "$TEST_HOME/note.txt" --name report.txt >/dev/null 2>&1 || rc=$?
check "attachments-upload exits 0" [ "$rc" -eq 0 ]
check "attachments-upload sends a multipart file with --name" logged "file=@$TEST_HOME/note.txt;filename=report.txt"
check "attachments-upload targets the incident" logged 'tas/api/incidents/iid-1/attachments'

rc=0; topdesk incidents-attachments-upload --id iid-1 --file "$TEST_HOME/missing" >/dev/null 2>&1 || rc=$?
check "attachments-upload rejects a missing file with exit 2" [ "$rc" -eq 2 ]

# get / search
out=$(topdesk persons-get --id p1 --raw 2>&1 || :)
check "persons-get by id" contains "$out" '"id":"p1"'
out=$(topdesk assets-get --id a1 --raw 2>&1 || :)
check "assets-get by id" contains "$out" '"objectNumber":"A-001"'

: > "$TEST_CURL_LOG"
out=$(topdesk persons-search --query 'networkLoginName==alice' --raw 2>&1 || :)
check "persons-search returns people" contains "$out" 'alice'
check "persons-search passes the query" logged 'tas/api/persons?'

: > "$TEST_CURL_LOG"
out=$(topdesk assets-search --query 'name==Laptop' --raw 2>&1 || :)
check "assets-search returns assets" contains "$out" 'Laptop'
check "assets-search passes the query" logged 'tas/api/assetmgmt/assets?'

# authentication variants on call
: > "$TEST_CURL_LOG"
( unset TDX_AUTH_TOKEN; TDX_USER=u1 TDX_PASS=p1 topdesk call GET /tas/api/incidents --raw >/dev/null 2>&1 ) || :
check "call uses basic auth without a token" logged '-u u1:p1'

: > "$TEST_CURL_LOG"
( unset TDX_AUTH_TOKEN; TDX_AUTH_HEADER="X-Api: k" topdesk call GET /tas/api/incidents --raw >/dev/null 2>&1 ) || :
check "call sends TDX_AUTH_HEADER verbatim" logged '-H X-Api: k'

rc=0; topdesk call GET /error/500 >/dev/null 2>&1 || rc=$?
check "call exits non-zero on HTTP 500" [ "$rc" -ne 0 ]

# ping
rc=0; out=$(topdesk ping 2>&1) || rc=$?
check "ping exits 0 against a 200" [ "$rc" -eq 0 ]
rc=0; out=$(topdesk ping --endpoint /error/404 2>&1) || rc=$?
check "ping treats a 404 as reachable (exit 0)" sh -c '[ "$1" -eq 0 ] && printf "%s" "$2" | grep -qF "endpoint not found"' _ "$rc" "$out"
rc=0; topdesk ping --endpoint /error/401 >/dev/null 2>&1 || rc=$?
check "ping exits 2 on HTTP 401" [ "$rc" -eq 2 ]
rc=0; topdesk ping --endpoint /error/500 >/dev/null 2>&1 || rc=$?
check "ping exits 1 on HTTP 500" [ "$rc" -eq 1 ]
rc=0; topdesk ping --endpoint /error/timeout >/dev/null 2>&1 || rc=$?
check "ping exits 1 when unreachable" [ "$rc" -eq 1 ]
out=$(topdesk ping --verbose 2>&1 || :)
check "ping --verbose masks the token" sh -c '! printf "%s" "$1" | grep -qF testtoken' _ "$out"

# config
out=$(TDX_USER=u1 TDX_PASS=secret-pass topdesk config list 2>&1 || :)
check "config list redacts the token" sh -c '! printf "%s" "$1" | grep -qF testtoken' _ "$out"
check "config list redacts the password" sh -c '! printf "%s" "$1" | grep -qF secret-pass' _ "$out"
rc=0; topdesk config validate >/dev/null 2>&1 || rc=$?
check "config validate passes with URL and token" [ "$rc" -eq 0 ]
rc=0; ( unset TDX_AUTH_TOKEN; topdesk config validate >/dev/null 2>&1 ) || rc=$?
check "config validate fails without auth" [ "$rc" -ne 0 ]
rc=0; topdesk config path >/dev/null 2>&1 || rc=$?
check "config path fails when no file exists" [ "$rc" -ne 0 ]
topdesk config init >/dev/null 2>&1 || :
out=$(topdesk config path 2>&1 || :)
check "config path shows the file config init wrote" [ "$out" = "$XDG_CONFIG_HOME/topdesk/config" ]
printf 'TDX_BASE_URL=https://kept.example\n' > "$XDG_CONFIG_HOME/topdesk/config"
topdesk config init >/dev/null 2>&1 || :
check "config init keeps an existing file" [ "$(cat "$XDG_CONFIG_HOME/topdesk/config")" = "TDX_BASE_URL=https://kept.example" ]

# dispatcher
rc=0; topdesk no-such-command >/dev/null 2>&1 || rc=$?
check "unknown command exits non-zero" [ "$rc" -ne 0 ]
out=$(topdesk --version 2>&1 || :)
check "--version prints VERSION" contains "$out" "$(cat "$ROOT_DIR/VERSION")"

finish
