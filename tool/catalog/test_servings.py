from readers.off_drinks import drinks, medians
from servings import is_drink, serve, type_serving


def food(name, water=90.0, alcohol=0.0, serving=None, source="ciqual", code="1", common=None):
    return {"name": name, "source": source, "code": code, "common_name": common or name.lower(),
            "serving_g": serving, "serving": None, "nutrients": {"water_g": water, "alcohol_g": alcohol}}


def test_drinks_and_not():
    assert is_drink(food("Beer, lager"))
    assert is_drink(food("Vodka", water=66, alcohol=33))
    assert is_drink(food("Apple juice"))
    assert not is_drink(food("Lemon juice")), "by the spoon"
    assert not is_drink(food("Milk, dry", water=3))
    assert not is_drink(food("Coconut milk, canned", water=68))
    assert not is_drink(food("Shrimp cocktail"))
    assert not is_drink(food("Water chestnuts, boiled"))


def test_kinds():
    assert type_serving("Wine, red")[0] == 148
    assert type_serving("Gin")[0] == 44
    assert type_serving("Ginger ale")[0] == 330, "not gin"
    assert type_serving("Espresso, single")[0] == 30
    assert type_serving("Rum and diet cola")[0] == 250, "a mixed drink, not a shot"
    assert type_serving("Orange juice, raw")[0] == 240


def test_serve_order_usda_then_same_name_then_kind():
    foods = [
        food("Cola, regular", source="usda_sr", code="7", common="cola"),
        food("Cola", common="cola"),
        food("Beer, white", common="white beer"),
        food("Tea, brewed", serving=240.0),
        food("Kefir", serving=971.0, common="kefir"),
    ]
    counts = serve(foods, {("usda_sr", "7"): (370.0, "1 can (12 fl oz)")})
    assert [f["serving_g"] for f in foods] == [370.0, 370.0, 355, 240.0, 240]
    assert counts == {"drinks": 5, "too big": 1, "had one": 1, "usda": 1, "same name": 1, "kind": 2}


def test_off_medians_need_five_labels():
    d = drinks(["# header", "Kvass\ten:kvass\t250\t1 glass (250 ml)", "Uzvar\ten:uzvar\t250\t1 glass"])
    labels = [({"en:kvass"}, {"kcal": k, "sugar_g": None if k > 30 else 5.0}) for k in (20, 25, 27, 30, 40)]
    rows = medians(d, labels)
    assert [r["name"] for r in rows] == ["Kvass"]
    assert rows[0]["nutrients"] == {"kcal": 27, "sugar_g": 5.0}
    assert rows[0]["serving_g"] == 250
