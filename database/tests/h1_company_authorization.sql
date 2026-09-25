-- B6-prime isolated fixture; caller owns BEGIN/ROLLBACK.
INSERT INTO company_groups(group_code,group_name) VALUES ('H1-G','H1 isolated fixture');
INSERT INTO companies(company_group_id,company_code,company_name)
SELECT id,v.code,v.name FROM company_groups CROSS JOIN (VALUES ('H1-A','Source company'),('H1-B','Destination company')) v(code,name) WHERE group_code='H1-G';
INSERT INTO users(username,display_name) VALUES ('h1-requester','H1 requester'),('h1-approver','H1 approver');
INSERT INTO request_types(request_type_code,request_type_name,target_entity)
VALUES ('H1-HISTORY','H1 company history','employee_company_history');
INSERT INTO approval_workflows(request_type_id,workflow_name,workflow_version,effective_from,status)
SELECT id,'H1 workflow',1,DATE '2026-01-01','active' FROM request_types WHERE request_type_code='H1-HISTORY';
INSERT INTO approval_steps(workflow_id,step_order,step_name,approver_user_id,approval_scope)
SELECT w.id,1,'H1 review',u.id,'company' FROM approval_workflows w CROSS JOIN users u
WHERE w.workflow_name='H1 workflow' AND u.username='h1-approver';
INSERT INTO change_requests(request_no,request_type_id,workflow_id,requester_id,company_id,title,status,completed_at,effective_date)
SELECT 'H1-REQ',t.id,w.id,u.id,c.id,'H1 isolated request','approved',now(),DATE '2026-02-01'
FROM request_types t JOIN approval_workflows w ON w.request_type_id=t.id
CROSS JOIN users u CROSS JOIN companies c
WHERE t.request_type_code='H1-HISTORY' AND u.username='h1-requester' AND c.company_code='H1-A';
INSERT INTO request_approvals(request_id,approval_step_id,approver_id,decision)
SELECT r.id,s.id,u.id,'approved' FROM change_requests r
JOIN approval_steps s ON s.workflow_id=r.workflow_id JOIN users u ON u.id=s.approver_user_id
WHERE r.request_no='H1-REQ';
INSERT INTO employees(employee_code,full_name,home_company_id,hire_date)
SELECT 'H1-EMP','H1 isolated employee',id,DATE '2026-01-01' FROM companies WHERE company_code='H1-A';
INSERT INTO employee_code_registry(code_normalized,code_original,employee_id,source)
SELECT upper(btrim(employee_code)),employee_code,id,'system' FROM employees WHERE employee_code='H1-EMP';
DO $b6$
DECLARE e uuid; company_b uuid; rid uuid;
BEGIN
 SELECT id INTO e FROM employees WHERE employee_code='H1-EMP';
 SELECT id INTO company_b FROM companies WHERE company_code='H1-B';
 SELECT id INTO rid FROM change_requests WHERE request_no='H1-REQ';
 IF e IS NULL OR company_b IS NULL OR rid IS NULL
    OR NOT rm_request_has_approval_evidence(rid)
    OR EXISTS (SELECT 1 FROM employee_company_history WHERE employee_id=e)
    OR (SELECT target_company_id IS NOT NULL FROM change_requests WHERE id=rid) THEN
  RAISE EXCEPTION 'B6_PRIME_FIXTURE_INVALID';
 END IF;
 BEGIN
  PERFORM rm_insert_approved_company_history(e,company_b,DATE '2026-02-01',NULL,rid);
  RAISE EXCEPTION 'B6_PRIME_WRONG_COMPANY_ACCEPTED';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'HISTORY_COMPANY_NOT_AUTHORIZED' THEN RAISE; END IF;
 END;
 IF EXISTS (SELECT 1 FROM employee_company_history WHERE employee_id=e AND company_id=company_b) THEN
  RAISE EXCEPTION 'B6_PRIME_UNAUTHORIZED_HISTORY_PERSISTED';
 END IF;
END $b6$;
SELECT 'PASS: B6-prime isolated company authorization' AS result;
