# Roster Master — ER Diagram (R2.1)
Source: baseline `001_schema.sql`; dotted/proposed logical entities described separately. Mermaid represents relationships, not executable SQL or a claim of implemented constraints.

## Existing organization and workforce
```mermaid
erDiagram
 COMPANY_GROUPS o|--o{ COMPANIES : groups
 COMPANIES ||--o{ DIVISIONS : owns
 DIVISIONS ||--o{ SECTIONS : contains
 DIVISIONS ||--o{ DEPARTMENTS : requires
 SECTIONS o|--o{ DEPARTMENTS : optional_section
 DEPARTMENTS ||--o{ POSITIONS : owns
 POSITIONS o|--o{ POSITIONS : current_parent
 COMPANIES ||--o{ EMPLOYEES : current_home
 EMPLOYMENT_TYPES o|--o{ EMPLOYEES : classifies
 EMPLOYMENT_TYPES o|--o{ POSITIONS : classifies
 EMPLOYEES ||--o| EMPLOYEE_PROFILES : profile
 NATIONALITIES o|--o{ EMPLOYEE_PROFILES : nationality
 EDUCATION_LEVELS o|--o{ EMPLOYEE_PROFILES : education
 EMPLOYEES ||--o{ EMPLOYEE_COMPANY_HISTORY : historical_home
 COMPANIES ||--o{ EMPLOYEE_COMPANY_HISTORY : employs
 EMPLOYEES ||--o{ EMPLOYEE_ASSIGNMENTS : works
 POSITIONS ||--o{ EMPLOYEE_ASSIGNMENTS : staffed
 POSITIONS ||--o{ POSITION_FTE_HISTORY : approved_fte
```

## Existing access, approvals, audit and migration
```mermaid
erDiagram
 EMPLOYEES o|--o| USERS : account
 USERS ||--o{ USER_ROLE_ASSIGNMENTS : has
 ROLES ||--o{ USER_ROLE_ASSIGNMENTS : assigned
 ROLES ||--o{ ROLE_PERMISSIONS : grants
 PERMISSIONS ||--o{ ROLE_PERMISSIONS : assigned
 REQUEST_TYPES ||--o{ APPROVAL_WORKFLOWS : defines
 COMPANIES o|--o{ APPROVAL_WORKFLOWS : override
 APPROVAL_WORKFLOWS ||--o{ APPROVAL_STEPS : includes
 REQUEST_TYPES ||--o{ CHANGE_REQUESTS : type
 APPROVAL_WORKFLOWS ||--o{ CHANGE_REQUESTS : selected
 USERS ||--o{ CHANGE_REQUESTS : submits
 COMPANIES ||--o{ CHANGE_REQUESTS : origin
 CHANGE_REQUESTS ||--o{ REQUEST_CHANGES : proposes
 CHANGE_REQUESTS ||--o{ REQUEST_APPROVALS : decisions
 APPROVAL_STEPS ||--o{ REQUEST_APPROVALS : step
 USERS ||--o{ REQUEST_APPROVALS : approver
 CHANGE_REQUESTS ||--o{ REQUEST_ATTACHMENTS : attachments
 USERS ||--o{ AUDIT_LOGS : actor
 CHANGE_REQUESTS o|--o{ AUDIT_LOGS : trace
 MIGRATION_BATCHES ||--o{ LEGACY_ID_MAPPINGS : maps
 MIGRATION_BATCHES ||--o{ MIGRATION_ISSUES : flags
```

## Proposed R2 logical relationship (NOT IN BASELINE SQL)
```mermaid
erDiagram
 POSITIONS ||--o{ POSITION_REPORTING_LINES : subordinate
 POSITIONS ||--o{ POSITION_REPORTING_LINES : supervisor
 CHANGE_REQUESTS o|--o{ POSITION_REPORTING_LINES : authorizes_new_edges
 MIGRATION_BATCHES o|--o{ POSITION_REPORTING_LINES : legacy_source
 DIVISIONS ||--o{ DIVISION_HISTORY : versions
 COMPANIES ||--o{ DIVISION_HISTORY : owner_as_of
 SECTIONS ||--o{ SECTION_HISTORY : versions
 DIVISIONS ||--o{ SECTION_HISTORY : division_as_of
 DEPARTMENTS ||--o{ DEPARTMENT_HISTORY : versions
 DIVISIONS ||--o{ DEPARTMENT_HISTORY : division_as_of
 SECTIONS o|--o{ DEPARTMENT_HISTORY : optional_section_as_of
 POSITIONS ||--o{ POSITION_HISTORY : versions
 DEPARTMENTS ||--o{ POSITION_HISTORY : department_as_of
```

Notes: `ORGANIZATION_OWNERSHIP_HISTORY` is a conceptual placeholder; physical normalization (division/department/position effective-dated edges) remains to be decided. `POSITION_REPORTING_LINES` replaces relying solely on current `positions.parent_position_id` for historical cross-company reporting. Approval-step membership, RLS, cycle prevention, aggregate FTE and effective-date integrity are NOT guaranteed by the diagram or baseline SQL. Reporting has separate employee-home and position-owner dimensions and must use historical company lineage for as-of queries.

## Revision 3 — remaining baseline FK edges (supplement to current diagrams)
```mermaid
erDiagram
 CHANGE_REQUESTS o|--o{ EMPLOYEE_ASSIGNMENTS : source_request
 CHANGE_REQUESTS o|--o{ EMPLOYEE_COMPANY_HISTORY : source_request
 CHANGE_REQUESTS o|--o{ POSITION_FTE_HISTORY : source_request
 COMPANIES o|--o{ CHANGE_REQUESTS : target_company
 COMPANIES o|--o{ USER_ROLE_ASSIGNMENTS : company_scope
 DIVISIONS o|--o{ USER_ROLE_ASSIGNMENTS : division_scope
 DEPARTMENTS o|--o{ USER_ROLE_ASSIGNMENTS : department_scope
 ROLES o|--o{ APPROVAL_STEPS : approver_role
 USERS o|--o{ APPROVAL_STEPS : approver_user
 COMPANIES o|--o{ AUDIT_LOGS : company
 USERS ||--o{ REQUEST_ATTACHMENTS : uploaded_by
 USERS o|--o{ MIGRATION_BATCHES : imported_by
 USERS o|--o{ MIGRATION_ISSUES : resolved_by
```

All 13 above are EXISTING FK edges omitted from earlier diagrams, not new constraints. Polymorphic references `request_changes.entity_id`, `legacy_id_mappings.new_id` and `audit_logs.entity_id` do not have database FK constraints. Composite FKs (department section/division and change-request workflow/type) are not fully expressible as Mermaid edges; refer to SQL. Proposed effective-dated version edges and `position_reporting_lines` do not exist in 001. For current chart `positions.parent_position_id` remains a baseline column; in R2 it is proposed as read-only derived current PRIMARY supervisor from approved reporting-line history. Historical organization names are drawn from versioned entities at report date.
