# Roster Master — Data Dictionary (R2.1 design)
Source of CURRENT columns: `database/migrations/001_schema.sql` on branch `docs/batch-2-1-foundation`. Types and constraints below describe baseline, not deployed behavior. Every table has UUID `id` PK unless noted. Arrow indicates FK. Proposed columns/tables are clearly labeled and NOT in SQL.

## Organization / reference
| Table | Current columns (type abbreviated; required = !) | Keys / integrity |
|---|---|---|
| company_groups | id uuid!, group_code text!, group_name text!, status text! | PK id; UNIQUE group_code; status active/inactive |
| companies | id uuid!, company_group_id uuid?, company_code text!, company_name text!, legal_name text?, tax_id text?, status text! | PK id; FK group -> company_groups; UNIQUE company_code |
| divisions | id uuid!, company_id uuid!, division_code text!, division_name text!, status text! | PK id; FK company; UNIQUE(company_id,division_code), UNIQUE(id,company_id) |
| sections | id uuid!, division_id uuid!, section_code text!, section_name text!, status text! | PK id; FK division; UNIQUE(division_id,section_code), UNIQUE(id,division_id) |
| departments | id uuid!, division_id uuid!, section_id uuid?, department_code text!, department_name text!, status text! | PK id; FK division; composite FK(section_id,division_id) -> sections(id,division_id); UNIQUE department_code, UNIQUE(id,division_id) |
| employment_types | id uuid!, type_code text!, type_name text!, status text! | PK id; UNIQUE type_code |
| nationalities | id uuid!, nationality_code text!, nationality_name text!, status text! | PK id; UNIQUE nationality_code |
| education_levels | id uuid!, education_code text!, education_name text!, sort_order int!, status text! | PK id; UNIQUE education_code |

## People / workforce
| Table | Current columns | Keys / integrity |
|---|---|---|
| employees | id uuid!, employee_code text!, full_name text!, nickname text?, employment_type_id uuid?, home_company_id uuid!, hire_date date?, probation_end_date date?, termination_date date?, termination_reason text?, status text!, created_at timestamptz!, updated_at timestamptz!, row_version int! | PK id; UNIQUE employee_code; FK employment_type and home_company; row_version > 0 |
| employee_profiles | employee_id uuid!, prefix text?, gender text?, birth_date date?, national_id_encrypted bytea?, national_id_lookup_hash bytea?, nationality_id uuid?, education_level_id uuid?, phone text?, email text?, address text?, emergency_contact_name text?, emergency_contact_phone text? | PK/FK employee_id; UNIQUE national_id_lookup_hash; FK nationality, education |
| positions | id uuid!, position_code text!, position_name text!, department_id uuid!, employment_type_id uuid?, grade smallint?, target_fte fte_amount!, parent_position_id uuid?, org_order int?, org_offset numeric(10,2)?, status text!, row_version int! | PK id; UNIQUE position_code; FK department, employment_type, self parent; grade 1..8; parent != self |
| employee_company_history | id uuid!, employee_id uuid!, company_id uuid!, effective_from date!, effective_to date?, source_request_id uuid? | PK id; FK employee, company, request; exclusion prevents overlapping history per employee; inclusive end date |
| employee_assignments | id uuid!, employee_id uuid!, position_id uuid!, assignment_type text!, assignment_fte fte_amount!, effective_from date!, effective_to date?, status text!, source_request_id uuid? | PK id; FK employee, position, request; FTE > 0; overlapping primary assignments excluded; NO aggregate <=1 enforcement yet |
| position_fte_history | id uuid!, position_id uuid!, target_fte fte_amount!, effective_from date!, effective_to date?, source_request_id uuid?, approved_at timestamptz? | PK id; FK position/request; nonoverlapping date ranges per position; current positions.target_fte NOT synchronized |
| users | id uuid!, auth_user_id uuid?, username text!, email text?, display_name text!, status text!, last_login_at timestamptz?, employee_id uuid? | PK id; UNIQUE auth_user_id, username, email, employee_id; FK employee |
| roles | id uuid!, role_code text!, role_name text!, description text?, status text! | PK id; UNIQUE role_code |
| permissions | id uuid!, permission_code text!, resource text!, action text!, description text? | PK id; UNIQUE permission_code |
| role_permissions | role_id uuid!, permission_id uuid! | Composite PK(role_id,permission_id), both FKs |
| user_role_assignments | id uuid!, user_id uuid!, role_id uuid!, scope_type text!, company_id uuid?, division_id uuid?, department_id uuid?, valid_from timestamptz!, valid_to timestamptz?, status text! | PK id; FKs user/role/company/division/department; exactly one target for noncentral scope |

## Requests / approvals
| Table | Current columns | Keys / integrity |
|---|---|---|
| request_types | id uuid!, request_type_code text!, request_type_name text!, target_entity text!, requires_attachment boolean!, requires_approval boolean!, status text! | PK id; UNIQUE request_type_code |
| approval_workflows | id uuid!, request_type_id uuid!, workflow_name text!, workflow_version int!, company_id uuid?, effective_from date!, effective_to date?, status text! | PK id; FK type/company; UNIQUE(id,request_type_id); overlapping active versions NOT excluded |
| approval_steps | id uuid!, workflow_id uuid!, step_order int!, step_name text!, approver_role_id uuid?, approver_user_id uuid?, approval_scope text!, required_approvals int!, allow_self_approval boolean! | PK id; FK workflow/role/user; UNIQUE(workflow_id,step_order), UNIQUE(id,workflow_id) |
| change_requests | id uuid!, request_no text!, request_type_id uuid!, workflow_id uuid!, requester_id uuid!, company_id uuid!, target_company_id uuid?, title text!, reason text?, status text!, current_step_order int?, submitted_at timestamptz?, completed_at timestamptz?, effective_date date?, row_version int! | PK id; UNIQUE request_no; composite FK(workflow_id,request_type_id) -> approval_workflows; UNIQUE(id,workflow_id) |
| request_changes | id uuid!, request_id uuid!, entity_type text!, entity_id uuid?, operation text!, before_data jsonb?, proposed_data jsonb!, expected_row_version int? | PK id; FK request; create requires null entity_id; update/deactivate require entity_id/version |
| request_approvals | id uuid!, request_id uuid!, approval_step_id uuid!, approver_id uuid!, review_round int!, decision text!, comment text?, decided_at timestamptz! | PK id; FKs request/step/approver; UNIQUE(request_id,approval_step_id,approver_id,review_round); cross-workflow step still possible |
| request_attachments | id uuid!, request_id uuid!, file_name text!, storage_key text!, mime_type text!, file_size bigint!, checksum_sha256 char(64)!, uploaded_by uuid!, uploaded_at timestamptz! | PK id; FK request/uploader; UNIQUE storage_key |

## Audit / migration
| Table | Current columns | Keys / integrity |
|---|---|---|
| audit_logs | id uuid!, actor_user_id uuid?, action text!, entity_type text!, entity_id uuid?, company_id uuid?, request_id uuid?, changed_fields jsonb?, occurred_at timestamptz! | PK id; FKs actor/company/request; append-only NOT enforced yet |
| migration_batches | id uuid!, source_version text?, source_checksum char(64)!, source_file_name text!, imported_by uuid?, imported_at timestamptz?, status text!, total_records int?, success_records int?, error_records int? | PK id; UNIQUE source_checksum; FK importer |
| legacy_id_mappings | id uuid!, migration_batch_id uuid!, entity_type text!, legacy_id text!, legacy_scope text!, new_id uuid!, mapping_status text! | PK id; FK batch; UNIQUE(batch,entity_type,legacy_scope,legacy_id) |
| migration_issues | id uuid!, migration_batch_id uuid!, entity_type text!, source_record_key text?, issue_code text!, issue_detail text!, source_data jsonb?, resolution_status text!, resolved_by uuid?, resolved_at timestamptz? | PK id; FK batch/resolver |

## R2 proposed logical additions / changes — NOT PRESENT in baseline
| Entity | Proposed change | Required enforcement / review |
|---|---|---|
| employee_assignments | Aggregate employee FTE across all concurrent intervals and companies; exclude cancelled | Transactional serialization by employee + interval-aware sum; reject >1.0000; reject duplicate employee-position overlapping effective periods |
| employee_company_history / employees | Make effective-dated history authoritative; derive current home company or enforce atomic synchronization | Prevent overlapping intervals within an employment; gaps after termination are valid; reconcile home_company_id and derive its current value from history |
| positions / position_fte_history | Make approved effective-dated FTE history authoritative; avoid two editable sources | As-of queries, baseline initialization, no unapproved history |
| position_reporting_lines (NEW) | id uuid PK, position_id uuid FK, supervisor_position_id uuid FK, effective_from date, effective_to date?, approval_request_id uuid FK, status text | No self-reference, cycles or overlapping primary supervisors; cross-company edge only with approved request; one PRIMARY supervisor at a time; additional COORDINATION lines permitted; both company approvals required for cross-company edges |
| organization ownership history (NEW; detailed below) | Effective-dated position/department/division company lineage | Use versioned division/section/department/position edges and names as-of date; prevent overlapping ownership and preserve approved backdated corrections |
| request_approvals / change_requests | Match approval step to request workflow; explicit review round, scheduled/applied/failed states | Composite FK or equivalent; immutable active workflow version; exactly-once apply |
| user_role_assignments and company-scoped tables | Runtime identity and RLS policies | No direct database client access; separate sensitive profile permission; cross-company assignment visibility must be scoped |
| reports (logical views/API; not persisted table) | home-company view vs position-owner view, as_of date, distinct HC, approved/actual FTE and gap | Distinguish home-company HC vs assignment-company distinct HC; never add overlapping HC slices |

## FTE definitions
`fte_amount` is currently a DOMAIN on numeric(10,4) with VALUE >= 0. `assignment_fte` additionally requires > 0. Proposed: sum all non-cancelled effective assignment fractions for one employee at every affected date <= 1.0000. Approved FTE as-of date = effective position_fte_history; actual FTE as-of date = sum effective assignments; gap = approved - actual. Home-company attribution must use effective company history, NOT current employees.home_company_id for historical dates.

## Revision 3 — proposed physical history entities (NOT PRESENT IN 001)
| Table | Proposed columns | Rules |
|---|---|---|
| division_history | id uuid PK, division_id uuid FK, company_id uuid FK, division_name text, effective_from date, effective_to date NULL, source_request_id uuid NULL | nonoverlap per division; approved changes only |
| section_history | id uuid PK, section_id uuid FK, division_id uuid FK, section_name text, effective_from date, effective_to date NULL, source_request_id uuid NULL | nonoverlap per section; referenced division effective for entire interval |
| department_history | id uuid PK, department_id uuid FK, division_id uuid FK, section_id uuid NULL FK, department_name text, effective_from date, effective_to date NULL, source_request_id uuid NULL | nonoverlap per department; optional section must share division at each effective date |
| position_history | id uuid PK, position_id uuid FK, department_id uuid FK, position_name text, effective_from date, effective_to date NULL, source_request_id uuid NULL | nonoverlap per position; owner company as-of D resolved through position_history -> department_history -> division_history |
| position_reporting_lines | id uuid PK, position_id uuid FK, supervisor_position_id uuid FK, line_type text PRIMARY/COORDINATION, effective_from date, effective_to date NULL, approval_request_id uuid NULL FK, migration_batch_id uuid NULL FK, status text | exactly one PRIMARY at a time; additional COORDINATION allowed; migrated rows may cite batch instead of approval; new cross-company edges require approved request and approvers of both companies; reject self-reference and effective-dated primary cycles |

Legacy `employees.home_company_id`, `positions.target_fte`, `positions.parent_position_id` and organization master name/parent columns are proposed read-only current projections of their effective-dated history, not independent sources of truth. Existing SQL does NOT enforce these proposals. Initial history rows must be created only from audited legacy records; never invent missing historical names, owners, or approval timestamps.

## Revision 3 — integrity, reporting and security design
- Employee identity: continuous company transfer retains UUID/code; rehire after termination creates NEW UUID/code. No duplicate employee-position assignments for overlapping dates, including secondary assignments; total concurrent assignment FTE <=1.0000 across companies.
- Approval: configure approvers by request type and multiple steps; cross-company reporting requires authorized approvers of both affected companies. Ensure workflow/company/type matches, approver authorization, review-round uniqueness, self-approval restrictions, immutable active versions and idempotent apply.
- Company access: position-owning company may view cross-company assignee employee code, name, position and assigned FTE only. Other profile fields require independent authorization; enforce via backend and database RLS/column-safe projections. Cross-company reporting-line links do not grant profile access.
- Reports: see `DECISIONS.md` Metric × company-view contract and fixture. Historical names and company lineage are resolved AS OF D. Home-company HC includes active employees without assignments; unassigned HC is separate. Numeric unallocated FTE formula remains open.
- Proposed trigger design: serialize by employee and validate total FTE over every affected interval at transaction end; deferred check must cover INSERT, UPDATE and DELETE including employee_id, date, status and FTE changes. Validate status 'ended' has effective_to. Reporting-line graph changes must serialize and validate cycles across overlapping effective periods.
- Baseline enums/defaults: consult `001_schema.sql` for authoritative current CHECK and DEFAULT expressions until full column-level transcription is added. Do not treat proposed `scheduled`, `applying`, `apply_failed` statuses as already permitted by current SQL.
