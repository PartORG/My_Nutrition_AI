"""Fetch stage: downloads every `ok` dataset of sources.tsv into nutrition-ai-assistant/data/<folder>/.

    python3 tool/catalog/fetch.py [id ...]     # all ok sources, or only these

A URL already in a folder's FETCHED.tsv is kept (delete its line to fetch it again).
Each folder gets FETCHED.tsv: file, bytes, sha256, url,
date, licence. API sources (Swedish Food Agency, MedQuAD's git repo) have their own fetchers below.
"""

import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE.parents[2] / "nutrition-ai-assistant/data"
AGENT = "MyFoodMind-catalog/1 (+https://github.com/PartORG/My_Nutrition_AI)"


def sources() -> list[dict]:
    lines = [l for l in (HERE / "sources.tsv").read_text().splitlines() if l.strip() and not l.startswith("#")]
    head, *body = (l.split("\t") for l in lines)
    return [dict(zip(head, row, strict=True)) for row in body]


def todo(rows: list[dict], only: list[str]) -> list[dict]:
    """The sources to fetch: status ok, and in [only] when given."""
    return [r for r in rows if r["status"] == "ok" and (not only or r["id"] in only)]


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def record(folder: Path, file: Path, url: str, licence: str) -> None:
    data = file.read_bytes()
    line = "\t".join(
        [file.name, str(len(data)), hashlib.sha256(data).hexdigest(), url, date.today().isoformat(), licence]
    )
    log = folder / "FETCHED.tsv"
    old = [l for l in log.read_text().splitlines()[1:] if not l.startswith(file.name + "\t")] if log.exists() else []
    log.write_text("\n".join(["file\tbytes\tsha256\turl\tdate\tlicence", *old, line]) + "\n")


def file_name(src: dict, data: bytes) -> str:
    """The URL's file name, decoded; a figshare URL ends in a number, so the id and the type its bytes show."""
    name = urllib.parse.unquote(src["url"].rstrip("/").split("/")[-1])
    if not name.isdigit():
        return name
    return src["id"] + (".pdf" if data.startswith(b"%PDF") else ".xlsx" if data.startswith(b"PK") else ".bin")


def fetch_file(src: dict, folder: Path) -> None:
    if (
        any(l.split("\t")[3] == src["url"] for l in (folder / "FETCHED.tsv").read_text().splitlines()[1:])
        if (folder / "FETCHED.tsv").exists()
        else False
    ):
        return
    data = get(src["url"])
    file = folder / file_name(src, data)
    file.write_bytes(data)
    record(folder, file, src["url"], src["licence"])


def fetch_livsmedelsverket(src: dict, folder: Path) -> None:
    """The food list, then each food's nutrient values (2,600 calls, paced), English names (sprak=2)."""
    file = folder / "livsmedel.json"
    if file.exists():
        return
    base = src["url"]
    foods = json.loads(get(f"{base}?offset=0&limit=5000&sprak=2"))["livsmedel"]
    for i, f in enumerate(foods):
        f["naringsvarden"] = json.loads(get(f"{base}/{f['nummer']}/naringsvarden?sprak=2"))
        if i % 200 == 0:
            print(f"  livsmedelsverket {i}/{len(foods)}", flush=True)
        time.sleep(0.1)
    file.write_text(json.dumps(foods, ensure_ascii=False))
    record(folder, file, base, src["licence"])


def fetch_git(src: dict, folder: Path) -> None:
    repo = folder / src["url"].rstrip("/").split("/")[-1]
    if not repo.exists():
        subprocess.run(["git", "clone", "--depth", "1", src["url"], str(repo)], check=True)


def fetch_kaggle(src: dict, folder: Path) -> None:
    """A Kaggle dataset, unzipped; the token is ~/.kaggle/access_token (the CLI reads it from KAGGLE_API_TOKEN)."""
    if any(folder.iterdir()):
        return
    token = (Path.home() / ".kaggle/access_token").read_text().strip()
    ref = src["url"].split("/datasets/")[1]
    subprocess.run(
        ["uvx", "kaggle", "datasets", "download", "-d", ref, "-p", str(folder), "--unzip"],
        check=True,
        env={**os.environ, "KAGGLE_API_TOKEN": token},
    )
    for f in folder.iterdir():
        record(folder, f, src["url"], src["licence"])


FETCHERS = {"livsmedelsverket": fetch_livsmedelsverket, "medquad": fetch_git, "south_asian_recipes": fetch_kaggle}


def main(only: list[str]) -> None:
    for src in todo(sources(), only):
        folder = DATA / src["folder"]
        folder.mkdir(parents=True, exist_ok=True)
        print(src["id"], flush=True)
        FETCHERS.get(src["id"], fetch_file)(src, folder)


if __name__ == "__main__":
    main(sys.argv[1:])
