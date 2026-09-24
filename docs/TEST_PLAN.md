# Batch 2.1 acceptance tests

## SQL smoke tests (run in disposable PostgreSQL database)
1. Apply `001_schema.sql` once to empty database; assert every table and index exists. Use a migration runner to record version; do not rerun the file directly.
2. Duplicate employee_code across different companies must fail unique constraint.
3. Department with null section_id and valid division_id must succeed; missing division_id must fail.
4. Department section_id from a different division must fail composite FK.
5. Negative target_fte and zero assignment_fte must fail.
6. Two overlapping primary assignments for same employee must fail; a nonoverlapping pair must succeed.
7. Two overlapping company-history intervals for same employee must fail.
8. Workflow request_type mismatch must fail composite FK.
9. User-role scope_type=company without company_id must fail.
10. Invalid effective date ranges must fail.

## Backend integration tests (must be implemented before pilot)
11. Company A user cannot read Company B via list, detail, chart, export, attachment, or manually edited API URL; central user can see authorized aggregate.
12. Sensitive profile fields remain hidden from users with only employee.read.
13. Cross-company transfer requires source/destination authorization; retains employee_code and UUID; closes old history and opens new history atomically on effective date.
14. Pending/rejected request never changes approved master records.
15. Duplicate approval/retry and concurrent updates apply once; stale row_version returns 409.
16. Workflow approver must belong to the request's workflow step; requester cannot self-approve unless explicitly enabled.
17. FTE totals and HC match known fixtures with one employee assigned to multiple positions and cross-company work.
18. Backup and restore reproduce counts, FK integrity, permissions, and request history.

**Status:** This is a test specification, not a claim that PostgreSQL or integration tests have been executed.
## Revision 5 — proposed 002a acceptance scenarios (not executed)
Each row provides setup / action / expected. Run on disposable PostgreSQL after implementing migrations; existing smoke test #13 must be updated to distinguish approved future history from current projection.
| ID | Setup | Action | Expected |
|---|---|---|---|
| APR-01 | request workflow A, step workflow B | submit B approval against A | rejected by composite workflow integrity |
| APR-02 | requester, approver, review round 1 | duplicate vote/self-approve then return and resubmit | duplicate/self vote denied; old round votes do not count |
| APR-03 | approved future request | reserve history then run activation twice | one ledger operation, no duplicate history/projection |
| APR-04 | two active workflows same company/type | activate both and submit | second activation denied; server selects valid workflow |
| APR-05 | active workflow with steps | remove last step or mutate active step | denied |
| APR-06 | approval step with both role and user, wrong company | approve | XOR and company authorization deny |
| APR-07 | same source/target on intercompany request, mismatched entity type | submit/apply | denied |
| EMP-01 | A company until D, B from D+1 | transfer same UUID and compare projection before/after effective date | no gap; same UUID/code; projection switches only when due |
| EMP-02 | hire H, termination T | report HC at T and T+1; add assignment after T | counted at T, excluded at T+1; assignment rejected |
| EMP-03 | terminated employee code and existing UUID | rehire, recycle code, hard-delete old row | rehire requires new UUID/code, no link; recycle/delete denied |
| FTE-01 | approved future assignment 0.60 starting D | approve overlapping 0.50 starting D | second approval rejected at final approval, not at activation |
| FTE-02 | concurrent writers for same employee | commit assignments 0.60 and 0.50 overlapping | at most one commits; no overlapping duplicate employee-position |
| INT-01 | row_version N | concurrent updates with stale version | version increments, stale update rejected |
| AUD-01 | approved request and audit rows | direct update/delete audit row | denied and recorded as policy violation |

Additional 002b/003 scenarios to specify before their migrations: ORG-01 temporal primary cycles and root coverage; ORG-02 division transfer causing cross-company edge and role suspension; ORG-03 code registry immutability; REP-01 as-of group names and unallocated FTE; SEC-01 cross-company 4-field projection; SEC-02 profile privacy; SEC-03 signed document access; PERF-01 FK indexes and as-of query plan; MIG-01/MIG-02 migration replay/data audit; API-01/API-02/API-03 endpoint and idempotency contract; TEST-01 import original X1-X26 probe definitions before claiming test completeness.
