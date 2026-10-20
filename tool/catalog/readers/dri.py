"""Dietary Reference Intakes (National Academies) as Health Canada publishes them: raw_medical/dri/*.html, the numbers
only (facts). One row per nutrient, sex, age band, life stage and kind: RDA, AI (the RDA/AI value marked with *), UL
(sodium's CDRR, the chronic-disease risk reduction intake, is its upper limit), AMDR min/max (% of energy). EARs, IU
and g/kg columns are left out. Units: each nutrient's DRI unit, converted to the panel's (copper µg → mg)."""

import html
import re

from normalize import UNIT, convert

FILES = ["reference-values-vitamins-dietary-reference-intakes-tables-2005.html", "reference-values-elements.html",
         "reference-values-macronutrients.html"]
# DRI name (start of the header) → (panel key, the DRI's unit).
NUTRIENTS = {
    "vitamin a": ("vitamin_a_ug", "µg"), "vitamin d": ("vitamin_d_ug", "µg"), "vitamin e": ("vitamin_e_mg", "mg"),
    "vitamin k": ("vitamin_k_ug", "µg"), "vitamin c": ("vitamin_c_mg", "mg"), "thiamin": ("vitamin_b1_mg", "mg"),
    "riboflavin": ("vitamin_b2_mg", "mg"), "niacin": ("vitamin_b3_mg", "mg"), "vitamin b6": ("vitamin_b6_mg", "mg"),
    "folate": ("folate_ug", "µg"), "vitamin b12": ("vitamin_b12_ug", "µg"), "pantothenic acid": ("vitamin_b5_mg", "mg"),
    "biotin": ("vitamin_b7_ug", "µg"), "choline": ("choline_mg", "mg"), "calcium": ("calcium_mg", "mg"),
    "copper": ("copper_mg", "µg"), "iodine": ("iodine_ug", "µg"), "iron": ("iron_mg", "mg"),
    "magnesium": ("magnesium_mg", "mg"), "manganese": ("manganese_mg", "mg"), "phosphorus": ("phosphorus_mg", "mg"),
    "selenium": ("selenium_ug", "µg"), "zinc": ("zinc_mg", "mg"), "potassium": ("potassium_mg", "mg"),
    "sodium": ("sodium_mg", "mg"), "carbohydrate": ("carbs_g", "g"), "total protein": ("protein_g", "g"),
    "linoleic acid": ("omega6_g", "g"), "α-linolenic acid": ("omega3_g", "g"), "total fibre": ("fiber_g", "g"),
}
AMDR = {"total carbohydrate": "carbs_g", "total protein": "protein_g", "total fat": "fat_g",
        "n-6 polyunsaturated": "omega6_g", "n-3 polyunsaturated": "omega3_g"}
GROUPS = {"infants": ("any", ""), "children": ("any", ""), "males": ("male", ""), "females": ("female", ""),
          "pregnancy": ("female", "pregnancy"), "lactation": ("female", "lactation")}


def text(cell: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", cell))).strip()


def cells(row: str) -> list[tuple[str, int]]:
    """A row's cells with their colspan."""
    return [(text(c), int((re.search(r'colspan="(\d+)"', attrs) or [0, "1"])[1]))
            for attrs, c in re.findall(r"<t[hd]([^>]*)>(.*?)</t[hd]>", row, re.DOTALL)]


def ages(label: str) -> tuple[float, float] | None:
    """'0–6 mo' → (0, 0.5); '19–30 y' → (19, 31); '> 70 y' → (71, 200); '≤ 18 y' (pregnancy) → (14, 19)."""
    s = label.replace("–", "-").replace(" ", "").lower()
    if m := re.fullmatch(r"(\d+)-(\d+)mo", s):
        return int(m[1]) / 12, (int(m[2]) + 1) / 12 if int(m[2]) < 12 else 1.0
    if m := re.fullmatch(r"(\d+)-(\d+)(y|years)", s):
        return float(m[1]), float(m[2]) + 1
    if m := re.fullmatch(r">(\d+)y", s):
        return float(m[1]) + 1, 200.0
    if m := re.fullmatch(r"≤(\d+)y", s):
        return 14.0, float(m[1]) + 1
    if m := re.fullmatch(r"(\d+)yearsandover", s):
        return float(m[1]), 200.0
    return None


def value(cell: str) -> tuple[float, bool] | None:
    """'1,300 Table 1 footnote *' → (1300, True: an AI); 'ND' → None."""
    m = re.match(r"([\d.,]+)", cell)
    return (float(m[1].replace(",", "")), "footnote *" in cell) if m else None


def nutrient_tables(page: str):
    for table in re.findall(r"<table.*?</table>", page, re.DOTALL):
        rows = re.findall(r"<tr.*?</tr>", table, re.DOTALL)
        if len(rows) < 3:
            continue
        head, kinds = cells(rows[0]), [c for c, _ in cells(rows[1])]
        if head[0][0] != "Age":
            continue
        columns = []  # one (nutrient key, unit, kind) per value column
        for name, span in head[1:]:
            key = next((v for k, v in NUTRIENTS.items() if name.lower().startswith(k)), None)
            columns += [key] * span
        sex, stage = "any", ""
        for row in rows[2:]:
            c = cells(row)
            if len(c) == 1:
                group = GROUPS.get(c[0][0].lower())
                if group:
                    sex, stage = group
                continue
            band = ages(c[0][0])
            if band is None:
                continue
            for (cell, _), target, kind in zip(c[1:], columns, kinds, strict=False):
                v = value(cell)
                if target is None or v is None or "IU" in kind or "kg" in kind or kind.startswith("EAR"):
                    continue
                key, unit = target
                amount = convert(v[0], unit, UNIT[key])
                name = "ul" if kind.startswith(("UL", "CDRR")) else "ai" if kind.startswith("AI") or v[1] else "rda"
                yield {"nutrient": key, "sex": sex, "age_from": band[0], "age_to": band[1], "life_stage": stage,
                       "kind": name, "amount": round(amount, 4), "source_id": "nasem_dri"}


def amdr_tables(page: str):
    for table in re.findall(r"<table.*?</table>", page, re.DOTALL):
        rows = re.findall(r"<tr.*?</tr>", table, re.DOTALL)
        head = [c for c, _ in cells(rows[0])] if rows else []
        if not head or not head[0].startswith("Males & Females"):
            continue
        keys = [next((v for k, v in AMDR.items() if h.lower().startswith(k)), None) for h in head[1:]]
        for row in rows[1:]:
            c = [x for x, _ in cells(row)]
            band = ages(c[0]) if c else None
            if band is None:
                continue
            for cell, key in zip(c[1:], keys, strict=False):
                m = re.match(r"([\d.]+)–([\d.]+)%", cell)
                if key and m:
                    for kind, amount in (("amdr_min", m[1]), ("amdr_max", m[2])):
                        yield {"nutrient": key, "sex": "any", "age_from": band[0], "age_to": band[1], "life_stage": "",
                               "kind": kind, "amount": float(amount), "source_id": "nasem_dri"}


def read(data) -> list[dict]:
    rows = []
    for f in FILES:
        page = (data / "raw_medical/dri" / f).read_text(encoding="utf-8")
        rows += [*nutrient_tables(page), *amdr_tables(page)]
    unique = {(r["nutrient"], r["sex"], r["age_from"], r["life_stage"], r["kind"]): r for r in rows}
    return list(unique.values())
