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
CREATE FUNCTION rm_business_date(p_at timestamptz DEFAULT now()) RETURNS date
 LANGUAGE sql STABLE AS $$ SELECT (p_at AT TIME ZONE 'Asia/Bangkok')::date $$;
COMMIT;
