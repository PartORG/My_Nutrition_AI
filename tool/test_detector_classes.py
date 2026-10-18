"""uv run --with pytest pytest tool/test_detector_classes.py"""

import detector_classes as d

NAMES = ["Potatoes, raw", "Potatoes, boiled, cooked in skin", "Tomatoes, red, ripe, raw", "Wine, red", "Tonic water"]
FOODS = [(n, set(d.toks(n)), set(d.toks(n.split(",")[0]))) for n in NAMES]
EXACT = d.exact_names(NAMES)


def m(name, imap=None):
    return d.match(name, imap or {}, FOODS, EXACT, {})


def test_curated_map_first_and_water_logs_nothing():
    assert m("tomato-raw", {"tomato": "Tomatoes, red, ripe, raw"}) == ("Tomatoes, red, ripe, raw", "map")
    assert m("water", {"water": "-"}) == ("-", "map")


def test_a_cooking_word_must_show_in_the_food():
    # The map and the loose name say raw potatoes; the class says steamed.
    assert m("potatoes-steamed", {"potatoes": "Potatoes, raw"}) == ("Potatoes, boiled, cooked in skin", "rule")
    assert m("potatoes") == ("Potatoes, raw", "loose")


def test_exact_and_none():
    assert m("wine-red") == ("Wine, red", "exact")
    assert m("unicorn-stew") == ("", "none")


def test_labels_file_check():
    text = "# comment\nlabel\tnutri_db\tboxes\tclasses\ncoffee\tCoffee, brewed\t9\tcoffee espresso\nwater\t-\t5\twater espresso\n"
    assert d.check_labels(text, {"coffee", "espresso", "water", "tea"}, {"Coffee, brewed"}) == [
        "espresso: in 'coffee' and 'water'", "tea: in no label"]
    assert d.check_labels("x\tGone\t1\tunicorn\n", set(), set()) == [
        "x: no nutri.db row 'Gone'", "unicorn: not a dataset class"]
