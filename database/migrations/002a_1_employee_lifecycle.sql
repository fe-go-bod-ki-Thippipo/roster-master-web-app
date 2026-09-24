-- Roster Master 002a-1 / initial incremental implementation (NOT READY TO APPLY)
-- This migration is deliberately a draft: history writer, coverage constraints,
-- assignment concurrency guards, projection reconciliation and role grants are pending.
-- DO NOT DEPLOY or merge until complete PostgreSQL acceptance tests pass.
BEGIN;
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
CREATE FUNCTION rm_registry_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 RAISE EXCEPTION 'Employee code reservations are immutable';
END $$;
CREATE TRIGGER registry_no_update BEFORE UPDATE ON employee_code_registry FOR EACH ROW EXECUTE FUNCTION rm_registry_immutable();
CREATE TRIGGER registry_no_delete BEFORE DELETE ON employee_code_registry FOR EACH ROW EXECUTE FUNCTION rm_registry_immutable();
CREATE TRIGGER registry_no_truncate BEFORE TRUNCATE ON employee_code_registry FOR EACH STATEMENT EXECUTE FUNCTION rm_registry_immutable();
CREATE FUNCTION rm_employee_code_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.employee_code IS DISTINCT FROM OLD.employee_code THEN
  RAISE EXCEPTION 'Employee code cannot be changed';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER employee_code_immutable BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION rm_employee_code_immutable();
CREATE FUNCTION rm_no_destructive_dml() RETURNS trigger LANGUAGE plpgsql AS $$
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
ALTER TABLE employees ADD CONSTRAINT employees_status_check CHECK (status IN ('active','inactive','terminated','cancelled'));
ALTER TABLE employees ADD CONSTRAINT employees_employment_dates CHECK (termination_date IS NULL OR hire_date IS NULL OR termination_date >= hire_date);
-- New history is versioned; baseline exclusion must be replaced to exclude superseded versions.
ALTER TABLE employee_company_history ADD COLUMN superseded_by_request_id uuid REFERENCES change_requests(id);
ALTER TABLE employee_company_history ADD COLUMN superseded_at timestamptz;
ALTER TABLE employee_company_history ADD COLUMN migration_batch_id uuid REFERENCES migration_batches(id);
ALTER TABLE employee_company_history ADD CONSTRAINT company_history_supersede_pair CHECK ((superseded_by_request_id IS NULL) = (superseded_at IS NULL));
ALTER TABLE employee_company_history ADD CONSTRAINT company_history_source_xor CHECK ((source_request_id IS NOT NULL) <> (migration_batch_id IS NOT NULL));
ALTER TABLE employee_company_history DROP CONSTRAINT employee_company_history_employee_id_daterange_excl;
ALTER TABLE employee_company_history ADD CONSTRAINT company_history_no_overlap
 EXCLUDE USING gist (employee_id WITH =, daterange(effective_from,COALESCE(effective_to + 1,'infinity'::date),'[)') WITH &&)
 WHERE (superseded_by_request_id IS NULL) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX company_history_effective_lookup ON employee_company_history(employee_id,effective_from,effective_to) WHERE superseded_by_request_id IS NULL;
-- Registry is seeded from baseline employee codes before new writes.
INSERT INTO employee_code_registry(code_normalized,code_original,employee_id,source,reserved_at)
 SELECT upper(btrim(employee_code)),employee_code,id,'system',created_at FROM employees;
-- Baseline rows have no source_request_id; they require a migration batch provenance
-- only after historical data reconciliation. Do not enforce full coverage until then.
CREATE FUNCTION rm_business_date(p_at timestamptz DEFAULT now()) RETURNS date
 LANGUAGE sql STABLE AS $$ SELECT (p_at AT TIME ZONE 'Asia/Bangkok')::date $$;
COMMIT;
