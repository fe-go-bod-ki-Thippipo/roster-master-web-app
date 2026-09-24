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
13. Cross-company transfer requires source/destination authorization; retains employee_code and UUID; commits approved future history atomically at final approval; current projection changes only on effective date.
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

## Revision 6 — additional acceptance cases (specification only; NOT run)
| ID | Setup | Action | Expected |
|---|---|---|---|
| APR-08 | approved scheduled transfer with future history | attempt direct cancel, then submit compensating cancellation and approve all companies | direct cancel denied; original history/audit preserved; superseding future timeline committed atomically |
| APR-09 | draft request with no workflow | submit, return after first approval, resubmit | server pins workflow once; same workflow and prior-round evidence retained; only new round counts |
| APR-10 | approved future request; activation job unavailable on effective date | query as-of report, restore job, rerun twice | history-based report correct while job down; projection catches up exactly once |
| APR-11 | approved future FTE 0.60 | approve backdated 0.50 overlapping future interval | later approval rejected under employee lock |
| APR-12 | apply ledger projection_activation failed | retry with same operation_key | one activation, increment ledger attempt, no duplicated history |
| ORG-01 | non-root with primary edge and root with none | introduce overlapping cycle, missing primary, or extra root primary | reject at transaction end |
| ORG-02 | division transfers A to B; A-scoped role and cross-company reporting edge exist | attempt apply with B approval missing, then approve B; query role access at effective date before job | no partial apply; both companies approve; old role denied immediately |
| ORG-03 | department/position code used then deactivated | create another entity with same code or edit used code | rejected; before-first-use edits follow approved rule |
| REP-01 | fixture E1 A 1.00, E2 A 0.00, E3 B 0.50 | report at D with company/group names changed historically | home A unallocated 1.00, home B 0.50; names as-of D; negative residual flagged |
| SEC-01 | B owns position filled by A employee | B user reads assignee list and employee profile | code/name/position/assigned FTE only; profile denied |
| SEC-02 | cross-company user without profile permission | query sensitive fields and direct profile endpoint | deny; log access attempts per policy |
| SEC-03 | attachment in company A | B user requests signed URL or guesses storage key | deny; signed URL short-lived and scoped |
| PERF-01 | representative synthetic dataset 20,000 employees, 5 years history, 3 company scopes | EXPLAIN ANALYZE as-of RLS report and compare indexed/unindexed plans | no full-table leak; record p95 latency and query plans; target p95 <= 2 seconds for summary, subject to owner SLA approval |
| MIG-01 | legacy unresolved mapping and repeated source checksum | import twice | unresolved new_id NULL, no duplicate mappings, idempotent rerun |
| MIG-02 | legacy active and former employees including duplicate/case-variant codes | audit/import and create new employee using former code | reserve all historical codes; collisions flagged before migration; reuse denied |
| API-01 | returned request and multi-company inbox | resubmit and list company approver inbox | pinned workflow, correct round, scoped inbox |
| API-02 | decision payload and compensating request | submit wrong-company approval or cancel scheduled directly | reject invalid approval/direct cancel; authorized compensation accepted |
| API-03 | duplicate client Idempotency-Key and internal retry | repeat request | stable API response; internal ledger prevents duplicate application |
| DOC-01 | baseline README references filenames | verify paths against repo tree | no broken references |
| TEST-01 | baseline 001 and migrations applied to disposable PostgreSQL | execute X1–X26 matrix below | all expected outcomes met; record failures |

### X1–X26 regression matrix (from Claude R5 review D2; test definitions, not results)
X1 foreign workflow step APR-01 reject; X2 manipulated review round APR-02 reject; X3 requester self-approval APR-02 reject; X4 foreign company workflow APR-04 reject; X5 and X6 overlapping company/global active workflows APR-04 reject; X7 and X22 active step edits APR-05 reject; X8 primary cycle ORG-01 reject; X9 unapproved cross-company edge ORG-02 reject; X10 aggregate 3.0 FTE FTE-02 reject; X11 duplicate employee-position interval FTE-02 reject; X12 case/whitespace employee-code collision EMP-03 reject; X13 direct home_company projection edit EMP-01 reject; X14 row_version not incremented INT-01 must increment; X15 direct division owner edit ORG-02 reject; X16 unresolved mapping with NULL new_id MIG-01 allow; X17 applied without applied_at APR-03 reject; X18 audit UPDATE/DELETE AUD-01 reject; X19 arbitrary entity_type INT-01 reject; X20 target_fte projection divergence FTE-01 prevent; X21 same source/target intercompany request APR-07 reject; X23 zero-step active workflow APR-05 reject; X24 assignment after termination EMP-02 reject; X25 assignment on nonexistent position interval ORG-01 reject; X26 incompatible source_request_id APR-07 reject.
