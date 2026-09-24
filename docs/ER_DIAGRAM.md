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
 CHANGE_REQUESTS ||--o{ POSITION_REPORTING_LINES : authorizes
 POSITIONS ||--o{ ORGANIZATION_OWNERSHIP_HISTORY : as_of_owner
 COMPANIES ||--o{ ORGANIZATION_OWNERSHIP_HISTORY : owner
```

Notes: `ORGANIZATION_OWNERSHIP_HISTORY` is a conceptual placeholder; physical normalization (division/department/position effective-dated edges) remains to be decided. `POSITION_REPORTING_LINES` replaces relying solely on current `positions.parent_position_id` for historical cross-company reporting. Approval-step membership, RLS, cycle prevention, aggregate FTE and effective-date integrity are NOT guaranteed by the diagram or baseline SQL. Reporting has separate employee-home and position-owner dimensions and must use historical company lineage for as-of queries.
