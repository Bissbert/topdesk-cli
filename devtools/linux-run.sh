#!/bin/sh
# Run every check in docs/measurement.md inside a Linux container.
#
#   sh devtools/linux-run.sh > docs/captures/linux-run.txt
#
# The repository is mounted read-only and copied inside the container. No
# Topdesk tenant is contacted: the test suite uses the curl shim in tests/bin,
# and the doctor runs use an empty temporary config location.
set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
IMAGE=python:3.12-slim-bookworm

docker pull -q "$IMAGE" >/dev/null
docker run --rm -v "$REPO":/repo:ro "$IMAGE" sh -c '
set -u
section() { printf "\n=== %s\n" "$*"; }

apt-get -qq update >/dev/null 2>&1
apt-get -qq install -y --no-install-recommends bash curl jq make git >/dev/null 2>&1
cp -r /repo /tmp/td && cd /tmp/td

section "environment"
uname -srm
bash --version | head -1
curl --version | head -1
jq --version
ls -l /bin/sh | sed "s/.* -> /sh -> /"

section "syntax check: sh -n on bin, lib, tools"
bad=0
for f in bin/topdesk lib/*.sh tools/*; do sh -n "$f" || bad=$((bad + 1)); done
echo "files with syntax errors: $bad"

section "devtools/repo-stats.sh"
sh devtools/repo-stats.sh

section "command table matches docs/commands.md"
sh devtools/command-surface.sh > /tmp/commands.md
diff docs/commands.md /tmp/commands.md && echo "identical ($(wc -l < /tmp/commands.md) lines)"

section "local commands"
for args in "--version" "help" "config --help" "doctor --help"; do
  ./bin/topdesk $args >/dev/null 2>&1; echo "topdesk $args  exit=$?"
done

section "test shim modes"
stat -c "%A %n" tests/bin/curl tests/bin/editor

section "make test, fresh HOME (entries 2, 4, 5)"
export SHELL=/bin/bash
fresh() { rm -rf /tmp/home && mkdir /tmp/home && export HOME=/tmp/home; }
fresh
make test > /tmp/test.log 2>&1; rc=$?
grep -E "^# |^1\.\.|^not ok|^Summary|^Failing" /tmp/test.log
echo "exit=$rc"

section "files make test left under HOME"
echo "files: $(find "$HOME" -type f | wc -l)"

section "make test again, same HOME"
make test > /tmp/test2.log 2>&1; rc=$?
grep "^Summary" /tmp/test2.log; echo "exit=$rc"

section "make test with an existing user config"
mkdir -p "$HOME/.config/topdesk"
printf "TDX_BASE_URL=https://tenant.example.com\n" > "$HOME/.config/topdesk/config"
before=$(cksum < "$HOME/.config/topdesk/config")
make test > /tmp/test3.log 2>&1; rc=$?
grep "^Summary" /tmp/test3.log; echo "exit=$rc"
[ "$(cksum < "$HOME/.config/topdesk/config")" = "$before" ] && echo "user config unchanged"

section "TAP status propagation: one check forced to fail, fresh HOME"
fresh
cp tests/run.sh /tmp/run.sh.orig
sed -i "s/contains \"\$out\" \"Usage: topdesk\"/contains \"\$out\" \"NO SUCH TEXT\"/" tests/run.sh
bash tests/run.sh > /tmp/test4.log 2>&1; rc=$?
grep "^not ok" /tmp/test4.log
echo "exit=$rc"
cp /tmp/run.sh.orig tests/run.sh

probe=$(mktemp -d)
doctor() { XDG_CONFIG_HOME="$probe" HOME="$probe" ./bin/topdesk doctor "$@" 2>&1 | sed "s/\x1b\[[0-9;]*m//g"; }

section "doctor, empty config location"
doctor > /tmp/doc.log; cat /tmp/doc.log

section "doctor --quiet, empty config location"
doctor --quiet > /tmp/docq.log; cat /tmp/docq.log
echo "lines=$(wc -l < /tmp/docq.log)"

section "doctor --verbose, empty config location"
doctor --verbose > /tmp/docv.log
echo "info lines=$(grep -c "ℹ" /tmp/docv.log) summary lines=$(grep -c "Checks passed" /tmp/docv.log)"

section "doctor with SHELL unset (entry 7)"
( unset SHELL; XDG_CONFIG_HOME="$probe" HOME="$probe" ./bin/topdesk doctor --verbose >/tmp/docs.log 2>&1; echo "exit=$?" )
sed "s/\x1b\[[0-9;]*m//g" /tmp/docs.log | grep -E "Shell:|Checks failed"
'
