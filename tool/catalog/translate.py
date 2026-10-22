"""Translate stage: everyday food names → Ukrainian, German and French aliases (docs/PLAN.md "Catalogue v4", decisions
10, 13), with TranslateGemma 4B through a local Ollama (tool/food_names.py's prompt). Cached in db/catalog/aliases.tsv:
it resumes where it stopped and never overwrites a cell, so reviewed names stay as reviewed.

    python3 tool/catalog/translate.py [limit]

Which names: the defaults people meet first: used by a recipe, listed in db/catalog/defaults.tsv, or from a government
table; most-used first.
"""

import csv
import json
import sys
from collections import Counter
from pathlib import Path

import match
from normalize import BUILD

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import food_names

TSV = Path(__file__).resolve().parents[2] / "db/catalog/aliases.tsv"
LANGS = list(food_names.LANGS)


def load() -> dict[str, dict[str, str]]:
    if not TSV.exists():
        return {}
    with TSV.open(newline="", encoding="utf-8") as fh:
        return {r["common_name"]: r for r in csv.DictReader(fh, delimiter="\t")}


def save(rows: dict[str, dict[str, str]]) -> None:
    tmp = TSV.with_suffix(".tmp")
    with tmp.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, ["common_name", *LANGS], delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows[k] for k in sorted(rows))
    tmp.replace(TSV)  # a crash mid-write never leaves half a file


def wanted() -> list[str]:
    """Default foods' everyday names, most used by recipes first."""
    foods = {}
    with open(BUILD / "matched/foods.jsonl") as fh:
        for line in fh:
            f = json.loads(line)
            if f["is_default"]:
                foods[f["id"]] = f
    uses = Counter()
    with open(BUILD / "matched/recipes.jsonl") as fh:
        for line in fh:
            for x in json.loads(line)["lines"]:
                if x["food_id"] in foods:
                    uses[foods[x["food_id"]]["common_name"]] += 1
    names = {f["common_name"] for f in foods.values() if f.get("authoritative") or len(f["aliases"]) > 2}
    names |= {f["common_name"] for f in foods.values() if f["source"] == "off_median"}  # db/catalog/drinks.tsv
    names |= {o["alias"] for o in match.overrides()}  # the reviewed everyday names of defaults.tsv
    return sorted(names | set(uses), key=lambda n: (-uses[n], n))


def main(limit: int | None) -> None:
    rows = load()
    todo = wanted()[:limit]
    done = 0
    for i, name in enumerate(todo, 1):
        row = rows.setdefault(name, {"common_name": name, **dict.fromkeys(LANGS, "")})
        for lang in LANGS:
            if not row[lang]:
                row[lang] = food_names.clean(food_names.translate_one(name, lang))
                done += 1
        if i % 100 == 0:
            save(rows)
            print(f"{i}/{len(todo)}", flush=True)
    save(rows)
    print(f"{len(todo)} names, {done} new translations")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else None)
