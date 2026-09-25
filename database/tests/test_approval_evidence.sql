-- Step 1 approval evidence: rollback-only positive/negative probes.
BEGIN;
INSERT INTO company_groups(group_code,group_name) VALUES ('APP-G','Approval fixture');
INSERT INTO companies(company_group_id,company_code,company_name)
SELECT id,'APP-C','Approval fixture' FROM company_groups WHERE group_code='APP-G';
INSERT INTO users(username,display_name) VALUES
 ('app-requester','Requester'),('app-reviewer-1','Reviewer 1'),('app-reviewer-2','Reviewer 2');
INSERT INTO request_types(request_type_code,request_type_name,target_entity)
VALUES ('APP-HISTORY','History change','employee_company_history');
INSERT INTO approval_workflows(request_type_id,workflow_name,workflow_version,effective_from,status)
SELECT id,'Approval test',1,DATE '2026-01-01','active'
FROM request_types WHERE request_type_code='APP-HISTORY';
INSERT INTO approval_steps(workflow_id,step_order,step_name,approver_user_id,approval_scope)
SELECT w.id,v.n,'Review '||v.n,u.id,'company'
FROM approval_workflows w CROSS JOIN (VALUES (1,'app-reviewer-1'),(2,'app-reviewer-2')) v(n,username)
JOIN users u ON u.username=v.username WHERE w.workflow_name='Approval test';
INSERT INTO change_requests(request_no,request_type_id,workflow_id,requester_id,company_id,title,status,completed_at)
SELECT 'APP-REQ',t.id,w.id,u.id,c.id,'Approval test','approved',now()
FROM request_types t JOIN approval_workflows w ON w.request_type_id=t.id
CROSS JOIN users u CROSS JOIN companies c
WHERE t.request_type_code='APP-HISTORY' AND u.username='app-requester' AND c.company_code='APP-C';
DO $test$
DECLARE rid uuid; step1 uuid; step2 uuid; reviewer1 uuid; reviewer2 uuid; requester uuid;
BEGIN
 SELECT id INTO rid FROM change_requests WHERE request_no='APP-REQ';
 SELECT id INTO step1 FROM approval_steps WHERE step_name='Review 1' AND workflow_id=(SELECT workflow_id FROM change_requests WHERE id=rid);
 SELECT id INTO step2 FROM approval_steps WHERE step_name='Review 2' AND workflow_id=(SELECT workflow_id FROM change_requests WHERE id=rid);
 SELECT id INTO reviewer1 FROM users WHERE username='app-reviewer-1';
 SELECT id INTO reviewer2 FROM users WHERE username='app-reviewer-2';
 SELECT id INTO requester FROM users WHERE username='app-requester';
 IF rm_request_has_approval_evidence(rid) THEN RAISE EXCEPTION 'APP_STATUS_ONLY_ACCEPTED'; END IF;
 INSERT INTO request_approvals(request_id,approval_step_id,approver_id,decision) VALUES(rid,step1,reviewer1,'approved');
 IF rm_request_has_approval_evidence(rid) THEN RAISE EXCEPTION 'APP_INCOMPLETE_STEPS_ACCEPTED'; END IF;
 INSERT INTO request_approvals(request_id,approval_step_id,approver_id,decision) VALUES(rid,step2,reviewer2,'approved');
 IF NOT rm_request_has_approval_evidence(rid) THEN RAISE EXCEPTION 'APP_VALID_APPROVAL_REJECTED'; END IF;
 UPDATE change_requests SET status='returned' WHERE id=rid;
 IF rm_request_has_approval_evidence(rid) THEN RAISE EXCEPTION 'APP_RETURNED_ACCEPTED'; END IF;
 UPDATE change_requests SET status='approved' WHERE id=rid;
 DELETE FROM request_approvals WHERE request_id=rid AND approval_step_id=step1;
 INSERT INTO request_approvals(request_id,approval_step_id,approver_id,decision)
 VALUES(rid,step1,requester,'approved');
 IF rm_request_has_approval_evidence(rid) THEN RAISE EXCEPTION 'APP_SELF_APPROVAL_ACCEPTED'; END IF;
END $test$;
-- Writer must reject a status-only approval even with valid employee registry.
INSERT INTO employees(employee_code,full_name,home_company_id,hire_date)
SELECT 'APP-EMP','Approval writer fixture',id,DATE '2026-01-01'
FROM companies WHERE company_code='APP-C';
INSERT INTO employee_code_registry(code_normalized,code_original,employee_id,source)
SELECT upper(btrim(employee_code)),employee_code,id,'system'
FROM employees WHERE employee_code='APP-EMP';
UPDATE change_requests SET effective_date=DATE '2026-02-01'
WHERE request_no='APP-REQ';
DO $writer$
DECLARE e uuid; c uuid; rid uuid;
BEGIN
 SELECT id INTO e FROM employees WHERE employee_code='APP-EMP';
 SELECT id INTO c FROM companies WHERE company_code='APP-C';
 SELECT id INTO rid FROM change_requests WHERE request_no='APP-REQ';
 -- Prior DO block leaves only a self-approval for step 1.
 BEGIN
  PERFORM rm_insert_approved_company_history(e,c,DATE '2026-02-01',NULL,rid);
  RAISE EXCEPTION 'WRITER_UNAUTHORIZED_REQUEST_ACCEPTED';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'HISTORY_APPROVAL_EVIDENCE_REQUIRED' THEN RAISE; END IF;
 END;
 IF EXISTS (SELECT 1 FROM employee_company_history WHERE employee_id=e) THEN
  RAISE EXCEPTION 'WRITER_UNAUTHORIZED_HISTORY_PERSISTED';
 END IF;
 -- A matching approved request cannot bypass the employee-code registry.
 DELETE FROM request_approvals WHERE request_id=rid;
 INSERT INTO request_approvals(request_id,approval_step_id,approver_id,decision)
 SELECT rid,s.id,u.id,'approved' FROM approval_steps s
 JOIN users u ON u.username=CASE s.step_order WHEN 1 THEN 'app-reviewer-1' ELSE 'app-reviewer-2' END
 WHERE s.workflow_id=(SELECT workflow_id FROM change_requests WHERE id=rid);
 IF NOT rm_request_has_approval_evidence(rid) THEN
  RAISE EXCEPTION 'WRITER_FIXTURE_APPROVAL_INVALID';
 END IF;
 BEGIN
  PERFORM rm_insert_approved_company_history(e,c,DATE '2026-02-02',NULL,rid);
  RAISE EXCEPTION 'WRITER_WRONG_EFFECTIVE_DATE_ACCEPTED';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'HISTORY_APPROVAL_EVIDENCE_REQUIRED' THEN RAISE; END IF;
 END;
 -- A valid request must produce exactly one history row.
 PERFORM rm_insert_approved_company_history(e,c,DATE '2026-02-01',NULL,rid);
 IF (SELECT count(*) FROM employee_company_history WHERE employee_id=e) <> 1 THEN
  RAISE EXCEPTION 'WRITER_VALID_INSERT_MISSING';
 END IF;
END $writer$;
ROLLBACK;
SELECT 'PASS: approval evidence and history writer positive and negative probes' AS result;
