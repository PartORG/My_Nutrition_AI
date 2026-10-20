"""The host tests' catalogue: test/nutri_test.db, test/health_test.db and test/products_test.db in the v4 schemas,
made from the same dummy data the v3 tests used (db/nutri_dummy.sql, loaded into the v3 schema and converted), so
the tests keep their foods, recipes and numbers.

    python3 tool/catalog/test_db.py
"""

import sqlite3
from pathlib import Path

import schema

ROOT = Path(__file__).resolve().parents[2]
KEYS = [n["key"] for n in schema.nutrients()]


def v3_dummy() -> sqlite3.Connection:
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    db.executescript((ROOT / "db/nutri_schema.sql").read_text())
    db.executescript((ROOT / "db/nutri_dummy.sql").read_text())
    return db


def fresh(name: str) -> sqlite3.Connection:
    path = ROOT / f"test/{name}_test.db"
    path.unlink(missing_ok=True)
    return schema.create(path, name)


def values(row: sqlite3.Row, keys=KEYS) -> list:
    return [row[k] if k in row.keys() else None for k in keys]  # noqa: SIM118 (`in row` tests values)


def nutri(v3: sqlite3.Connection) -> None:
    db = fresh("nutri")
    db.execute("INSERT INTO sources VALUES ('dummy', 'DUMMY development data', 'none', NULL, 0)")
    cols = ["id", "name", "common_name", "is_default", "category", "source_id", "serving_g", *KEYS]
    insert = f"INSERT INTO foods ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})"
    for f in v3.execute("SELECT * FROM foods"):
        common = f["name"].split(",")[0].strip().lower()
        db.execute(insert, (f["id"], f["name"], common, 1, "food", "dummy", f["serving_g"], *values(f)))
        db.executemany("INSERT OR IGNORE INTO food_aliases VALUES (?, 'en', ?)", [(f["name"].lower(), f["id"]),
                                                                                (common, f["id"])])
    for d in v3.execute("SELECT * FROM dishes WHERE kcal IS NOT NULL"):  # dishes are foods now (ids 101-)
        db.execute(insert, (100 + d["id"], d["name"], d["name"], 1, "dish", "dummy", d["serving_g"], *values(d)))
        db.execute("INSERT INTO food_aliases VALUES (?, 'en', ?)", (d["name"], 100 + d["id"]))
    db.executemany("INSERT INTO food_aliases VALUES (?, ?, ?)",
                   [(r["name"], r["lang"], r["food_id"]) for r in v3.execute("SELECT * FROM food_names")])
    db.executemany("INSERT INTO food_allergens VALUES (?, ?)",
                   [(r["food_id"], r["allergen"]) for r in v3.execute("SELECT * FROM allergens")])
    names = {r["id"]: r["name"] for r in v3.execute("SELECT id, name FROM foods")}
    for r in v3.execute("SELECT * FROM recipes"):
        db.execute("INSERT INTO recipes (id, title, title_en, servings, minutes, texture, source_id) "
                   "VALUES (?, ?, ?, ?, ?, ?, 'dummy')", (r["id"], r["title"], r["title"], r["servings"], r["minutes"],
                                                         r["texture"]))
        db.execute("INSERT INTO recipe_steps VALUES (?, 1, ?, NULL)", (r["id"], r["instructions"]))
        db.executemany("INSERT INTO recipe_tags VALUES (?, ?)", [(r["id"], t) for t in r["tags"].split(",") if t])
        lines = v3.execute("SELECT food_id, grams FROM recipe_ingredients WHERE recipe_id = ? ORDER BY rowid", (r["id"],))
        db.executemany("INSERT INTO recipe_ingredients (recipe_id, position, food_id, grams, line) VALUES (?, ?, ?, ?, ?)",
                       [(r["id"], i, x["food_id"], x["grams"], f"{x['grams']:g} g {names[x['food_id']]}")
                        for i, x in enumerate(lines, 1)])
    db.executemany("INSERT INTO meta VALUES (?, ?)", [("schema_version", "4"), ("data_version", "5"),
                                                      ("embedding_model", "embeddinggemma-300m"), ("built_at", "dummy")])
    for t in ("foods_fts", "recipes_fts"):
        db.execute(f"INSERT INTO {t}({t}) VALUES ('rebuild')")
    db.commit()


def health(v3: sqlite3.Connection) -> None:
    db = fresh("health")
    db.execute("INSERT INTO sources VALUES ('dummy', 'DUMMY', 'none', NULL)")
    titles = {"diabetes_t2": "Type 2 diabetes", "hypertension": "High blood pressure", "gout": "Gout",
              "als": "ALS (motor neurone disease)", "ms": "Multiple sclerosis"}
    db.executemany("INSERT INTO conditions VALUES (?, ?, ?, 'DUMMY', 'dummy')",
                   [(r["id"], r["name"], titles[r["name"]]) for r in v3.execute("SELECT * FROM conditions")])
    db.executemany("INSERT INTO condition_rules (condition_id, nutrient, max_per_day, note, source_id) "
                   "VALUES (?, ?, ?, ?, 'dummy')", [tuple(r) for r in v3.execute("SELECT * FROM condition_rules")])
    db.executemany("INSERT INTO condition_foods VALUES (?, ?, 'avoid', ?, 'dummy')",
                   [tuple(r) for r in v3.execute("SELECT condition_id, food_id, note FROM condition_avoid")])
    db.executemany("INSERT INTO docs (id, kind, text, source_id) VALUES (?, 'guideline', ?, 'dummy')",
                   [(r["id"], r["text"]) for r in v3.execute("SELECT * FROM docs")])
    db.executemany("INSERT INTO meta VALUES (?, ?)", [("schema_version", "1"), ("built_at", "dummy")])
    db.execute("INSERT INTO docs_fts(docs_fts) VALUES ('rebuild')")
    db.commit()


def products(v3: sqlite3.Connection) -> None:
    db = fresh("products")
    db.execute("INSERT INTO sources VALUES ('dummy', 'DUMMY', 'none', NULL)")
    cols = ["barcode", "name", "kind", "source_id", *KEYS]
    db.executemany(f"INSERT INTO products ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})",
                   [(p["barcode"], p["name"], "packaged", "dummy", *values(p)) for p in v3.execute("SELECT * FROM products")])
    db.executemany("INSERT INTO meta VALUES (?, ?)", [("schema_version", "4"), ("built_at", "dummy"), ("rows", "3")])
    db.execute("INSERT INTO products_fts(products_fts) VALUES ('rebuild')")
    db.commit()


if __name__ == "__main__":
    dummy = v3_dummy()
    for build in (nutri, health, products):
        build(dummy)
    print("test/nutri_test.db, test/health_test.db, test/products_test.db")
