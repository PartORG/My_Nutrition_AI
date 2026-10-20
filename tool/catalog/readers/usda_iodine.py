"""USDA, FDA and ODS-NIH Database for the Iodine Content of Common Foods, Release 4.0 (public domain):
raw_iodine/IODINE_RELEASE_4.zip, per 100 g. Not foods of its own: fill.py lends its iodine to the USDA rows with the
same NDB number ("01253 (100297)": the SR number, then the Foundation one)."""

import csv
import io
import re
import zipfile
from collections import defaultdict

import openpyxl

FDC = {"usda_sr": "raw_fdc/sr_legacy/FoodData_Central_sr_legacy_food_csv_2018-04/sr_legacy_food.csv",
       "usda_foundation": "raw_fdc/foundation/FoodData_Central_foundation_food_csv_2026-04-30/foundation_food.csv"}
URL = "https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/" \
      "methods-and-application-of-food-composition-laboratory/mafcl-site-pages/iodine/"


def read(data) -> dict[tuple[str, str], float]:
    """→ {(source, FDC id): iodine µg per 100 g} for usda_sr and usda_foundation rows."""
    ndb = defaultdict(list)  # NDB number → [(source, fdc id)]: SR and Foundation share some numbers
    for source, path in FDC.items():
        with open(data / path, newline="") as fh:
            for r in csv.DictReader(fh):
                ndb[r["NDB_number"].lstrip("0")].append((source, r["fdc_id"]))
    with zipfile.ZipFile(data / "raw_iodine/IODINE_RELEASE_4.zip") as z:
        book = openpyxl.load_workbook(io.BytesIO(z.read("Iodine Database_Release 4_Per 100g.xlsx")), read_only=True)
    out = {}
    for row in book.active.iter_rows(min_row=3, values_only=True):
        numbers, value = row[1], row[5]
        if not numbers or not isinstance(value, (int, float)):
            continue  # a group heading
        for n in re.findall(r"\d+", str(numbers)):
            for key in ndb.get(n.lstrip("0"), []):
                out[key] = float(value)
    return out
