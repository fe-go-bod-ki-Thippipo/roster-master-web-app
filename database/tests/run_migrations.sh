#!/usr/bin/env bash
# CI-only runner. Invoke from repository root against a disposable database.
set -euo pipefail
specs=("001:database/migrations/001_schema.sql" "002a-1:database/migrations/002a_1_employee_lifecycle.sql")
if [[ "$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT to_regclass('public.schema_migration_ledger') IS NULL")" == t ]]; then
  psql -X -v ON_ERROR_STOP=1 -f database/tests/000_migration_ledger.sql
fi
# Validate every known version before applying any pending migration.
pending=()
applied=0
seen_pending=0
for spec in "${specs[@]}"; do
  version="${spec%%:*}"
  path="${spec#*:}"
  python3 database/tests/check_migration_sql.py "$path"
  checksum="$(sha256sum "$path" | cut -d' ' -f1)"
  existing="$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT checksum_sha256 FROM public.schema_migration_ledger WHERE version = '$version'")"
  if [[ -n "$existing" ]]; then
    if [[ "$existing" != "$checksum" ]]; then
      echo "CHECKSUM_DRIFT: $version" >&2
      exit 3
    fi
    if [[ "$seen_pending" -eq 1 ]]; then
      echo "MIGRATION_ORDER_INVALID: $version already applied after a missing version" >&2
      exit 5
    fi
    applied=$((applied + 1))
  else
    seen_pending=1
    pending+=("$version:$path:$checksum")
  fi
done
if [[ "${#pending[@]}" -eq 0 ]]; then
  echo "REPLAY_BLOCKED: all ${applied} migrations already applied" >&2
  exit 2
fi
for item in "${pending[@]}"; do
  version="${item%%:*}"
  rest="${item#*:}"
  path="${rest%%:*}"
  checksum="${rest##*:}"
  # The transaction-scoped lock serializes concurrent migration runners across hosts.
  # Recheck the ledger after acquiring the lock to close the preflight race.
  psql -X -v ON_ERROR_STOP=1 -1 \
    -c "SELECT pg_advisory_xact_lock(728419, 20021)" \
    -c "DO \$guard\$ BEGIN IF EXISTS (SELECT 1 FROM public.schema_migration_ledger WHERE version = '$version') THEN RAISE EXCEPTION 'MIGRATION_ALREADY_APPLIED: $version'; END IF; END \$guard\$;" \
    -f "$path" \
    -c "INSERT INTO public.schema_migration_ledger(version,checksum_sha256) VALUES ('$version','$checksum')"
  echo "APPLIED: $version"
done
