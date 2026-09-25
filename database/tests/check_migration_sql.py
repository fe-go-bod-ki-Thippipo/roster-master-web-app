#!/usr/bin/env python3
"""Fail closed on transaction statements and psql meta commands in migration SQL."""
import sys
from pathlib import Path
from pglast import parse_sql, ast, visitors

def check(path: str) -> None:
    source = Path(path).read_text(encoding="utf-8")
    # Migration files are SQL, not psql scripts. A backslash at the beginning
    # of a line can change client execution independently of SQL parsing.
    for number, line in enumerate(source.splitlines(), 1):
        if line.lstrip().startswith("\\"):
            raise ValueError(f"{path}:{number}: psql meta-command forbidden")
    tree = parse_sql(source)
    for raw in tree:
        if isinstance(raw.stmt, ast.TransactionStmt):
            raise ValueError(f"{path}: transaction control forbidden")
    # Transaction control nested in a DO block is not parsed as top-level SQL;
    # a runtime guard and the ledger rollback tests remain mandatory.
if __name__ == "__main__":
    try:
        for file in sys.argv[1:]:
            check(file)
    except Exception as exc:
        print(f"TRANSACTION_CONTROL_FORBIDDEN: {exc}", file=sys.stderr)
        sys.exit(4)
