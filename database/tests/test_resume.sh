#!/usr/bin/env bash
# Validate resuming from an already-applied 001 in a disposable database.
set -euo pipefail
psql -X -v ON_ERROR_STOP=1 -f database/tests/000_migration_ledger.sql
checksum="$(sha256sum database/migrations/001_schema.sql | cut -d' ' -f1)"
psql -X -v ON_ERROR_STOP=1 -1 -f database/migrations/001_schema.sql -c "INSERT INTO public.schema_migration_ledger(version,checksum_sha256) VALUES ('001','$checksum')"
test "$(psql -X -v ON_ERROR_STOP=1 -Atc 'SELECT count(*) FROM public.schema_migration_ledger')" = 1
output="$(bash database/tests/run_migrations.sh)"
grep -qx 'APPLIED: 002a-1' <<< "$output"
! grep -q 'APPLIED: 001' <<< "$output"
psql -X -v ON_ERROR_STOP=1 -Atc "SELECT count(*) = 2 AND bool_and(checksum_sha256 ~ '^[0-9a-f]{64}$') FROM public.schema_migration_ledger" | grep -qx t
echo 'PASS: resumed from 001 and applied only 002a-1'
