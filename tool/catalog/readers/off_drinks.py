"""Drinks no government table has (db/catalog/drinks.tsv) → one generic food each: the median of the Open Food Facts
labels in its categories (ODbL), per nutrient over the labels that give it, from at least MIN_PRODUCTS products.
Checked like every OFF row (readers.off.label); source off_median, code = the drink's name."""

from pathlib import Path
from statistics import median

from readers import off

DRINKS = Path(__file__).resolve().parents[3] / "db/catalog/drinks.tsv"
MIN_PRODUCTS = 5


def drinks(lines: list[str]) -> list[dict]:
    out = []
    for line in lines:
        if line.strip() and not line.startswith("#"):
            name, tags, serving_g, serving = line.split("\t")
            out.append({"name": name, "tags": set(tags.split("|")), "serving_g": float(serving_g), "serving": serving})
    return out


def medians(drink: list[dict], labels) -> list[dict]:
    """[labels]: (categories, label) pairs → one row per drink with enough labels."""
    found = {d["name"]: [] for d in drink}
    for tags, n in labels:
        for d in drink:
            if d["tags"] & tags:
                found[d["name"]].append(n)
    rows = []
    for d in drink:
        got = found[d["name"]]
        if len(got) < MIN_PRODUCTS:
            continue
        keys = {k for n in got for k, v in n.items() if v is not None}
        rows.append({
            "code": d["name"].lower(),
            "name": d["name"],
            "category": "food",
            "serving_g": d["serving_g"],
            "serving": d["serving"],
            "products": len(got),
            "nutrients": {k: median(v for n in got if (v := n.get(k)) is not None) for k in keys},
        })
    return rows


def read(data):
    drink = drinks(DRINKS.read_text().splitlines())
    wanted = set().union(*(d["tags"] for d in drink))

    def labels():
        for r in off.rows(data):
            tags = set((r.get("categories_tags") or "").split(","))
            if tags & wanted and (checked := off.label(r)) is not None:
                _, n = checked
                yield tags, off.v3.plausible(n) | {k: n[k] for k in off.CORE}

    for row in medians(drink, labels()):
        print(f"  {row['name']}: median of {row['products']} labels")
        yield {**row, "source": "off_median"}
