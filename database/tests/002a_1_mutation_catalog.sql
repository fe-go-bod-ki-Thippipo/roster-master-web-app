-- Mutation-specific catalog assertions: no fixture, no nested transaction.
DO $test$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.employee_code_registry'::regclass AND tgname='registry_no_update' AND tgenabled='O' AND NOT tgisinternal) THEN RAISE EXCEPTION 'Registry immutability trigger missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.employees'::regclass AND tgname='employee_code_immutable' AND tgenabled='O' AND NOT tgisinternal) THEN RAISE EXCEPTION 'Employee code immutability trigger missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.audit_logs'::regclass AND tgname='audit_no_delete' AND tgenabled='O' AND NOT tgisinternal) THEN RAISE EXCEPTION 'Audit delete trigger missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.employee_company_history'::regclass AND conname='company_history_no_overlap' AND contype='x') THEN RAISE EXCEPTION 'Active company-history exclusion constraint missing'; END IF;
END $test$;
