"""Everyday names and the default form of a food.

uv run --with pytest pytest tool/catalog/test_names.py
"""

import pytest

from names import common_name, default_score, singular, state


@pytest.mark.parametrize(
    "name, common",
    [
        ("Bananas, raw", "banana"),
        ("Banana, pulp, raw", "banana"),
        ("Bananas, flesh only", "banana"),
        ("Egg, whole, cooked, hard-boiled", "hard-boiled egg"),
        ("Egg, whole, raw, fresh", "egg"),
        ("Chicken, breast, flesh, roasted", "chicken breast"),
        ("Chicken, broilers or fryers, breast, meat only, cooked, roasted", "chicken breast"),
        ("Bread, white", "white bread"),
        ("Beans, kidney, all types, mature seeds, cooked, boiled", "kidney bean"),
        ("Bread, white wheat, sliced, prepacked, composite", "white wheat bread"),
        ("Rice, white, long-grain, regular, cooked", "white rice"),
        ("Oil, olive, salad or cooking", "olive oil"),
        ("Cheese, cheddar", "cheddar cheese"),
        ("Beef, ground, 80% lean meat / 20% fat, raw", "ground beef"),
        ("Tomatoes, red, ripe, raw, year round average", "tomato"),
        ("Apples, raw, with skin (Includes foods for USDA's Food Distribution Program)", "apple"),
        ("Strawberries, raw", "strawberry"),
        ("Asparagus, raw", "asparagus"),
        ("Hummus, commercial", "hummus"),
    ("Spices, cinnamon, ground", "cinnamon"),
    ("Nuts, pecans", "pecan"),
    ("Tomato products, canned, paste, without salt added", "tomato paste"),
    ("Soup, chicken broth, canned, ready-to-serve", "chicken broth"),
    ("Leavening agents, baking soda", "baking soda"),
    ("Coriander (cilantro) leaves, raw", "coriander leaf"),
        ("(Crunchy), peanut butter", "peanut butter"),
        ("(Ghee)", "ghee"),
    ],
)
def test_common_name(name, common):
    assert common_name(name) == common


def test_singular_keeps_words_that_end_in_s():
    assert [singular(w) for w in ["berries", "potatoes", "peaches", "glass", "couscous", "oats"]] == [
        "berry",
        "potato",
        "peach",
        "glass",
        "couscous",
        "oat",
    ]


def test_default_is_the_plain_form_raw_fruit_cooked_rice_and_government_tables_first():
    rank = {"usda_sr": 0, "ciqual": 1, "healthy_foods_db": 9}

    def best(*foods):
        rows = [
            {"name": n, "source": s, "common_name": common_name(n), "authoritative": s != "healthy_foods_db"}
            for n, s in foods
        ]
        return min(rows, key=lambda f: default_score(f, rank))["name"]

    assert best(("Bananas, dehydrated, or banana powder", "usda_sr"), ("Bananas, raw", "usda_sr")) == "Bananas, raw"
    assert (
        best(
            ("Rice, white, long-grain, regular, raw", "usda_sr"),
            ("Rice, white, long-grain, regular, cooked", "usda_sr"),
        )
        == "Rice, white, long-grain, regular, cooked"
    )
    assert best(("Banana, raw", "healthy_foods_db"), ("Banana, pulp, raw", "ciqual")) == "Banana, pulp, raw"
    assert (
        best(("Chicken Breast", "healthy_foods_db"), ("Chicken, breast, roasted, meat only, average", "ciqual"))
        == "Chicken, breast, roasted, meat only, average"
    ), "a government table before fewer words"
    assert state("Egg, whole, cooked, hard-boiled") == "cooked"


def test_a_defaults_alias_belongs_only_to_its_food():
    from match import match_foods

    def row(code, name):
        return {"source": "frida", "code": code, "name": name, "category": "food"}

    rows = [row("1", "Rice, boiled"), row("2", "Rice, white, medium-grain, enriched, cooked")]
    defaults = [{"alias": "rice", "source": "", "name": "Rice, white, medium-grain, enriched, cooked", "serving_g": None}]
    foods, _, _ = match_foods(rows, defaults)
    by_code = {f["code"]: f for f in foods}
    assert "rice" not in by_code["1"]["aliases"]
    assert "rice" in by_code["2"]["aliases"]


def test_a_translation_goes_to_the_english_names_owner_once_per_language():
    from write import translated_aliases

    foods = [
        {"id": 1, "common_name": "rice", "is_default": True, "aliases": []},  # the group default, not the owner
        {"id": 2, "common_name": "white rice", "is_default": True, "aliases": ["rice", "white rice"]},
        {"id": 3, "common_name": "rice bran", "is_default": True, "aliases": ["rice bran"]},
    ]
    names = {"rice": {"uk": "рис", "de": "Reis", "fr": "riz"}, "rice bran": {"uk": "Рис", "de": "Reiskleie", "fr": ""}}
    got = translated_aliases(foods, names)
    assert ("рис", "uk", 2) in got and ("Reis", "de", 2) in got
    assert [g for g in got if g[2] == 3] == [("Reiskleie", "de", 3)]
