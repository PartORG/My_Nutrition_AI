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


def test_detector_data_boxes_from_polygons_and_merged_labels():
    import detector_data as dd
    labels, of = dd.read_labels("label\tnutri_db\tboxes\tclasses\ncoffee\tCoffee, brewed\t3\tcoffee espresso\nbread\t-\t1\tbread\n")
    assert labels == ["coffee", "bread"] and of == {"coffee": "coffee", "espresso": "coffee", "bread": "bread"}
    assert dd.polygon_box([[10, 20, 50, 25, 30, 90]], 40, 100) == [10, 20, 30, 70], "clipped to the image width"
    assert dd.polygon_box([[5, 5, 6, 5, 5, 6]], 100, 100) is None, "a speck"
    coco = {"images": [{"id": 7, "file_name": "7.jpg", "width": 100, "height": 100, "extra": 1}],
            "categories": [{"id": 900, "name": "espresso"}, {"id": 901, "name": "bread"}],
            "annotations": [{"id": 1, "image_id": 7, "category_id": 900, "bbox": [0, 0, 1, 1],
                             "segmentation": [[10, 10, 30, 10, 30, 40]]}]}
    out = dd.convert(coco, labels, of)
    assert out["categories"] == [{"id": 1, "name": "coffee"}, {"id": 2, "name": "bread"}]
    assert out["annotations"] == [{"id": 1, "image_id": 7, "category_id": 1, "bbox": [10, 10, 20, 30], "area": 600,
                                   "iscrowd": 0}]
    assert out["images"] == [{"id": 7, "file_name": "7.jpg", "width": 100, "height": 100}]
