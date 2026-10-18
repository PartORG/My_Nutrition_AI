"""Detector classes (step 7, docs/PLAN.md) -> nutri.db foods, as a TSV to review by hand.

    python3 tool/detector_classes.py ~/datasets/food-recognition-2022/public_training_set_release_2.0/annotations.json \
        assets/nutri.db db/detector_classes.tsv

Each MyFoodRepo class ("tomato-raw") gets its number of training boxes and the nutri.db row it would log:
from tool/ingredient_map.txt (curated), a government-table food of exactly that name, a dish of that name,
or the "every word in the food's name, head noun in its first part" rule build_real_nutri_db.py uses.
`action` is a suggestion for the review: keep (matched, >= MIN_BOXES boxes), check (matched loosely or by the
rule), merge (too few boxes to learn alone: fold into a broader class), none (no row found).
The reviewed decision is db/detector_labels.tsv (label, nutri.db row, classes); this checks it against the data.
Stdlib only.
"""

import json
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path

MIN_BOXES = 50  # fewer than this and the detector can't learn the class on its own
TRUSTED = ("usda_sr28", "usda_sr", "usda_fdc_foundation", "usda_fndds", "nz_foodfiles", "ciqual", "cofid")
# Words that say how food was made or served, not what it is: tried without them too.
PREP = {"raw", "cooked", "steamed", "boiled", "baked", "fried", "grilled", "roasted", "with", "without", "sauce",
        "caffeine", "decaffeinated", "fresh", "plain", "homemade", "and", "or", "in", "of", "the", "a"}
# A cooking word in the class must show in the food's name (the map was made for recipes: raw forms).
COOKED = {"steamed": {"steamed", "boiled", "cooked"}, "boiled": {"boiled", "cooked"}, "cooked": {"cooked", "boiled"},
          "baked": {"baked", "cooked"}, "fried": {"fried"}, "grilled": {"grilled", "broiled", "cooked"},
          "roasted": {"roasted", "roast", "cooked"}}


def toks(s: str) -> list[str]:
    return [w[:-1] if w.endswith("s") and not w.endswith("ss") and len(w) > 3 else w for w in re.findall(r"[a-z]+", s.lower())]


def load_map(path: Path) -> dict[str, str]:
    """ingredient_map.txt: phrase | exact food name ("=phrase" aliases another line; "-" = deliberately none)."""
    m, aliases = {}, {}
    for line in path.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        phrase, food = [x.strip() for x in (line.split("|") + [""])[:2]]
        (aliases if food.startswith("=") else m)[phrase] = food.lstrip("=")
    for a, target in aliases.items():
        if target in m:
            m[a] = m[target]
    return m


def exact_names(names: list[str]) -> dict[str, tuple[str, bool]]:
    """Normalised name -> (food, whole name matched). "Wine, red" is exact for "wine red"; "Tomatoes, raw" only
    by its first part (loose) for "tomato"."""
    exact = {" ".join(toks(n)): (n, True) for n in names}
    for n in names:
        exact.setdefault(" ".join(toks(n.split(",")[0])), (n, False))
    return exact


def match(name: str, imap: dict[str, str], foods: list[tuple[str, set, set]], exact: dict[str, str],
          dishes: dict[str, str]) -> tuple[str, str]:
    """Class name -> (nutri.db name, how). how: map ("-" = known, logs nothing, e.g. water), exact, loose (first
    part of the name only), dish, rule, none."""
    words = name.replace("-", " ").lower().split()
    core = [w for w in words if w not in PREP] or words
    cooked = set().union(*(COOKED[w] for w in words if w in COOKED))

    def ok(food: str) -> bool:
        return not cooked or bool(cooked & set(toks(food)))

    for phrase in dict.fromkeys([" ".join(words), " ".join(core)]):  # full name first, then without prep words
        for p in (phrase, phrase + "s", phrase[:-1] if phrase.endswith("s") else None):
            if p and p in imap and (imap[p] == "-" or ok(imap[p])):
                return imap[p], "map"
            hit = exact.get(" ".join(toks(p))) if p else None
            if hit and ok(hit[0]):
                return hit[0], "exact" if hit[1] else "loose"
            if p and p in dishes and ok(dishes[p]):
                return dishes[p], "dish"
    want = set(toks(" ".join(core)))
    if not want:
        return "", "none"
    best = None
    for fname, ft, first in foods:
        if not want <= ft or not want & first or cooked and not cooked & ft:
            continue
        # Fewest extra words, raw preferred when the class says raw, shorter names first.
        score = (len(ft - want) - ("raw" in ft and "raw" in words) * 1.5, len(fname))
        if best is None or score < best[0]:
            best = (score, fname)
    return (best[1], "rule") if best else ("", "none")


def check_labels(text: str, classes: set[str], rows: set[str]) -> list[str]:
    """Problems in detector_labels.tsv: a class missing, unknown or in two labels; a nutri.db row that isn't there."""
    problems, seen = [], {}
    for line in text.splitlines():
        if not line.strip() or line.startswith("#") or line.startswith("label\t"):
            continue
        label, row, _, members = line.split("\t")
        if row != "-" and row not in rows:
            problems.append(f"{label}: no nutri.db row {row!r}")
        for c in members.split():
            if c in seen:
                problems.append(f"{c}: in {seen[c]!r} and {label!r}")
            elif c not in classes:
                problems.append(f"{c}: not a dataset class")
            seen[c] = label
    problems += [f"{c}: in no label" for c in sorted(classes - seen.keys())]
    return problems


def main(ann: str, db: str, out: str) -> None:
    data = json.loads(Path(ann).read_text())
    boxes = Counter(a["category_id"] for a in data["annotations"])
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    rows = con.execute(f"SELECT name FROM foods WHERE source IN ({','.join('?' * len(TRUSTED))})", TRUSTED).fetchall()
    foods = [(n, set(toks(n)), set(toks(n.split(",")[0]))) for (n,) in rows]
    exact = exact_names([n for n, _, _ in foods])
    dishes = {n.lower(): n for (n,) in con.execute("SELECT name FROM dishes")}
    imap = load_map(Path(__file__).parent / "ingredient_map.txt")

    lines = ["class\tboxes\tnutri_db\thow\taction"]
    tally = Counter()
    for c in sorted(data["categories"], key=lambda c: -boxes[c["id"]]):
        food, how = match(c["name"], imap, foods, exact, dishes)
        n = boxes[c["id"]]
        action = "none" if how == "none" else "merge" if n < MIN_BOXES else "check" if how in ("rule", "loose") else "keep"
        tally[action] += 1
        lines.append(f"{c['name']}\t{n}\t{food}\t{how}\t{action}")
    Path(out).write_text("\n".join(lines) + "\n")
    print(f"{len(data['categories'])} classes -> {out}: " + ", ".join(f"{k} {v}" for k, v in tally.most_common()))

    labels = Path(out).parent / "detector_labels.tsv"
    if labels.exists():
        rows = {n for (n,) in con.execute("SELECT name FROM foods UNION SELECT name FROM dishes")}
        problems = check_labels(labels.read_text(), {c["name"] for c in data["categories"]}, rows)
        print(f"{labels}: " + ("OK" if not problems else "\n  ".join([f"{len(problems)} problems"] + problems)))
        if problems:
            sys.exit(1)


if __name__ == "__main__":
    main(*sys.argv[1:4])
