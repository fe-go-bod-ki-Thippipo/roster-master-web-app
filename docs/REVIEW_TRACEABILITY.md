# R2.1 Review Traceability — Revision 3
Source: Claude R2.1 review (PR #2), IDs R-01..R-13 and suggestions S-01..S-04. This document tracks *design responses*, not SQL implementation or independently verified closure. The full F-01..F-22, A-01..A-05, T-01 and M-01 summary was supplied in Claude's Revision 3 review (section D); Revision 4 maps these below. All mappings are documentation plans, NOT implementation or tested closure.

| ID | Disposition | Design response / target |
|---|---|---|
| R-01 | Accepted; partially documented | Earlier-review traceability is still incomplete; obtain full original findings before R2.2. Current known items: row_version/optimistic locking, self-approval, workflow-company selection, inactive assignments, ownership edits, employee-code normalization, FK indexes, migration, audit append-only, idempotency. Targets 002a/002b/003 as appropriate. |
| R-02 | Accepted; design proposed | DECISIONS and DATA_DICTIONARY define four versioned organization history entities, effective dates and historical names; 002b. |
| R-03 | Accepted; design proposed | parent_position_id read-only derived current primary edge from reporting-line history; migrate legacy values only after audit; 002b. |
| R-04 | Accepted; design proposed | DECISIONS metric × view table and fixture; reporting/API implementation later. Numeric unallocated FTE remains open. |
| R-05 | Accepted; documented | Duplicate employee-position and no-recycle are now owner-confirmed D11/D12. |
| R-06 | Accepted; documented | Approval by request type, multiple steps, company and central approvers D18. |
| R-07 | Accepted; documented | Glossary D17; owner confirmed. |
| R-08 | Accepted; design proposed | Rehire new UUID/code, legal gaps; history authoritative and current home-company cache read-only; 002a. |
| R-09 | Accepted; documented | Added 13 omitted baseline FK edges and polymorphic-reference caveat in ER_DIAGRAM. |
| R-10 | Accepted; design proposed | Migrated reporting edges cite migration batch; new cross-company edges require approved request and two-company authorization; 002b. |
| R-11 | Accepted; documented | Legacy implicit 1/N FTE marked unverified assumption; migration data audit required. |
| R-12 | Deferred with rationale | Full baseline CHECK/DEFAULT transcription requires mechanical schema catalog validation; authoritative source remains 001_schema.sql; complete before migration implementation. |
| R-13 | Deferred with rationale | Baseline README filename correction is outside three-document R2.1 scope; correct in documentation cleanup before merge. |
| S-01 | Accepted as technical proposal | Per-employee serialization and deferred interval-aware FTE check; 002a; concurrency tests required. |
| S-02 | Accepted as technical proposal | Effective-dated reporting-line cycle validation and serialization; 002b. |
| S-03 | Accepted as technical proposal | Assignment ended status must have effective_to; 002a. |
| S-04 | Accepted; pending design | RLS policy matrix by scope/table/field; 003, with cross-company limited assignee fields D15. |

## Gate before R2.2
1. Fetch complete earlier Claude review and map EVERY F-01..F-22, A-01..A-05, T-01, M-01 to exact disposition, migration and test. Do not infer unknown IDs.
2. Independently review proposed history model, as-of reporting fixture, and approval lineage.
3. Resolve numeric unallocated FTE capacity and remaining open questions as needed for implementation.
4. No SQL, runtime tests or deployment were performed in R2.1 Revision 3; no merge to main.

## Revision 4 — original Claude findings (source: Claude Revision 3 report, section D)
Disposition = documented plan / pending implementation unless explicitly 'decision closed'. Test IDs are proposed acceptance cases, not tests run.
| ID | Original finding | Disposition / target | Acceptance test |
|---|---|---|---|
| F-01 | No RLS, policies or triggers | 003 design pending; policy matrix and cross-company field-limited views | SEC-01 |
| F-02 | Approval step not bound to request workflow | 002a composite workflow FKs specified in DD | APR-01 |
| F-03 | Missing current round, duplicate/self approval | 002a current_review_round and approver authorization | APR-02 |
| F-04 | Missing scheduled/apply_failed and apply metadata | 002a explicit states, applied_at, attempts, error | APR-03 |
| F-05 | Current home_company and history diverge; transfer API example incomplete | 002a history authoritative, derived projection; API update | EMP-01 |
| F-06 | Foreign company workflow and duplicate active workflow | 002a server selection and effective-dated nonoverlap | APR-04 |
| F-07 | Active step editable / workflow with zero steps | 002a immutable activated version and >=1 step | APR-05 |
| F-08 | Two target FTE sources and no position time dimension | 002a FTE history authoritative; 002b position history | FTE-01 |
| F-09 | Parent cycle and unapproved cross-company reporting | 002b approved effective-dated edges, temporal cycle check | ORG-01 |
| F-10 | Aggregate FTE unbounded and duplicate position assignment | 002a interval check and concurrency locking | FTE-02 |
| F-11 | Assignment after termination or inactive position | 002a last-day-inclusive employment; 002b position existence | EMP-02 |
| F-12 | row_version not auto-incremented, absent elsewhere, entity_type unconstrained | 002a version trigger, scoped entity type catalog | INT-01 |
| F-13 | Silent direct division ownership reassignment | 002b history authoritative; master read-only projection | ORG-02 |
| F-14 | Employee code normalization missing | 002a after legacy audit and approved normalization rule | EMP-03 |
| F-15 | Missing indexes on 34 FK locations | 002a/002b inventory and index creation | PERF-01 |
| F-16 | Fake unresolved new_id, duplicate cross-batch mapping, checksum blocks rerun | migration design after data audit; nullable unresolved ID and rerun ledger | MIG-01 |
| F-17 | Unclear code uniqueness scopes | Decision closed D04/D12/D17/D23; audit existing collisions | ORG-03 |
| F-18 | Audit logs mutable | 002a/003 append-only access and trigger | AUD-01 |
| F-19 | Sensitive profile data plaintext | 003 PDPA decision and restricted/encrypted storage design pending | SEC-02 |
| F-20 | Approval step both role and user; related_company undefined | 002a XOR and source/target company scopes | APR-06 |
| F-21 | Same source/target company for intercompany request; request-type mismatch | 002a type-specific checks and source_request validation | APR-07 |
| F-22 | README filename incorrect | docs cleanup before merge | DOC-01 |
| A-01 | Missing resubmit, retry, inbox, workflow/role/reference/export/search endpoints | API revision after 002a | API-01 |
| A-02 | Decision body unspecified and workflow chosen by client | API revision: server workflow selection and body schema | API-02 |
| A-03 | Report definitions unclear | Decision metric contract documented; API implementation pending | REP-01 |
| A-04 | Pagination incomplete and no idempotency table | API + 002a apply ledger | API-03 |
| A-05 | Document scope and signed URL undefined | API/003 design pending | SEC-03 |
| T-01 | Missing X1-X26, RLS, as-of and migration tests | tests paired with 002a/002b/003, no tests run yet | TEST-01 |
| M-01 | No v5.41 data audit or migration script | data audit required before migration | MIG-02 |

## Revision 4 — new findings N-01..N-15
| Finding | Document disposition | Gate |
|---|---|---|
| N-01 | Full original findings mapped above; approval column proposals in DATA_DICTIONARY | 002a review |
| N-02 | Idempotent future activation + history-only RLS/report reads | 002b/003 |
| N-03 | Approved existence intervals and position validity | 002b |
| N-04 | Source/target owner as-of effective date; two company approvals | 002b |
| N-05 | Count active+ended effective assignments; exclude cancelled | 002a |
| N-06 | Gapless company history per UUID; gap means new UUID/code, no link | 002a |
| N-07 | Revised DD and ER sections supersede stale draft; final editorial pass pending | documentation review |
| N-08 | Temporal parent coverage every hierarchy level | 002b |
| N-09 | Approved root designation per position, at most one primary | 002b |
| N-10 | Reporting provenance XOR and status set; all new edges approved | 002b |
| N-11 | termination_date last worked day inclusive; reject later assignments | 002a |
| N-12 | Company/group name history and as-of group membership | 002b |
| N-13 | Four proposed source_request ER edges added | documentation review |
| N-14 | Codes editable before first use only; immutable after use | 002b |
| N-15 | D05 historical lineage corrected; earlier draft still requires final editorial cleanup | documentation review |

**Status:** All 29 original findings and 15 new findings have a documented disposition, but this does not mean the vulnerabilities are fixed. Remaining gates: approve technical proposals, reconcile baseline SQL CHECK/DEFAULT and review status transitions, validate company ownership on cross-company approval, complete source v5.41 data audit, update API and test plan, and run independent Claude review before starting SQL. No merge to main.
