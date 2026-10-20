"""Swedish Food Agency food composition database (CC BY 4.0): raw_se/livsmedel.json from its API, English names,
per 100 g, a EuroFIR code on every value."""

import json


def read(data):
    for f in json.loads((data / "raw_se/livsmedel.json").read_text()):
        yield {
            "code": str(f["nummer"]),
            "name": f["namn"].strip(),
            "amounts": [("eurofir", v["euroFIRkod"], v["varde"], v["enhet"]) for v in f["naringsvarden"]],
        }
