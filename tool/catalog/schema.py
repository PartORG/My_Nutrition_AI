"""Catalogue v4 schemas (db/catalog/*.sql) with the nutrient panel expanded (docs/PLAN.md "Catalogue v4").

python3 tool/catalog/schema.py nutri    # prints the expanded SQL
"""

import sqlite3
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[2] / "db/catalog"
MARKER = "/*NUTRIENTS*/"


def nutrients() -> list[dict]:
    """db/catalog/nutrients.tsv → rows (key, unit, group, name), in column order."""
    lines = [l for l in (CATALOG / "nutrients.tsv").read_text().splitlines() if l.strip() and not l.startswith("#")]
    head, *body = (l.split("\t") for l in lines)
    return [dict(zip(head, row + [""] * (len(head) - len(row)), strict=True)) for row in body]  # empty trailing codes


def recipe_nutrition_view() -> str:
    """Per serving from the lines with a food and grams; known = the nutrients only some of those lines know."""
    keys = [n["key"] for n in nutrients()]
    sums = ",\n       ".join(f"SUM(f.{k} * ri.grams / 100) / r.servings AS {k}" for k in keys)
    known = " ||\n       ".join(
        f"CASE WHEN COUNT(f.{k}) BETWEEN 1 AND COUNT(*) - 1 THEN '{k}:' || COUNT(f.{k}) || '/' || COUNT(*) || ',' "
        f"ELSE '' END" for k in keys)
    return (f"CREATE VIEW recipe_nutrition AS\nSELECT r.id AS recipe_id,\n       {sums},\n"
            f"       rtrim({known}, ',') AS known\nFROM recipes r\nJOIN recipe_ingredients ri ON ri.recipe_id = r.id "
            f"AND ri.food_id IS NOT NULL AND ri.grams > 0\nJOIN foods f ON f.id = ri.food_id\nGROUP BY r.id")


def sql(name: str) -> str:
    """The schema of nutri.db, health.db or products.db, one REAL column per nutrient at the marker."""
    return ((CATALOG / f"{name}.sql").read_text()
            .replace(MARKER, ",\n  ".join(f"{n['key']} REAL" for n in nutrients()))
            .replace("/*RECIPE_NUTRITION*/", recipe_nutrition_view()))


def create(path: str | Path, name: str) -> sqlite3.Connection:
    con = sqlite3.connect(path)
    con.executescript(sql(name))
    return con


if __name__ == "__main__":
    print(sql(sys.argv[1]))
