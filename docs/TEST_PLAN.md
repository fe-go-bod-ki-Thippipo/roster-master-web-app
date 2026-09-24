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