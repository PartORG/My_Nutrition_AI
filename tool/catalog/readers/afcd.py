"""Australian Food Composition Database Release 3 (FSANZ, CC BY 4.0): raw_afcd, per 100 g. Its nutrient-details
workbook gives each column's INFOODS tagname; amino acids there are mg per g of nitrogen, converted with the food's
nitrogen."""

import re

import openpyxl

from normalize import number

FOLDER = "raw_afcd"


def header(cell) -> tuple[str, str]:
    """'Protein \\n(g)' → ('protein', 'g')."""
    text = " ".join(str(cell or "").split())
    m = re.match(r"(.*?)\s*\(([^)]*)\)\s*$", text)
    return ((m[1] if m else text).strip().lower(), (m[2] if m else "").strip())


def tags(data) -> dict[str, str]:
    """Component name (lower case) → INFOODS tagname, from every sheet of the nutrient-details workbook."""
    wb = openpyxl.load_workbook(data / FOLDER / "AFCD Release 3 - Nutrient details.xlsx", read_only=True)
    out = {}
    for ws in wb.worksheets[1:]:
        cols = None
        for row in ws.iter_rows(values_only=True):
            if row and row[0] == "Component":
                cols = {str(c): i for i, c in enumerate(row) if c}
                continue
            if cols and row and row[0] and "INFOODs tagname" in cols and row[cols["INFOODs tagname"]]:
                out[" ".join(str(row[0]).split()).lower()] = str(row[cols["INFOODs tagname"]]).strip()
    return out


# Profile columns named longer than in the details workbook (lower case, without the unit).
ALIASES = {
    "energy with dietary fibre, equated": "ENERC",
    "moisture (water)": "WATER",
    "fat, total": "FAT",
    "total dietary fibre": "FIBT",
    "alcohol": "ALC",
    "added sugars": "SUGAD",
    "total saturated fatty acids, equated": "FASAT",
    "total monounsaturated fatty acids, equated": "FAMS",
    "total polyunsaturated fatty acids, equated": "FAPU",
    "total trans fatty acids, imputed": "FATRN",
}


def read(data):
    tag = tags(data) | ALIASES
    wb = openpyxl.load_workbook(data / FOLDER / "AFCD Release 3 - Nutrient profiles.xlsx", read_only=True)
    rows = wb["All solids & liquids per 100 g"].iter_rows(values_only=True)
    head = next(r for r in rows if r and r[0] == "Public Food Key")
    cols = [header(c) for c in head]
    for row in rows:
        if not row or not row[0]:
            continue
        values = {cols[i][0]: (number(v), cols[i][1]) for i, v in enumerate(row) if i >= 4}
        nitrogen = (values.get("nitrogen") or (None,))[0]
        amounts = []
        for name, (v, unit) in values.items():
            code = tag.get(name)
            if code is None or v is None:
                continue
            if unit == "mg/g N":  # amino acids per g nitrogen → mg per 100 g food
                if nitrogen is None:
                    continue
                v, unit = v * nitrogen, "mg"
            amounts.append(("eurofir", code, v, unit.replace("ug", "µg")))
        yield {
            "code": row[0],
            "name": str(row[3]).strip(),
            "group": str(row[1]),
            "derivation": row[2],
            "amounts": amounts,
        }
