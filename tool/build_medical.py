"""Write the medical tables of a nutri.db from db/medical.sql (Python stdlib only).

    python3 tool/build_medical.py assets/nutri.db

Replaces conditions, condition_rules, condition_avoid and docs in place, in one transaction,
so a medical update needs no full rebuild. tool/build_real_nutri_db.py calls apply() too.
"""

import re
import sqlite3
import sys
from pathlib import Path

MEDICAL_SQL = Path(__file__).resolve().parent.parent / "db/medical.sql"


def apply(db: sqlite3.Connection) -> dict[str, int]:
    """Returns row counts for the build report."""
    db.create_function("regexp", 2, lambda p, v: v is not None and re.search(p, v) is not None, deterministic=True)
    db.execute("PRAGMA foreign_keys = ON")
    # One script, one transaction: a failing statement leaves the old tables untouched.
    db.executescript("BEGIN;"
                     "DELETE FROM condition_avoid; DELETE FROM condition_rules; DELETE FROM docs; DELETE FROM conditions;"
                     + MEDICAL_SQL.read_text() +
                     ";INSERT INTO docs_fts(docs_fts) VALUES ('rebuild');")
    if bad := db.execute("PRAGMA foreign_key_check").fetchall():
        db.rollback()
        raise SystemExit(f"foreign key violations: {bad[:5]}")
    db.commit()
    counts = {f"{t} rows": db.execute(f"SELECT count(*) FROM {t}").fetchone()[0]
              for t in ("conditions", "condition_rules", "docs")}
    for name, n in db.execute("SELECT c.name, count(a.food_id) FROM conditions c "
                              "LEFT JOIN condition_avoid a ON a.condition_id = c.id GROUP BY c.id"):
        counts[f"foods to avoid: {name}"] = n
    return counts


if __name__ == "__main__":
    if len(sys.argv) != 2 or not Path(sys.argv[1]).exists():
        raise SystemExit(__doc__)
    con = sqlite3.connect(sys.argv[1])
    for k, v in apply(con).items():
        print(f"{k}: {v}")
    con.close()
