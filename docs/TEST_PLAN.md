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

## Revision 6.1 — mandatory 002a-1 acceptance specifications (NOT EXECUTED)
| ID | Setup | Action | Expected |
|---|---|---|---|
| EMP-04 | cancelled employee with hire date and previously approved assignment; historical report dates before/after cancellation | query HC and attempt new/effective assignment | HC excluded for ALL dates; effective non-cancelled assignment rejected; 002a-1 rejects cancellation until existing assignment is cancelled through privileged test fixture; full approved compensating assignment workflow deferred to 002a-2; audit remains |
| EMP-05 | employee code A-001 and audit rows; runtime role and table-owner test roles | UPDATE employee_code (including same normalized code), DELETE employees, TRUNCATE employees, UPDATE/DELETE/TRUNCATE audit_logs | all runtime and owner-level DML rejected by triggers; runtime privileges revoked; reserved code cannot be reused |
| EMP-06 | employment H..T and company A H..D, B D+1..T; alternative gap/overlap and missing initial interval | commit valid history, then commit gap/overlap or uncovered hire/termination day | valid sequence commits; gap/overlap/uncovered interval rejected at transaction end; T counted, T+1 excluded |
| EMP-07 | legacy former employee code with unknown hire_date, active employee with case/whitespace variant | reserve/import and try new employee with normalized collision | former code reserved without fabricated employee row; normalized duplicate rejected; unresolved legacy collision blocks migration |
| EMP-08 | approved future transfer A->B, effective Nov 1 Asia/Bangkok; new compensating request approved Oct 20 | supersede A [H, Oct 31] and B [Nov 1, infinity), insert replacement A' [H, infinity) (bounded by T if terminated) in one locked transaction; query every day H..Nov 1 and inspect audit | exactly one effective company interval on every employment day; replacement A' effective from H; old versions and approval evidence retained; projection reads non-superseded history only; no DELETE/UPDATE original payload |
| EMP-09 | cancelled employee; legacy inactive record; termination T | report HC at T and T+1, and for cancelled record on historical date; simulate missed status job | T counted and T+1 excluded for terminated; cancelled never counted; legacy inactive migration requires semantic audit; projection catches up after missed job |
| MIG-03 | legacy code variants ' ab-01 ' and 'AB-01', historical code of former employee | run preimport registry audit twice | collision reported, import blocked pending resolution, reservation idempotent, no code recycled |
| INT-02 | employee + initial company history inserted in one transaction | commit with correct/mismatched home_company_id; query future transfer before effective date | INSERT derives projection from effective history; direct projection UPDATE denied; employee non-projection UPDATE succeeds even when a future-effective transfer has become due but reconciliation has not run; history authoritative for as-of reads |
| AUD-02 | approved future history with one-time supersede metadata | attempt second supersede, change original effective dates/provenance, delete original | all rejected; ordinary approved transfer/termination correction and cancellation each use one-time supersede plus full gapless replacement atomically; direct UPDATE of original dates rejected |

**Gate:** 002a-1 implementation PR must execute EMP-01..EMP-13, INT-01/02, AUD-01..03, MIG-02/03 and X12–X14/X18 on disposable PostgreSQL and attach results. APR-13 midnight cancellation/activation race remains 002a-2; this documentation adds no SQL or executed tests.

## Revision 6.2 — additional 002a-1 executable test specifications (NOT RUN)
| ID | Setup | Action | Expected |
|---|---|---|---|
| EMP-10 | session TimeZone UTC; fixed instant 2026-10-31 17:30Z; A->B effective 2026-11-01 Bangkok | evaluate business_date and reconcile projection twice | business_date=Nov 1; home_company=B; repeat is idempotent |
| EMP-11 | two concurrent sessions for same employee; two other sessions reserve ' ab-01 ' and 'AB-01' | attempt conflicting history writes and code creation simultaneously | employee row lock serializes writers; no history gap/overlap; at most one normalized code reservation commits |
| EMP-12 | legacy_reservation unbound; existing registry row; runtime role | attempt NULL->new employee binding, registry UPDATE code/source/owner, DELETE and TRUNCATE; attempt later complete import with reserved code | all direct mutations denied; later import blocks for explicit reconciliation; historical reservation never recycled |
| AUD-03 | A [H, Oct 31] and approved B [Nov 1, infinity) | ordinary transfer/cancellation/termination correction through history writer, then direct UPDATE old effective_to, second supersede and mismatched replacement source_request_id | approved writer produces complete non-superseded timeline, original row payload preserved; direct edit/re-supersede/provenance mismatch rejected |
| EMP-13 | cancelled employee and active employee with T | insert/update assignment outside [H,T] or for cancelled employee; cancel employee with any non-cancelled assignment, shorten termination_date or move hire_date to exclude assignment; race cancellation versus assignment insertion | reject unless assignment is cancelled through privileged fixture; lock employee to serialize races; no assignment outside employment |

**002a-1 gate boundary:** EMP-01..EMP-12 (plus EMP-13), INT-01/02, AUD-01/02 (plus AUD-03), MIG-02/03 and X12–X14/X18 require disposable PostgreSQL execution and attached evidence in the SQL PR. X16/MIG-01 belong to the later migration phase, not 002a-1. APR-13 and full multi-company compensating approval API remain 002a-2. Fixture creation of approved/applied requests is permitted under isolated test role; this is NOT evidence that the future approval workflow is implemented.
