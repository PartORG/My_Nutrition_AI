"""Training set for the live detector (step 7, docs/PLAN.md): Food Recognition 2022 → COCO with our labels.

    python3 tool/detector_data.py ~/datasets/food-recognition-2022 ~/datasets/detector

Writes <out>/annotations/{train,val}.json with the 164 labels of db/detector_labels.tsv as categories, and
links <out>/{train2017,val2017} to the dataset's image folders (the names YOLOX's COCO loader expects).
Boxes come from the polygons: the dataset's own `bbox` field is wrong for 96 % of objects (its y repeats
the x, checked by drawing both on photos, 2026-10-18). Stdlib only.
"""

import json
import sys
from pathlib import Path

LABELS = Path(__file__).resolve().parent.parent / "db" / "detector_labels.tsv"
SPLITS = {"train": "public_training_set_release_2.0", "val": "public_validation_set_2.0"}


def read_labels(text: str) -> tuple[list[str], dict[str, str]]:
    """detector_labels.tsv → (labels in file order, dataset class → label)."""
    labels, of = [], {}
    for line in text.splitlines():
        if not line.strip() or line.startswith("#") or line.startswith("label\t"):
            continue
        label, _, _, members = line.split("\t")
        labels.append(label)
        of.update(dict.fromkeys(members.split(), label))
    return labels, of


def polygon_box(segmentation: list[list[float]], width: int, height: int) -> list[float] | None:
    """COCO [x, y, w, h] around all polygon points, clipped to the image; None if it has no area."""
    xs = [x for p in segmentation for x in p[0::2]]
    ys = [y for p in segmentation for y in p[1::2]]
    if not xs:
        return None
    x0, y0 = max(0.0, min(xs)), max(0.0, min(ys))
    x1, y1 = min(float(width), max(xs)), min(float(height), max(ys))
    return [x0, y0, x1 - x0, y1 - y0] if x1 - x0 >= 2 and y1 - y0 >= 2 else None


def convert(coco: dict, labels: list[str], of: dict[str, str]) -> dict:
    """The dataset's COCO → ours: categories = labels (ids from 1), boxes from polygons, no masks."""
    ids = {label: n + 1 for n, label in enumerate(labels)}
    cat = {c["id"]: ids[of[c["name"]]] for c in coco["categories"]}  # KeyError = a class in no label
    images = {i["id"]: i for i in coco["images"]}
    anns = []
    for a in coco["annotations"]:
        im = images[a["image_id"]]
        box = polygon_box(a["segmentation"], im["width"], im["height"])
        if box:
            anns.append({"id": len(anns) + 1, "image_id": a["image_id"], "category_id": cat[a["category_id"]],
                         "bbox": box, "area": box[2] * box[3], "iscrowd": 0})
    return {
        "images": [{k: i[k] for k in ("id", "file_name", "width", "height")} for i in coco["images"]],
        "annotations": anns,
        "categories": [{"id": ids[label], "name": label} for label in labels],
    }


def main(src: str, out: str) -> None:
    labels, of = read_labels(LABELS.read_text())
    src_dir, out_dir = Path(src).expanduser(), Path(out).expanduser()
    (out_dir / "annotations").mkdir(parents=True, exist_ok=True)
    for split, folder in SPLITS.items():
        coco = convert(json.loads((src_dir / folder / "annotations.json").read_text()), labels, of)
        (out_dir / "annotations" / f"{split}.json").write_text(json.dumps(coco))
        link = out_dir / f"{split}2017"
        if not link.exists():
            link.symlink_to(src_dir / folder / "images", target_is_directory=True)
        print(f"{split}: {len(coco['images'])} images, {len(coco['annotations'])} boxes, {len(labels)} labels")


if __name__ == "__main__":
    main(*sys.argv[1:3])
