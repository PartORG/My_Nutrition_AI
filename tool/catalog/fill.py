"""Fill stage (docs/PLAN.md "Catalogue v4", decision 15): a food's missing nutrients come from the same food elsewhere.
Same food = the same everyday name and the same state (raw and dried differ in water, so never lend to each other).
1. borrowed: the most authoritative government row of that food that has the value;
2. estimated: else the median of every row of that food that has it.
Nothing is calculated from other nutrients; a value no row has stays unknown. Products keep their label as printed.
Reads and rewrites BUILD/matched/foods.jsonl.

    python3 tool/catalog/fill.py
"""

import json
from collections import defaultdict
from statistics import median

from match import SOURCE_RANK
from normalize import BUILD, PANEL

KEYS = [n["key"] for n in PANEL]


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
                    borrowed.append(k)
                    continue
                values = [x["nutrients"][k] for x in group if x is not f and k in x["nutrients"]]
                if values:
                    f["nutrients"][k] = round(median(values), 4)
                    estimated.append(k)
            f["borrowed"], f["estimated"] = borrowed, estimated
            counts["borrowed"] += len(borrowed)
            counts["estimated"] += len(estimated)
    return counts


def main() -> None:
    path = BUILD / "matched/foods.jsonl"
    with open(path) as fh:
        foods = [json.loads(line) for line in fh]
    known_before = sum(len(f["nutrients"]) for f in foods)
    counts = fill(foods)
    with open(path, "w") as fh:
        fh.writelines(json.dumps(f, ensure_ascii=False) + "\n" for f in foods)
    print(f"{len(foods)} foods: {known_before} values measured, {counts['borrowed']} borrowed, {counts['estimated']} estimated")


if __name__ == "__main__":
    main()
