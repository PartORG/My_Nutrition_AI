"""McCance and Widdowson's CoFID 2021 (OHID, Open Government Licence v3.0): raw_eu/cofid/cofid2021.xlsx, per 100 g
(drinks per 100 ml). Each table sheet has its own codes in the row under the names: mapped to EuroFIR here.
'Tr' = trace, 'N' = unknown. Carbohydrate is available carbohydrate (fibre added in derive); fibre is AOAC, else NSP."""

from collections import defaultdict

import openpyxl

from normalize import number

EUROFIR = {
    "WATER": "WATER",
    "PROT": "PROT",
    "FAT": "FAT",
    "CHO": "CHO",
    "KCALS": ("ENERC", "kcal"),
    "KJ": ("ENERC", "kJ"),
    "STAR": "STARCH",
    "TOTSUG": "SUGAR",
    "GLUC": "GLUS",
    "FRUCT": "FRUS",
    "SUCR": "SUCS",
    "LACT": "LACS",
    "ALCO": "ALC",
    "AOACFIB": "FIBT",
    "ENGFIB": "FIBNSP",
    "SATFOD": "FASAT",
    "TOTn6PFOD": "FAPUN6",
    "TOTn3PFOD": "FAPUN3",
    "MONOFOD": "FAMS",
    "POLYFOD": "FAPU",
    "FACTRANS": "FATRN",
    "CHOL": "CHORL",
    "NA": "NA",
    "K": "K",
    "CA": "CA",
    "MG": "MG",
    "P": "P",
    "FE": "FE",
    "CU": "CU",
    "ZN": "ZN",
    "MN": "MN",
    "SE": "SE",
    "I": "ID",
    "RET": "RETOL",
    "BCAR": "CARTB",
    "ACAR": "CARTA",
    "CRYPT": "CRYPXB",
    "VITD": "VITD",
    "ATOPH": "TOCPHA",
    "VITK1": "VITK1",
    "THIA": "THIA",
    "RIBO": "RIBF",
    "NIAC": "NIA",
    "VITB6": "VITB6",
    "VITB12": "VITB12",
    "FOLT": "FOL",
    "PANTO": "PANTAC",
    "BIOT": "BIOT",
    "VITC": "VITC",
}
UNITS = {
    "PROT": "g",
    "SE": "µg",
    "I": "µg",
    "RET": "µg",
    "BCAR": "µg",
    "ACAR": "µg",
    "CRYPT": "µg",
    "VITD": "µg",
    "VITK1": "µg",
    "VITB12": "µg",
    "FOLT": "µg",
    "BIOT": "µg",
    "NA": "mg",
    "K": "mg",
    "CA": "mg",
    "MG": "mg",
    "P": "mg",
    "FE": "mg",
    "CU": "mg",
    "ZN": "mg",
    "MN": "mg",
    "CHOL": "mg",
    "ATOPH": "mg",
    "THIA": "mg",
    "RIBO": "mg",
    "NIAC": "mg",
    "VITB6": "mg",
    "PANTO": "mg",
    "VITC": "mg",
}
# Pizza, sandwiches, pasta dishes, meat and vegetable dishes, curries, egg and fish dishes.
DISHES = {"A", "AB", "AD", "MR", "MIG", "DR", "CDE", "J"}
SHEETS = ["1.3 Proximates", "1.4 Inorganics", "1.5 Vitamins", "1.6 Vitamin Fractions"]


def read(data):
    wb = openpyxl.load_workbook(data / "raw_eu/cofid/cofid2021.xlsx", read_only=True)
    amounts, names = defaultdict(list), {}
    for sheet in SHEETS:
        rows = wb[sheet].iter_rows(values_only=True)
        next(rows)
        codes = next(rows)
        for row in rows:
            if not row or not row[0] or not row[1] or row[0] == codes[0]:
                continue
            names[row[0]] = (str(row[1]).strip(), row[3])
            for i, code in enumerate(codes):
                target = EUROFIR.get(code) if code else None
                if target is None:
                    continue
                euro, unit = target if isinstance(target, tuple) else (target, UNITS.get(code, "g"))
                v = None if str(row[i]).strip() == "N" else number(row[i])
                amounts[row[0]].append(("eurofir", euro, v, unit))
    for code, (name, group) in names.items():
        a = amounts[code]
        if not any(c == "FIBT" and v is not None for _, c, v, _u in a):  # no AOAC fibre: the NSP value
            a = [(s, "FIBT" if c == "FIBNSP" else c, v, u) for s, c, v, u in a]
        amounts[code] = a
        yield {
            "code": str(code),
            "name": name,
            "group": group,
            "category": "dish" if group in DISHES else "food",
            "amounts": amounts[code],
        }
