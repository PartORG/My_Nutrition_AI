"""Recipe ingredient lines -> (quantity, unit, name), and name normalising.

Used by build_real_nutri_db.py. Stdlib only so it can be tested on its own:
    uv run --with pytest pytest tool/test_ingredients.py
"""

import re
import unicodedata

FRACTIONS = {"½": ".5", "¼": ".25", "¾": ".75", "⅓": ".333", "⅔": ".667", "⅛": ".125",
             "⅜": ".375", "⅝": ".625", "⅞": ".875", "⅕": ".2", "⅙": ".167"}

# unit -> (kind, factor). mass: grams per unit; volume: ml per unit; count: 1.
UNITS = {
    **dict.fromkeys(["g", "gr", "gram", "grams", "gm", "gms"], ("mass", 1.0)),
    **dict.fromkeys(["kg", "kgs", "kilo", "kilos", "kilogram", "kilograms"], ("mass", 1000.0)),
    **dict.fromkeys(["mg"], ("mass", 0.001)),
    **dict.fromkeys(["oz", "ounce", "ounces"], ("mass", 28.35)),
    **dict.fromkeys(["lb", "lbs", "pound", "pounds"], ("mass", 453.6)),
    **dict.fromkeys(["ml", "millilitre", "milliliter", "millilitres", "milliliters", "mls"], ("volume", 1.0)),
    **dict.fromkeys(["cl"], ("volume", 10.0)),
    **dict.fromkeys(["dl"], ("volume", 100.0)),
    **dict.fromkeys(["l", "litre", "liter", "litres", "liters", "ltr"], ("volume", 1000.0)),
    **dict.fromkeys(["cup", "cups", "c"], ("volume", 236.6)),
    **dict.fromkeys(["tbsp", "tbsps", "tablespoon", "tablespoons", "tbs", "tbl", "tbls", "tb", "T"], ("volume", 14.79)),
    **dict.fromkeys(["tsp", "tsps", "teaspoon", "teaspoons", "t"], ("volume", 4.93)),
    **dict.fromkeys(["floz", "fl oz", "fluid ounce", "fluid ounces", "fl. oz", "fl.oz"], ("volume", 29.57)),
    **dict.fromkeys(["pint", "pints", "pt"], ("volume", 473.2)),
    **dict.fromkeys(["quart", "quarts", "qt"], ("volume", 946.4)),
    **dict.fromkeys(["gallon", "gallons", "gal"], ("volume", 3785.0)),
    **dict.fromkeys(["dash", "dashes"], ("volume", 0.6)),
    **dict.fromkeys(["pinch", "pinches"], ("volume", 0.3)),
    **dict.fromkeys(["drop", "drops"], ("volume", 0.05)),
    **dict.fromkeys(["dozen"], ("count", 12.0)),
    # Counted things; the food decides how much one weighs.
    **dict.fromkeys(["clove", "cloves", "slice", "slices", "stick", "sticks", "can", "cans", "tin", "tins",
                     "package", "packages", "pkg", "pkgs", "packet", "packets", "pack", "packs", "jar", "jars",
                     "bottle", "bottles", "box", "boxes", "bag", "bags", "carton", "cartons", "envelope",
                     "envelopes", "sachet", "sachets", "bunch", "bunches", "head", "heads", "sprig", "sprigs",
                     "stalk", "stalks", "rib", "ribs", "piece", "pieces", "fillet", "fillets", "leaf", "leaves",
                     "ear", "ears", "loaf", "loaves", "cube", "cubes", "strip", "strips", "ball", "balls",
                     "handful", "handfuls", "knob", "knobs", "large", "medium", "small", "whole", "x"],
                    ("count", 1.0)),
}
# Longest first so 'fl oz' wins over 'fl', 'tbsp' over 't'.
_UNIT_RE = "|".join(sorted((re.escape(u) for u in UNITS), key=len, reverse=True))

_NUM = r"\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*/\s*\d+)?"
_QTY = rf"(?P<qty>{_NUM}(?:\s*(?:-|–|to|or)\s*{_NUM})?)"
# '2 (21 ounce) cans', '1 (14 oz) can', '2 x 400g tins'
_SIZED = re.compile(rf"^\s*{_QTY}\s*(?:\(\s*|x\s*)(?P<sqty>{_NUM})\s*-?\s*(?P<sunit>{_UNIT_RE})\.?\s*\)?\s*"
                    rf"(?:(?:{_UNIT_RE})\b\.?)?\s*(?P<rest>.*)$", re.I)
_PLAIN = re.compile(rf"^\s*{_QTY}?\s*(?P<unit>(?:{_UNIT_RE}))?(?(unit)\b\.?|)\s*(?P<rest>.*)$", re.I)

# Words that describe preparation, not the food.
PREP = set("""
chopped minced diced sliced grated shredded crushed fresh freshly finely coarsely roughly thinly thickly
peeled seeded cored halved quartered cubed julienned trimmed rinsed drained softened melted beaten
packed firmly lightly loosely heaping heaped level sifted divided optional cold warm room temperature very
snipped unsifted
large medium small extra big jumbo boneless skinless about approx approximately plus more for to taste
taste serving garnish good quality of the a an and or into cut pieces piece inch inches cm thick thin
stemmed pitted lukewarm thawed prepared homemade storebought store bought good-quality free-range organic
good generous approximately
""".split())
# Lines that are fine to leave out of nutrition when they can't be matched.
NEGLIGIBLE = re.compile(r"^(water|ice|ice cubes|cold water|hot water|boiling water|warm water|salt and pepper|"
                        r"salt & pepper|salt pepper|pepper|black pepper|ground pepper|cooking spray|"
                        r"nonstick cooking spray|non-stick cooking spray|kosher salt and pepper)$")


def _num(s: str) -> float:
    s = s.strip().replace(",", ".")
    total = 0.0
    for part in s.split():
        if "/" in part:
            a, b = part.split("/", 1)
            total += float(a) / float(b) if float(b) else 0
        else:
            total += float(part)
    return total


def qty_value(q: str) -> float:
    """'1 1/2' -> 1.5, '2-3' -> 2.5 (ranges take the middle), '1/2' -> .5."""
    q = re.sub(r"\s*/\s*", "/", q)
    parts = re.split(r"\s*(?:-|–|\bto\b|\bor\b)\s*", q)
    vals = [_num(p) for p in parts if p.strip()]
    return sum(vals) / len(vals) if vals else 0.0


def clean_line(line: str) -> str:
    line = unicodedata.normalize("NFKC", "".join(" " + FRACTIONS[c] if c in FRACTIONS else c for c in line))
    line = re.sub(r"(\d)\s+\.(\d)", lambda m: str(int(m[1]) + float("." + m[2])), line)  # '1 .5' from '1½'
    line = re.sub(r"(?<!\d)\.(\d)", r"0.\1", line)
    line = re.sub(r"(\d)-(\d+/\d+)", r"\1 \2", line)  # '1-1/2 cups' -> '1 1/2 cups'
    line = re.sub(r"^[\s*•\-–·]+", "", line)          # bullets
    return re.sub(r"\s+", " ", line).strip()


def parse_line(line: str) -> tuple[float | None, str | None, str]:
    """-> (quantity, unit, rest). quantity None = no amount given ('salt to taste').
    Sized packages fold into grams/ml: '2 (21 ounce) cans x' -> (42, 'ounce', 'x')."""
    line = re.sub(r"^(?:a|an|one)\s+(?:good\s+|large\s+|small\s+|generous\s+)?(?=[a-z])", "1 ", clean_line(line), flags=re.I)
    if m := _SIZED.match(line):
        qty, unit, rest = qty_value(m["qty"]) * qty_value(m["sqty"]), m["sunit"].lower(), m["rest"].strip()
    else:
        m = _PLAIN.match(line)
        qty = qty_value(m["qty"]) if m["qty"] else None
        unit = m["unit"]
        rest = m["rest"].strip()
        if unit is not None and unit not in ("T", "t"):
            unit = unit.lower()
    # '500g flour/1lb 2oz' and '20ml/¾fl oz oil': drop the imperial echo after a slash.
    rest = re.sub(rf"^/\s*{_NUM}\s*(?:{_UNIT_RE})\b\.?(?:\s*{_NUM}\s*(?:{_UNIT_RE})\b\.?)?\s*", "", rest, flags=re.I)
    if qty is not None and unit is None:  # '1 heaping teaspoon', '2 scant cups'
        rest = re.sub(r"^(?:heaping|heaped|scant|rounded|level|generous|good|full|big|small|large)\s+(?=\w+)", "", rest,
                      flags=re.I) if re.match(rf"^(?:heaping|heaped|scant|rounded|level|generous|good|full|big)\s+(?:{_UNIT_RE})\b",
                                              rest, re.I) else rest
    if qty is not None and unit is None and (m2 := re.match(rf"^(?P<unit>{_UNIT_RE})\b\.?\s+(?P<r>.*)$", rest, re.I)):
        unit, rest = m2["unit"].lower(), m2["r"]
    # '7g sachet yeast', '400g can tomatoes': the weight is already known, the container word is noise.
    if unit is not None and unit_kind(unit)[0] != "count" and (m2 := re.match(r"^(\w+)\s+(.*)$", rest)) \
            and UNITS.get(m2[1].lower(), ("",))[0] == "count" and m2[1].lower() not in ("large", "medium", "small", "whole"):
        rest = m2[2]
    if unit is not None and qty is None:  # 'pinch of salt', 'handful of rocket'
        qty = 1.0
    return qty, unit, rest


def normalize_name(rest: str) -> str:
    """'onion, chopped ' -> 'onion'; 'firmly packed light brown sugar' -> 'light brown sugar'."""
    s = rest.lower()
    s = re.sub(r"\([^)]*\)?", " ", s)             # (optional), (about 3/4 pound)
    s = re.split(r",|;| - | – |\bfor\b|\bto taste\b|\bplus\b|\bif\b", s)[0]
    s = re.sub(r"\bor\b.*$", "", s)                 # 'earl grey tea or ceylon tea' -> first
    s = re.sub(r"[^a-zà-ÿ' &-]", " ", s)
    words = [w.strip("'-") for w in s.split()]
    words = [w for w in words if w and w not in PREP and not re.fullmatch(r"\d+", w)]
    return " ".join(words)


def unit_kind(unit: str | None) -> tuple[str, float]:
    if unit is None:
        return "count", 1.0
    return UNITS.get(unit, UNITS.get(unit.lower(), ("count", 1.0)))
