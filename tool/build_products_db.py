# /// script
# requires-python = ">=3.12"
# dependencies = ["duckdb", "openpyxl"]
# ///
"""Build products.db (the optional "all packaged products" download) from the current Open Food Facts dump.

    curl -L -o products.csv.gz https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz
    uv run tool/build_products_db.py products.csv.gz products.db
    gzip -k -9 products.db        # products.db.gz is what the app downloads (lib/app_state.dart productsUrl)

Same rows and checks as nutri.db's 2019 products (build_real_nutri_db.off_product): a barcode, a name,
kcal/protein/fat/carbs present and plausible. Same table and FTS as nutri.db, so the app searches either.
Open Food Facts is ODbL: the app credits it and the database stays open.
"""

import csv
import gzip
import sqlite3
import sys
from collections import Counter
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_real_nutri_db import MICROS, NUTRIENTS, off_product, r3  # noqa: E402

csv.field_size_limit(sys.maxsize)
SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE products (
  barcode TEXT PRIMARY KEY, name TEXT NOT NULL,
  kcal REAL NOT NULL, protein_g REAL NOT NULL, fat_g REAL NOT NULL, carbs_g REAL NOT NULL,
  fiber_g REAL, sugar_g REAL, sodium_mg REAL,
  -- From the label, per 100 g; NULL = not on it.
  calcium_mg REAL, iron_mg REAL, magnesium_mg REAL, potassium_mg REAL, vitamin_c_mg REAL, vitamin_d_ug REAL,
  vitamin_b12_ug REAL
);
CREATE VIRTUAL TABLE products_fts USING fts5 (name, barcode UNINDEXED, content = 'products');
"""


def main(src: Path, out: Path) -> None:
    tmp = out.with_suffix(".tmp")
    tmp.unlink(missing_ok=True)
    db = sqlite3.connect(tmp)
    db.execute("PRAGMA journal_mode = OFF")
    db.executescript(SCHEMA)
    dropped, rows, batch = Counter(), 0, []
    with gzip.open(src, "rt", encoding="utf-8", errors="replace", newline="") as fh:
        for r in csv.DictReader(fh, delimiter="\t", quoting=csv.QUOTE_NONE):
            rows += 1
            got = off_product(lambda k: r.get(k) or "")
            if isinstance(got, str):
                dropped[got] += 1
                continue
            batch.append((got["barcode"], got["name"], *(r3(got[k]) for k in NUTRIENTS), *(r3(got[m]) for m in MICROS)))
            if len(batch) >= 50_000:
                db.executemany(f"INSERT OR IGNORE INTO products VALUES ({",".join("?" * 16)})", batch)
                batch.clear()
    db.executemany(f"INSERT OR IGNORE INTO products VALUES ({",".join("?" * 16)})", batch)
    kept = db.execute("SELECT COUNT(*) FROM products").fetchone()[0]
    db.executemany("INSERT INTO meta VALUES (?, ?)", [
        ("schema_version", "2"), ("built_at", date.today().isoformat()), ("rows", str(kept)),
        ("source", "Open Food Facts (ODbL), en.openfoodfacts.org.products.csv; tool/build_products_db.py")])
    db.execute("INSERT INTO products_fts(products_fts) VALUES ('rebuild')")
    db.commit()
    db.execute("VACUUM")
    db.close()
    tmp.replace(out)
    print(f"{rows:,} rows, {kept:,} kept, {out.stat().st_size:,} bytes; dropped: {dict(dropped.most_common())}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]), Path(sys.argv[2]))
