"""Write stage: nutri.db, health.db and products.db (db/catalog/*.sql) from the matched and normalized files.

    python3 tool/catalog/write.py OUT_DIR [nutri|health|products ...]

nutri.db: foods (filled), aliases, allergens, recipes (lines, steps, tags, nutrition per serving with coverage).
health.db: DRI reference values, the curated conditions of db/medical.sql (run against the v4 foods), MedQuAD passages.
products.db: Open Food Facts (2026 dump) and every other branded row, one per barcode (the most complete label).
"""

import json
import re
import sqlite3
import sys
from datetime import date
from pathlib import Path

import schema
import translate
from normalize import BUILD, DATA, PANEL

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_real_nutri_db as v3
from build_medical import MEDICAL_SQL

KEYS = [n["key"] for n in PANEL]
NUTRI_SCHEMA, NUTRI_DATA = 4, 5  # lib/data/nutri_db.dart reads these
HEALTH_SCHEMA = 1
V3 = "a dataset of the v3 build, kept (owner, 2026-10-19); licence as listed in docs/DATA_SOURCES.md"
SCRAPED = "scraped recipe site: copyright stays with the site and authors (owner's exception, 2026-10-19)"
# id → (name, licence, url, authoritative)
SOURCES = {
    "usda_sr": ("USDA SR Legacy (FoodData Central)", "public domain (US government)", "https://fdc.nal.usda.gov", 1),
    "usda_foundation": (
        "USDA Foundation Foods (FoodData Central)",
        "public domain (US government)",
        "https://fdc.nal.usda.gov",
        1,
    ),
    "usda_fndds": (
        "USDA FNDDS 2021-2023 (FoodData Central)",
        "public domain (US government)",
        "https://fdc.nal.usda.gov",
        1,
    ),
    "cnf": (
        "Canadian Nutrient File 2015, Health Canada",
        "Open Government Licence - Canada",
        "https://open.canada.ca/data/dataset/089885f9-ed53-44e6-854a-14d21a1ec2e0",
        1,
    ),
    "frida": ("Frida 5.5, DTU Food Institute (Denmark)", "CC BY 4.0", "https://doi.org/10.11583/DTU.29500682", 1),
    "livsmedelsverket": (
        "Swedish Food Agency food composition database",
        "CC BY 4.0",
        "https://www.livsmedelsverket.se/en/about-us/open-data/food-composition-data/",
        1,
    ),
    "matvaretabellen": (
        "Norwegian Food Composition Table, Mattilsynet",
        "NLOD 2.0",
        "https://www.matvaretabellen.no",
        1,
    ),
    "afcd": (
        "Australian Food Composition Database Release 3, FSANZ",
        "CC BY 4.0",
        "https://www.foodstandards.gov.au/science-data/food-nutrient-databases/afcd",
        1,
    ),
    "swiss": (
        "Swiss Food Composition Database 7.1, FSVO",
        "free use incl. commercial, source required",
        "https://naehrwertdaten.ch",
        1,
    ),
    "ciqual": ("ANSES-CIQUAL 2025", "Licence Ouverte / etalab 2.0", "https://doi.org/10.57745/RDMHWY", 1),
    "cofid": (
        "McCance and Widdowson's CoFID 2021, OHID",
        "Open Government Licence v3.0",
        "https://www.gov.uk/government/publications/composition-of-foods-integrated-dataset-cofid",
        1,
    ),
    "nz": ("NZ FOODfiles 2018, Plant & Food Research / Ministry of Health", V3, "https://www.foodcomposition.co.nz", 1),
    "off": ("Open Food Facts", "ODbL 1.0 (database), DbCL (contents)", "https://world.openfoodfacts.org", 0),
    "off_extract": ("Open Food Facts extract (v3)", "ODbL 1.0", "https://world.openfoodfacts.org", 0),
    "usda_fdc_branded": (
        "USDA Branded Foods (FoodData Central)",
        "public domain (US government)",
        "https://fdc.nal.usda.gov",
        0,
    ),
    "fda_produce": (
        "FDA nutrition facts for raw fruits, vegetables and fish",
        "public domain (US government)",
        None,
        0,
    ),
    "food.com": ("food.com recipes", SCRAPED, "https://www.food.com", 0),
    "bbcgoodfood": ("BBC Good Food recipes", SCRAPED, "https://www.bbcgoodfood.com", 0),
    "allrecipes99": ("allrecipes recipes", SCRAPED, "https://www.allrecipes.com", 0),
    "christmas": ("BBC Christmas recipes", SCRAPED, None, 0),
    "reddit": ("Reddit recipe posts", SCRAPED, "https://www.reddit.com", 0),
    "nasem_dri": (
        "Dietary Reference Intakes, National Academies (as published by Health Canada)",
        "facts (numbers) only",
        (
            "https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/"
            "dietary-reference-intakes/tables.html"
        ),
        0,
    ),
    "curated": (
        "Guidelines curated by the developer (db/medical.sql: each row names its guideline)",
        "paraphrased, not copied",
        None,
        0,
    ),
}


def source_row(sid: str) -> tuple:
    if sid.startswith("medquad_"):
        return (
            sid,
            f"MedQuAD ({sid.removeprefix('medquad_').upper()}, NIH)",
            "CC BY 4.0",
            "https://github.com/abachaa/MedQuAD",
            0,
        )
    name, licence, url, auth = SOURCES.get(sid, (sid, V3, None, 0))
    return (sid, name, licence, url, auth)


def jsonl(path: Path):
    with open(path) as fh:
        for line in fh:
            yield json.loads(line)


def fresh(path: Path, name: str) -> sqlite3.Connection:
    path.unlink(missing_ok=True)
    con = schema.create(path, name)
    con.execute("PRAGMA journal_mode = OFF")
    con.execute("PRAGMA synchronous = OFF")
    return con


def finish(con: sqlite3.Connection, fts: list[str]) -> None:
    for table in fts:
        con.execute(f"INSERT INTO {table}({table}) VALUES ('rebuild')")
    con.commit()
    con.execute("VACUUM")
    con.close()


def nutrients(n: dict) -> list:
    return [n.get(k) for k in KEYS]


def translated_aliases(foods, names: dict | None = None) -> list[tuple]:
    """Translated everyday names → (alias, lang, food id): the food that owns the English name (defaults.tsv wins
    over the group default), and each word once per language, the most-used name first ("rice bran" → "рис" too)."""
    if names is None:
        rows = translate.load()
        names = {n: rows[n] for n in translate.wanted() if n in rows}  # most used by recipes first
    owner = {}
    for f in foods:
        if f["is_default"]:
            owner.setdefault(f["common_name"], f["id"])
    for f in foods:
        owner.update({a: f["id"] for a in f["aliases"]})
    out, seen = [], set()
    for name, row in names.items():
        for lang in translate.LANGS:
            if name in owner and row[lang] and (row[lang].lower(), lang) not in seen:
                seen.add((row[lang].lower(), lang))
                out.append((row[lang], lang, owner[name]))
    return out


def write_nutri(out: Path) -> None:
    con = fresh(out / "nutri.db", "nutri")
    foods = {f["id"]: f for f in jsonl(BUILD / "matched/foods.jsonl")}
    recipes = list(jsonl(BUILD / "matched/recipes.jsonl"))
    used = {f["source"] for f in foods.values()} | {r["source"] for r in recipes}
    con.executemany("INSERT INTO sources VALUES (?, ?, ?, ?, ?)", [source_row(s) for s in sorted(used)])
    cols = [
        "id",
        "name",
        "common_name",
        "is_default",
        "category",
        "state",
        "source_id",
        "source_code",
        "serving_g",
        "serving",
        *KEYS,
        "borrowed",
        "estimated",
    ]
    con.executemany(
        f"INSERT INTO foods ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})",
        [
            (
                f["id"],
                f["name"][:200],
                f["common_name"],
                int(f["is_default"]),
                f["category"],
                f.get("state"),
                f["source"],
                f["code"],
                f.get("serving_g"),
                f.get("serving"),
                *nutrients(f["nutrients"]),
                ",".join(f.get("borrowed", [])),
                ",".join(f.get("estimated", [])),
            )
            for f in foods.values()
        ],
    )
    con.executemany(
        "INSERT OR IGNORE INTO food_aliases VALUES (?, 'en', ?)",
        [(a, f["id"]) for f in foods.values() for a in f["aliases"]],
    )
    con.executemany("INSERT OR IGNORE INTO food_aliases VALUES (?, ?, ?)", translated_aliases(foods.values()))
    con.executemany(
        "INSERT OR IGNORE INTO food_allergens VALUES (?, ?)",
        [(f["id"], a) for f in foods.values() for a in v3.allergens_from_text(f["name"])],
    )
    for r in recipes:
        con.execute(
            "INSERT INTO recipes (id, lang, title, title_en, servings, minutes, texture, rating, reviews, "
            "published_kcal, source_id, url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                r["id"],
                r["lang"],
                r["title"],
                r.get("title_en", r["title"]),
                r["servings"],
                r["minutes"],
                r["texture"],
                None,
                None,
                r["published_kcal"],
                r["source"],
                r["url"],
            ),
        )
        con.executemany(
            "INSERT INTO recipe_ingredients (recipe_id, position, food_id, grams, line, line_en) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            [
                (r["id"], x["position"], x["food_id"], x["grams"], x["line"], x.get("line_en"))  # NULL: English
                for x in r["lines"]
            ],
        )
        con.executemany(
            "INSERT INTO recipe_steps VALUES (?, ?, ?, NULL)", [(r["id"], i, s) for i, s in enumerate(r["steps"], 1)]
        )
        con.executemany("INSERT OR IGNORE INTO recipe_tags VALUES (?, ?)", [(r["id"], t) for t in r["tags"]])
    con.executemany(
        "INSERT INTO meta VALUES (?, ?)",
        [
            ("schema_version", str(NUTRI_SCHEMA)),
            ("data_version", str(NUTRI_DATA)),
            ("built_at", date.today().isoformat()),
            ("embedding_model", "embeddinggemma-300m"),
            ("source", 'tool/catalog (docs/PLAN.md "Catalogue v4")'),
        ],
    )
    # Stored, not computed per query: the bundled budget is 800 MB (owner, 2026-10-20) and this costs ~140 MB.
    con.executescript("""
        CREATE TABLE stored_nutrition AS SELECT * FROM recipe_nutrition;
        DROP VIEW recipe_nutrition;
        ALTER TABLE stored_nutrition RENAME TO recipe_nutrition;
        CREATE UNIQUE INDEX recipe_nutrition_recipe ON recipe_nutrition (recipe_id);
    """)
    finish(con, ["foods_fts", "recipes_fts"])
    print(f"nutri.db: {len(foods)} foods, {len(recipes)} recipes, {(out / 'nutri.db').stat().st_size:,} bytes")


def curated(foods: list[dict]) -> sqlite3.Connection:
    """db/medical.sql run as v3 ran it, against a v3-shaped table of the v4 foods: its rules, foods to avoid and
    passages come back unchanged."""
    tmp = sqlite3.connect(":memory:")
    tmp.create_function("regexp", 2, lambda p, v: v is not None and re.search(p, v) is not None)
    tmp.executescript("""
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE foods (id INTEGER PRIMARY KEY, name TEXT, sugar_g REAL);
        CREATE TABLE conditions (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE condition_rules (condition_id INTEGER, nutrient TEXT, max_per_day REAL, note TEXT);
        CREATE TABLE condition_avoid (condition_id INTEGER, food_id INTEGER, note TEXT);
        CREATE TABLE docs (id INTEGER PRIMARY KEY, source TEXT, text TEXT, embedding BLOB);""")
    tmp.executemany(
        "INSERT INTO foods VALUES (?, ?, ?)", [(f["id"], f["name"], f["nutrients"].get("sugar_g")) for f in foods]
    )
    tmp.executescript(MEDICAL_SQL.read_text())
    return tmp


CONDITIONS = {
    "diabetes_t2": "Type 2 diabetes",
    "hypertension": "High blood pressure",
    "gout": "Gout",
    "als": "ALS (motor neurone disease)",
    "ms": "Multiple sclerosis",
}


def write_health(out: Path) -> None:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from readers import dri, medquad

    con = fresh(out / "health.db", "health")
    foods = list(jsonl(BUILD / "matched/foods.jsonl"))
    tmp = curated(foods)
    qa = list(medquad.read(DATA))
    sids = {"nasem_dri", "curated"} | {d["source_id"] for d in qa}
    con.executemany("INSERT INTO sources VALUES (?, ?, ?, ?)", [source_row(s)[:4] for s in sorted(sids)])
    con.executemany(
        "INSERT INTO reference_values VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                r["nutrient"],
                r["sex"],
                r["age_from"],
                r["age_to"],
                r["life_stage"],
                r["kind"],
                r["amount"],
                r["source_id"],
            )
            for r in dri.read(DATA)
        ],
    )
    for cid, key in tmp.execute("SELECT id, name FROM conditions"):
        con.execute(
            "INSERT INTO conditions VALUES (?, ?, ?, ?, 'curated')",
            (cid, key, CONDITIONS.get(key, key), CONDITIONS.get(key, key)),
        )
    con.executemany(
        "INSERT INTO condition_rules (condition_id, nutrient, max_per_day, note, source_id) "
        "VALUES (?, ?, ?, ?, 'curated')",
        tmp.execute("SELECT * FROM condition_rules"),
    )
    con.executemany(
        "INSERT OR IGNORE INTO condition_foods VALUES (?, ?, 'avoid', ?, 'curated')",
        tmp.execute("SELECT condition_id, food_id, note FROM condition_avoid"),
    )
    con.executemany(
        "INSERT INTO docs (kind, condition_id, question, text, source_id, url) "
        "VALUES ('guideline', NULL, NULL, ?, 'curated', NULL)",
        [(f"{text}\n\nSource: {src}",) for src, text in tmp.execute("SELECT source, text FROM docs")],
    )
    con.executemany(
        "INSERT INTO docs (kind, condition_id, question, text, source_id, url) VALUES ('qa', ?, ?, ?, ?, ?)",
        [(None, d["question"], d["text"], d["source_id"], d["url"]) for d in qa],
    )
    con.executemany(
        "INSERT INTO meta VALUES (?, ?)",
        [
            ("schema_version", str(HEALTH_SCHEMA)),
            ("built_at", date.today().isoformat()),
            ("nutri_built_at", date.today().isoformat()),
            ("embedding_model", "embeddinggemma-300m"),
        ],
    )
    finish(con, ["docs_fts"])
    print(f"health.db: {len(qa)} Q&A passages, {(out / 'health.db').stat().st_size:,} bytes")


def write_products(out: Path) -> None:
    con = fresh(out / "products.db", "products")
    best: dict[str, tuple] = {}
    rows, sids = [], set()

    def add(p: dict, kind: str) -> None:
        sids.add(p["source"])
        row = (
            p.get("barcode"),
            p["name"][:200],
            p.get("brand"),
            kind,
            p["source"],
            p.get("serving_g"),
            p.get("serving"),
            *nutrients(p["nutrients"]),
        )
        if not p.get("barcode"):
            rows.append((row, p.get("allergens") or []))
        elif p["barcode"] not in best or len(p["nutrients"]) > best[p["barcode"]][1]:
            best[p["barcode"]] = (row, len(p["nutrients"]), p.get("allergens") or [])

    menus = {"mcdonalds_menu", "chains_nutrition_values", "india_chains"}
    for p in jsonl(BUILD / "matched/products.jsonl"):
        add(p, "menu" if p["source"] in menus else "packaged")
    for p in jsonl(BUILD / "normalized/off.jsonl"):
        add(p, "packaged")
    con.executemany("INSERT INTO sources VALUES (?, ?, ?, ?)", [source_row(s)[:4] for s in sorted(sids)])
    cols = ["barcode", "name", "brand", "kind", "source_id", "serving_g", "serving", *KEYS]
    sql = f"INSERT INTO products ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})"
    allergens = []
    for row, *rest in [*best.values(), *((r, 0, a) for r, a in rows)]:
        cur = con.execute(sql, row)
        allergens += [(cur.lastrowid, a) for a in rest[-1]]
    con.executemany("INSERT OR IGNORE INTO product_allergens VALUES (?, ?)", allergens)
    n = con.execute("SELECT count(*) FROM products").fetchone()[0]
    con.executemany(
        "INSERT INTO meta VALUES (?, ?)",
        [("schema_version", str(NUTRI_SCHEMA)), ("built_at", date.today().isoformat()), ("rows", str(n))],
    )
    finish(con, ["products_fts"])
    print(f"products.db: {n:,} products, {(out / 'products.db').stat().st_size:,} bytes")


def main(out: Path, which: list[str]) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for name in which or ["nutri", "health", "products"]:
        {"nutri": write_nutri, "health": write_health, "products": write_products}[name](out)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]), sys.argv[2:])
