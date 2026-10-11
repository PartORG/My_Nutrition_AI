"""Translated names of the recipe ingredients, from db/food_names.tsv (Python stdlib only).

    python3 tool/food_names.py translate assets/nutri.db   # fill missing rows with TranslateGemma
    python3 tool/food_names.py apply assets/nutri.db       # write the food_names table

translate: every food used in a recipe that has no name yet in a language gets one from
TranslateGemma 4B through a local Ollama (`ollama pull translategemma:4b`). It resumes where it
stopped and never overwrites a name already in the file, so reviewed rows stay as reviewed.
apply: replaces food_names in place; tool/build_real_nutri_db.py calls apply() too. A row whose
English name no longer matches foods.name is stale (the food changed) and is skipped.
"""

import csv
import json
import sqlite3
import sys
import urllib.request
from pathlib import Path

TSV = Path(__file__).resolve().parent.parent / "db/food_names.tsv"
LANGS = {"uk": "Ukrainian", "de": "German", "fr": "French"}
COLUMNS = ["food_id", "en", *LANGS]
OLLAMA = "http://localhost:11434/api/generate"
MODEL = "translategemma:4b"


def load(path: Path = TSV) -> dict[int, dict[str, str]]:
    if not path.exists():
        return {}
    with path.open(newline="", encoding="utf-8") as f:
        return {int(r["food_id"]): r for r in csv.DictReader(f, delimiter="\t")}


def save(rows: dict[int, dict[str, str]], path: Path = TSV) -> None:
    tmp = path.with_suffix(".tmp")
    with tmp.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, COLUMNS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows[k] for k in sorted(rows))
    tmp.replace(path)  # a crash mid-write never leaves half a file


def prompt(name: str, lang: str) -> str:
    """TranslateGemma's own prompt format (ollama.com/library/translategemma)."""
    target = LANGS[lang]
    return (f"You are a professional English (en) to {target} ({lang}) translator. Your goal is to accurately "
            f"convey the meaning and nuances of the original English text while adhering to {target} grammar, "
            f"vocabulary, and cultural sensitivities.\n"
            f"Produce only the {target} translation, without any additional explanations or commentary. "
            f"Please translate the following English text into {target}:\n\n\n{name}")


def clean(out: str) -> str:
    """First non-empty line, no quotes, tabs, stress marks or closing full stop: the TSV cell."""
    line = next((s for s in out.strip().splitlines() if s.strip()), "")
    return line.strip().strip('"«»„“”').replace("\t", " ").replace("\u0301", "").strip().removesuffix(".")


def translate_one(name: str, lang: str) -> str:
    body = json.dumps({"model": MODEL, "prompt": prompt(name, lang), "stream": False,
                       "options": {"temperature": 0}}).encode()
    req = urllib.request.Request(OLLAMA, body, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return clean(json.load(r)["response"])


def translate(db: sqlite3.Connection, path: Path = TSV) -> int:
    rows = load(path)
    foods = db.execute("SELECT id, name FROM foods WHERE id IN (SELECT DISTINCT food_id FROM recipe_ingredients) "
                       "ORDER BY id").fetchall()
    done = 0
    for i, (fid, name) in enumerate(foods, 1):
        row = rows.setdefault(fid, {"food_id": str(fid), "en": name, **{lang: "" for lang in LANGS}})
        if row["en"] != name:  # the food changed: its old translations are wrong now
            row.update({"en": name, **{lang: "" for lang in LANGS}})
        for lang in LANGS:
            if not row.get(lang):
                row[lang] = translate_one(name, lang)
                done += 1
        if i % 25 == 0 or i == len(foods):
            save(rows, path)
            print(f"{i}/{len(foods)} foods, {done} new names", flush=True)
    return done


def apply(db: sqlite3.Connection, path: Path = TSV) -> dict[str, int]:
    """Returns row counts for the build report."""
    names = dict(db.execute("SELECT id, name FROM foods"))
    tsv = load(path)
    rows = [(fid, lang, r[lang]) for fid, r in tsv.items() if names.get(fid) == r["en"] for lang in LANGS if r.get(lang)]
    stale = sum(1 for fid, r in tsv.items() if names.get(fid) != r["en"])
    db.executescript("BEGIN;"
                     "CREATE TABLE IF NOT EXISTS food_names (food_id INTEGER NOT NULL REFERENCES foods (id), "
                     "lang TEXT NOT NULL, name TEXT NOT NULL, PRIMARY KEY (food_id, lang)) WITHOUT ROWID;"
                     "DELETE FROM food_names;")
    db.executemany("INSERT INTO food_names VALUES (?, ?, ?)", rows)
    db.commit()
    return {"food_names rows": len(rows), "food_names stale (skipped)": stale}


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("translate", "apply") or not Path(sys.argv[2]).exists():
        raise SystemExit(__doc__)
    con = sqlite3.connect(sys.argv[2])
    if sys.argv[1] == "translate":
        print(f"{translate(con)} names translated")
    else:
        print(apply(con))
    con.close()
