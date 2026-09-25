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
ROLLBACK;
SELECT 'PASS: approval evidence positive and negative probes' AS result;
