"""Normalize stage: every source's foods in one shape, as JSON lines in BUILD/normalized/<source>.jsonl.

    python3 tool/catalog/normalize.py [source ...]   # all readers, or only these

A reader (tool/catalog/readers/<source>.py) yields foods as dicts: source, code, name, lang ('en'), category
('food' | 'dish' | 'branded'), serving_g / serving (optional), and amounts: a list of (scheme, code, value, unit)
with scheme 'usda' or 'eurofir', per 100 g. panel() turns amounts into the nutrient panel of db/catalog/nutrients.tsv.
"""

import contextlib
import importlib
import json
import sys
from pathlib import Path

import schema

HERE = Path(__file__).resolve().parent
BUILD = HERE.parents[2] / "nutrition-ai-assistant/build/catalog"
DATA = HERE.parents[2] / "nutrition-ai-assistant/data"
READERS = [
    "cnf",
    "frida",
    "livsmedelsverket",
    "matvaretabellen",
    "afcd",
    "swiss",
    "usda_sr",
    "usda_fndds",
    "usda_foundation",
    "ciqual",
    "cofid",
    "nz",
    "legacy",
    "off",
    "recipes",
]

PANEL = schema.nutrients()
UNIT = {n["key"]: n["unit"] for n in PANEL}
MAX = {n["key"]: float(n["max"]) for n in PANEL}
CODES = {
    (scheme, code): n["key"] for n in PANEL for scheme in ("usda", "eurofir") for code in n[scheme].split("|") if code
}

_MASS = {"kg": 1e3, "g": 1.0, "mg": 1e-3, "µg": 1e-6, "ug": 1e-6, "mcg": 1e-6}


def convert(value: float, unit: str, to: str) -> float | None:
    """[value] in [unit] → [to]; None when the units can't be converted (a % of fatty acids, IU of an unknown)."""
    unit = unit.strip().replace("μ", "µ").split("/")[0].strip()
    if unit.lower() in {"kcal", "kj"} or to == "kcal":
        return {"kcal": value, "kj": value / 4.184}.get(unit.lower()) if to == "kcal" else None
    if unit in _MASS and to in _MASS:
        return value * _MASS[unit] / _MASS[to]
    return None


def derive(found: dict[str, float], raw: dict[str, list[tuple[float, str]]]) -> dict[str, float]:
    """Panel values that need a rule, from the source's own codes ([raw]: eurofir/usda code → [(value, unit)], as
    given: g, mg, µg as the panel has them for these codes). Only fills what [found] lacks."""
    out = dict(found)

    def g(*codes: str) -> float | None:  # the first code present
        for c in codes:
            if c in raw:
                return raw[c][0][0]
        return None

    def energy(codes: set[str], unit: str) -> float | None:
        return next((v for c in codes for v, u in raw.get(c, []) if u.split("/")[0].strip().lower() == unit), None)

    if "kcal" not in out:
        kcal = energy({"ENERC", "ENERC_KCAL", "208"}, "kcal")
        kj = energy({"ENERC", "ENERC1", "ENERC_KJ", "268"}, "kj")
        if kcal is not None or kj is not None:
            out["kcal"] = kcal if kcal is not None else kj / 4.184
    # European "available carbohydrate" excludes fibre; carbs_g is total (USDA, by difference) = available + fibre.
    if "carbs_g" not in out and (cho := g("CHO", "CHOAVL", "CHOAVLM")) is not None:
        out["carbs_g"] = cho + out.get("fiber_g", 0.0)
    # Retinol activity equivalents: retinol + β-carotene / 12 (+ other carotenoids / 24); not RE (β-carotene / 6).
    if "vitamin_a_ug" not in out and (retinol := g("RETOL", "RETOLAT", "319")) is not None:
        beta = out.get("beta_carotene_ug", g("CARTB", "CARTBTOT", "321") or 0.0)
        out["vitamin_a_ug"] = (
            retinol + beta / 12 + (g("CARTA", "834") or 0.0) / 24 + (g("CRYPXB", "CRYPX", "835") or 0.0) / 24
        )
    # Total folate where no DFE is given: equal for unfortified food, low for fortified (a known underestimate).
    if "folate_ug" not in out and (fol := g("FOL", "FOLFD", "417", "FOLT")) is not None:
        out["folate_ug"] = fol
    if "vitamin_d_ug" not in out and (iu := g("324", "VITD_IU")) is not None:
        out["vitamin_d_ug"] = iu / 40
    # Omega-3 / omega-6 as the sum of their fatty acids when no total is given.
    n3 = [g(c) for c in ("F18:3", "F18D3N3", "F18D3CN3", "F20D5N3", "F20:5", "F22D5N3", "F22:5", "F22D6N3", "F22:6")]
    if "omega3_g" not in out and any(v is not None for v in n3):
        out["omega3_g"] = sum(v for v in n3 if v is not None)
    if "omega6_g" not in out and (la := g("F18D2N6", "F18D2CN6", "F18:2")) is not None:
        out["omega6_g"] = la + (g("F20D4N6", "F20:4") or 0.0)
    return out


def panel(amounts: list[tuple[str, str, float | None, str]]) -> dict[str, float]:
    """Amounts as a source gives them → the panel, in its units, rounded; unknown and unconvertible values
    left out."""
    found: dict[str, float] = {}
    raw: dict[str, list[tuple[float, str]]] = {}
    for scheme, code, value, unit in amounts:
        if value is None:
            continue
        raw.setdefault(code, []).append((value, unit))
        key = CODES.get((scheme, code))
        if key is None or key in found:
            continue
        v = convert(value, unit or UNIT[key], UNIT[key])
        if v is not None:
            found[key] = v
    return clean(derive(found, raw))


def clean(nutrients: dict[str, float | None]) -> dict[str, float]:
    """Panel keys only, rounded; unknown, negative and impossible values (above MAX: a wrong unit) left out."""
    return {k: round(v, 4) for k, v in nutrients.items() if k in MAX and v is not None and 0 <= v <= MAX[k]}


def number(v) -> float | None:
    """A cell → a number; 'tr', 'trace' → 0; '', '-', 'n.d.', 'NULL' and text → None. Commas as decimal points."""
    if v is None or isinstance(v, bool):
        return None
    if isinstance(v, int | float):
        return float(v)
    s = str(v).strip().lower().replace(",", ".").lstrip("<~")
    if s in {"tr", "trace", "traces", "spor"}:
        return 0.0
    try:
        return float(s)
    except ValueError:
        return None


def write(source: str, foods) -> int:
    """One file per source; a row may name its own source (readers.legacy writes several) and may bring finished
    nutrients (already panel keys) instead of amounts."""
    (BUILD / "normalized").mkdir(parents=True, exist_ok=True)
    files, n = {}, 0
    with contextlib.ExitStack() as stack:
        for f in foods:
            row = {"source": source, "lang": "en", "category": "food", **{k: v for k, v in f.items() if k != "amounts"}}
            if "nutrients" in f:
                row["nutrients"] = clean(f["nutrients"])
            else:
                row["nutrients"] = panel(f["amounts"])
            if row["name"] and row["nutrients"]:
                if row["source"] not in files:
                    files[row["source"]] = stack.enter_context(
                        open(BUILD / "normalized" / f"{row['source']}.jsonl", "w")
                    )
                files[row["source"]].write(json.dumps(row, ensure_ascii=False) + "\n")
                n += 1
    return n


def main(only: list[str]) -> None:
    sys.path.insert(0, str(HERE))
    for source in only or READERS:
        reader = importlib.import_module(f"readers.{source}")
        if source == "recipes":  # recipes have their own shape (readers/recipes.py)
            print(source, reader.write(BUILD, reader.read(DATA)), flush=True)
        else:
            print(source, write(source, reader.read(DATA)), flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
