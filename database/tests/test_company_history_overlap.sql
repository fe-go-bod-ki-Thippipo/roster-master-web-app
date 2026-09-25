-- N-04: behavioral exclusion checks; all fixture writes are rolled back.
BEGIN;
INSERT INTO company_groups(group_code,group_name) VALUES ('N04-G','N04 fixture');
INSERT INTO companies(company_group_id,company_code,company_name)
SELECT id,'N04-C','N04 company' FROM company_groups WHERE group_code='N04-G';
INSERT INTO employees(employee_code,full_name,home_company_id,hire_date)
SELECT 'N04-EMP','N04 fixture',id,DATE '2026-01-01' FROM companies WHERE company_code='N04-C';
INSERT INTO migration_batches(source_checksum,source_file_name)
VALUES (repeat('a',64),'n04-fixture');
INSERT INTO employee_company_history(employee_id,company_id,effective_from,effective_to,migration_batch_id)
SELECT e.id,c.id,DATE '2026-01-01',DATE '2026-01-31',m.id
FROM employees e CROSS JOIN companies c CROSS JOIN migration_batches m
WHERE e.employee_code='N04-EMP' AND c.company_code='N04-C' AND m.source_file_name='n04-fixture';
-- An adjacent period must be permitted.
INSERT INTO employee_company_history(employee_id,company_id,effective_from,effective_to,migration_batch_id)
SELECT e.id,c.id,DATE '2026-02-01',DATE '2026-02-28',m.id
FROM employees e CROSS JOIN companies c CROSS JOIN migration_batches m
WHERE e.employee_code='N04-EMP' AND c.company_code='N04-C' AND m.source_file_name='n04-fixture';
SET CONSTRAINTS company_history_no_overlap IMMEDIATE;
DO $test$
DECLARE e uuid; c uuid; m uuid;
BEGIN
 SELECT id INTO e FROM employees WHERE employee_code='N04-EMP';
 SELECT id INTO c FROM companies WHERE company_code='N04-C';
 SELECT id INTO m FROM migration_batches WHERE source_file_name='n04-fixture';
 BEGIN
  INSERT INTO employee_company_history(employee_id,company_id,effective_from,effective_to,migration_batch_id)
  VALUES(e,c,DATE '2026-01-31',DATE '2026-02-05',m);
  RAISE EXCEPTION 'N04_OVERLAP_ACCEPTED';
 EXCEPTION WHEN exclusion_violation THEN NULL;
 END;
 IF (SELECT count(*) FROM employee_company_history WHERE employee_id=e) <> 2 THEN
  RAISE EXCEPTION 'N04_UNEXPECTED_HISTORY_ROWS';
 END IF;
END $test$;
-- Superseding the first period removes it from the active exclusion set.
INSERT INTO users(username,display_name) VALUES ('n04-reviewer','N04 reviewer');
INSERT INTO request_types(request_type_code,request_type_name,target_entity)
VALUES ('N04-REQUEST','N04 fixture','employee_company_history');
INSERT INTO approval_workflows(request_type_id,workflow_name,workflow_version,effective_from)
SELECT id,'N04 workflow',1,DATE '2026-01-01' FROM request_types WHERE request_type_code='N04-REQUEST';
INSERT INTO change_requests(request_no,request_type_id,workflow_id,requester_id,company_id,title)
SELECT 'N04-CHANGE',t.id,w.id,u.id,c.id,'N04 fixture'
FROM request_types t JOIN approval_workflows w ON w.request_type_id=t.id
CROSS JOIN users u CROSS JOIN companies c
WHERE t.request_type_code='N04-REQUEST' AND u.username='n04-reviewer' AND c.company_code='N04-C';
UPDATE employee_company_history h
SET superseded_by_request_id=(SELECT id FROM change_requests WHERE request_no='N04-CHANGE'),
    superseded_at=now()
FROM employees e
WHERE h.employee_id=e.id AND e.employee_code='N04-EMP'
  AND h.effective_from=DATE '2026-01-01';
INSERT INTO employee_company_history(employee_id,company_id,effective_from,effective_to,migration_batch_id)
SELECT e.id,c.id,DATE '2026-01-15',DATE '2026-01-31',m.id
FROM employees e CROSS JOIN companies c CROSS JOIN migration_batches m
WHERE e.employee_code='N04-EMP' AND c.company_code='N04-C' AND m.source_file_name='n04-fixture';
SET CONSTRAINTS company_history_no_overlap IMMEDIATE;
DO $test$
BEGIN
 IF (SELECT count(*) FROM employee_company_history h JOIN employees e ON e.id=h.employee_id
     WHERE e.employee_code='N04-EMP' AND h.superseded_by_request_id IS NULL) <> 2 THEN
   RAISE EXCEPTION 'N04_SUPERSEDE_ACTIVE_SET_INCORRECT';
 END IF;
END $test$;
ROLLBACK;
SELECT 'PASS: N-04 adjacent periods accepted; overlapping periods rejected; superseded periods excluded' AS n04_result;
