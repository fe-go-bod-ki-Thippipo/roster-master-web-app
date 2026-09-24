# Roster Master — R2.1 Architecture Decisions
Status: APPROVED BUSINESS RULES / DESIGN PROPOSALS ONLY. Baseline: `database/migrations/001_schema.sql` on `docs/batch-2-1-foundation`. No SQL or application code changes in R2.1.

## Confirmed decisions
- D01: `employees.employee_code` unique globally. One employee UUID persists through intercompany transfers; retain effective-dated company history and approved request linkage.
- D02: Sum of all simultaneous, non-cancelled employee assignment FTE across all companies must be <= 1.0000, including future-dated intervals. HC is distinct employees, not assignments.
- D03: Cross-company reporting lines are permitted only through an approved organization-change request. Prevent self-reference, cycles and inconsistent effective dates. Cross-company reporting does NOT grant cross-company access to personal data.
- D04: `departments.department_code` and `positions.position_code` unique globally, across the entire system. Department requires a division; section is optional and, if set, must belong to same division.
- D05: Reports must expose TWO separate company dimensions: employee home company **as of report date** and position-owning company (position -> department -> division -> company). Report HC and FTE independently, with explicit denominators and no summing HC across overlapping assignment-company slices.
- D06: Approved target FTE is effective-dated and separate from actual assignment FTE. FTE gap = approved target - actual, with report date and dimension displayed.
- D07: Each company sees only authorized company data; central sees authorized group-wide data. Sensitive employee profile permissions are separate. All changes requiring approval remain pending until approved and effective.
- D08: Pilot scope: central office and selected plantation units. Legacy v5.41 remains untouched.

## Existing baseline vs proposed R2 changes
Baseline already has global UNIQUE codes, composite department-section FK, overlapping primary-assignment exclusion, employee-company-history interval exclusion, and request-to-workflow request-type composite FK. These are **not** claimed missing.
Proposed: enforce aggregate assignment FTE and duplicate secondary intervals; historical organization ownership and reporting-line edges; prevent contradictory home_company_id vs company history; make position FTE history authoritative; add effective-dated activation and exactly-once apply; enforce approver step/workflow membership and immutable active workflow versions; implement runtime RLS with explicit company-scope and sensitive-field policies. No proposed controls are implemented by this document.

## Superseded open questions
The open questions below were recorded in the original R2.1 draft; owner answers in Revision 3 below supersede any conflicting entries. Remaining unresolved items are listed at the end of Revision 3.

## Open design decisions (historical draft; see Revision 3)
- Employee with no active assignment: HC inclusion and unallocated FTE representation; employee with no active company-history interval: fail closed and flag data issue.
- Whether employee total assigned FTE may be below 1.0000 (ceiling is approved; minimum is not); how to treat inactive/terminated people in historic reporting.
- Whether reporting-line changes need source and destination company approvers, and whether a position may have multiple reporting lines on the same date.
- Historical changes to division/department/position ownership, backdated corrections, workflow exception and audit retention policy.
- RLS authorization for cross-company assignment summary vs identifying details, and definition of home-company HC for staff assigned elsewhere.
- Existing legacy data with implicit 1/N FTE must not silently become approved explicit assignment FTE. Require reconciliation and owner sign-off.

## Acceptance boundary
R2.1 is documentation only. Do not claim database controls, SQL execution, backend implementation, or production readiness. Next: review decisions, design migration 002 and RLS 003, implement and test in disposable PostgreSQL, and submit to independent review. No merge to main.


## R2.1 Revision 3 — Owner-confirmed business decisions (supersede conflicting earlier text)
- D09: Active employees with no assignment count in home-company HC. Display unallocated FTE separately; its numeric definition is pending (do NOT automatically assume every person has an approved 1.00 individual capacity).
- D10: Rehire after termination creates a NEW employee code and NEW UUID. Do not reuse the previous employment record. An uninterrupted intercompany transfer retains the SAME employee code and UUID. Historical employment intervals may have legitimate gaps; do not enforce continuous company history across separate employments.
- D11: No overlapping effective-dated assignments for the same employee and position, irrespective of primary/secondary type. Aggregate active assignment FTE across companies at every affected date <= 1.0000.
- D12: Globally unique department and position codes are never reassigned to a new entity, even when the original entity is inactive.
- D13: Exactly one PRIMARY supervisor position at a time; additional COORDINATION reporting lines are allowed. A coordination edge must not automatically grant personal-data access.
- D14: Cross-company reporting-line changes require approval from authorized approvers of BOTH companies. Approval history and effective dates must be retained.
- D15: When a company owns a position staffed by an employee of another company, authorized users of the position-owning company may see employee code, name, position and assigned FTE only; no other personal profile data by default. Central access remains role-scoped.
- D16: Historical reports show names and organization structure AS OF the report date; approved backdated corrections require audit logging and must preserve previous values and approval provenance.
- D17: Thai-English glossary: กลุ่มบริษัท = company_groups; บริษัท = companies; ส่วน = divisions; แผนก = sections (optional); หน่วยงาน = departments (division mandatory); ตำแหน่ง = positions. Global code uniqueness applies to departments and positions, NOT to sections by this decision.
- D18: Approvers are configured by request type; multi-step workflows may include company-level and central approvers. Pending requests cannot change master data; authorized approval and effective date are prerequisites to apply.

## Revision 3 design choices (technical proposals, subject to review; NOT SQL implementation)
- One source of truth for current home company: effective-dated `employee_company_history`; legacy `employees.home_company_id` becomes a read-only derived/cache field maintained transactionally, not independently editable. For active employees missing a history interval, fail closed and raise a data-quality issue. A terminated employment may have no current interval.
- One source of truth for approved position FTE: `position_fte_history`; legacy `positions.target_fte` becomes read-only derived/cache. `positions.parent_position_id` similarly becomes read-only derived/cache from approved PRIMARY reporting lines, never an independently editable source.
- Historical ownership proposed as three versioned edges: `division_history(division_id, company_id, division_name, effective_from, effective_to, source_request_id)`, `section_history(section_id, division_id, section_name, effective_from, effective_to, source_request_id)`, `department_history(department_id, division_id, section_id NULL, department_name, effective_from, effective_to, source_request_id)`, and `position_history(position_id, department_id, position_name, effective_from, effective_to, source_request_id)`. Section must belong to the same division at every effective date. All versions of the same entity must not overlap; retain prior versions for as-of queries. Master names and parent references are read-only current projections.
- `position_reporting_lines(id, position_id, supervisor_position_id, line_type PRIMARY|COORDINATION, effective_from, effective_to, approval_request_id NULL, migration_batch_id NULL, status)`. A migrated historical edge may cite a migration batch instead of a request, but new cross-company edges require an approved request with both company approvals. PRIMARY intervals must not overlap per subordinate; cycle checks consider only edges whose effective periods overlap, with serialization of concurrent graph edits. Whether coordination edges participate in cycle validation is a technical review item.
- FTE implementation proposal: per-employee serialization + deferred transaction-end interval check (including future dates) for inserts/updates/deletes/status changes; enforce assignment status/date consistency. These are design requirements, not current SQL features.
- Backdated correction proposal: create approved effective-dated versions and immutable audit entries; do not overwrite history silently. Exact retention and cutoff are still open.

## Metric × company-view specification (proposed report contract)
Report date D; active employee means employment valid at D and not terminated as of D. Count HC as distinct employee UUID within each view. Assignments count only if effective at D and non-cancelled.
| Metric | A: employee home company at D | B: position-owning company at D |
|---|---|---|
| HC | Distinct active employees with company-history row at D, including zero-assignment employees | Distinct active employees with >=1 effective assignment to a position owned by that company at D; one person may appear in two company rows, so do not sum row HC to get group HC |
| Actual FTE | Sum ALL effective assignment FTE of home-company employees across ALL position-owning companies; separately show cross-company allocation | Sum effective assignment FTE to positions owned by that company, irrespective of employee home company |
| Approved FTE | Not applicable as a home-company employee metric; show blank/N/A, NOT zero | Sum effective approved position target FTE for positions owned by company at D |
| FTE Gap | N/A (no comparable approved FTE denominator in view A) | Approved FTE minus Actual FTE |
| Unallocated FTE | Separate indicator for home-company active employees without assignments; numeric capacity formula awaits owner approval | Not applicable |

Fixture at D: A owns position PA target 1.00, B owns PB target 1.50. Employee E1 home A assigned PA 0.50 + PB 0.50; E2 home A no assignment; E3 home B assigned PB 0.50. View A: company A HC 2, actual 1.00, unassigned HC 1; company B HC 1, actual 0.50. View B: A HC 1, approved 1.00, actual 0.50, gap 0.50; B HC 2, approved 1.50, actual 1.00, gap 0.50. Group distinct HC 3, not sum of B company HC (3 in this fixture happens to coincide; E1 is in both rows and E2 in neither). Group actual FTE 1.50; group approved 2.50. This fixture is illustrative, not imported legacy data.

## Remaining open items
- Numeric definition of per-person unallocated FTE (whether approved individual capacity is 1.00), and treatment of leave/inactive employees in reports.
- Whether additional COORDINATION lines may form cycles, and how to define approval of a reporting edge spanning more than two companies.
- Whether historic section/department/position names require multilingual versions; detailed backdated correction cutoffs and approval escalation.
- Legacy v5.41 data shape, current FTE interpretation, code normalization and historical baseline must be audited before migration. Earlier "implicit 1/N FTE" was an UNVERIFIED ASSUMPTION, not a known property of v5.41.
