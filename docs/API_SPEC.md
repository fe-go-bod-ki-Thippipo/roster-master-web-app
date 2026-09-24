# Roster Master Web App — API contract draft v0.1

Base path `/api/v1`; JSON; HTTPS only. Authenticated requests use a secure server-side session or verified bearer token. All endpoints enforce server-side company scope and field-level permissions. Dates are ISO 8601; UUIDs are immutable identifiers; decimal FTE values are serialized as strings, e.g. `"0.5000"`.

## Shared response / concurrency
- Collection: `{ "data": [], "page": { "limit": 50, "cursor": null } }`; cursor is opaque.
- Single: `{ "data": { ... }, "row_version": 1 }`.
- Mutation: send `If-Match: "1"` or `expected_row_version`; stale versions return `409 CONFLICT`.
- Errors: `{ "error": { "code": "VALIDATION_ERROR", "message": "...", "fields": {} } }`. Use 401 unauthenticated, 403 unauthorized, 404 missing or hidden resource, 409 conflict, 422 invalid state.
- All POST writes support `Idempotency-Key` scoped to authenticated user and endpoint.

## Endpoints and required permissions
| Method | Route | Purpose | Permission |
|---|---|---|---|
| GET | `/me` | User and authorized scopes | authenticated |
| GET | `/company-groups` | Visible groups | `org.read` |
| GET | `/companies` | Visible companies | `org.read` |
| GET | `/divisions?company_id=` | Filter by company | `org.read` |
| GET | `/sections?division_id=` | Filter by division | `org.read` |
| GET | `/departments?division_id=&section_id=` | Filter by parent | `org.read` |
| GET | `/positions?department_id=` | Positions and approved FTE | `position.read` |
| GET | `/employees?company_id=&status=` | Company-scoped employee list, no sensitive profile | `employee.read` |
| GET | `/employees/{id}` | Employee detail, field-filtered | `employee.read` |
| GET | `/employees/{id}/profile` | Sensitive profile | `employee.profile.read` |
| GET | `/employees/{id}/assignments?as_of=` | Effective assignments | `assignment.read` |
| GET | `/employees/{id}/company-history` | Transfer history | `employee.history.read` |
| GET | `/reports/workforce?company_id=&as_of=` | HC, approved FTE, actual FTE, gap | `report.read` |
| GET | `/org-chart?company_id=&as_of=` | Hierarchy with safe field selection | `org.read` |
| GET | `/request-types` | Request type catalog | `request.read` |
| GET | `/approval-workflows?request_type_id=&company_id=` | Applicable workflows | `workflow.read` |
| GET | `/requests?company_id=&status=` | Authorized requests | `request.read` |
| POST | `/requests` | Create draft, changes, attachments metadata | `request.create` |
| GET | `/requests/{id}` | Authorized request details | `request.read` |
| PATCH | `/requests/{id}` | Update own editable draft | `request.update` |
| POST | `/requests/{id}/submit` | Validate and submit | `request.submit` |
| POST | `/requests/{id}/decisions` | Approve/reject/return current step | `request.approve` + workflow assignment |
| POST | `/requests/{id}/cancel` | Cancel per state rules | `request.cancel` |
| POST | `/requests/{id}/attachments` | Authorized file upload | `request.update` |
| GET | `/requests/{id}/attachments/{attachment_id}` | Authorized download | `request.read` + document scope |
| GET | `/audit-logs?company_id=` | Restricted audit view | `audit.read` |
| POST | `/admin/migrations/validate` | Stage JSON and report issues, no production writes | `migration.manage` |
| POST | `/admin/migrations/{id}/commit` | Explicitly approved import transaction | `migration.manage` |

**Writes to employees, positions, departments, assignments, and approved FTE:** route through `change_requests` when their request type requires approval. Do not expose direct write endpoints to ordinary users. Separate privileged configuration endpoints may be added after their authorization rules and audit requirements are approved.

## Sample: cross-company transfer request
```json
{
  "request_type_code": "EMPLOYEE_TRANSFER",
  "company_id": "<source-company-uuid>",
  "target_company_id": "<destination-company-uuid>",
  "title": "Transfer employee",
  "reason": "Approved organizational transfer",
  "effective_date": "2026-10-01",
  "changes": [{
    "entity_type": "employee",
    "entity_id": "<employee-uuid>",
    "operation": "update",
    "expected_row_version": 4,
    "proposed_data": { "home_company_id": "<destination-company-uuid>" }
  }]
}
```

## Report definitions
- HC at date: count DISTINCT active employee IDs in the authorized company scope; cross-company assignment is not a second employee.
- Actual FTE: sum of active, effective `assignment_fte` per position/company on the report date.
- Approved FTE: effective `position_fte_history.target_fte`, falling back to a documented opening baseline only if no history exists.
- Gap FTE: approved FTE minus actual FTE. Report company affiliation (home vs assignment company) explicitly.