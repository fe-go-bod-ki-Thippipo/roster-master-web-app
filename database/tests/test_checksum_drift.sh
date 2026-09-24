#!/usr/bin/env bash
# Execute after successful baseline migration in a disposable CI database.
set -euo pipefail
original=database/migrations/001_schema.sql
backup="$(mktemp)"
cp "$original" "$backup"
restore() { cp "$backup" "$original"; rm -f "$backup"; }
trap restore EXIT
printf '\n-- deliberate checksum drift for CI negative test\n' >> "$original"
set +e
output="$(bash database/tests/run_migrations.sh 2>&1)"
status=$?
set -e
test "$status" -eq 3 || { echo "Expected checksum-drift exit 3; got $status: $output" >&2; exit 1; }
grep -q 'CHECKSUM_DRIFT: 001' <<< "$output"
! grep -q 'APPLIED:' <<< "$output"
echo "PASS: runner rejects changed applied migration before execution"
