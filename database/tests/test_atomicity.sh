#!/usr/bin/env bash
# Run only against a disposable empty database owned by the non-superuser migrator.
set -euo pipefail
psql -X -v ON_ERROR_STOP=1 -f database/tests/000_migration_ledger.sql
psql -X -v ON_ERROR_STOP=1 <<'SQL'
CREATE FUNCTION public.step0_reject_ledger_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 RAISE EXCEPTION 'STEP0_FORCED_LEDGER_FAILURE';
END $$;
CREATE TRIGGER step0_reject_ledger_insert BEFORE INSERT ON public.schema_migration_ledger
FOR EACH ROW EXECUTE FUNCTION public.step0_reject_ledger_insert();
SQL
set +e
output="$(bash database/tests/run_migrations.sh 2>&1)"
status=$?
set -e
if [[ "$status" -eq 0 ]] || ! grep -q 'STEP0_FORCED_LEDGER_FAILURE' <<< "$output"; then
 echo "FAIL: migration did not fail on forced ledger insert: $status" >&2
 echo "$output" >&2
 exit 1
fi
# The 001 schema must not survive a failed ledger insert.
for relation in public.company_groups public.companies public.employees; do
 result="$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT to_regclass('$relation') IS NULL")"
 [[ "$result" == t ]] || { echo "FAIL: schema remained after rollback: $relation" >&2; exit 1; }
done
[[ "$(psql -X -v ON_ERROR_STOP=1 -Atc 'SELECT count(*) FROM public.schema_migration_ledger')" == 0 ]]
echo "PASS: failed ledger insert rolls back migration 001 schema and ledger together"
