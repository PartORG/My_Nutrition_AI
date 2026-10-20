"""Open Food Facts dump 2026-10-16 (ODbL): raw_off_2026-10-16/products.csv.gz → products. Rows are checked as in v3
(build_real_nutri_db.off_product: a barcode, a name, plausible kcal/macros); the rest of the label comes from its
*_100g columns, all in grams per 100 g. EU labels give carbohydrate without fibre, US labels with it: the panel's
carbs_g is total, so fibre is added unless the product is sold in the US or the label gives the total."""

import csv
import gzip
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import build_real_nutri_db as v3

from normalize import UNIT, convert, number

csv.field_size_limit(sys.maxsize)
LABEL = {
    "saturated-fat": "saturated_fat_g",
    "monounsaturated-fat": "mono_fat_g",
    "polyunsaturated-fat": "poly_fat_g",
    "trans-fat": "trans_fat_g",
    "omega-3-fat": "omega3_g",
    "omega-6-fat": "omega6_g",
    "cholesterol": "cholesterol_mg",
    "starch": "starch_g",
    "sucrose": "sucrose_g",
    "glucose": "glucose_g",
    "fructose": "fructose_g",
    "lactose": "lactose_g",
    "added-sugars": "added_sugar_g",
    "alcohol": "alcohol_g",
    "water": "water_g",
    "vitamin-a": "vitamin_a_ug",
    "beta-carotene": "beta_carotene_ug",
    "vitamin-d": "vitamin_d_ug",
    "vitamin-e": "vitamin_e_mg",
    "vitamin-k": "vitamin_k_ug",
    "vitamin-c": "vitamin_c_mg",
    "vitamin-b1": "vitamin_b1_mg",
    "vitamin-b2": "vitamin_b2_mg",
    "vitamin-pp": "vitamin_b3_mg",
    "pantothenic-acid": "vitamin_b5_mg",
    "vitamin-b6": "vitamin_b6_mg",
    "biotin": "vitamin_b7_ug",
    "vitamin-b9": "folate_ug",
    "vitamin-b12": "vitamin_b12_ug",
    "choline": "choline_mg",
    "potassium": "potassium_mg",
    "calcium": "calcium_mg",
    "phosphorus": "phosphorus_mg",
    "iron": "iron_mg",
    "magnesium": "magnesium_mg",
    "zinc": "zinc_mg",
    "copper": "copper_mg",
    "manganese": "manganese_mg",
    "selenium": "selenium_ug",
    "iodine": "iodine_ug",
}
CORE = ("kcal", "protein_g", "fat_g", "carbs_g", "fiber_g", "sugar_g", "sodium_mg")


def read(data):
    with gzip.open(
        data / "raw_off_2026-10-16/products.csv.gz", "rt", encoding="utf-8", errors="replace", newline=""
    ) as fh:
        for r in csv.DictReader(fh, delimiter="\t", quoting=csv.QUOTE_NONE):
            got = v3.off_product(lambda k, r=r: r.get(k) or "")
            if isinstance(got, str):
                continue
            n = {k: got[k] for k in CORE}
            total = number(r.get("carbohydrates-total_100g"))
            if total is not None:
                n["carbs_g"] = total
            elif "United States" not in (r.get("countries_en") or "") and n["fiber_g"] is not None:
                n["carbs_g"] += n["fiber_g"]
            for col, key in LABEL.items():
                if (v := number(r.get(f"{col}_100g"))) is not None:
                    n[key] = convert(v, "g", UNIT[key])
            yield {
                "source": "off",
                "code": got["barcode"],
                "barcode": got["barcode"],
                "name": got["name"],
                "brand": (r.get("brands") or "").split(",")[0].strip() or None,
                "category": "branded",
                "serving_g": number(r.get("serving_quantity")),
                "serving": (r.get("serving_size") or None),
                "allergens": sorted(v3.allergens_from_text(r.get("allergens_en") or r.get("allergens") or "")),
                "nutrients": v3.plausible(n) | {k: n[k] for k in CORE},
            }
