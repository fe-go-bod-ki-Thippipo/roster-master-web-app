-- Step 0 ledger replay and checksum mutation negative tests.
DO $test$
DECLARE old_checksum text;
BEGIN
 SELECT checksum_sha256 INTO old_checksum FROM public.schema_migration_ledger WHERE version='001';
 IF old_checksum IS NULL THEN RAISE EXCEPTION 'Baseline ledger entry missing'; END IF;
 BEGIN
  INSERT INTO public.schema_migration_ledger(version,checksum_sha256) VALUES ('001',old_checksum);
  RAISE EXCEPTION 'Expected duplicate migration version rejection';
 EXCEPTION WHEN unique_violation THEN NULL;
 END;
 BEGIN
  UPDATE public.schema_migration_ledger SET checksum_sha256=repeat('0',64) WHERE version='001';
  RAISE EXCEPTION 'Expected immutable ledger rejection';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Expected immutable ledger rejection' THEN RAISE; END IF;
 END;
 BEGIN
  DELETE FROM public.schema_migration_ledger WHERE version='001';
  RAISE EXCEPTION 'Expected ledger delete rejection';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Expected ledger delete rejection' THEN RAISE; END IF;
 END;
END $test$;
