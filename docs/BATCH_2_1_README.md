# Roster Master — Batch 2.1 foundation package

This is a **design/development starter**, not a deployed Web App. Original `roster_master_structure_v5_41.html` was not modified. No employee data was imported.

Files:
- `001_schema.sql`: PostgreSQL 15+ foundational physical schema; run only on a new disposable database initially.
- `API_SPEC.md`: draft backend routes, payload and permission contract.
- `002_security_and_integrity_plan.md`: mandatory additional enforcement before production.
- `TEST_PLAN.md`: database smoke tests and backend integration acceptance tests.

Important unresolved items: employee total FTE policy; final workflow catalog and approver assignments; source JSON data audit; full Row Level Security policies; future effective-date activation; SQL-based hierarchy cycle protection; migration script and rollback/restore rehearsal. Do not put real personnel data into this starter before those controls are built and tested.