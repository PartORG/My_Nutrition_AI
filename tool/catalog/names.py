"""Everyday names for foods (docs/PLAN.md "Catalogue v4", decision 13): "Bananas, raw" → "banana",
"Chicken, breast, roasted" → "chicken breast", "Bread, white" → "white bread".
Pure functions, tested in test_names.py."""

import re

# A segment made only of these words says how the food is, not what it is.
STATE_WORDS = {
    "raw",
    "cooked",
    "boiled",
    "baked",
    "roasted",
    "fried",
    "grilled",
    "steamed",
    "stewed",
    "braised",
    "broiled",
    "sun-dried",
    "poached",
    "sauteed",
    "microwaved",
    "toasted",
    "canned",
    "frozen",
    "dried",
    "dehydrated",
    "fresh",
    "chilled",
    "prepared",
    "unprepared",
    "drained",
    "undrained",
    "reheated",
    "heated",
    "ready-to-eat",
    "flesh",
    "pulp",
    "only",
    "with",
    "without",
    "skin",
    "peel",
    "peeled",
    "unpeeled",
    "seeds",
    "all",
    "varieties",
    "variety",
    "average",
    "composite",
    "prepacked",
    "homemade",
    "retail",
    "commercial",
    "meat",
    "lean",
    "and",
    "fat",
    "salt",
    "salted",
    "unsalted",
    "plain",
    "regular",
    "nfs",
    "ns",
    "as",
    "to",
    "form",
    "in",
    "water",
    "no",
    "added",
    "oil",
    "whole",
    "edible",
    "portion",
    "fluid",
    "solids",
    "liquids",
    "enriched",
    "unenriched",
    "fortified",
    "unfortified",
    "mature",
    "immature",
}
STATES = [
    "raw",
    "cooked",
    "boiled",
    "baked",
    "roasted",
    "fried",
    "grilled",
    "steamed",
    "stewed",
    "braised",
    "broiled",
    "poached",
    "toasted",
    "canned",
    "frozen",
    "dried",
    "dehydrated",
]
# Category words whose second segment names the food ("Bread, white"); for meats the cut follows ("chicken breast").
BROAD = {
    "chicken",
    "beef",
    "pork",
    "lamb",
    "turkey",
    "veal",
    "mutton",
    "goat",
    "duck",
    "goose",
    "venison",
    "fish",
    "bread",
    "cheese",
    "milk",
    "rice",
    "oil",
    "beans",
    "bean",
    "flour",
    "pasta",
    "yogurt",
    "yoghurt",
    "cream",
    "sausage",
    "sausages",
    "soup",
    "juice",
    "tea",
    "coffee",
    "wine",
    "beer",
    "nuts",
    "nut",
    "cereal",
    "cereals",
    "sauce",
    "cake",
    "cakes",
    "cookie",
    "cookies",
    "crackers",
    "cracker",
    "potatoes",
    "potato",
    "egg",
    "eggs",
    "sugar",
    "sugars",
    "ham",
    "bacon",
    "butter",
    "margarine",
    "chocolate",
    "peppers",
    "pepper",
    "cabbage",
    "lettuce",
    "squash",
    "onions",
    "onion",
    "apples",
    "apple",
    "tuna",
    "salmon",
    "cod",
    "shrimp",
    "mushrooms",
    "mushroom",
    "corn",
    "wheat",
    "oats",
    "peas",
    "lentils",
    "seeds",
    "noodles",
    "spaghetti",
    "salad",
    "dressing",
    "jam",
    "honey",
    "syrup",
    "spices",
    "spice",
}
CUTS = {
    "breast",
    "breasts",
    "thigh",
    "thighs",
    "wing",
    "wings",
    "drumstick",
    "leg",
    "liver",
    "heart",
    "kidney",
    "loin",
    "tenderloin",
    "ribs",
    "rib",
    "chop",
    "chops",
    "steak",
    "fillet",
    "fillets",
    "mince",
    "minced",
    "ground",
}
MEATS = {"chicken", "beef", "pork", "lamb", "turkey", "veal", "mutton", "goat", "duck", "goose", "venison"}
# First segments that are only a filing category: the next segment alone is the food ("Spices, cinnamon" → "cinnamon").
CATEGORIES = {"spices", "spice", "leavening agents", "beverages", "soup", "soups", "candies", "snacks", "seasoning",
              "sweeteners", "babyfood", "fast foods", "restaurant", "alcoholic beverage", "alcoholic beverages"}
IRREGULAR = {"leaves": "leaf", "halves": "half", "loaves": "loaf", "knives": "knife", "children": "child"}
KEEP_S = ("ss", "us", "is", "ous", "ics")
SEGMENTS = re.compile(r",\s*(?![^()]*\))")  # commas inside (...) belong to the part


def singular(word: str) -> str:
    w = word
    if w in IRREGULAR:
        return IRREGULAR[w]
    if len(w) <= 3 or w.endswith(KEEP_S):
        return w
    if w.endswith("ies"):
        return w[:-3] + "y"
    if w.endswith(("oes", "ches", "shes", "sses", "xes")):
        return w[:-2]
    return w.removesuffix("s")


def segments(name: str) -> list[str]:
    return [re.sub(r"\s*\([^)]*\)", "", s).strip().lower() for s in SEGMENTS.split(name) if s.strip()]


def is_state(segment: str) -> bool:
    return all(w in STATE_WORDS for w in re.findall(r"[a-z\-]+", segment))


def common_name(name: str) -> str:
    """The everyday name: the first segment (singular), with the next one when the first is only a category."""
    parts = [p for p in segments(name) if p.split()]
    if not parts:
        return re.sub(r"[()]", "", name).strip().lower()
    first = parts[0]
    rest = [p for p in parts[1:] if not is_state(p)]
    if first in CATEGORIES and rest:
        first, rest = rest[0], rest[1:]
    if first in {"nuts", "nut", "seeds"} and rest:  # "Nuts, pecans" → "pecan"
        words = rest[0].split()
        return " ".join([*words[:-1], singular(words[-1])])
    if first.endswith(" products") and rest:  # "Tomato products, canned, paste" → "tomato paste"
        return f"{first.removesuffix(' products')} {rest[0]}"
    head = first.split()
    if len(head) == 1 and head[0] in MEATS:
        # The cut can come after a kind ("Chicken, broilers or fryers, breast, meat only").
        cut = next((p for p in rest if p.split()[-1] in CUTS), None)
        if cut == "ground":
            return f"ground {head[0]}"
        if cut:
            return f"{head[0]} {singular(cut.split()[-1])}"
    if len(head) == 1 and head[0] in BROAD and rest:
        return f"{rest[0]} {singular(head[0])}"
    words = first.split()
    return " ".join([*words[:-1], singular(words[-1])])


def state(name: str) -> str | None:
    words = set(re.findall(r"[a-z]+", name.lower()))
    return next((s for s in STATES if s in words), None)


# Foods eaten cooked: their default is a cooked form; everything else defaults to raw where there is one.
COOKED = re.compile(
    r"\b(rice|pasta|spaghetti|noodle|macaroni|quinoa|couscous|bulgur|barley|lentil|bean|chickpea|"
    r"egg|chicken|beef|pork|lamb|turkey|veal|duck|sausage|bacon|potato|oat|porridge)\b"
)


def default_score(food: dict, source_rank: dict[str, int]) -> tuple:
    """Lower is a better default for its common name: a government table, fewest extra words, the expected state,
    the most authoritative table, the shortest name."""
    parts = segments(food["name"])
    extra = sum(1 for p in parts[1:] if not is_state(p))
    st = food.get("state") or state(food["name"])
    cooked = bool(COOKED.search(food["common_name"]))
    want = st in {"boiled", "cooked", "roasted", "baked", "grilled", "steamed"} if cooked else st in {None, "raw"}
    return (
        not food.get("authoritative", True),
        extra,
        not want,
        source_rank.get(food["source"], 99),
        len(food["name"]),
    )
