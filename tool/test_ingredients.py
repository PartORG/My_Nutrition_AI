"""Checks for the real nutri.db pipeline: line parsing, allergen words, food checks.

    uv run --with pytest --with duckdb --with openpyxl pytest tool/test_ingredients.py
"""

import pytest

import build_real_nutri_db as b
import ingredients as ing


@pytest.mark.parametrize("line, qty, unit, name", [
    ("1   small    onion, chopped ", 1, "small", "onion"),
    ("2 (21   ounce) cans   cherry pie filling", 42, "ounce", "cherry pie filling"),
    ("1 (14 oz) can sweetened condensed milk (not evaporated)", 14, "oz", "sweetened condensed milk"),
    ("2 x 400g cans chopped tomatoes", 800, "g", "tomatoes"),
    ("1 x 5kg/11lb good-quality free-range turkey", 5, "kg", "turkey"),
    ("40g/1½oz unsalted butter, softened", 40, "g", "unsalted butter"),
    ("20ml/¾fl oz rapeseed oil", 20, "ml", "rapeseed oil"),
    ("7g sachet fast action yeast", 7, "g", "fast action yeast"),
    ("1½ tsp salt", 1.5, "tsp", "salt"),
    ("1-1/2 cups Spinach Leaves (Palak) - or 1 bunch", 1.5, "cups", "spinach leaves"),
    ("1 -2   clove    garlic, minced ", 1.5, "clove", "garlic"),
    ("2-3 carrots", 2.5, None, "carrots"),
    ("¼ cup milk", 0.25, "cup", "milk"),
    ("2 T butter", 2, "T", "butter"),
    ("2 t sugar", 2, "t", "sugar"),
    ("1/2  cup   firmly packed light brown sugar", 0.5, "cup", "light brown sugar"),
    ("a good pinch of oregano", 1, "pinch", "oregano"),
    ("handful of rocket leaves", 1, "handful", "rocket leaves"),
    ("  ground pepper, to taste ", None, None, "ground pepper"),
    ("3   teaspoons    earl grey tea or 3   teaspoons   ceylon tea", 3, "teaspoons", "earl grey tea"),
    ("1 garlic clove", 1, None, "garlic clove"),
    ("1 lemon", 1, None, "lemon"),
])
def test_parse_line(line, qty, unit, name):
    q, u, rest = ing.parse_line(line)
    assert (q is None and qty is None) or q == pytest.approx(qty)
    assert u == unit
    assert ing.normalize_name(rest) == name


def test_units():
    assert ing.unit_kind("T") == ("volume", 14.79)   # tablespoon
    assert ing.unit_kind("t") == ("volume", 4.93)    # teaspoon
    assert ing.unit_kind("lbs")[0] == "mass"
    assert ing.unit_kind(None) == ("count", 1.0)


@pytest.mark.parametrize("text, want", [
    ("eggplant", set()), ("scalloped potatoes", set()), ("oyster mushrooms", set()),
    ("coconut milk", set()), ("almond milk", {"tree nuts"}), ("peanut butter", {"peanuts"}),
    ("butternut squash", set()), ("nutmeg", set()), ("water chestnuts", set()),
    ("corn tortillas", set()), ("flour tortillas", {"gluten"}), ("rice flour", set()),
    ("bacon, cooked and crumbled", set()), ("creamy peanut butter", {"peanuts"}),
    ("shrimp, peeled and butterflied", {"shellfish"}), ("catfish fillets", {"fish"}),
    ("soy sauce", {"soy", "gluten"}), ("worcestershire sauce", {"fish"}), ("pesto", {"tree nuts"}),
    ("hummus", {"sesame"}), ("egg noodles", {"egg", "gluten"}), ("Butter, with salt", {"milk"}),
    ("Salad dressing, mayonnaise, regular", {"egg"}), ("ritz crackers", {"gluten"}),
])
def test_allergens_from_text(text, want):
    assert b.allergens_from_text(text) == want


def test_chosen_text_uses_first_alternative():
    assert b.chosen_text("butter or margarine (or oil)").strip() == "butter"
    assert "pie" not in b.chosen_text("pumpkin puree (not pie filling)")


@pytest.mark.parametrize("n, ok", [
    ({"kcal": 52, "protein_g": 0.3, "fat_g": 0.2, "carbs_g": 13.8, "fiber_g": 2.4, "sugar_g": 10.4}, True),   # apple
    ({"kcal": 51, "protein_g": 0.9, "fat_g": 5, "carbs_g": 0.8}, True),                                       # consistent
    ({"kcal": 600, "protein_g": 1, "fat_g": 1, "carbs_g": 10}, False),                                        # kcal off
    ({"kcal": 300, "protein_g": 60, "fat_g": 30, "carbs_g": 30}, False),                                      # > 100 g
    ({"kcal": 100, "protein_g": 1, "fat_g": 1, "carbs_g": 20, "sugar_g": 30}, False),                         # sugar > carbs
    ({"kcal": 231, "protein_g": 0, "fat_g": 0, "carbs_g": 0}, True),                                         # vodka
])
def test_check(n, ok):
    assert (b.check(n, "Vodka" if n["kcal"] == 231 else "x") is None) == ok


def test_sr_long_name_refuses_ties():
    oils = [("Oil, soybean, salad or cooking", 0, 100, b.toks("Oil, soybean, salad or cooking")),
            ("Oil, sesame, salad or cooking", 0, 100, b.toks("Oil, sesame, salad or cooking"))]
    assert b.sr_long_name("oil, soybn, salad or cooking", oils) == "Oil, soybean, salad or cooking"
    assert b.sr_long_name("oil, salad or cooking", oils) is None  # can't tell which: no name rather than a wrong one
    butter = [("Butter, without salt", 1, 81, b.toks("Butter, without salt"))]
    assert b.sr_long_name("butter, with salt", butter) is None


def test_iso_minutes_and_lists():
    assert b.iso_minutes("PT1H30M") == 90
    assert b.iso_minutes("1 hrs 30 mins") == 90
    assert b.iso_minutes("180") == 180
    assert b.iso_minutes("10 mins") == 10
    assert b.iso_minutes("1 hr and 15 mins") == 75
    assert b.iso_minutes("No Time") is None
    assert b.lst('["1. Add KELLOGG"S cereal.", "2. Bake"]') == ['1. Add KELLOGG"S cereal.', "2. Bake"]
    assert b.lst('c("a", "b")') == ["a", "b"]


def test_stable_id_is_stable():
    assert b.stable_id("recipe", "food.com", 38) == b.stable_id("recipe", "food.com", 38) < 2 ** 53
