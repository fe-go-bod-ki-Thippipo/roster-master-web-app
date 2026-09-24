-- Step 0: test-runner ledger, not an application/legacy import table.
CREATE TABLE IF NOT EXISTS public.schema_migration_ledger (
 version text PRIMARY KEY,
 checksum_sha256 text NOT NULL CHECK (checksum_sha256 ~ '^[0-9a-f]{64}$'),
 applied_at timestamptz NOT NULL DEFAULT now(),
 CHECK (version ~ '^[0-9]{3}[a-z0-9_-]*$')
);
REVOKE ALL ON public.schema_migration_ledger FROM PUBLIC;
