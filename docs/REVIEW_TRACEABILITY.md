# R2.1 Review Traceability — Revision 5
Source: Claude R2.1 review (PR #2), IDs R-01..R-13 and suggestions S-01..S-04. This document tracks *design responses*, not SQL implementation or independently verified closure. The full F-01..F-22, A-01..A-05, T-01 and M-01 summary was supplied in Claude's Revision 3 review (section D); Revision 4 maps these below. All mappings are documentation plans, NOT implementation or tested closure.

| ID | Disposition | Design response / target |
|---|---|---|
| R-01 | Accepted; partially documented | Original findings mapped in Revision 4; verify implementation separately. Current known items: row_version/optimistic locking, self-approval, workflow-company selection, inactive assignments, ownership edits, employee-code normalization, FK indexes, migration, audit append-only, idempotency. Targets 002a/002b/003 as appropriate. |
| R-02 | Accepted; design proposed | DECISIONS and DATA_DICTIONARY define six versioned organization and company/group history entities, effective dates and historical names; 002b. |
| R-03 | Accepted; design proposed | parent_position_id read-only derived current primary edge from reporting-line history; migrate legacy values only after audit; 002b. |
| R-04 | Accepted; design proposed | DECISIONS metric × view table and fixture; reporting/API implementation later. Numeric unallocated FTE fixed by D32: 1.0000 minus effective assignment FTE for every active employee. |
| R-05 | Accepted; documented | Duplicate employee-position and no-recycle are now owner-confirmed D11/D12. |
| R-06 | Accepted; documented | Approval by request type, multiple steps, company and central approvers D18. |
| R-07 | Accepted; documented | Glossary D17; owner confirmed. |
| R-08 | Accepted; design proposed | Rehire new UUID/code, gaps require new UUID/code; history authoritative and current home-company cache read-only; 002a. |
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
1. Review the mapped F-01..F-22, A-01..A-05, T-01, M-01 against actual implementation and test evidence.
2. Independently review proposed history model, as-of reporting fixture, and approval lineage.
3. Apply D32 numeric capacity and resolve only remaining open technical gates.
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
| F-13 | Silent division reassignment AND inherited division-scoped access crossing companies | 002b history authoritative, affected-company approvals and 003 role suspension/reauthorization | ORG-02 |
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

## Revision 5 — Claude R4 findings disposition
Source: Claude Independent Architecture Review PR #4 (HEAD f48b9b5), findings R4-01..R4-16. All below are DOCUMENTATION responses only; no SQL, code, or tests executed.
| ID | Severity | Source in Claude report | Doc status | Impl status | Revision 5 response / gate |
|---|---|---|---|---|---|
| R4-01 | High | DD L91; DEC L79/L6 | addressed; owner decision D30 | not started | Final approval writes future history atomically; projections activate when due; test future 0.60+0.50 conflict |
| R4-02 | High | DD L87; DEC L81; TRACE F-13 | design proposed; independent review needed | not started | D31, impact closure for descendants, edges, role suspension, approvals from all companies; 002b/003 |
| R4-03 | Medium | DD L91 | transition proposal; baseline mapping pending | not started | State graph, round/reject/return and clock-free CHECK in DD; 002a |
| R4-04 | Medium | DD L68-71/L87; ER L106 | proposed XOR across all histories | not started | request vs audited migration provenance; 002a/002b |
| R4-05 | Medium | DEC L16/L21-27/L36/L38/L46/L48/L54; DD L54/L56/L57/L68-72; TRACE L1/L6/L13/L25/L28 | partial: key rules updated; full editorial reconciliation still needed | not started | Read all original sections; remove obsolete draft rules and duplicate contradictory statements before 002a/002b |
| R4-06 | Medium | SQL L16; DD L19/L85; DEC L72-73 | proposed | not started | hire_date NOT NULL, termination >= hire, gapless company coverage; 002a |
| R4-07 | Medium | TRACE L34-62; TEST_PLAN | 002a test cases added; full ID inventory review pending | not started | Test ID setup/action/expected; X1-X26 remain to import from original report |
| R4-08 | Medium | DEC L75; DD L89 | proposed | not started | effective-dated position_history.is_root and deferred coverage; 002b |
| R4-09 | Medium | SQL L28; DEC L67 | owner decision D31; detail proposed | not started | one request multiple affected companies, approval per company; 002b |
| R4-10 | Medium | DD L91/L93; TRACE L45/L48/L59 | proposed; baseline catalog pending | not started | row_version, entity types, ledger, approved_at in DD; 002a |
| R4-11 | Low | DD L89; SQL L27 | proposed; legacy mapping pending | not started | scope enum + related_company audit/mapping; 002a |
| R4-12 | Low | ER L98/L106 | proposed; full ER reconciliation pending | not started | nullable company group, migration edges, root attribute; 002b |
| R4-13 | Low | TRACE L34-62 | partial | not started | R4 table has separate severity/source/doc/impl; original F/A/T/M table still needs same metadata |
| R4-14 | Low | DD L85 | proposed | not started | mandatory per-employee row locking for all writers; 002a |
| R4-15 | Low | DEC L79 | proposal pending benchmark | not started | as-of history view and indexed predicates, no current-master cache for authorization; 003 |
| R4-16 | Low | DEC L73 | owner decision D33 | not started | never recycle employee code; no hard-delete; 002a |

**Review gates:** R4-05 editorial reconciliation, R4-07 full test coverage, R4-10 baseline schema reconciliation, R4-11 legacy enum mapping and R4-13 original finding metadata remain open. Never describe a proposed design as an implemented fix.

## Revision 6 — Claude R5 findings disposition (documentation only)
| Finding | Doc disposition | Implementation | Gate / verification |
|---|---|---|---|
| R5-01 High | D09/D32 and metric fixture reconciled | not started | Confirm no obsolete unallocated wording |
| R5-02 High | Canonical request statuses and compensating cancellation D34 proposed | not started | Compare all baseline enum values and transitions before 002a-2 |
| R5-03 High | Workflow pinned once at first submit; draft nullable | not started | Composite FK and return/resubmit test |
| R5-04 High | Per-company step instances + single request_approvals evidence table; activation does not reopen approval | not started | Independent review before 002b |
| R5-05 Medium | granted_owner_company_id and fail-closed as-of RLS proposed | not started | 002b/003 ownership-transfer test |
| R5-06 Medium | Draft conflicts edited in source; remaining editorial audit required | not started | Cross-file text search and independent review |
| R5-07 Medium | Ledger is only attempt/error source, phase/key specified | not started | 002a-2 replay/retry tests |
| R5-08 Medium | D35/D36 employee lifecycle, immutable code | not started | 002a-1 lifecycle tests |
| R5-09 Medium | Import/reserve former employee codes | not started | MIG-02 legacy collision audit |
| R5-10 Medium | Added test scenarios and X1–X26 matrix | not started | Run after SQL; check original source fixtures |
| R5-11 Low | Original 29 findings severity/source/doc/impl metadata still needs independent reconciliation | not started | Documentation review |
| R5-12 Low | Entity allowlist and column/type proposals normalized | not started | Baseline SQL catalog |
| R5-13 Low | No clamp; negative residual flagged as data-quality error | not started | REP-01 |
| R5-14 Low | Remove unused related_company from new enum subject to verifying no existing workflow rows | not started | 002a catalog |
| R5-15 Low | Proposed PERF-01 benchmark in TEST_PLAN | not started | Agree SLA before 003 |

**Original F/A/T/M metadata (all 29):** severity/source classifications in Claude R5 review section D1 are proposed and not independent severity verification. F-01 Critical; F-02..F-08 High; F-09..F-19 Medium; F-20..F-22 Low; A-01 High; A-02..A-04 Medium; A-05 Low; T-01 and M-01 Medium. Source for each is Claude's original F/A/T/M review as reproduced in R5 section D; documentation status is proposed/decision closed only where explicitly noted in the original table; implementation status is NOT STARTED for every row. Original table above is retained for exact per-ID descriptions and tests.

## Revision 6.1 — narrowly scoped R6 gates (documentation only)
| Finding | 6.1 response | Implementation status | Next gate |
|---|---|---|---|
| R6-01 High | Supersede columns, partial exclusion, provenance, compensating link and example in DECISIONS/DD; only employee_company_history targeted for 002a-1 | NOT STARTED | Independent review of replacement timeline and baseline FK before SQL; other histories 002a-2/002b |
| R6-03 Medium | Single normalized employee_code_registry including unbound legacy reservations | NOT STARTED | Legacy collision audit, FK/trigger review before 002a-1 |
| R6-04 Medium | BEFORE UPDATE/DELETE/TRUNCATE triggers plus runtime REVOKE and owner privilege boundary | NOT STARTED | PostgreSQL negative tests EMP-05/AUD-02 |
| R6-08 Medium | Non-cancelled historical HC predicate; inactive migration gated on data audit; Bangkok date | NOT STARTED | EMP-04/09 and legacy audit |
| R6-09 Medium | EMP-04/05/06 plus supplementary 002a-1 cases | NOT STARTED | Execute on disposable PostgreSQL after SQL implementation |
| R6-05 (002a-1 subset) | DD old unallocated/open and home-company alternatives reconciled; organization-related editorial cleanup deferred | NOT STARTED | Independent targeted text review; full cleanup before 002a-2/002b |
| R6-02, R6-06, R6-07, R6-10..R6-13 | Not within 6.1 six-item implementation gate; R6-02 race and APR-13 explicitly deferred to 002a-2; other items retain original report deadlines | NOT STARTED | Do not mark resolved or merge main based on 6.1 |

**Timezone owner confirmation:** Asia/Bangkok (UTC+07:00). **Review boundary:** documentation addendum only; no SQL/application edits, migration execution, tests or merge. 002a-1 may start only after targeted independent review accepts the six gate items and the baseline-compatible provenance/status strategy.
