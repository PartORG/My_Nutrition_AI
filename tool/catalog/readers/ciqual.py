"""ANSES-CIQUAL 2025 (Licence Ouverte / etalab 2.0): raw_eu/ciqual XML, per 100 g, English names; each constituent
carries its INFOODS code and unit (in its name). Group 01 is starters and dishes."""

import re
import xml.etree.ElementTree as ET
from collections import defaultdict

from normalize import number

UNIT = re.compile(r"\(([^)/]+)/100\s?g\)")


def items(path, tag):
    for _, el in ET.iterparse(path):
        if el.tag == tag:
            yield {c.tag: (c.text or "").strip() for c in el}
            el.clear()


def read(data):
    folder = data / "raw_eu/ciqual"
    const = {}
    for c in items(folder / "const.xml", "CONST"):
        unit = UNIT.search(c.get("const_nom_eng", ""))
        if c.get("code_INFOODS") and unit:
            const[c["const_code"]] = (c["code_INFOODS"], unit[1].strip())
    amounts = defaultdict(list)
    for c in items(folder / "compo.xml", "COMPO"):
        if c["const_code"] in const:
            code, unit = const[c["const_code"]]
            amounts[c["alim_code"]].append(("eurofir", code, number(c.get("teneur")), unit))
    for a in items(folder / "alim.xml", "ALIM"):
        yield {
            "code": a["alim_code"],
            "name": a.get("alim_nom_eng") or a["alim_nom_fr"],
            "name_fr": a["alim_nom_fr"],
            "group": a.get("alim_ssssgrp_code"),
            "category": "dish" if a.get("alim_grp_code") == "01" else "food",
            "amounts": amounts[a["alim_code"]],
        }
