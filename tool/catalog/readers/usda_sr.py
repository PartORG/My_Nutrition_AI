"""USDA SR Legacy (the SR28 foods with all nutrients): see fdc.py. Chain items ("McDONALD'S, Big Mac") are branded."""

import re

from readers.fdc import read_set

BRAND = re.compile(r"^[A-Za-z0-9'&.\- ]*[A-Z]{3,}[A-Za-z0-9'&.\- ]*,")  # an all-capitals maker before the first comma
DISHES = {"22", "36"}  # Meals, Entrees, and Side Dishes; Restaurant Foods


def read(data):
    for f in read_set(data, "usda_sr", DISHES):
        if BRAND.match(f["name"]) and not f["name"].startswith("USDA"):  # USDA Commodity foods are generic
            f["category"] = "branded"
        yield f
