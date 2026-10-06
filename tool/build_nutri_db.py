"""Build nutri.db from the schema plus data SQL files (Python stdlib only).

    python3 tool/build_nutri_db.py test/nutri_test.db db/nutri_schema.sql db/nutri_dummy.sql

tool/build_real_nutri_db.py builds the real one: schema, its own inserts, then finish().
"""

import sqlite3
import sys
from pathlib import Path

FTS_TABLES = ("foods_fts", "recipes_fts", "dishes_fts", "docs_fts", "products_fts")


def build(out: Path, sql_files: list[Path]) -> None:
    tmp = out.with_suffix(".tmp")
    tmp.unlink(missing_ok=True)
    db = sqlite3.connect(tmp)
    db.execute("PRAGMA foreign_keys = ON")
    for f in sql_files:
        db.executescript(f.read_text())
    finish(db, tmp, out)


def finish(db: sqlite3.Connection, tmp: Path, out: Path) -> None:
    """Index for search, check the contract, then swap tmp into place."""
    for t in FTS_TABLES:
        db.execute(f"INSERT INTO {t}({t}) VALUES ('rebuild')")
    if bad := db.execute("PRAGMA foreign_key_check").fetchall():
        raise SystemExit(f"foreign key violations: {bad}")
    for key in ("schema_version", "embedding_model", "built_at"):
        if not db.execute("SELECT 1 FROM meta WHERE key = ?", (key,)).fetchone():
            raise SystemExit(f"meta.{key} missing")
    db.commit()
    db.execute("VACUUM")
    db.close()
    tmp.replace(out)  # atomic: a failed build never leaves a half-written db


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    build(Path(sys.argv[1]), [Path(p) for p in sys.argv[2:]])
