#!/usr/bin/env bash
# Each mutation is rolled back in a disposable CI database.
set -euo pipefail
psql -X -v ON_ERROR_STOP=1 -Atc "SELECT to_regclass('public.employee_code_registry') IS NOT NULL" | grep -qx t
run_mutation() {
  local name="$1" sql="$2" expected="$3"
  local result status
  set +e
  result="$(psql -X -v ON_ERROR_STOP=1 -At <<SQL 2>&1
BEGIN;
$sql
\\i database/tests/002a_1_mutation_catalog.sql
ROLLBACK;
SQL
)"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    echo "MUTATION_SURVIVED: $name (assertions did not reject mutation)" >&2
    return 1
  fi
  if ! grep -Fq "$expected" <<< "$result"; then
    echo "MUTATION_INVALID: $name (unexpected SQL error, not the expected assertion)" >&2
    echo "$result" >&2
    return 1
  fi
  echo "MUTATION_KILLED: $name ($expected)"
}
run_mutation registry_trigger "ALTER TABLE public.employee_code_registry DISABLE TRIGGER registry_no_update;" "Registry immutability trigger missing"
run_mutation employee_code_trigger "ALTER TABLE public.employees DISABLE TRIGGER employee_code_immutable;" "Employee code immutability trigger missing"
run_mutation audit_delete_trigger "ALTER TABLE public.audit_logs DISABLE TRIGGER audit_no_delete;" "Audit delete trigger missing"
run_mutation company_history_exclusion "ALTER TABLE public.employee_company_history DROP CONSTRAINT company_history_no_overlap;" "Active company-history exclusion constraint missing"
