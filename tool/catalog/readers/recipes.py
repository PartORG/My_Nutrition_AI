"""Recipes as their sources give them, before matching: the v3 loaders (food.com, BBC Good Food, allrecipes, BBC
Christmas, Reddit; tool/build_real_nutri_db.py) read the files as before, but hand each recipe to Collector.add
instead of Recipes.add, so the lines stay text until the match stage maps them to v4 foods. Scraped content, kept as
the owner's exception (docs/PLAN.md "Catalogue v4", decisions 8, 9)."""

import html
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import build_real_nutri_db as v3

URL = {"food.com": "https://www.food.com/recipe/{}", "bbcgoodfood": "{}", "allrecipes99": "{}"}


class Collector:
    """Recipes.add's signature; keeps what a recipe needs, drops only what can never become one."""

    def __init__(self):
        self.recipes: list[dict] = []

    def add(
        self,
        rep,
        src,
        sid,
        title,
        lines,
        steps,
        servings,
        minutes=None,
        raw_tags=(),
        published_kcal=None,
        rank=0.0,
        curated_only=False,
    ):
        title = v3.tidy(html.unescape(str(title or "")))
        lines = [html.unescape(str(x)).strip() for x in lines or [] if str(x).strip()]
        steps = [re.sub(r"\s+", " ", html.unescape(str(s))).strip() for s in v3.lst(steps)]
        steps = [s for s in steps if s]
        try:
            servings = round(float(servings)) if servings not in (None, "") else None
        except (TypeError, ValueError):
            servings = None
        why = (
            "no title"
            if not title
            else "no ingredient lines"
            if not lines
            else "no instructions"
            if not steps
            else "no servings"
            if not servings or not 1 <= servings <= 60
            else None
        )
        if why:
            rep["dropped"][why] += 1
            return
        rep["kept"] += 1
        url = (
            URL.get(src, "").format(sid)
            if src in URL and str(sid).startswith(("http", "1", "2", "3", "4", "5", "6", "7", "8", "9"))
            else None
        )
        self.recipes.append(
            {
                "source": src,
                "code": str(sid),
                "lang": "en",
                "title": title[:200],
                "servings": servings,
                "minutes": minutes if minutes and 0 < minutes <= 60 * 24 * 3 else None,
                "tags": [str(t) for t in raw_tags if t],
                "published_kcal": published_kcal,
                "rank": rank,
                "curated_only": curated_only,
                "url": url,
                "lines": lines,
                "steps": steps,
            }
        )


def read(data) -> list[dict]:
    c = Collector()
    v3.load_foodcom(data, c)
    v3.load_bbc(data, c)
    v3.load_small_recipes(data, c)
    return c.recipes


def write(build: Path, recipes: list[dict]) -> int:
    (build / "normalized").mkdir(parents=True, exist_ok=True)
    with open(build / "normalized" / "recipes.jsonl", "w") as out:
        out.writelines(json.dumps(r, ensure_ascii=False) + "\n" for r in recipes)
    return len(recipes)
