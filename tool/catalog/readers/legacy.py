"""The v3 builder's loaders for the smaller and branded files (tool/build_real_nutri_db.py: load_fdc, load_flat_foods),
reused as they are: their checks (energy ≈ macros, ranges) stay, and their rows already use the panel's key names.
Each row keeps its v3 source id. Not read here: what the government readers cover (SR28 = usda_sr, the Foundation
rows of comprehensive_foods_usda.csv = usda_foundation, NZ, CIQUAL, CoFID) and the 2019 Open Food Facts dump (the
2026 dump in readers.off replaces it)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import build_real_nutri_db as v3

# Generic (food) sources; everything else is branded and goes to products.
GENERIC = {"foodstruct", "indb", "indonesia", "nutrients_csvfile", "fda_produce", "food_nutrition_dataset"}
GOVERNMENT = {"usda_sr", "usda_fdc_foundation", "nz_foodfiles", "ciqual", "cofid", "usda_fndds"}


def row(f: dict, category: str) -> dict:
    nutrients = {k: f.get(k) for k in (*v3.NUTRIENTS, *v3.MICROS)}
    return {
        "source": f["src"],
        "code": str(f.get("skey", "")),
        "name": f["name"],
        "category": category,
        "serving_g": f.get("serving_g"),
        "ingredients": f.get("ingredients"),
        "allergens": sorted(f.get("allergen_flags") or []),
        "nutrients": nutrients,
    }


def read(data):
    for f in v3.load_fdc(data):
        if f["src"] == "usda_fdc_branded":
            yield row(f, "branded")
    foods, dishes = v3.load_flat_foods(data)
    for f in foods:
        if f["src"] not in GOVERNMENT:
            yield row(f, "food" if f["src"] in GENERIC else "branded")
    for d in dishes:  # chain menus (branded); Food-101 dish labels and daily_food (generic dishes)
        yield row(d, "dish" if d["src"] in {"food101", "daily_food"} else "branded")
