#!/usr/bin/env bash
# Run two independent migration runners against the same disposable database.
set -euo pipefail
psql -X -v ON_ERROR_STOP=1 -f database/tests/000_migration_ledger.sql
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
# Hold the same advisory lock before launching either runner to force real contention.
# A persistent lock holder must stay connected; use a FIFO to release it after both
# runners reach the waiting state.
psql -X -v ON_ERROR_STOP=1 -Atc "SELECT pg_advisory_lock(728419,20021); SELECT pg_sleep(8);" >"$dir/holder.log" 2>&1 &
holder=$!
sleep 1
bash database/tests/run_migrations.sh >"$dir/first.log" 2>&1 &
first=$!
bash database/tests/run_migrations.sh >"$dir/second.log" 2>&1 &
second=$!
sleep 2
waiters="$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event='advisory' AND query LIKE '%pg_advisory_xact_lock(728419, 20021)%'")"
if [[ "$waiters" -lt 2 ]]; then
 echo "FAIL: both runners did not contend for the advisory lock (waiters=$waiters)" >&2
 kill "$first" "$second" "$holder" 2>/dev/null || true
 exit 1
fi
wait "$holder"
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
