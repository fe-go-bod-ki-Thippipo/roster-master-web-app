# R2.1 Review Traceability — Revision 3
Source: Claude R2.1 review (PR #2), IDs R-01..R-13 and suggestions S-01..S-04. This document tracks *design responses*, not SQL implementation or independently verified closure. Earlier F-01..F-22, A-01..A-05, T-01, M-01 must be transcribed from the complete earlier review before R2.2; the R2.1 review mentions only a subset, so do not invent descriptions or claim all earlier findings are resolved.

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
