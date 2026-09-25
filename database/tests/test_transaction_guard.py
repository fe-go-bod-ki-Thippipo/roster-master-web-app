#!/usr/bin/env python3
"""Negative tests for migration SQL transaction preflight."""
import subprocess
import tempfile
from pathlib import Path

CASES = {
    "begin_comment": ("BEGIN /* split */ TRANSACTION;", False),
    "commit_multiline": ("COMMIT\nWORK;", False),
    "rollback_comment": ("ROLLBACK /* comment */;", False),
    "start_transaction": ("START TRANSACTION;", False),
    "savepoint": ("SAVEPOINT x;", False),
    "release_savepoint": ("RELEASE SAVEPOINT x;", False),
    "rollback_to": ("ROLLBACK TO SAVEPOINT x;", False),
    "prepare_transaction": ("PREPARE TRANSACTION 'gid';", False),
    "psql_include": ("\\i other.sql\nSELECT 1;", False),
    "psql_gexec": ("SELECT 1 \\gexec", False),
    "comment_only": ("-- BEGIN;\nSELECT 1;", True),
    "string_literal": ("SELECT 'COMMIT;';", True),
    "dollar_literal": ("SELECT $$ROLLBACK;$$;", True),
}
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "probe.sql"
    for name, (sql, allowed) in CASES.items():
        path.write_text(sql, encoding="utf-8")
        result = subprocess.run(
            ["python3", "database/tests/check_migration_sql.py", str(path)],
            capture_output=True, text=True,
        )
        if (result.returncode == 0) != allowed:
            raise AssertionError(
                f"{name}: expected {'accept' if allowed else 'reject'}, "
                f"got exit {result.returncode}: {result.stderr}"
            )
        print(f"PASS: {name} {'accepted' if allowed else 'rejected'}")
