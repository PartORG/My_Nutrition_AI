"""Units, derived values and cell parsing of the normalize stage.

uv run --with pytest --with openpyxl pytest tool/catalog/test_normalize.py
"""

import pytest

import normalize
from normalize import convert, number, panel


def test_units_convert_and_unknown_units_drop():
    assert convert(1, "mg", "g") == pytest.approx(0.001)
    assert convert(250, "µg/100g", "mg") == pytest.approx(0.25)
    assert convert(418.4, "kJ", "kcal") == pytest.approx(100)
    assert convert(5, "%T", "g") is None, "a share of fatty acids is not an amount"
    assert convert(5, "RE (µg/100g)", "µg") is None


def test_every_nutrient_code_maps_to_one_panel_key():
    seen = {}
    for (scheme, code), key in normalize.CODES.items():
        assert seen.setdefault((scheme, code), key) == key
    assert normalize.CODES[("usda", "203")] == "protein_g"
    assert normalize.CODES[("eurofir", "PROT")] == "protein_g"


def test_european_available_carbohydrate_becomes_total_with_fibre():
    p = panel([("eurofir", "CHO", 20.0, "g"), ("eurofir", "FIBT", 2.0, "g")])
    assert p["carbs_g"] == 22.0
    usda = panel([("usda", "205", 22.8, "g"), ("eurofir", "CHO", 20.0, "g")])
    assert usda["carbs_g"] == 22.8, "a total given by the source wins"


def test_energy_from_kcal_else_kilojoules_whatever_the_unit_suffix():
    assert panel([("eurofir", "ENERC", 400, "kJ/100g"), ("eurofir", "ENERC", 95, "kcal/100 g")])["kcal"] == 95
    assert panel([("eurofir", "ENERC", 418.4, "kJ")])["kcal"] == pytest.approx(100)


def test_vitamin_a_is_retinol_activity_equivalents_not_retinol_equivalents():
    p = panel([("eurofir", "VITA", 31.3, "RE"), ("eurofir", "RETOL", 29.8, "µg"), ("eurofir", "CARTB", 12, "µg")])
    assert p["vitamin_a_ug"] == pytest.approx(30.8)  # 29.8 + 12 / 12, never the RE value
    assert panel([("usda", "320", 3.0, "µg"), ("usda", "319", 50, "µg")])["vitamin_a_ug"] == 3.0


def test_folate_dfe_else_total_folate_and_omega3_from_its_fatty_acids():
    assert panel([("usda", "435", 30, "µg"), ("usda", "417", 20, "µg")])["folate_ug"] == 30
    assert panel([("eurofir", "FOL", 20, "µg")])["folate_ug"] == 20
    assert panel([("eurofir", "F18D3N3", 0.1, "g"), ("eurofir", "F22D6N3", 0.2, "g")])["omega3_g"] == pytest.approx(0.3)
    # USDA numbers: ALA's n-3 form wins over its undifferentiated total (no double count), plus DHA.
    usda = panel([("usda", "851", 0.1, "g"), ("usda", "619", 0.12, "g"), ("usda", "621", 0.2, "g"),
                  ("usda", "618", 1.0, "g"), ("usda", "620", 0.05, "g")])
    assert usda["omega3_g"] == pytest.approx(0.3) and usda["omega6_g"] == pytest.approx(1.05)


def test_cells():
    assert [number(v) for v in ["1,5", "tr", "n.d.", "", None, "<0.1", 3]] == [1.5, 0.0, None, None, None, 0.1, 3.0]
