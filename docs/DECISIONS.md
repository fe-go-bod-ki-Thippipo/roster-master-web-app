# Roster Master — R2.1 Architecture Decisions
Status: APPROVED BUSINESS RULES / DESIGN PROPOSALS ONLY. Baseline: `database/migrations/001_schema.sql` on `docs/batch-2-1-foundation`. No SQL or application code changes in R2.1.

## Confirmed decisions
- D01: `employees.employee_code` unique globally. One employee UUID persists through intercompany transfers; retain effective-dated company history and approved request linkage.
- D02: Sum of all simultaneous, non-cancelled employee assignment FTE across all companies must be <= 1.0000, including future-dated intervals; reject overlapping assignments to the same employee and position. HC is distinct employees, not assignments.
- D03: Cross-company reporting lines are permitted only through an approved organization-change request. Prevent self-reference, cycles and inconsistent effective dates. Cross-company reporting does NOT grant cross-company access to personal data.
- D04: `departments.department_code` and `positions.position_code` unique globally, including inactive records; do not recycle identifiers. Department requires a division; section is optional and, if set, must belong to same division.
- D05: Reports must expose TWO separate company dimensions: employee home company **as of report date** and position-owning company (position -> department -> division -> company). Report HC and FTE independently, with explicit denominators and no summing HC across overlapping assignment-company slices.
- D06: Approved target FTE is effective-dated and separate from actual assignment FTE. FTE gap = approved target - actual, with report date and dimension displayed.
- D07: Each company sees only authorized company data; central sees authorized group-wide data. Sensitive employee profile permissions are separate. All changes requiring approval remain pending until approved and effective.
- D08: Pilot scope: central office and selected plantation units. Legacy v5.41 remains untouched.

## Existing baseline vs proposed R2 changes
Baseline already has global UNIQUE codes, composite department-section FK, overlapping primary-assignment exclusion, employee-company-history interval exclusion, and request-to-workflow request-type composite FK. These are **not** claimed missing.
Proposed: enforce aggregate assignment FTE and duplicate secondary intervals; historical organization ownership and reporting-line edges; prevent contradictory home_company_id vs company history; make position FTE history authoritative; add effective-dated activation and exactly-once apply; enforce approver step/workflow membership and immutable active workflow versions; implement runtime RLS with explicit company-scope and sensitive-field policies. No proposed controls are implemented by this document.

## Open design decisions (NOT approved business rules)
- Employee with no active assignment: HC inclusion and unallocated FTE representation; employee with no active company-history interval: fail closed and flag data issue.
- Whether employee total assigned FTE may be below 1.0000 (ceiling is approved; minimum is not); how to treat inactive/terminated people in historic reporting.
- Whether reporting-line changes need source and destination company approvers, and whether a position may have multiple reporting lines on the same date.
- Historical changes to division/department/position ownership, backdated corrections, workflow exception and audit retention policy.
- RLS authorization for cross-company assignment summary vs identifying details, and definition of home-company HC for staff assigned elsewhere.
- Existing legacy data with implicit 1/N FTE must not silently become approved explicit assignment FTE. Require reconciliation and owner sign-off.

## Acceptance boundary
R2.1 is documentation only. Do not claim database controls, SQL execution, backend implementation, or production readiness. Next: review decisions, design migration 002 and RLS 003, implement and test in disposable PostgreSQL, and submit to independent review. No merge to main.
