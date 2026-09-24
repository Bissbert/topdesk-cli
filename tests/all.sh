#!/bin/sh
# Run every test file and print one summary line.
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
pass=0; fail=0; files_failed=""
for f in run.sh commands.sh doctor.sh isolation.sh; do
  printf '# %s\n' "$f"
  out=$(bash "$DIR/$f" 2>&1); rc=$?
  printf '%s\n' "$out"
  pass=$((pass + $(printf '%s\n' "$out" | grep -c '^ok ')))
  fail=$((fail + $(printf '%s\n' "$out" | grep -c '^not ok ')))
  [ "$rc" -eq 0 ] || files_failed="$files_failed $f"
done
printf '\nSummary: %d passed, %d failed\n' "$pass" "$fail"
[ -z "$files_failed" ] || { printf 'Failing files:%s\n' "$files_failed"; exit 1; }
