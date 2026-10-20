"""Match stage, foods: every normalized food gets an id, its everyday name, its state and whether it is the default
for that name; branded rows go to products. Reads BUILD/normalized/*.jsonl (not the recipes, not Open Food Facts:
readers.off rows are products already), writes BUILD/matched/foods.jsonl and products.jsonl.

    python3 tool/catalog/match.py

db/catalog/defaults.tsv is the reviewed override: a word people say → the exact food it means (and its serving).
"""

import hashlib
import json
import sys
from collections import defaultdict
from pathlib import Path

from names import common_name, default_score, state
from normalize import BUILD

HERE = Path(__file__).resolve().parent
DEFAULTS = HERE.parents[1] / "db/catalog/defaults.tsv"
# Government tables first (the order breaks ties between equally plain rows), then the rest.
SOURCE_RANK = {
    s: i
    for i, s in enumerate(
        [
            "usda_sr",
            "usda_foundation",
            "cofid",
            "ciqual",
            "cnf",
            "nz",
            "afcd",
            "frida",
            "livsmedelsverket",
            "matvaretabellen",
            "swiss",
            "usda_fndds",
            "foodstruct",
            "indb",
            "indonesia",
            "fda_produce",
            "nutrients_csvfile",
            "food_nutrition_dataset",
            "daily_food",
            "food101",
        ]
    )
}
AUTHORITATIVE = set(list(SOURCE_RANK)[:12])


def food_id(source: str, code: str) -> int:
    """Stable across rebuilds for the same source row; 52 bits, so it is exact in Dart and JSON."""
    return int.from_bytes(hashlib.sha1(f"{source}\x00{code}".encode()).digest()[:7]) >> 4


def overrides() -> list[dict]:
    """defaults.tsv: alias | source | food name | serving_g (may be empty). A later line for the same alias wins."""
    out = {}
    for line in DEFAULTS.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            alias, source, name, serving = (line.split("\t") + ["", "", ""])[:4]
            out[alias.strip().lower()] = {
                "alias": alias.strip().lower(),
                "source": source.strip(),
                "name": name.strip(),
                "serving_g": float(serving) if serving.strip() else None,
            }
    return list(out.values())


def match_foods(rows: list[dict], defaults: list[dict] | None = None) -> tuple[list[dict], list[dict], list[str]]:
    """→ (foods, products, problems). Defaults: the override's food, else the best default_score per common name."""
    foods, products = [], []
    for r in rows:
        r["id"] = food_id(r["source"], r["code"])
        if r["category"] == "branded":
            products.append(r)
            continue
        r["common_name"] = common_name(r["name"])
        r["state"] = state(r["name"])
        r["authoritative"] = r["source"] in AUTHORITATIVE
        r["is_default"] = False
        r["aliases"] = []
        foods.append(r)
    by_name = defaultdict(list)
    for f in foods:
        by_name[f["name"].lower()].append(f)
    groups = defaultdict(list)
    for f in foods:
        groups[f["common_name"]].append(f)
    problems = []
    chosen: dict[str, dict] = {}
    defaults = overrides() if defaults is None else defaults
    owner: dict[str, dict] = {}  # alias → the override's food: nobody else may answer to it
    for o in defaults:
        hits = [f for f in by_name.get(o["name"].lower(), []) if not o["source"] or f["source"] == o["source"]]
        if not hits:
            problems.append(
                f"defaults.tsv: no food named {o['name']!r} ({o['source'] or 'any source'}) for {o['alias']!r}"
            )
            continue
        f = min(hits, key=lambda h: SOURCE_RANK.get(h["source"], 99))
        if o["serving_g"]:
            f["serving_g"] = o["serving_g"]
        f["aliases"].append(o["alias"])
        owner[o["alias"]] = f
        # The override's food is the default of its own common name; a line whose alias is that name wins over one
        # that only points there ("sun-dried tomato" must not make sun-dried the default "tomato").
        if o["alias"] == f["common_name"]:
            chosen[f["common_name"]] = f
        else:
            chosen.setdefault(f["common_name"], f)
    for name, group in groups.items():
        best = chosen.get(name) or min(group, key=lambda f: default_score(f, SOURCE_RANK))
        best["is_default"] = True
    for f in foods:
        if f["is_default"]:
            plural = f["common_name"] + ("es" if f["common_name"].endswith(("ch", "sh", "s", "x", "o")) else "s")
            f["aliases"] = sorted({f["common_name"], plural, *f["aliases"]} - {""})
        else:
            f["aliases"] = sorted(set(f["aliases"]))
        f["aliases"] = [a for a in f["aliases"] if owner.get(a, f) is f]
    return foods, products, problems


def load(folder: Path) -> list[dict]:
    rows = []
    for path in sorted(folder.glob("*.jsonl")):
        if path.stem in {"off", "recipes"}:
            continue
        with open(path) as fh:
            rows += [json.loads(line) for line in fh]
    return rows


def main() -> None:
    foods, products, problems = match_foods(load(BUILD / "normalized"))
    out = BUILD / "matched"
    out.mkdir(parents=True, exist_ok=True)
    for name, rows in (("foods", foods), ("products", products)):
        with open(out / f"{name}.jsonl", "w") as fh:
            fh.writelines(json.dumps(r, ensure_ascii=False) + "\n" for r in rows)
    defaults = sum(f["is_default"] for f in foods)
    print(f"{len(foods)} foods ({defaults} defaults), {len(products)} branded rows to products")
    print(*problems, sep="\n", file=sys.stderr)


if __name__ == "__main__":
    main()
