"""Checks for tool/food_names.py.

    uv run --with pytest pytest tool/test_food_names.py
"""

import sqlite3
from pathlib import Path

import food_names

ROOT = Path(__file__).resolve().parent.parent


def test_apply_writes_matching_rows_and_skips_stale(tmp_path):
    db = sqlite3.connect(":memory:")
    db.executescript((ROOT / "db/nutri_schema.sql").read_text())
    db.executemany("INSERT INTO foods (id, name, kcal, protein_g, fat_g, carbs_g) VALUES (?, ?, 0, 0, 0, 0)",
                   [(1, "Garlic, raw"), (2, "Onions, raw")])
    tsv = tmp_path / "names.tsv"
    food_names.save({
        1: {"food_id": "1", "en": "Garlic, raw", "uk": "Часник, сирий", "de": "Knoblauch, roh", "fr": ""},
        2: {"food_id": "2", "en": "Onions, cooked", "uk": "Цибуля, варена", "de": "", "fr": ""},  # renamed since
    }, tsv)
    assert food_names.apply(db, tsv) == {"food_names rows": 2, "food_names stale (skipped)": 1}
    assert db.execute("SELECT food_id, lang, name FROM food_names ORDER BY lang").fetchall() == [
        (1, "de", "Knoblauch, roh"), (1, "uk", "Часник, сирий")]
    food_names.apply(db, tsv)  # again: replaces, no duplicates
    assert db.execute("SELECT count(*) FROM food_names").fetchone() == (2,)


def test_clean_keeps_only_the_translation():
    assert food_names.clean('\n"Часник, сирий"\n\nNote: raw garlic') == "Часник, сирий"
    assert food_names.clean("Knoblauch\troh") == "Knoblauch roh"
    assert food_names.clean("Бро\u0301т, з вітаміном D.") == "Брот, з вітаміном D"
