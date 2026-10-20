"""sources.tsv is complete and only licence-confirmed sources are fetched.

uv run --with pytest pytest tool/catalog/test_fetch.py
"""

import fetch


def test_every_source_has_a_licence_a_known_status_and_a_unique_id():
    rows = fetch.sources()
    assert len({r["id"] for r in rows}) == len(rows)
    for r in rows:
        assert r["status"] in {"ok", "manual", "check", "no"}, r
        assert r["licence"] and r["url"].startswith("https://"), r


def test_only_ok_sources_are_fetched():
    rows = fetch.sources()
    assert {r["status"] for r in fetch.todo(rows, [])} == {"ok"}
    assert "nevo" not in {r["id"] for r in fetch.todo(rows, ["nevo"])}, "excluded: its licence forbids a paid app"
    assert [r["id"] for r in fetch.todo(rows, ["cnf"])] == ["cnf"]


def test_file_names_are_decoded_and_figshare_ids_get_their_type():
    def name(url, data=b""):
        return fetch.file_name({"id": "frida", "url": url}, data)

    assert name("https://x/AFCD%20Release%203%20-%20Recipes.xlsx") == "AFCD Release 3 - Recipes.xlsx"
    assert name("https://ndownloader.figshare.com/files/60901597", b"%PDF-1.7") == "frida.pdf"
    assert name("https://ndownloader.figshare.com/files/60901603", b"PK\x03\x04") == "frida.xlsx"


def test_record_keeps_one_line_per_file(tmp_path):
    f = tmp_path / "a.zip"
    f.write_bytes(b"x")
    fetch.record(tmp_path, f, "https://e/a.zip", "CC BY 4.0")
    f.write_bytes(b"xy")
    fetch.record(tmp_path, f, "https://e/a.zip", "CC BY 4.0")
    lines = (tmp_path / "FETCHED.tsv").read_text().splitlines()
    assert len(lines) == 2 and lines[1].split("\t")[1] == "2"
