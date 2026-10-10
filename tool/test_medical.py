"""Checks for db/medical.sql: foods to avoid hit the right foods, every row is sourced.

    uv run --with pytest pytest tool/test_medical.py
"""

import sqlite3
from pathlib import Path

import pytest

import build_medical

ROOT = Path(__file__).resolve().parent.parent
# (name, sugar_g per 100 g)
FOODS = [
    ("Chicken liver", 0), ("Beef, variety meats and by-products, kidneys, raw", 0), ("Lamb, offal, sweetbreads, raw", 0),
    ("Almonds, slivered", 4), ("Beans, kidney, all types, mature seeds, raw", 2), ("Artichoke hearts", 1),
    ("Chicken, roasting, meat and skin and giblets and neck, raw", 0),
    ("Beverages, carbonated, cola, regular", 9.9), ("Red Bull Energy Drink", 10), ("Lemonade", 10),
    ("Beverages, carbonated, low calorie, cola, with aspartame", 0), ("Coca-Cola Zero", 0),
    ("Chocolate sauce", 50), ("Butternut squash", 6), ("Barrels candy, root beer", 60), ("Cola Cao Original", 9),
]


@pytest.fixture(scope="module")
def db():
    con = sqlite3.connect(":memory:")
    con.executescript((ROOT / "db/nutri_schema.sql").read_text())
    con.executemany("INSERT INTO foods (id, name, kcal, protein_g, fat_g, carbs_g, sugar_g) VALUES (?, ?, 0, 0, 0, 0, ?)",
                    [(i, n, s) for i, (n, s) in enumerate(FOODS, 1)])
    build_medical.apply(con)
    yield con
    con.close()


def avoided(db, condition: str) -> set[str]:
    return {r[0] for r in db.execute("SELECT f.name FROM condition_avoid a JOIN foods f ON f.id = a.food_id "
                                     "JOIN conditions c ON c.id = a.condition_id WHERE c.name = ?", (condition,))}


def test_gout_avoids_organ_meat_and_sugary_drinks(db):
    assert avoided(db, "gout") == {"Chicken liver", "Beef, variety meats and by-products, kidneys, raw",
                                   "Lamb, offal, sweetbreads, raw", "Beverages, carbonated, cola, regular",
                                   "Red Bull Energy Drink", "Lemonade"}


def test_diabetes_avoids_sugary_drinks_only(db):
    assert avoided(db, "diabetes_t2") == {"Beverages, carbonated, cola, regular", "Red Bull Energy Drink", "Lemonade"}


def test_condition_ids_are_stable(db):
    # Profiles store these ids.
    assert db.execute("SELECT id, name FROM conditions ORDER BY id").fetchall() == [
        (1, "diabetes_t2"), (2, "hypertension"), (3, "gout"), (4, "als"), (5, "ms")]


def test_every_row_names_its_guideline(db):
    assert db.execute("SELECT count(*) FROM docs WHERE source = '' OR source LIKE '%DUMMY%'").fetchone()[0] == 0
    assert db.execute("SELECT count(*) FROM condition_rules WHERE coalesce(note, '') = ''").fetchone()[0] == 0
    assert db.execute("SELECT count(*) FROM docs_fts WHERE docs_fts MATCH 'gout'").fetchone()[0] > 0


def test_reapplying_replaces_rather_than_duplicates(db):
    before = db.execute("SELECT count(*) FROM condition_avoid").fetchone()[0]
    build_medical.apply(db)
    assert db.execute("SELECT count(*) FROM condition_avoid").fetchone()[0] == before
