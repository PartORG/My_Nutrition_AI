"""Fill stage (docs/PLAN.md "Catalogue v4", decision 15, and "All nutrients" 5): every missing nutrient of a food.
Same food = the same everyday name and the same state (raw and dried differ in water, so never lend to each other).
1. borrowed: the most authoritative government row of that food that has the value;
2. estimated: else the median of every row of that food that has it;
3. estimated: else from the 5 most similar foods that measured it (nutrient profile + name), scaled by its base
   where it has one (amino acids by protein, fatty acids by fat, single sugars by sugar, starch by carbohydrate).
Before 1, the USDA iodine database lends measured iodine to USDA rows, and db/catalog/manual_values.tsv its researched
values (with their URL), which also replace the same food's measured values more than 3x off them. Before 3,
db/catalog/same_food.tsv (reviewed twins in other tables) lends its measured values over every estimate.
Each value's origin is in f["sources"]: the lender's source id, a URL, "same", "similar" or "atwater" (kcal from
the macros). Products keep their label.
Reads and rewrites BUILD/matched/foods.jsonl; prints how far step 3 is off on held-back measured values.

    uv run --with numpy --with scipy --with openpyxl python3 tool/catalog/fill.py
"""

import json
import random
import re
import warnings
from collections import defaultdict
from pathlib import Path
from statistics import median

from match import SOURCE_RANK
from normalize import BUILD, DATA, MAX, PANEL, UNIT
from readers import usda_iodine

KEYS = [n["key"] for n in PANEL]
# The share of a nutrient scales with its base: 2 g of leucine per 10 g of protein, not per food.
BASE = {n["key"]: {"amino": "protein_g", "sugar": "sugar_g"}.get(n["group"]) for n in PANEL}
BASE.update({k: "fat_g" for k in ("saturated_fat_g", "mono_fat_g", "poly_fat_g", "trans_fat_g", "omega3_g",
                                  "omega6_g")}, starch_g="carbs_g")
FEATURES = ["protein_g", "fat_g", "carbs_g", "fiber_g", "sugar_g", "sodium_mg", "water_g"]
NAME_WEIGHT = 1.5  # a food with no word in common is as far as 1.5 standard deviations of profile


def fill(foods: list[dict]) -> dict[str, int]:
    groups = defaultdict(list)
    for f in foods:
        groups[(f["common_name"], f.get("state"))].append(f)
    counts = {"borrowed": 0, "estimated": 0}
    for group in groups.values():
        if len(group) < 2:
            continue
        lenders = sorted((f for f in group if f.get("authoritative")), key=lambda f: SOURCE_RANK.get(f["source"], 99))
        for f in group:
            borrowed, estimated = [], []
            for k in KEYS:
                if k in f["nutrients"]:
                    continue
                lender = next((x for x in lenders if x is not f and k in x["nutrients"]), None)
                if lender is not None:
                    f["nutrients"][k] = lender["nutrients"][k]
                    f.setdefault("sources", {})[k] = lender.get("sources", {}).get(k, lender["source"])
                    borrowed.append(k)
                    continue
                values = [x["nutrients"][k] for x in group if x is not f and k in x["nutrients"]]
                if values:
                    f["nutrients"][k] = round(median(values), 4)
                    f.setdefault("sources", {})[k] = "same"
                    estimated.append(k)
            f["borrowed"], f["estimated"] = borrowed, estimated
            counts["borrowed"] += len(borrowed)
            counts["estimated"] += len(estimated)
    return counts


def neighbours(foods: list[dict], hidden: set = frozenset(), size: int = 200, rows: list[int] | None = None):
    """Per food, the indices of the [size] most similar other foods: distance between standardized log profiles of
    FEATURES (a missing one counts as typical) plus NAME_WEIGHT × (1 - shared words of the everyday name)."""
    import numpy as np
    from scipy import sparse

    n = len(foods)
    size = min(size, n - 1)
    x = np.full((n, len(FEATURES)), np.nan)
    for i, f in enumerate(foods):
        for j, k in enumerate(FEATURES):
            if k in f["nutrients"] and (i, k) not in hidden:
                x[i, j] = np.log1p(max(f["nutrients"][k], 0))
    with np.errstate(all="ignore"), warnings.catch_warnings(action="ignore"):  # a feature nobody has, or everyone the same: no information
        x = np.nan_to_num((x - np.nanmean(x, 0)) / np.nanstd(x, 0))
    words = [set(re.findall(r"[a-z]+", f["common_name"])) for f in foods]
    vocab = {w: i for i, w in enumerate(sorted(set().union(*words)))}
    owner = [i for i, ws in enumerate(words) for _ in ws]
    t = sparse.csr_matrix((np.ones(len(owner), np.float32), (owner, [vocab[w] for ws in words for w in ws])),
                          shape=(n, len(vocab)))
    count = np.asarray(t.sum(1)).ravel()
    sq = (x * x).sum(1)
    rows = np.arange(n) if rows is None else np.asarray(rows)
    out = {}
    for start in range(0, len(rows), 1000):
        r = rows[start:start + 1000]
        d = np.sqrt(np.maximum(sq[r, None] + sq[None, :] - 2 * x[r] @ x.T, 0))
        shared = (t[r] @ t.T).toarray()
        union = count[r, None] + count[None, :] - shared
        d += NAME_WEIGHT * (1 - np.divide(shared, union, out=np.zeros_like(shared), where=union > 0))
        d[np.arange(len(r)), r] = np.inf  # never itself
        near = np.argpartition(d, size - 1, 1)[:, :size]
        near = np.take_along_axis(near, np.argsort(np.take_along_axis(d, near, 1), 1), 1)
        out.update(zip(r.tolist(), near))
    return out


def atwater(n: dict) -> float | None:
    """kcal from the macros (4 protein, 9 fat, 4 available carbohydrate, 2 fibre, 7 alcohol), when all are known."""
    if any(k not in n for k in ("protein_g", "fat_g", "carbs_g")):
        return None
    fiber = n.get("fiber_g", 0)
    return round(4 * n["protein_g"] + 9 * n["fat_g"] + 4 * max(n["carbs_g"] - fiber, 0) + 2 * fiber
                 + 7 * n.get("alcohol_g", 0), 1)


def predict(foods: list[dict], near, i: int, k: str, hidden: set = frozenset(), donors: int = 5) -> float | None:
    """Food i's value of k from its nearest foods that measured it (borrowed counts; estimates never lend)."""
    f, base = foods[i], BASE.get(k)
    if k == "kcal":
        return atwater(f["nutrients"])
    own_base = f["nutrients"].get(base) if base else None
    if own_base == 0:
        return 0.0  # no sugar, no sucrose
    values = []
    for j in near[i]:
        g = foods[j]
        if k not in g["nutrients"] or k in g.get("estimated", ()) or (j, k) in hidden:
            continue
        if own_base is not None:
            if not g["nutrients"].get(base):
                continue
            values.append(g["nutrients"][k] / g["nutrients"][base] * own_base)
        else:
            values.append(g["nutrients"][k])
        if len(values) == donors:
            break
    if not values:
        return None
    return round(min(median(values), MAX[k], own_base if own_base is not None and UNIT[k] == "g" else MAX[k]), 4)


def estimate_similar(foods: list[dict]) -> int:
    near = neighbours(foods)
    todo = [(i, k) for i, f in enumerate(foods) for k in KEYS if k not in f["nutrients"]]
    # Bases first (protein before its amino acids), so a share always scales a known base; kcal from the macros last.
    todo.sort(key=lambda c: (c[1] == "kcal", BASE.get(c[1]) is not None))
    n, left = 0, []
    for i, k in todo:
        v = predict(foods, near, i, k)
        if v is None:
            left.append((i, k))
            continue
        n += fill_one(foods[i], k, v)
    # Rare nutrients of unusual foods: no measured value among the 200 nearest, so rank every food, 200 foods at a
    # time (a full ranking is 41k indices a food).
    rows = sorted({i for i, _ in left})
    for start in range(0, len(rows), 200):
        far = neighbours(foods, size=len(foods) - 1, rows=rows[start:start + 200])
        for i, k in left:
            if i in far and (v := predict(foods, far, i, k)) is not None:
                n += fill_one(foods[i], k, v)
    return n


def fill_one(f: dict, k: str, v: float) -> int:
    f["nutrients"][k] = v
    f.setdefault("sources", {})[k] = "atwater" if k == "kcal" else "similar"
    f["estimated"] = [*f.get("estimated", []), k]
    return 1


def evaluate(foods: list[dict], share: float = 0.03, seed: int = 4) -> list[tuple]:
    """Hide [share] of each nutrient's measured values, estimate them as step 3 would, and compare with the truth
    and with a guess of the nutrient's median → (key, n, median error, baseline's median error, within ±25 %)."""
    rnd = random.Random(seed)
    cells = defaultdict(list)
    for i, f in enumerate(foods):
        for k in f["nutrients"]:
            if k in KEYS and k not in f.get("estimated", ()) and k not in f.get("borrowed", ()):
                cells[k].append(i)
    hidden = {(i, k) for k, idx in cells.items() for i in rnd.sample(idx, min(len(idx), max(1, int(len(idx) * share)), 1000))}
    near = neighbours(foods, hidden)
    report = []
    for k in KEYS:
        mine = [i for (i, kk) in hidden if kk == k]
        if not mine:
            continue
        typical = median(foods[i]["nutrients"][k] for i in cells[k])
        errors, base_errors, close = [], [], 0
        for i in mine:
            truth = foods[i]["nutrients"][k]
            saved = {kk: foods[i]["nutrients"].pop(kk) for kk in KEYS if (i, kk) in hidden}  # nothing hidden leaks
            v = predict(foods, near, i, k, hidden)
            foods[i]["nutrients"].update(saved)
            if v is None:
                continue
            errors.append(abs(v - truth))
            base_errors.append(abs(typical - truth))
            close += abs(v - truth) <= 0.25 * truth or abs(v - truth) <= 0.01 * MAX[k] / 100
        if errors:
            report.append((k, len(errors), median(errors), median(base_errors), close / len(errors)))
    return report


CATALOG = Path(__file__).resolve().parents[2] / "db/catalog"
MANUAL, SAME = CATALOG / "manual_values.tsv", CATALOG / "same_food.tsv"


def rows_of(lines: list[str]) -> list[list[str]]:
    return [line.split("\t") for line in lines if line.strip() and not line.startswith(("#", "source\t"))]


def lend(f: dict, k: str, value: float, origin: str) -> bool:
    """A value from elsewhere for what f did not measure; False when f measured it (its own value stays)."""
    if k in f["nutrients"] and k not in f.get("borrowed", ()) and k not in f.get("estimated", ()):
        return False
    f["nutrients"][k] = value
    f.setdefault("sources", {})[k] = origin
    f["estimated"] = [x for x in f.get("estimated", []) if x != k]
    f["borrowed"] = [*(x for x in f.get("borrowed", []) if x != k), k]
    return True


def apply_same(foods: list[dict], lines: list[str]) -> tuple[int, list[str]]:
    """same_food.tsv: source | name | lender source | lender name → the lender's measured values, f's estimates."""
    by_name = {(f["source"], f["name"].lower()): f for f in foods}
    n, problems = 0, []
    for row in rows_of(lines):
        f, twin = by_name.get((row[0], row[1].lower())), by_name.get((row[2], row[3].lower()))
        if f is None or twin is None:
            problems.append(f"same_food.tsv: {row!r}")
            continue
        for k, v in twin["nutrients"].items():
            measured = k in KEYS and k not in twin.get("estimated", ()) and k not in twin.get("borrowed", ())
            if measured and (k not in f["nutrients"] or k in f.get("estimated", ())):
                n += lend(f, k, v, twin["source"])
    return n, problems


# A researched value replaces the same food's measured value this many times off it: Staggs 2004 found published
# biotin (microbiological assays, as in CoFID/Frida) often several times too high, milk 20x.
OUTLIER = 3


def apply_manual(foods: list[dict], lines: list[str]) -> tuple[int, list[str]]:
    """manual_values.tsv lines: source | food name | nutrient | value per 100 g | URL. Never over the food's own
    measured value; over the same food's (name and state) in other tables when more than OUTLIER times off.
    Source "*": the name is a regular expression (whole name, any case) for a kind of food every table names its own
    way (plain cow's milk); every match gets the value, unless it measured one within OUTLIER times of it."""
    by_name, groups = defaultdict(list), defaultdict(list)
    for f in foods:
        by_name[(f["source"], f["name"].lower())].append(f)
        groups[(f.get("common_name"), f.get("state"))].append(f)

    def outlier(g: dict, k: str, v: float) -> bool:
        return k in g["nutrients"] and not v / OUTLIER <= g["nutrients"][k] <= v * OUTLIER

    n, problems = 0, []
    for row in rows_of(lines):
        source, name, k, value, url = row
        v = float(value)
        if source == "*":
            hits = [f for f in foods if re.fullmatch(name, f["name"], re.IGNORECASE)]
            for f in hits:
                if outlier(f, k, v):
                    del f["nutrients"][k]
                n += lend(f, k, v, url)
            if not hits:
                problems.append(f"manual_values.tsv: no food matches {row!r}")
            continue
        hits = by_name.get((source, name.lower()))
        if not hits or k not in KEYS or not url.startswith("http"):
            problems.append(f"manual_values.tsv: {row!r}")
            continue
        for f in hits:
            n += lend(f, k, v, url)
            for g in groups[(f.get("common_name"), f.get("state"))]:
                if g not in hits and outlier(g, k, v):
                    del g["nutrients"][k]  # the outlier; lend() puts the researched value in its place
                    n += lend(g, k, v, url)
    return n, problems


def main() -> None:
    path = BUILD / "matched/foods.jsonl"
    with open(path) as fh:
        foods = [json.loads(line) for line in fh]
    known_before = sum(len(f["nutrients"]) for f in foods)
    iodine = usda_iodine.read(DATA)  # measured iodine for USDA rows, lent before the same food shares it
    lent = sum(lend(f, "iodine_ug", iodine[(f["source"], f["code"])], usda_iodine.URL)
               for f in foods if (f["source"], f["code"]) in iodine)
    manual, more = apply_manual(foods, MANUAL.read_text().splitlines() if MANUAL.exists() else [])
    counts = fill(foods)
    counts["borrowed"] += lent
    print(f"{lent} iodine values from the USDA iodine database")
    twins, problems = apply_same(foods, SAME.read_text().splitlines())
    print(f"{twins} values from reviewed twins, {manual} researched values", *problems, *more, sep="\n")
    counts["borrowed"] += twins + manual
    print("held-back check of similar-food estimates: nutrient, n, median error, median-guess error, within ±25 %")
    for k, n, err, base, close in evaluate(foods):
        print(f"  {k:18} {n:5} {err:10.3g} {base:10.3g} {close:6.0%}")
    counts["estimated"] += estimate_similar(foods)
    with open(path, "w") as fh:
        fh.writelines(json.dumps(f, ensure_ascii=False) + "\n" for f in foods)
    print(f"{len(foods)} foods: {known_before} values measured, {counts['borrowed']} borrowed, {counts['estimated']} estimated")


if __name__ == "__main__":
    main()
