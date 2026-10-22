"""Catalogue v4 schemas load and hold their rules.

uv run --with pytest pytest tool/catalog/test_schema.py
"""

import re
import sqlite3

import pytest

import schema


def test_nutrient_panel_keys_are_unique_columns_with_their_unit():
    keys = [n["key"] for n in schema.nutrients()]
    assert len(keys) == len(set(keys))
    assert keys[:4] == ["kcal", "protein_g", "fat_g", "carbs_g"]
    for n in schema.nutrients():
        assert re.fullmatch(r"[a-z0-9_]+", n["key"])
        unit = {"g": "_g", "mg": "_mg", "µg": "_ug", "kcal": "kcal"}[n["unit"]]
        assert n["key"].endswith(unit), n


@pytest.mark.parametrize("name", ["nutri", "health"])
def test_schemas_load(name):
    con = schema.create(":memory:", name)
    assert schema.MARKER not in schema.sql(name)
    assert con.execute("SELECT count(*) FROM meta").fetchone() == (0,)


def test_nutrient_columns_on_foods_and_recipe_totals():
    keys = [n["key"] for n in schema.nutrients()]
    nutri = schema.create(":memory:", "nutri")
    for table in ["foods", "recipe_nutrition"]:
        cols = [r[1] for r in nutri.execute(f"PRAGMA table_info({table})")]
        assert [c for c in cols if c in keys] == keys, table


def test_one_default_row_per_common_name_and_a_food_twice_in_a_recipe():
    con = schema.create(":memory:", "nutri")
    con.execute("INSERT INTO sources (id, name, licence) VALUES ('usda_sr28', 'USDA SR28', 'public domain')")
    food = "INSERT INTO foods (id, name, common_name, is_default, source_id, kcal) VALUES (?, ?, 'banana', ?, 'usda_sr28', 89)"
    con.execute(food, (1, "Bananas, raw", 1))
    con.execute(food, (2, "Bananas, dried", 0))
    with pytest.raises(sqlite3.IntegrityError):
        con.execute(food, (3, "Banana, pulp, raw", 1))
    con.execute(
        "INSERT INTO recipes (id, title, title_en, servings, source_id) VALUES (1, 'Banana bread', 'Banana bread', 8, 'usda_sr28')"
    )
    line = "INSERT INTO recipe_ingredients (recipe_id, position, food_id, grams, line, line_en) VALUES (1, ?, 1, 100, 'x', 'x')"
    con.execute(line, (1,))
    con.execute(line, (2,))  # the same food on another line
    with pytest.raises(sqlite3.IntegrityError):
        con.execute(line, (2,))


def test_condition_rule_needs_a_limit_and_a_source():
    con = schema.create(":memory:", "health")
    con.execute("PRAGMA foreign_keys = ON")
    con.execute("INSERT INTO sources (id, name, licence) VALUES ('who', 'WHO', 'CC BY-NC-SA 3.0 IGO')")
    con.execute(
        "INSERT INTO conditions (id, key, name, summary, source_id) VALUES (1, 'hypertension', 'High blood pressure', 's', 'who')"
    )
    con.execute(
        "INSERT INTO condition_rules (condition_id, nutrient, max_per_day, source_id) VALUES (1, 'sodium_mg', 2000, 'who')"
    )
    with pytest.raises(sqlite3.IntegrityError):
        con.execute("INSERT INTO condition_rules (condition_id, nutrient, source_id) VALUES (1, 'kcal', 'who')")
    with pytest.raises(sqlite3.IntegrityError):
        con.execute(
            "INSERT INTO condition_rules (condition_id, nutrient, max_per_day, source_id) VALUES (1, 'fat_g', 70, 'nobody')"
        )
