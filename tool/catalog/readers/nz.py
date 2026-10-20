"""NZ FOODfiles 2018 (Plant & Food Research / Ministry of Health): raw_nutritions/Nutritional Datasets for New Zealand
Foods.xlsx, sheet FOODFiles-Nutrients, per 100 g. Mapped by column; its amino-acid columns hold 0 where nothing was
reported (bread: 0 g leucine), so they're left out and filled from other tables."""

import openpyxl

from normalize import number

FILE = "raw_nutritions/Nutritional Datasets for New Zealand Foods.xlsx"
COLUMNS = {  # column → (EuroFIR code, unit)
    3: ("ENERC", "kJ"),
    4: ("ENERC", "kcal"),
    5: ("SUGAR", "g"),
    6: ("FASAT", "g"),
    7: ("FAT", "g"),
    8: ("CHORL", "mg"),
    9: ("PROT", "g"),
    10: ("FIBT", "g"),
    11: ("VITC", "mg"),
    12: ("VITE", "mg"),
    13: ("CA", "mg"),
    14: ("FE", "mg"),
    15: ("MG", "mg"),
    16: ("K", "mg"),
    17: ("THIA", "mg"),
    18: ("RIBF", "mg"),
    19: ("FOLDFE", "µg"),
    20: ("ZN", "mg"),
    21: ("VITB12", "µg"),
    22: ("P", "mg"),
    23: ("CU", "mg"),
    24: ("MN", "µg"),
    25: ("SE", "µg"),
    27: ("PANTAC", "mg"),
    28: ("VITB6", "mg"),
    30: ("VITK", "µg"),
    31: ("FAPU", "g"),
    32: ("ID", "µg"),
    33: ("NA", "mg"),
    34: ("VITD", "µg"),
    46: ("ALC", "g"),
    48: ("TOCPHA", "mg"),
    54: ("CARTB", "µg"),
    75: ("FAMS", "g"),
    76: ("FAPUN3", "g"),
    77: ("FAPUN6", "g"),
    78: ("FATRN", "g"),
    84: ("FRUS", "g"),
    86: ("GLUS", "g"),
    87: ("LACS", "g"),
    90: ("NIA", "mg"),
    92: ("RETOL", "µg"),
    93: ("STARCH", "g"),
    94: ("SUCS", "g"),
    95: ("SUGAD", "g"),
    97: ("CHOCDF", "g"),
    100: ("VITA_RAE", "µg"),
    102: ("WATER", "g"),
}


def read(data):
    wb = openpyxl.load_workbook(data / FILE, read_only=True, data_only=True)
    for row in wb["FOODFiles-Nutrients"].iter_rows(min_row=6, values_only=True):
        if not row or not row[0] or not row[2]:
            continue
        yield {
            "code": str(row[0]),
            "name": str(row[2]).strip(),
            "group": row[1],
            "amounts": [("eurofir", code, number(row[i]), unit) for i, (code, unit) in COLUMNS.items() if i < len(row)],
        }
