#!/usr/bin/env bash
# CI-only runner. Invoke from repository root against a disposable database.
set -euo pipefail
if [[ "$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT to_regclass('public.schema_migration_ledger') IS NULL")" == t ]]; then
  psql -X -v ON_ERROR_STOP=1 -f database/tests/000_migration_ledger.sql
fi
for spec in "001:database/migrations/001_schema.sql" "002a-1:database/migrations/002a_1_employee_lifecycle.sql"; do
  version="${spec%%:*}"
  path="${spec#*:}"
  if grep -Ein '^[[:space:]]*(BEGIN|COMMIT|ROLLBACK)([[:space:]]+(WORK|TRANSACTION))?[[:space:]]*;([[:space:]]*--.*)?[[:space:]]*$' "$path"; then
    echo "TRANSACTION_CONTROL_FORBIDDEN: $version" >&2
    exit 4
  fi
  checksum="$(sha256sum "$path" | cut -d' ' -f1)"
  existing="$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT checksum_sha256 FROM public.schema_migration_ledger WHERE version = '$version'")"
  if [[ -n "$existing" ]]; then
    if [[ "$existing" != "$checksum" ]]; then
      echo "CHECKSUM_DRIFT: $version" >&2
      exit 3
    fi
    echo "REPLAY_BLOCKED: $version" >&2
    exit 2
  fi
  psql -X -v ON_ERROR_STOP=1 -1 -f "$path" -c "INSERT INTO public.schema_migration_ledger(version,checksum_sha256) VALUES ('$version','$checksum')"
  echo "APPLIED: $version"
done
