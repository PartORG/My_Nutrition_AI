"""DRI table parsing and a recipe's nutrition per serving with its coverage.

    uv run --with pytest pytest tool/catalog/test_health_and_recipes.py
"""

from pathlib import Path

import pytest

import schema
from readers import dri

DATA = Path(__file__).resolve().parents[3] / "nutrition-ai-assistant/data"


def test_age_bands_and_values():
    assert dri.ages("0–6 mo") == (0, 7 / 12)
    assert dri.ages("19–30 y") == (19, 31)
    assert dri.ages("> 70 y") == (71, 200)
    assert dri.ages("≤ 18 y") == (14, 19)
    assert dri.value("1,300 Table 1 footnote *") == (1300, True), "an asterisk marks an AI"
    assert dri.value("ND") is None


@pytest.mark.skipif(not (DATA / "raw_medical/dri").exists(), reason="the Health Canada pages are not downloaded")
def test_published_values_come_through():
    rows = dri.read(DATA)

    def q(nutrient, sex, age, kind, stage=""):
        return [r["amount"] for r in rows if r["nutrient"] == nutrient and r["sex"] == sex and r["kind"] == kind
                and r["age_from"] <= age < r["age_to"] and r["life_stage"] == stage]

    assert q("vitamin_c_mg", "male", 25, "rda") == [90]
    assert q("folate_ug", "female", 25, "rda", "pregnancy") == [600]
    assert q("sodium_mg", "male", 40, "ul") == [2300], "sodium's CDRR is its upper limit"
    assert q("copper_mg", "female", 30, "rda") == [0.9], "µg/day converted to the panel's mg"
    assert q("fat_g", "any", 30, "amdr_min") == [20] and q("fat_g", "any", 30, "amdr_max") == [35]


def test_recipe_nutrition_per_serving_says_how_many_lines_knew_each_value():
    con = schema.create(":memory:", "nutri")
    con.execute("INSERT INTO sources (id, name, licence) VALUES ('s', 's', 'x')")
    con.execute("INSERT INTO foods (id, name, common_name, source_id, kcal, iodine_ug) VALUES (1, 'a', 'a', 's', 100, 10)")
    con.execute("INSERT INTO foods (id, name, common_name, source_id, kcal) VALUES (2, 'b', 'b', 's', 50)")
    con.execute("INSERT INTO recipes (id, title, title_en, servings, source_id) VALUES (7, 't', 't', 2, 's')")
    line = "INSERT INTO recipe_ingredients (recipe_id, position, food_id, grams, line) VALUES (7, ?, ?, ?, 'x')"
    con.executemany(line, [(1, 1, 200), (2, 2, 100), (3, None, 0)])  # the third: "salt to taste"
    row = dict(zip([d[0] for d in con.execute("SELECT * FROM recipe_nutrition").description],
                   con.execute("SELECT * FROM recipe_nutrition").fetchone(), strict=True))
    assert row["kcal"] == 125  # (200 + 50) / 2
    assert row["iodine_ug"] == 10, "only the first line knows it"
    assert row["known"] == "iodine_ug:1/2", "water and 'salt to taste' lines don't count"
    assert row["zinc_mg"] is None
