# Roster Master — R2.1 Architecture Decisions
Status: APPROVED BUSINESS RULES / DESIGN PROPOSALS ONLY. Baseline: `database/migrations/001_schema.sql` on `docs/batch-2-1-foundation`. No SQL or application code changes in R2.1.

## Confirmed decisions
- D01: `employees.employee_code` unique globally. One employee UUID persists through intercompany transfers; retain effective-dated company history and approved request linkage.
- D02: Sum of all simultaneous, non-cancelled employee assignment FTE across all companies must be <= 1.0000, including future-dated intervals. HC is distinct employees, not assignments.
- D03: Cross-company reporting lines are permitted only through an approved organization-change request. Prevent self-reference, cycles and inconsistent effective dates. Cross-company reporting does NOT grant cross-company access to personal data.
- D04: `departments.department_code` and `positions.position_code` unique globally, across the entire system. Department requires a division; section is optional and, if set, must belong to same division.
- D05: Reports must expose TWO separate company dimensions: employee home company **as of report date** and position-owning company (position_history -> department_history -> division_history -> company_history as-of report date). Report HC and FTE independently, with explicit denominators and no summing HC across overlapping assignment-company slices.
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
- D11: No overlapping effective-dated assignments for the same employee and position, irrespective of primary/secondary type. Aggregate effective active-or-ended (not cancelled) assignment FTE across companies at every affected date <= 1.0000.
- D12: Globally unique department and position codes are never reassigned to a new entity, even when the original entity is inactive.
- D13: Exactly one PRIMARY supervisor for a non-root position and none for an approved root position at a time; additional COORDINATION reporting lines are allowed. A coordination edge must not automatically grant personal-data access.
- D14: Cross-company reporting-line changes require approval from authorized approvers of BOTH companies. Approval history and effective dates must be retained.
- D15: When a company owns a position staffed by an employee of another company, authorized users of the position-owning company may see employee code, name, position and assigned FTE only; no other personal profile data by default. Central access remains role-scoped.
- D16: Historical reports show names and organization structure AS OF the report date; approved backdated corrections require audit logging and must preserve previous values and approval provenance.
- D17: Thai-English glossary: กลุ่มบริษัท = company_groups; บริษัท = companies; ส่วน = divisions; แผนก = sections (optional); หน่วยงาน = departments (division mandatory); ตำแหน่ง = positions. Global code uniqueness applies to departments and positions, NOT to sections by this decision.
- D18: Approvers are configured by request type; multi-step workflows may include company-level and central approvers. Pending requests cannot change master data; authorized approval and effective date are prerequisites to apply.

## Revision 3 design choices (technical proposals, subject to review; NOT SQL implementation)
- One source of truth for current home company: effective-dated `employee_company_history`; legacy `employees.home_company_id` becomes a read-only derived/cache field reconciled by an idempotent activation job at effective date, not independently editable. For active employees missing a history interval, fail closed and raise a data-quality issue. A terminated employment may have no current interval.
- One source of truth for approved position FTE: `position_fte_history`; legacy `positions.target_fte` becomes read-only derived/cache. `positions.parent_position_id` similarly becomes read-only derived/cache from approved PRIMARY reporting lines, never an independently editable source.
- Historical ownership proposed as six effective-dated organization and company/group history entities: `division_history(division_id, company_id, division_name, effective_from, effective_to, source_request_id)`, `section_history(section_id, division_id, section_name, effective_from, effective_to, source_request_id)`, `department_history(department_id, division_id, section_id NULL, department_name, effective_from, effective_to, source_request_id)`, and `position_history(position_id, department_id, position_name, effective_from, effective_to, source_request_id)`. Section must belong to the same division at every effective date. All versions of the same entity must not overlap; retain prior versions for as-of queries. Master names and parent references are read-only current projections.
- `position_reporting_lines(id, position_id, supervisor_position_id, line_type PRIMARY|COORDINATION, effective_from, effective_to, approval_request_id NULL, migration_batch_id NULL, status)`. A migrated historical edge may cite a migration batch instead of a request, but new cross-company edges require an approved request with both company approvals. PRIMARY intervals must not overlap per subordinate; cycle checks consider only edges whose effective periods overlap, with serialization of concurrent graph edits. Whether coordination edges participate in cycle validation is a technical review item.
- FTE implementation proposal: per-employee serialization + deferred transaction-end interval check (including future dates) for inserts/updates/deletes/status changes; enforce assignment status/date consistency. These are design requirements, not current SQL features.
- Backdated correction proposal: create approved effective-dated versions and immutable audit entries; do not overwrite history silently. Exact retention and cutoff are still open.

## Metric × company-view specification (proposed report contract)
Report date D; active employee means employment valid at D and within inclusive hire_date through termination_date (or open-ended) at D. Count HC as distinct employee UUID within each view. Assignments count only if effective at D and non-cancelled.
| Metric | A: employee home company at D | B: position-owning company at D |
|---|---|---|
| HC | Distinct active employees with company-history row at D, including zero-assignment employees | Distinct active employees with >=1 effective assignment to a position owned by that company at D; one person may appear in two company rows, so do not sum row HC to get group HC |
| Actual FTE | Sum ALL effective assignment FTE of home-company employees across ALL position-owning companies; separately show cross-company allocation | Sum effective assignment FTE to positions owned by that company, irrespective of employee home company |
| Approved FTE | Not applicable as a home-company employee metric; show blank/N/A, NOT zero | Sum effective approved position target FTE for positions owned by company at D |
| FTE Gap | N/A (no comparable approved FTE denominator in view A) | Approved FTE minus Actual FTE |
| Unallocated FTE | Separate indicator for home-company active employees without assignments; numeric capacity formula awaits owner approval | Not applicable |

Fixture at D: A owns position PA target 1.00, B owns PB target 1.50. Employee E1 home A assigned PA 0.50 + PB 0.50; E2 home A no assignment; E3 home B assigned PB 0.50. View A: company A HC 2, actual 1.00, unassigned HC 1; company B HC 1, actual 0.50. View B: A HC 1, approved 1.00, actual 0.50, gap 0.50; B HC 2, approved 1.50, actual 1.00, gap 0.50. Group home-company HC 3; group distinct assigned HC in view B 2 (E1 and E3), NOT the sum of view-B company HC rows (1+2=3): E1 appears in both B rows while E2 has no assignment. Group actual FTE 1.50; group approved 2.50. This fixture is illustrative, not imported legacy data.

## Remaining open items
- Numeric definition of per-person unallocated FTE (whether approved individual capacity is 1.00), and treatment of leave/inactive employees in reports.
- Whether additional COORDINATION lines may form cycles, and how to define approval of a reporting edge spanning more than two companies.
- Whether historic section/department/position names require multilingual versions; detailed backdated correction cutoffs and approval escalation.
- Legacy v5.41 data shape, current FTE interpretation, code normalization and historical baseline must be audited before migration. Earlier "implicit 1/N FTE" was an UNVERIFIED ASSUMPTION, not a known property of v5.41.

## Revision 4 — owner-confirmed decisions (authoritative; override any historical draft conflicts)
- D19 / N-11: `termination_date` is the LAST day worked and is included in active HC. No assignment may be effective after termination_date. For an employee with hire_date H and termination_date T, active employment interval is [H,T] inclusive; if T null, open-ended. Position/assignment validity and company history must cover every active day.
- D20 / N-06: A transfer retains employee UUID and code ONLY if company membership is continuous with no uncovered calendar day; close company A interval on day D and start B on D+1. Any gap is a new employment with a NEW UUID/code, with NO link to prior employee record. Within each UUID, exactly one company-history interval covers every active employment day; no overlapping intervals or gaps. A new employment starts at its own hire_date.
- D21 / N-12: Store effective-dated names of BOTH companies and company groups; reports show names and group membership as-of date D. Historical legal identity must remain stable even when name changes.
- D22 / N-09: Root/no-supervisor status is designated per position through an approved organization structure; a non-root position has exactly one PRIMARY reporting edge at each effective date, a root has zero. COORDINATION edges may be additional and never grant profile access.
- D23 / N-14: Department and position codes may be corrected only BEFORE first real use. Once used, codes are immutable, including after deactivation; never reuse any retired code. "Use" includes assignment, approved staffing plan, reporting edge, or other linked operational record; technical proposal: use an immutable code registry/reservation to avoid recycling and log pre-use corrections.
- D24 / N-10: Every reporting-line change, INCLUDING within-company PRIMARY and COORDINATION, requires an approved change request by configured authorized approvers. Cross-company edges additionally require authorization by BOTH companies.
- D25 / N-05: At report date D, assignments count when effective_from <= D <= effective_to (or end null), and status is active OR ended; cancelled is excluded. 'ended' represents a historical valid assignment whose end date is mandatory. The same inclusion rule applies to aggregate FTE checks on all affected historical/future intervals.
- D26 / N-02: RLS and all as-of reports MUST resolve company membership, organization ownership and names from effective-dated history/view, NEVER a current-master cache. Future-dated approved changes need idempotent activation/reconciliation job (including missed-run recovery) to update current projections on effective date; cache is non-authoritative. Scheduled changes may not be applied before approved effective date.
- D27 / N-03: Entity existence at D means an approved lifecycle/history interval covers D. Deactivation closes interval at last valid date, and status in master is only current projection. Assignment and position FTE intervals must be within position existence; child organization intervals must be covered by parent existence. Reopening requires approved new interval and nonoverlap.
- D28 / N-04: A new cross-company reporting edge must include an approved request with approval evidence for each of the two actual position-owning companies resolved at effective date; verify both on apply, including when ownership changed since submission. Two-company requirement applies even when requester and central office are the same person. Technical design: resolve source_company/target_company steps from change_requests.company_id/target_company_id but validate these against historical owners; if mismatch, return request for reapproval, never silently substitute.
- D29: Historical backdated corrections preserve prior values and append-only audit, and must not rewrite past approval evidence. The date-dependent read model must incorporate approved correction versions.

### Revision 4 acceptance gates
002a requires traceability for all original findings and exact approval state/column specification, as well as D19/D20/D25 and tests for termination-day and gapless transfer. 002b requires D21-D24 and D26-D28, temporal parent coverage, provenance and root tests. RLS/003 must be independently reviewed with column-limited cross-company views. No SQL or app changes are made in this documentation revision.

## Revision 5 — owner-approved decisions
- D30: At FINAL approval, write approved effective-dated history (including future-dated rows) atomically with validation of all overlapping present and future intervals, including concurrent requests. Current projections are not changed before effective date; idempotent daily/on-demand activation reconciles them when due. Approval and activation are separate events. An already-approved future request may not silently bypass revalidation when earlier history is backdated.
- D31: ONE request may affect multiple companies. Determine complete affected-company set from changed organization ownership, descendant positions, existing reporting edges and role assignments as-of every affected date. Require authorization evidence from every affected company before applying any change; if affected set changes, invalidate/restart approval. No partial application.
- D32: Standard individual capacity = 1.0000 FTE. Unallocated FTE at date D = max(0,1.0000 - sum of effective active-or-ended, non-cancelled assignments at D) for each active employee; show separately by home company. Employees without assignments have 1.0000 unallocated. Aggregate by summing per-person residual, not by subtracting headcount from company-owned position FTE.
- D33: Employee codes are globally unique for all time and never recycled, even after termination/cancellation. Never hard-delete employee records; use approved status transitions and append-only audit. Rehire is a separate UUID and code, without link to prior record.

## Revision 5 — approval timing example
On 1 October approve two requests for the same employee, both effective 1 November: first 0.60 FTE, second 0.50 FTE. First writes future history and passes; second must be rejected or returned for revision at final approval because 1.10 > 1.00. Neither may change the current projection before 1 November. Effective-dated approved history is the source for future validation, not the projection.

## Remaining architecture review gates
R4-01..R4-16 are tracked in REVIEW_TRACEABILITY; technical schema proposals are not owner-approved SQL. A historical correction affecting already-approved future records must lock/revalidate impacted intervals and require explicit conflict resolution. Company-scope role access after ownership changes must be recalculated from history and reauthorized, never inherited implicitly.
