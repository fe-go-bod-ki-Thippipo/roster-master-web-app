-- Step 0 regression probes: fail the test on any unexpected result.
DO $test$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_constraint WHERE conrelid='employee_code_registry'::regclass AND contype='p';
 IF n<>1 THEN RAISE EXCEPTION 'Registry primary key missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='employee_code_registry'::regclass AND tgname='registry_no_update' AND NOT tgisinternal) THEN RAISE EXCEPTION 'Registry immutability trigger missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='employees'::regclass AND tgname='employee_code_immutable' AND NOT tgisinternal) THEN RAISE EXCEPTION 'Employee code immutability trigger missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='audit_logs'::regclass AND tgname='audit_no_delete' AND NOT tgisinternal) THEN RAISE EXCEPTION 'Audit delete trigger missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='employee_company_history'::regclass AND conname='company_history_no_overlap' AND contype='x') THEN RAISE EXCEPTION 'Active company-history exclusion constraint missing'; END IF;
 IF rm_business_date('2026-10-31 17:30:00+00'::timestamptz) <> DATE '2026-11-01' THEN RAISE EXCEPTION 'Bangkok midnight conversion failed'; END IF;
END $test$;
-- Create a fixture inside a rollback-only transaction; never leak fixture data.
BEGIN;
INSERT INTO company_groups(group_code,group_name) VALUES ('STEP0','Step 0 group');
INSERT INTO companies(company_group_id,company_code,company_name)
SELECT id,'STEP0A','Step 0 company' FROM company_groups WHERE group_code='STEP0';
INSERT INTO employees(employee_code,full_name,home_company_id,hire_date)
SELECT 'STEP0-001','Step 0 employee',id,DATE '2026-01-01' FROM companies WHERE company_code='STEP0A';
INSERT INTO employee_code_registry(code_normalized,code_original,employee_id,source)
SELECT 'STEP0-001','STEP0-001',id,'system' FROM employees WHERE employee_code='STEP0-001';
DO $test$
DECLARE eid uuid;
BEGIN
 SELECT id INTO eid FROM employees WHERE employee_code='STEP0-001';
 BEGIN
  UPDATE employees SET employee_code='STEP0-002' WHERE id=eid;
  RAISE EXCEPTION 'Expected immutable employee code rejection';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Expected immutable employee code rejection' THEN RAISE; END IF;
 END;
 BEGIN
  UPDATE employee_code_registry SET code_original='STEP0-002' WHERE employee_id=eid;
  RAISE EXCEPTION 'Expected immutable registry rejection';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Expected immutable registry rejection' THEN RAISE; END IF;
 END;
 BEGIN
  INSERT INTO employee_code_registry(code_normalized,code_original,employee_id,source)
  VALUES ('STEP0-001','STEP0-001',gen_random_uuid(),'system');
  RAISE EXCEPTION 'Expected duplicate registry rejection';
 EXCEPTION WHEN unique_violation THEN NULL;
 END;
 BEGIN
  DELETE FROM employees WHERE id=eid;
  RAISE EXCEPTION 'Expected employee delete rejection';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Expected employee delete rejection' THEN RAISE; END IF;
 END;
 BEGIN
  UPDATE employees SET hire_date=NULL WHERE id=eid;
  RAISE EXCEPTION 'Expected NOT NULL hire date rejection';
 EXCEPTION WHEN not_null_violation THEN NULL;
 END;
END $test$;
ROLLBACK;
