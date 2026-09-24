#!/usr/bin/env bash
# Run two independent migration runners against the same disposable database.
set -euo pipefail
psql -X -v ON_ERROR_STOP=1 -f database/tests/000_migration_ledger.sql
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
bash database/tests/run_migrations.sh >"$dir/first.log" 2>&1 &
first=$!
bash database/tests/run_migrations.sh >"$dir/second.log" 2>&1 &
second=$!
set +e
wait "$first"; first_status=$?
wait "$second"; second_status=$?
set -e
cat "$dir/first.log" "$dir/second.log"
if [[ "$first_status" -eq 0 && "$second_status" -eq 0 ]]; then
  echo 'FAIL: both concurrent runners reported success' >&2; exit 1
fi
if [[ "$first_status" -ne 0 && "$second_status" -ne 0 ]]; then
  echo 'FAIL: neither concurrent runner completed successfully' >&2; exit 1
fi
if ! grep -Eq 'MIGRATION_ALREADY_APPLIED|REPLAY_BLOCKED|duplicate key value violates unique constraint' "$dir/first.log" "$dir/second.log"; then
  echo 'FAIL: losing runner failed for an unexpected reason' >&2; exit 1
fi
psql -X -v ON_ERROR_STOP=1 -Atc "SELECT count(*)=2 AND count(DISTINCT version)=2 AND bool_and(checksum_sha256 ~ '^[0-9a-f]{64}$') FROM public.schema_migration_ledger" | grep -qx t
psql -X -v ON_ERROR_STOP=1 -Atc "SELECT to_regclass('public.employees') IS NOT NULL" | grep -qx t
echo 'PASS: concurrent runners produced one successful installation and exactly two ledger records'
