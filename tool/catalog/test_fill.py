"""Gaps are filled from the same food in the same state, marked, never invented.

    uv run --with pytest pytest tool/catalog/test_fill.py
"""

from fill import fill


def food(source, state, authoritative=True, **nutrients):
    return {"source": source, "common_name": "banana", "state": state, "authoritative": authoritative,
            "nutrients": nutrients}


def test_borrowed_from_the_best_government_row_of_the_same_food_and_state():
    usda = food("usda_sr", "raw", kcal=89, iodine_ug=None)
    del usda["nutrients"]["iodine_ug"]
    ciqual = food("ciqual", "raw", kcal=90, iodine_ug=2.0)
    cofid = food("cofid", "raw", kcal=95, iodine_ug=3.0)
    dried = food("usda_sr", "dried", kcal=346, iodine_ug=9.0)
    fill([usda, ciqual, cofid, dried])
    assert usda["nutrients"]["iodine_ug"] == 3.0, "cofid ranks above ciqual; the dried row never lends to raw"
    assert usda["borrowed"] == ["iodine_ug"] and usda["estimated"] == []
    assert ciqual["borrowed"] == [], "its own value stays"


def test_estimated_as_the_median_when_no_government_row_has_it():
    a = food("usda_sr", "raw", kcal=89)
    b = food("healthy_foods_db", "raw", authoritative=False, kcal=90, zinc_mg=0.1)
    c = food("foodstruct", "raw", authoritative=False, kcal=91, zinc_mg=0.3)
    fill([a, b, c])
    assert a["nutrients"]["zinc_mg"] == 0.2 and a["estimated"] == ["zinc_mg"]


def test_a_food_alone_in_its_group_keeps_its_gaps():
    a = food("usda_sr", "raw", kcal=89)
    fill([a])
    assert a["nutrients"] == {"kcal": 89}


def test_similar_foods_lend_their_share_scaled_by_the_base_and_never_estimates():
    from fill import estimate_similar

    def f(name, **n):
        return {"source": "usda_sr", "common_name": name, "state": "raw", "nutrients": n}

    beef = [f(f"beef {c}", protein_g=20, fat_g=10, water_g=65, leucine_g=1.6, iron_mg=2.5) for c in "abcde"]
    steak = f("beef steak", protein_g=30, fat_g=10, water_g=58)
    apple = f("apple", protein_g=0.3, fat_g=0.2, water_g=85, iron_mg=0.1)
    guess = f("beef stew", protein_g=10, fat_g=5, water_g=80, iron_mg=9.0, estimated=None)
    guess["estimated"] = ["iron_mg"]  # an estimate never lends
    estimate_similar([*beef, steak, apple, guess])
    assert steak["nutrients"]["leucine_g"] == 2.4, "8 % of protein, from the beef rows"
    assert steak["nutrients"]["iron_mg"] == 2.5 and steak["sources"]["iron_mg"] == "similar"
    assert "iron_mg" in steak["estimated"]


def test_kcal_comes_from_the_macros():
    from fill import atwater

    assert atwater({"protein_g": 10, "fat_g": 5, "carbs_g": 20, "fiber_g": 4, "alcohol_g": 0}) == 157.0
    assert atwater({"protein_g": 10, "fat_g": 5}) is None


def test_a_researched_value_wins_over_estimates_never_over_a_measurement():
    from fill import apply_manual

    a = {"source": "usda_sr", "name": "Salt, table", "nutrients": {"iodine_ug": 3.0, "sodium_mg": 38758},
         "estimated": ["iodine_ug"]}
    url = "https://fdc.nal.usda.gov/x"
    n, problems = apply_manual([a], [f"usda_sr\tSalt, table\tiodine_ug\t0\t{url}",
                                     f"usda_sr\tSalt, table\tsodium_mg\t1\t{url}", "usda_sr\tNope\tiron_mg\t1\thttp://x"])
    assert (n, a["nutrients"]["iodine_ug"], a["nutrients"]["sodium_mg"]) == (1, 0.0, 38758)
    assert a["sources"]["iodine_ug"] == url and a["borrowed"] == ["iodine_ug"] and a["estimated"] == []
    assert len(problems) == 1


def test_a_researched_value_replaces_the_same_foods_measurements_more_than_3x_off():
    from fill import apply_manual

    def milk(source, name, state=None, **n):
        return {"source": source, "name": name, "common_name": "whole milk", "state": state, "nutrients": n}

    usda, cofid, frida, close = (milk("usda_sr", "Milk, whole"), milk("cofid", "Milk, whole", vitamin_b7_ug=2.4),
                                 milk("frida", "Milk, whole", vitamin_b7_ug=0.2), milk("nz", "Milk", vitamin_b7_ug=0.3))
    dried = milk("cofid", "Milk, dried", "dried", vitamin_b7_ug=20.0)
    url = "https://pmc.ncbi.nlm.nih.gov/articles/PMC1450323/"
    n, _ = apply_manual([usda, cofid, frida, close, dried], [f"usda_sr\tMilk, whole\tvitamin_b7_ug\t0.1\t{url}"])
    assert n == 2 and usda["nutrients"]["vitamin_b7_ug"] == cofid["nutrients"]["vitamin_b7_ug"] == 0.1
    assert cofid["sources"]["vitamin_b7_ug"] == url and cofid["borrowed"] == ["vitamin_b7_ug"]
    assert frida["nutrients"]["vitamin_b7_ug"] == 0.2 and close["nutrients"]["vitamin_b7_ug"] == 0.3, "within 3x"
    assert dried["nutrients"]["vitamin_b7_ug"] == 20.0, "another state is another food"


def test_a_reviewed_twin_lends_its_measured_values_for_estimates_only():
    from fill import apply_same

    onion = {"source": "usda_foundation", "name": "Onions, white, raw", "nutrients": {"kcal": 40, "iodine_ug": 9.0},
             "estimated": ["iodine_ug"]}
    twin = {"source": "frida", "name": "Onion, raw", "nutrients": {"kcal": 35, "iodine_ug": 0.5, "zinc_mg": 0.2},
            "estimated": ["zinc_mg"]}
    n, problems = apply_same([onion, twin], ["usda_foundation\tOnions, white, raw\tfrida\tOnion, raw", "x\ty\tz\tw"])
    assert n == 1 and onion["nutrients"] == {"kcal": 40, "iodine_ug": 0.5}, "kcal measured; zinc only estimated there"
    assert onion["sources"]["iodine_ug"] == "frida" and onion["borrowed"] == ["iodine_ug"]
    assert len(problems) == 1
