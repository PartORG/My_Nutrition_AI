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
