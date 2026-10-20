"""USDA FoodData Central bulk CSV (public domain), per 100 g, nutrient_nbr = USDA numbers. One reader for the three
generic sets: SR Legacy (the SR28 foods, all nutrients), FNDDS survey foods (foods and dishes as eaten) and
Foundation foods. A Foundation food's samples are rows of food.csv too: only its foundation_food.csv ids count."""

import csv
import re
from collections import defaultdict

SETS = {
    "usda_sr": ("raw_fdc/sr_legacy/FoodData_Central_sr_legacy_food_csv_2018-04", "sr_legacy_food.csv"),
    "usda_fndds": ("raw_fdc/survey/FoodData_Central_survey_food_csv_2024-10-31", "survey_fndds_food.csv"),
    "usda_foundation": ("raw_fdc/foundation/FoodData_Central_foundation_food_csv_2026-04-30", "foundation_food.csv"),
}
# Foundation reports energy only as Atwater general (957) / specific (958) factors.
ENERGY = {"957": "208", "958": "208"}
VOLUME = re.compile(r"\b(cup|tbsp|tablespoon|tsp|teaspoon|fl oz|ml|oz|lb|inch|cubic|cm)\b", re.IGNORECASE)


def rows(folder, name):
    with open(folder / name, newline="", encoding="utf-8") as f:
        yield from csv.DictReader(f)


def read_set(data, key: str, dish_categories: set[str] = frozenset()):
    folder = data / SETS[key][0]
    ids = {r["fdc_id"] for r in rows(folder, SETS[key][1])}
    nutrients = {}
    for r in rows(folder, "nutrient.csv"):
        nbr = ENERGY.get(r["nutrient_nbr"], r["nutrient_nbr"]).split(".")[0]
        nutrients[r["id"]] = (nbr, r["unit_name"])
        nutrients.setdefault(nbr, (nbr, r["unit_name"]))  # the FNDDS export refers to nutrients by number
    amounts = defaultdict(list)
    for r in rows(folder, "food_nutrient.csv"):
        if r["fdc_id"] in ids and r["nutrient_id"] in nutrients and r["amount"]:
            nbr, unit = nutrients[r["nutrient_id"]]
            amounts[r["fdc_id"]].append(
                ("usda", nbr.split(".")[0], float(r["amount"]), unit.replace("UG", "µg").lower())
            )
    units = {r["id"]: r["name"] for r in rows(folder, "measure_unit.csv")}
    serving = {}
    for r in rows(folder, "food_portion.csv"):
        if r["fdc_id"] not in ids or not r["gram_weight"]:
            continue
        unit = units.get(r["measure_unit_id"], "")
        # FNDDS writes a portion code in amount and the whole label in portion_description ("1 piece, medium pizza").
        label = (
            r["portion_description"].strip()
            or " ".join(
                x for x in [r["amount"].removesuffix(".0"), "" if unit == "undetermined" else unit, r["modifier"]] if x
            ).strip()
        )
        if "not specified" in label.lower():
            continue
        one = label.startswith("1 ") or (not r["portion_description"] and r["amount"] in {"", "1", "1.0"})
        old = serving.get(r["fdc_id"])
        if one and not VOLUME.search(label) and (old is None or ("medium" in label and "medium" not in old[1])):
            serving[r["fdc_id"]] = (float(r["gram_weight"]), label)  # a medium one if any
    for r in rows(folder, "food.csv"):
        if r["fdc_id"] not in ids:
            continue
        grams, label = serving.get(r["fdc_id"], (None, None))
        yield {
            "code": r["fdc_id"],
            "name": r["description"].strip(),
            "group": r.get("food_category_id"),
            "category": "dish" if r.get("food_category_id") in dish_categories else "food",
            "serving_g": grams,
            "serving": label,
            "amounts": amounts[r["fdc_id"]],
        }
