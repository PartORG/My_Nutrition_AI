"""Servings stage, after fill: every drink gets a serving, so "a beer" is a bottle and not 100 g. Only empty ones:
1. a USDA drink: its own portion from FoodData Central (CC0) — the reader leaves volume portions out, and a drink has
   no other ("1 can (12 fl oz)", "1 cup");
2. else the median serving of the drinks of the same everyday name;
3. else the usual size of its kind (TYPES).
A serving over MAX_SERVING (a table's "1 bottle" of a litre) counts as empty.
Grams = ml (a drink is near 1 g/ml; spirits 0.95). Reads and rewrites BUILD/matched/foods.jsonl.

    python3 tool/catalog/servings.py
"""

import json
import re
from collections import defaultdict
from statistics import median

from normalize import BUILD, DATA
from readers.fdc import SETS, rows

DRINK = re.compile(
    r"\b(coffee|espresso|latte|cappuccino|macchiato|mocha|americano|tea|chai|beer|lager|ale|stout|porter|cider|radler|"
    r"shandy|wine|champagne|prosecco|cava|sherry|port|vermouth|sangria|vodka|whisk(?:e)?y|gin|rum|brandy|cognac|"
    r"tequila|liqueur|schnapps|spirits?|liquor|absinthe|grappa|raki|ouzo|pastis|limoncello|aquavit|sake|mead|cola|"
    r"soda|soft drinks?|lemonade|tonic|energy drink|ginger ale|root beer|juice|nectar|smoothie|milkshake|shake|"
    r"milk|kefir|ayran|lassi|buttermilk|ryazhenka|kvass|kombucha|cocoa|hot chocolate|water|drinks?|beverages?|"
    r"cocktail|punch|mojito|spritz)\b",
    re.IGNORECASE,
)
# Liquids eaten by the spoon, solids named after a drink, and what an adult app doesn't serve.
NOT_DRINK = re.compile(
    r"\b(lemon juice|lime juice|vinegar|sauce|syrup|broth|stock|soup|pur[ée]e|baby|infant|formula|chestnuts?|"
    r"cake|bread|biscuits?|ice cream|pudding|custard|jelly|powder|dry|dried|concentrate|conc\.?|frozen|"
    r"condensed|evaporated|cream|cheese|yog(?:h)?urt(?! drink)|fish|shrimp|prawn|fruit cocktail|rice|cereal)\b",
    re.IGNORECASE,
)
# The usual size of a kind of drink, first match wins: (pattern, grams, label). Alcohol as NIAAA's standard drinks.
TYPES = [
    (r"espresso|ristretto", 30, "1 espresso (30 ml)"),
    (r"\band\b.*\b(cola|soda|tonic|juice|lemonade|energy drink)", 250, "1 glass (250 ml)"),  # rum and cola
    (r"energy drink", 250, "1 can (250 ml)"),
    (r"cola|soda|soft drink|lemonade|tonic|ginger ale|root beer|orangeade|iced tea", 330, "1 can (330 ml)"),
    (
        (
            r"vodka|whisk|\bgin\b|\brum\b|brandy|cognac|tequila|liqueur|schnapps|spirit|liquor|absinth|grappa|raki|"
            r"ouzo|pastis|limoncello|aquavit"
        ),
        44,
        "1 shot (44 ml)",
    ),
    (r"wine|champagne|prosecco|cava|sherry|\bport\b|vermouth|sangria|sake", 148, "1 glass (150 ml)"),
    (r"beer|lager|\bale\b|stout|porter|cider|radler|shandy", 355, "1 bottle (355 ml)"),
    (r"\bwater\b", 250, "1 glass (250 ml)"),
    (r".", 240, "1 cup (240 ml)"),
]
# A FoodData Central portion of a drink, most wanted first.
PORTIONS = ["shot", "jigger", "can", "glass", "cup", "bottle", "mug"]


def is_drink(f: dict) -> bool:
    n = f["nutrients"]
    liquid = n.get("water_g", 0) >= 80 or n.get("alcohol_g", 0) >= 8
    return liquid and bool(DRINK.search(f["name"])) and not NOT_DRINK.search(f["name"])


def usda_portions(ids: dict[str, set[str]]) -> dict[tuple[str, str], tuple[float, str]]:
    """(source, fdc_id) → (grams, label) of the most wanted "1 …" portion, for the ids asked per set."""
    out = {}
    for source, wanted in ids.items():
        folder = DATA / SETS[source][0]
        units = {r["id"]: r["name"] for r in rows(folder, "measure_unit.csv")}
        found = defaultdict(list)
        for r in rows(folder, "food_portion.csv"):
            if r["fdc_id"] not in wanted or not r["gram_weight"] or float(r["gram_weight"]) <= 0:
                continue
            unit = units.get(r["measure_unit_id"], "")
            label = r["portion_description"].strip() or " ".join(
                x for x in [r["amount"].removesuffix(".0"), "" if unit == "undetermined" else unit, r["modifier"]] if x
            ).strip()
            if not label.startswith("1 "):
                continue
            rank = next((i for i, w in enumerate(PORTIONS) if re.search(rf"\b{w}", label, re.IGNORECASE)), None)
            if rank is not None:
                found[r["fdc_id"]].append((rank, float(r["gram_weight"]), label))
        for fdc_id, portions in found.items():
            _, grams, label = min(portions)
            out[(source, fdc_id)] = (grams, label)
    return out


def type_serving(name: str) -> tuple[float, str]:
    return next((g, label) for pattern, g, label in TYPES if re.search(pattern, name, re.IGNORECASE))


# A table's own "serving" of a drink above this is the whole carton ("1 bottle", a litre of kefir): one glass instead.
MAX_SERVING = 750


def serve(foods: list[dict], portions: dict) -> dict[str, int]:
    drinks = [f for f in foods if is_drink(f)]
    counts = {"drinks": len(drinks), "too big": 0, "had one": 0, "usda": 0, "same name": 0, "kind": 0}
    for f in drinks:
        if (f.get("serving_g") or 0) > MAX_SERVING:
            f["serving_g"] = f["serving"] = None
            counts["too big"] += 1
    for f in drinks:
        if f.get("serving_g"):
            counts["had one"] += 1
        elif (p := portions.get((f["source"], f["code"]))) is not None:
            f["serving_g"], f["serving"] = p
            counts["usda"] += 1
    by_name = defaultdict(list)
    for f in drinks:
        if f.get("serving_g"):
            by_name[f["common_name"]].append(f)
    for f in drinks:
        if f.get("serving_g"):
            continue
        if same := by_name.get(f["common_name"]):
            g = median(s["serving_g"] for s in same)
            f["serving_g"] = g
            f["serving"] = min(same, key=lambda s: abs(s["serving_g"] - g)).get("serving")
            counts["same name"] += 1
        else:
            f["serving_g"], f["serving"] = type_serving(f["name"])
            counts["kind"] += 1
    return counts


def main() -> None:
    path = BUILD / "matched/foods.jsonl"
    with open(path) as fh:
        foods = [json.loads(line) for line in fh]
    ids = defaultdict(set)
    for f in foods:
        if f["source"] in SETS and not f.get("serving_g") and is_drink(f):
            ids[f["source"]].add(f["code"])
    counts = serve(foods, usda_portions(ids))
    with open(path, "w") as fh:
        fh.writelines(json.dumps(f, ensure_ascii=False) + "\n" for f in foods)
    print(", ".join(f"{k}: {v}" for k, v in counts.items()))


if __name__ == "__main__":
    main()
