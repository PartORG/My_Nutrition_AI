"""Canadian Nutrient File 2015 (Health Canada, OGL-Canada): raw_cnf/cnf-fcen-csv.zip, per 100 g, USDA numbers.
The update zip only lists what changed since 2010; the full zip is already 2015."""

import csv
import io
import re
import zipfile
from collections import defaultdict

DISHES = {21, 22}  # Fast Foods, Mixed Dishes
PIECE = re.compile(r"^1 (?!.*\b(ml|cup|tbsp|tsp|fl oz|g)\b)", re.IGNORECASE)  # "1 medium (118 g)", not "1 cup" or "1 g"


def table(z: zipfile.ZipFile, name: str):
    return csv.DictReader(io.TextIOWrapper(z.open(name), encoding="latin-1"))


def read(data):
    with zipfile.ZipFile(data / "raw_cnf/cnf-fcen-csv.zip") as z:
        units = {r["NutrientID"]: r["NutrientUnit"] for r in table(z, "NUTRIENT NAME.csv")}
        amounts = defaultdict(list)
        for r in table(z, "NUTRIENT AMOUNT.csv"):
            if r["NutrientID"] in units:  # 328 has amounts but no NUTRIENT NAME row: unknown unit, skipped
                amounts[r["FoodID"]].append(
                    ("usda", r["NutrientID"], float(r["NutrientValue"]), units[r["NutrientID"]])
                )
        measures = {r["MeasureID"]: r["MeasureDescription"] for r in table(z, "MEASURE NAME.csv")}
        serving = {}
        for r in table(z, "CONVERSION FACTOR.csv"):  # factor × the per-100 g values = per measure
            m = measures.get(r["MeasureID"], "")
            if (
                PIECE.match(m)
                and float(r["ConversionFactorValue"]) > 0
                and (r["FoodID"] not in serving or ("medium" in m and "medium" not in serving[r["FoodID"]][1]))
            ):
                serving[r["FoodID"]] = (round(float(r["ConversionFactorValue"]) * 100, 1), m)  # a medium one if any
        for r in table(z, "FOOD NAME.csv"):
            grams, label = serving.get(r["FoodID"], (None, None))
            yield {
                "code": r["FoodID"],
                "name": r["FoodDescription"].strip(),
                "name_fr": r["FoodDescriptionF"].strip(),
                "group": r["FoodGroupID"],
                "category": "dish" if int(r["FoodGroupID"]) in DISHES else "food",
                "serving_g": grams,
                "serving": label,
                "amounts": amounts[r["FoodID"]],
            }
