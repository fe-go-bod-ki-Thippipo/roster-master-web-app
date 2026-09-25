#!/usr/bin/env bash
set -euo pipefail
signature="rm_insert_approved_company_history(uuid,uuid,date,date,uuid)"
before="$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT md5(pg_get_functiondef('$signature'::regprocedure))")"
test -n "$before"
mutation_file="$(mktemp)"
trap 'rm -f "$mutation_file"' EXIT
python3 - "$mutation_file" <<'PY'
from pathlib import Path
import sys
source = Path('database/migrations/002a_1_employee_lifecycle.sql').read_text()
start = source.index('CREATE FUNCTION rm_insert_approved_company_history(')
end = source.index('END $history$;', start) + len('END $history$;')
definition = source[start:end]
correct = 'NOT (v_request.company_id IS NOT DISTINCT FROM p_company_id OR v_request.target_company_id IS NOT DISTINCT FROM p_company_id)'
mutant = 'NOT (v_request.company_id = p_company_id OR v_request.target_company_id = p_company_id)'
if definition.count(correct) != 1:
    raise SystemExit('MUTATION_INVALID: H-1 predicate not found exactly once')
definition = definition.replace('CREATE FUNCTION rm_insert_approved_company_history(', 'CREATE OR REPLACE FUNCTION rm_insert_approved_company_history(', 1).replace(correct, mutant)
Path(sys.argv[1]).write_text(definition + '\n')
PY
set +e
output="$(psql -X -v ON_ERROR_STOP=1 <<SQL 2>&1
BEGIN;
\i $mutation_file
\i database/tests/h1_company_authorization.sql
ROLLBACK;
SQL
)"
status=$?
set -e
after="$(psql -X -v ON_ERROR_STOP=1 -Atc "SELECT md5(pg_get_functiondef('$signature'::regprocedure))")"
if [[ "$before" != "$after" ]]; then
  echo "MUTATION_INVALID: h1_null_company_logic function definition changed after rollback" >&2
  echo "$output" >&2
  exit 1
fi
if [[ "$status" -eq 0 ]]; then
  echo "MUTATION_SURVIVED: h1_null_company_logic" >&2
  exit 1
fi
error_lines="$(printf '%s\n' "$output" | grep -E '(^|[[:space:]])ERROR:' || true)"
if [[ "$(printf '%s\n' "$error_lines" | grep -c 'ERROR:' || true)" -eq 1 ]] && [[ "$error_lines" == *'ERROR:  B6_PRIME_WRONG_COMPANY_ACCEPTED'* ]]; then
  echo "MUTATION_KILLED: h1_null_company_logic (B6_PRIME_WRONG_COMPANY_ACCEPTED)"
  echo "FUNCTION_MD5_UNCHANGED: h1_null_company_logic"
else
  echo "MUTATION_INVALID: h1_null_company_logic (unexpected error)" >&2
  echo "$output" >&2
  exit 1
fi
