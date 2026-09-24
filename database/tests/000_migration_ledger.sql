-- Step 0: test-runner ledger, not an application/legacy import table.
CREATE TABLE IF NOT EXISTS public.schema_migration_ledger (
 version text PRIMARY KEY,
 checksum_sha256 text NOT NULL CHECK (checksum_sha256 ~ '^[0-9a-f]{64}$'),
 applied_at timestamptz NOT NULL DEFAULT now(),
 CHECK (version ~ '^[0-9]{3}[a-z0-9_-]*$')
);
REVOKE ALL ON public.schema_migration_ledger FROM PUBLIC;
CREATE OR REPLACE FUNCTION public.rm_ledger_immutable() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $fn$
BEGIN
 RAISE EXCEPTION 'Migration ledger entries are immutable';
END $fn$;
CREATE TRIGGER schema_migration_ledger_immutable BEFORE UPDATE OR DELETE ON public.schema_migration_ledger FOR EACH ROW EXECUTE FUNCTION public.rm_ledger_immutable();
