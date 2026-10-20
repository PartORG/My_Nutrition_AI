"""Norwegian Food Composition Table (Mattilsynet, NLOD 2.0): raw_no/foods.json from its API, English names, per
100 g edible part. Its nutrient ids are its own (nutrients.json gives no EuroFIR codes), so they're mapped here."""

import json

EUROFIR = {
    "Vann": "WATER",
    "Fett": "FAT",
    "Mettet": "FASAT",
    "Trans": "FATRN",
    "Enumet": "FAMS",
    "Flerum": "FAPU",
    "Omega-3": "FAPUN3",
    "Omega-6": "FAPUN6",
    "Kolest": "CHORL",
    "Karbo": "CHO",
    "Stivel": "STARCH",
    "Mono+Di": "SUGAR",
    "Sukker": "SUGAD",
    "Fiber": "FIBT",
    "Protein": "PROT",
    "Alko": "ALC",
    "Vit A": "VITA_RAE",
    "Retinol": "RETOL",
    "B-karo": "CARTB",
    "Vit D": "VITD",
    "Vit E": "TOCPHA",
    "Vit B1": "THIA",
    "Vit B2": "RIBF",
    "Niacin": "NIA",
    "Vit B6": "VITB6",
    "Folat": "FOL",
    "Vit B12": "VITB12",
    "Vit C": "VITC",
    "Ca": "CA",
    "Fe": "FE",
    "Na": "NA",
    "K": "K",
    "Mg": "MG",
    "Zn": "ZN",
    "Se": "SE",
    "Cu": "CU",
    "P": "P",
    "I": "ID",
    "C18:2n-6Linolsyre": "F18D2N6",
    "C18:3n-3AlfaLinolensyre": "F18D3N3",
    "C20:5n-3Eikosapentaensyre": "F20D5N3",
    "C22:5n-3Dokosapentaensyre": "F22D5N3",
    "C22:6n-3Dokosaheksaensyre": "F22D6N3",
}
# Units it writes that mean the panel's unit: RAE = µg RAE, mg-ATE (α-tocopherol equivalents) ≈ mg α-tocopherol.
UNITS = {"RAE": "µg", "mg-ATE": "mg"}


def read(data):
    for f in json.loads((data / "raw_no/foods.json").read_text())["foods"]:
        amounts = [
            ("eurofir", EUROFIR[c["nutrientId"]], c.get("quantity"), UNITS.get(c.get("unit"), c.get("unit") or ""))
            for c in f.get("constituents", [])
            if c["nutrientId"] in EUROFIR
        ]
        for e in (f.get("calories"), f.get("energy")):
            if e and e.get("quantity") is not None:
                amounts.append(("eurofir", "ENERC", e["quantity"], e["unit"]))
        portion = next(
            (p for p in f.get("portions", []) if p.get("unit") == "g" and p.get("portionUnit") not in {"dl", "g"}), None
        )
        yield {
            "code": f["foodId"],
            "name": f["foodName"].strip(),
            "group": f.get("foodGroupId"),
            "serving_g": portion["quantity"] if portion else None,
            "serving": portion["portionName"] if portion else None,
            "amounts": amounts,
        }
