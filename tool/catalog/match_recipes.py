"""Match stage, recipes: every ingredient line of BUILD/normalized/recipes.jsonl → a v4 food and grams, with the v3
matcher (tool/build_real_nutri_db.py: Matcher, map_line, tool/ingredient_map.txt) and v3's rules: a recipe is kept only
if every line maps to a food and grams, no line's words imply an allergen its food lacks, and calories per serving are
plausible and agree with the source's published value. The matcher works on v3's food list, whose curated names
ingredient_map.txt uses; each match is then translated to the same row in v4 (source + code). Writes
BUILD/matched/recipes.jsonl.

    python3 tool/catalog/match_recipes.py
"""

import csv
import json
import sys
from collections import Counter
from pathlib import Path

from match import food_id
from names import common_name
from normalize import BUILD, DATA

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_real_nutri_db as v3

SRC = {"usda_sr28": "usda_sr", "usda_fdc_foundation": "usda_foundation", "nz_foodfiles": "nz"}
SR_LEGACY = "raw_fdc/sr_legacy/FoodData_Central_sr_legacy_food_csv_2018-04/sr_legacy_food.csv"


def v3_foods(data: Path) -> list[dict]:
    """The v3 food list as v3 built it (merge_foods: one row per name, the most authoritative winning)."""
    sr = v3.load_sr(data)
    sr += v3.load_food_csv(data, sr)
    fdc = v3.load_fdc(data)
    v3.fill_foundation(data, fdc)
    flat, _ = v3.load_flat_foods(data)
    eu = v3.load_ciqual(data) + v3.load_cofid(data)
    return v3.merge_foods([sr, fdc, v3.load_fndds(data), v3.load_nz(data), eu, flat])


def v4_ids(foods: list[dict], data: Path) -> dict[int, int]:
    """v3 food id → v4 food id (the same source row). SR28 is keyed by NDB number in v3 and by fdc_id in v4."""
    with open(data / SR_LEGACY, newline="") as fh:
        ndb = {int(r["NDB_number"]): r["fdc_id"] for r in csv.DictReader(fh)}
    out = {}
    for f in foods:
        source = SRC.get(f["src"], f["src"])
        code = str(f["skey"])
        if source == "usda_sr":
            code = ndb.get(int(code)) if code.isdigit() else None
        if code is not None:
            out[f["id"]] = food_id(source, code)
    return out


def match(recipe: dict, m, kcal: dict[int, float], to_v4: dict[int, int], v4_foods: set[int]) -> dict | str:
    """→ the recipe with matched lines, or why it was dropped (v3 Recipes.add's rules)."""
    lines, auto = [], False
    for position, text in enumerate(recipe["lines"], 1):
        got = v3.map_line(m, text)
        if isinstance(got, str):
            if got.startswith("allergen mismatch"):
                return "ingredient words imply an allergen the matched food lacks"
            if got.startswith("unmatched") or got == "empty ingredient line":
                return "ingredient not matched to a food"
            return "ingredient amount not convertible to grams" if got.startswith("no grams") else got
        _name, food, grams, _extra, was_auto = got
        auto |= was_auto
        fid = None
        if food is not None:
            fid = to_v4.get(food["id"])
            if fid not in v4_foods:
                return "ingredient matched a branded or dropped food"
        lines.append({"position": position, "food_id": fid, "v3_food": food["id"] if food else None,
                      "grams": round(grams, 2) if food else 0.0, "line": text})
    if not any(line["food_id"] for line in lines):
        return "no ingredient with nutrition"
    if auto and recipe["curated_only"]:
        return "ingredient matched only by name similarity, no published calories to confirm"
    per_serving = sum(kcal[line["v3_food"]] * line["grams"] / 100 for line in lines if line["v3_food"]) / recipe["servings"]
    if not 15 <= per_serving <= 2500:
        return "calories per serving implausible"
    rank = recipe["rank"] or 0.0
    if recipe["published_kcal"] and recipe["published_kcal"] > 0:
        if abs(per_serving - recipe["published_kcal"]) > max(80, 0.3 * recipe["published_kcal"]):
            return "calories differ from the source's published value"
        rank += 1  # confirmed by the source
    tags = v3.tags_of(recipe["tags"], recipe["minutes"])
    for line in lines:
        del line["v3_food"]
    return {**recipe, "id": food_id("recipe:" + recipe["source"], recipe["code"]), "rank": rank,
            "tags": [t for t in tags.split(",") if t], "texture": v3.texture_of(recipe["title"], tags), "lines": lines}


def main() -> None:
    foods = v3_foods(DATA)
    m = v3.Matcher(foods, Path(v3.__file__).parent / "ingredient_map.txt")
    to_v4 = v4_ids(foods, DATA)
    with open(BUILD / "matched/foods.jsonl") as fh:
        rows = [json.loads(line) for line in fh]
    v4_foods = {r["id"] for r in rows}
    # A v3 food that is a product in v4 (a branded butter) or gone: the v4 default of the same everyday name.
    defaults = {r["common_name"]: r["id"] for r in rows if r["is_default"]}
    for f in foods:
        if to_v4.get(f["id"]) not in v4_foods and (fid := defaults.get(common_name(f["name"]))):
            to_v4[f["id"]] = fid
    kcal = {f["id"]: f["kcal"] for f in foods}
    dropped, kept, seen = Counter(), 0, set()
    with open(BUILD / "normalized/recipes.jsonl") as src, open(BUILD / "matched/recipes.jsonl", "w") as out:
        for line in src:
            got = match(json.loads(line), m, kcal, to_v4, v4_foods)
            if isinstance(got, str):
                dropped[got] += 1
                continue
            k = (v3.key(got["title"]), frozenset(x["food_id"] for x in got["lines"] if x["food_id"]))
            if k in seen:
                dropped["duplicate of a recipe already kept"] += 1
                continue
            seen.add(k)
            out.write(json.dumps(got, ensure_ascii=False) + "\n")
            kept += 1
    print(f"{kept} recipes kept; dropped: {dict(dropped.most_common())}")


if __name__ == "__main__":
    main()
