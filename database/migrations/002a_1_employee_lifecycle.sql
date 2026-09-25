-- Roster Master 002a-1 / incremental implementation (NOT READY TO APPLY)
-- This migration is deliberately a draft: history writer, coverage constraints,
-- assignment concurrency guards, projection reconciliation and role grants are pending.
-- DO NOT DEPLOY or merge until complete PostgreSQL acceptance tests pass.
-- 002a-1 creates the NEW database schema only. Legacy import is a separate phase.
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM employees) OR EXISTS (SELECT 1 FROM employee_company_history) THEN
  RAISE EXCEPTION '002a-1 requires empty employees and employee_company_history; import legacy data after migration';
 END IF;
END $$;
CREATE TABLE employee_code_registry (
 code_normalized text PRIMARY KEY,
 code_original text NOT NULL,
 employee_id uuid UNIQUE REFERENCES employees(id) DEFERRABLE INITIALLY DEFERRED,
 source text NOT NULL CHECK(source IN ('system','legacy_import','legacy_reservation')),
 migration_batch_id uuid REFERENCES migration_batches(id),
 reserved_at timestamptz NOT NULL DEFAULT now(),
 CHECK (code_normalized = upper(btrim(code_original)) AND code_normalized <> ''),
 CHECK ((source = 'legacy_reservation') = (employee_id IS NULL)),
 CHECK ((source = 'system') = (migration_batch_id IS NULL)),
 CHECK (source <> 'legacy_import' OR migration_batch_id IS NOT NULL)
);
CREATE FUNCTION rm_registry_immutable() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
BEGIN
 RAISE EXCEPTION 'Employee code reservations are immutable';
END $$;
CREATE TRIGGER registry_no_update BEFORE UPDATE ON employee_code_registry FOR EACH ROW EXECUTE FUNCTION rm_registry_immutable();
CREATE TRIGGER registry_no_delete BEFORE DELETE ON employee_code_registry FOR EACH ROW EXECUTE FUNCTION rm_registry_immutable();
CREATE TRIGGER registry_no_truncate BEFORE TRUNCATE ON employee_code_registry FOR EACH STATEMENT EXECUTE FUNCTION rm_registry_immutable();
CREATE FUNCTION rm_employee_code_immutable() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
BEGIN
 IF NEW.employee_code IS DISTINCT FROM OLD.employee_code THEN
  RAISE EXCEPTION 'Employee code cannot be changed';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER employee_code_immutable BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION rm_employee_code_immutable();
CREATE FUNCTION rm_no_destructive_dml() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
BEGIN
 RAISE EXCEPTION 'Permanent deletion or audit mutation is prohibited';
END $$;
CREATE TRIGGER employees_no_delete BEFORE DELETE ON employees FOR EACH ROW EXECUTE FUNCTION rm_no_destructive_dml();
CREATE TRIGGER employees_no_truncate BEFORE TRUNCATE ON employees FOR EACH STATEMENT EXECUTE FUNCTION rm_no_destructive_dml();
CREATE TRIGGER audit_no_update BEFORE UPDATE ON audit_logs FOR EACH ROW EXECUTE FUNCTION rm_no_destructive_dml();
CREATE TRIGGER audit_no_delete BEFORE DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION rm_no_destructive_dml();
CREATE TRIGGER audit_no_truncate BEFORE TRUNCATE ON audit_logs FOR EACH STATEMENT EXECUTE FUNCTION rm_no_destructive_dml();
-- Retain legacy status semantics only after migration data audit.
ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_status_check;
ALTER TABLE employees ADD CONSTRAINT employees_status_check CHECK (status IN ('active','terminated','cancelled'));
ALTER TABLE employees ALTER COLUMN hire_date SET NOT NULL;
ALTER TABLE employees ADD CONSTRAINT employees_employment_dates CHECK (termination_date IS NULL OR termination_date >= hire_date);
-- New history is versioned; baseline exclusion must be replaced to exclude superseded versions.
ALTER TABLE employee_company_history ADD COLUMN superseded_by_request_id uuid REFERENCES change_requests(id);
ALTER TABLE employee_company_history ADD COLUMN superseded_at timestamptz;
ALTER TABLE employee_company_history ADD COLUMN migration_batch_id uuid REFERENCES migration_batches(id);
ALTER TABLE employee_company_history ADD CONSTRAINT company_history_supersede_pair CHECK ((superseded_by_request_id IS NULL) = (superseded_at IS NULL));
ALTER TABLE employee_company_history ADD CONSTRAINT company_history_source_xor CHECK ((source_request_id IS NOT NULL) <> (migration_batch_id IS NOT NULL));
DO $$ DECLARE constraint_name name; constraint_count integer; BEGIN
 SELECT count(*), min(c.conname) INTO constraint_count, constraint_name
 FROM pg_constraint c WHERE c.conrelid = 'employee_company_history'::regclass AND c.contype = 'x';
 IF constraint_count <> 1 THEN RAISE EXCEPTION 'Expected exactly one baseline employee company history exclusion constraint, found %', constraint_count; END IF;
 EXECUTE format('ALTER TABLE employee_company_history DROP CONSTRAINT %I', constraint_name);
END $$;
ALTER TABLE employee_company_history ADD CONSTRAINT company_history_no_overlap
 EXCLUDE USING gist (employee_id WITH =, daterange(effective_from,COALESCE(effective_to + 1,'infinity'::date),'[)') WITH &&)
 WHERE (superseded_by_request_id IS NULL) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX company_history_supersede_request_idx ON employee_company_history(superseded_by_request_id) WHERE superseded_by_request_id IS NOT NULL;
-- Employee creation and legacy code reservations must be atomic in privileged writer functions.
-- Importing legacy records is deferred to a separate audited migration phase.
CREATE FUNCTION rm_business_date(p_at timestamptz DEFAULT now()) RETURNS date
 LANGUAGE sql STABLE SET search_path = pg_catalog, public AS $$ SELECT (p_at AT TIME ZONE 'Asia/Bangkok')::date $$;

-- Step 1: approval evidence predicate. Status alone is never sufficient.
-- This checks the final review round, each required step and authorized approver identity.
-- Company-scope authorization and writer permissions remain separate pending gates.
CREATE FUNCTION rm_request_has_approval_evidence(p_request_id uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path = pg_catalog, public AS $approval$
 SELECT EXISTS (
  SELECT 1 FROM change_requests r
  WHERE r.id = p_request_id AND r.status IN ('approved','applied')
    AND r.completed_at IS NOT NULL
    AND EXISTS (SELECT 1 FROM approval_steps s WHERE s.workflow_id = r.workflow_id)
    AND NOT EXISTS (
      SELECT 1 FROM approval_steps s
      WHERE s.workflow_id = r.workflow_id
        AND (
          SELECT count(DISTINCT a.approver_id)
          FROM request_approvals a
          WHERE a.request_id = r.id AND a.approval_step_id = s.id
            AND a.review_round = (
              SELECT max(a2.review_round) FROM request_approvals a2
              WHERE a2.request_id = r.id
            )
            AND a.decision = 'approved'
            AND (s.approver_user_id = a.approver_id OR
                 (s.approver_user_id IS NULL AND EXISTS (
                   SELECT 1 FROM user_role_assignments ura
                   WHERE ura.user_id = a.approver_id AND ura.role_id = s.approver_role_id
                     AND ura.status = 'active'
                 )))
            AND (s.allow_self_approval OR a.approver_id <> r.requester_id)
        ) < s.required_approvals
    )
 )
$approval$;

-- Step 1 incremental writer: request-backed company history only.
-- No SECURITY DEFINER or runtime grants until company-scoped authorization is implemented.
-- This function intentionally does not implement supersede or initial hire.
CREATE FUNCTION rm_insert_approved_company_history(
 p_employee_id uuid, p_company_id uuid, p_effective_from date,
 p_effective_to date, p_request_id uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, public AS $history$
DECLARE v_employee employees%ROWTYPE;
        v_request change_requests%ROWTYPE;
        v_history_id uuid;
BEGIN
 IF p_employee_id IS NULL OR p_company_id IS NULL OR p_effective_from IS NULL
    OR p_request_id IS NULL OR (p_effective_to IS NOT NULL AND p_effective_to < p_effective_from) THEN
  RAISE EXCEPTION 'HISTORY_INVALID_ARGUMENTS';
 END IF;
 SELECT * INTO STRICT v_employee FROM employees WHERE id=p_employee_id FOR UPDATE;
 SELECT * INTO STRICT v_request FROM change_requests WHERE id=p_request_id FOR UPDATE;
 IF v_employee.status='cancelled' OR p_effective_from < v_employee.hire_date
    OR (v_employee.termination_date IS NOT NULL AND
        (p_effective_to IS NULL OR p_effective_to > v_employee.termination_date)) THEN
  RAISE EXCEPTION 'HISTORY_OUTSIDE_EMPLOYMENT';
 END IF;
 IF NOT EXISTS (
   SELECT 1 FROM employee_code_registry
   WHERE employee_id=p_employee_id AND code_normalized=upper(btrim(v_employee.employee_code))
 ) THEN
  RAISE EXCEPTION 'HISTORY_EMPLOYEE_CODE_NOT_RESERVED';
 END IF;
 IF v_request.effective_date IS DISTINCT FROM p_effective_from
    OR v_request.request_type_id NOT IN (
      SELECT id FROM request_types WHERE target_entity='employee_company_history'
    )
    OR NOT (v_request.company_id=p_company_id OR v_request.target_company_id=p_company_id)
    OR NOT rm_request_has_approval_evidence(p_request_id) THEN
  RAISE EXCEPTION 'HISTORY_APPROVAL_EVIDENCE_REQUIRED';
 END IF;
 INSERT INTO employee_company_history(employee_id,company_id,effective_from,effective_to,source_request_id)
 VALUES (p_employee_id,p_company_id,p_effective_from,p_effective_to,p_request_id)
 RETURNING id INTO v_history_id;
 SET CONSTRAINTS company_history_no_overlap IMMEDIATE;
 RETURN v_history_id;
END $history$;
