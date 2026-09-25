# Migration 002a-1 — Step 1 implementation gates

Status: IN PROGRESS; this is an implementation checklist, not an acceptance or deployment authorization.
Baseline: 15e0f3de432d1a96d1feb23f351450893c684409 (Claude accepted R-01).

## Dependency order
1. Preserve existing baseline schema and CI; retain inclusive `effective_to + 1` overlap semantics.
2. Introduce a privileged, transactional employee/history writer. Reserve normalized employee codes atomically; no direct runtime INSERT into employee or registry tables.
3. For a request-sourced company-history write, lock employee and request, verify final approval and actual approval evidence, then validate effective-date coverage and company transfer continuity. A `change_requests.status = 'approved'` flag alone is not sufficient evidence of authorized approval.
4. Implement supersede as an approved compensating request: lock affected history, mark old versions superseded once, insert complete replacement intervals in the same transaction, preserve original dates, provenance and audit. Reject draft/returned/rejected requests; prohibit ordinary UPDATE/DELETE of historical payload.
5. Add deferred, transaction-end coverage checks for all employment days [hire_date, termination_date] inclusive, including future intervals, while permitting atomic multi-row replacement inside one transaction. Lock by employee to serialize concurrent writers.
6. Add tests for initial hire, uninterrupted transfer, one-day gap, termination day, future-approved transfer, overlapping transfer, supersede/cancellation, missing approval evidence, double supersede, concurrent writers, immutable audit, registry mismatch and failed transaction rollback.
7. Adjust `test_company_history_overlap.sql` fixture **in the same commit** that activates approval/registry guards (R-03); it currently uses a draft request and has no employee-code registry reservation. Do not weaken production guards merely to accommodate the fixture.
8. Track N-05 surviving mutations and R-02 deferred/other-employee behavior before final acceptance.

## Safety boundary
Migration 002a-1 is not complete. No deploy, no main merge, no claim of production authorization. PostgreSQL 15/16 non-superuser CI and independent review are required after implementation.
