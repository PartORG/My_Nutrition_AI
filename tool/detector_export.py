"""Live detector (step 7, docs/PLAN.md): YOLOX-Tiny ONNX -> TFLite int8, then the same val AP for each file.

    ~/src/tflite-export/.venv/bin/python tool/detector_export.py ~/src/YOLOX/export/yolox_tiny_food.onnx \
        ~/datasets/detector

The venv has onnx2tf 1.28.8, tensorflow 2.19.0, tf_keras, onnx 1.17.0, onnx_graphsurgeon, sng4onnx, ai_edge_litert,
onnxsim 0.8.1, protobuf 3.20.3, onnxruntime, opencv-python-headless, pycocotools. The ONNX comes from YOLOX's
tools/export_onnx.py (raw head: decode_in_inference off, so pixel boxes and 0-1 scores never share one int8
tensor). Calibration uses CALIB training photos. letterbox() and decode() are what the app must do in Dart.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import cv2
import numpy as np

SIZE = 416
STRIDES = (8, 16, 32)
CALIB = 200
CONF, NMS = 0.01, 0.65  # YOLOX's eval settings; the app shows only confident boxes


def letterbox(path: Path) -> tuple[np.ndarray, float]:
    """YOLOX preproc: BGR 0-255, scaled to fit SIZE, top-left, grey 114 padding. HWC float32, and the scale."""
    img = cv2.imread(str(path))
    r = min(SIZE / img.shape[0], SIZE / img.shape[1])
    out = np.full((SIZE, SIZE, 3), 114, np.uint8)
    out[: int(img.shape[0] * r), : int(img.shape[1] * r)] = cv2.resize(
        img, (int(img.shape[1] * r), int(img.shape[0] * r)), interpolation=cv2.INTER_LINEAR)
    return out.astype(np.float32), r


def _grid() -> tuple[np.ndarray, np.ndarray]:
    cells, strides = [], []
    for s in STRIDES:
        n = SIZE // s
        yv, xv = np.meshgrid(np.arange(n), np.arange(n), indexing="ij")
        cells.append(np.stack([xv, yv], -1).reshape(-1, 2))
        strides.append(np.full((n * n, 1), s))
    return np.concatenate(cells).astype(np.float32), np.concatenate(strides).astype(np.float32)


GRID, STRIDE = _grid()  # 52*52 + 26*26 + 13*13 = 3549 anchors


def decode(raw: np.ndarray, conf: float = CONF, nms: float = NMS) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """[3549, 5 + classes] raw head -> (xyxy boxes in input pixels, scores, class indices), per-class NMS."""
    xy = (raw[:, :2] + GRID) * STRIDE
    wh = np.exp(raw[:, 2:4]) * STRIDE
    cls = raw[:, 5:].argmax(1)
    score = raw[:, 4] * raw[np.arange(len(raw)), 5 + cls]
    keep = score >= conf
    xy, wh, cls, score = xy[keep], wh[keep], cls[keep], score[keep]
    if not len(score):
        return np.zeros((0, 4)), score, cls
    idx = cv2.dnn.NMSBoxesBatched(np.concatenate([xy - wh / 2, wh], 1).tolist(), score.tolist(), cls.tolist(),
                                  conf, nms)
    idx = np.asarray(idx, int).reshape(-1)
    return np.concatenate([xy - wh / 2, xy + wh / 2], 1)[idx], score[idx], cls[idx]


def runner(path: Path):
    """Model file -> function(HWC image) -> raw [3549, 169]."""
    if path.suffix == ".onnx":
        import onnxruntime as ort
        s = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
        name = s.get_inputs()[0].name
        return lambda x: s.run(None, {name: x.transpose(2, 0, 1)[None]})[0][0]
    from ai_edge_litert.interpreter import Interpreter
    it = Interpreter(model_path=str(path), num_threads=4)
    it.allocate_tensors()
    inp, out = it.get_input_details()[0], it.get_output_details()[0]

    def run(x):
        it.set_tensor(inp["index"], x[None])
        it.invoke()
        return it.get_tensor(out["index"])[0]
    return run


def evaluate(path: Path, data: Path) -> tuple[float, float, float]:
    """(AP, AP50, ms per image) on the val split, the way YOLOX's evaluator scores it."""
    from pycocotools.coco import COCO
    from pycocotools.cocoeval import COCOeval
    gt = COCO(str(data / "annotations" / "val.json"))
    cats = sorted(gt.getCatIds())
    run, dets, ms = runner(path), [], []
    for im in gt.loadImgs(gt.getImgIds()):
        x, r = letterbox(data / "val2017" / im["file_name"])
        t = time.perf_counter()
        raw = run(x)
        ms.append((time.perf_counter() - t) * 1000)
        for (x0, y0, x1, y1), s, c in zip(*decode(raw)):
            dets.append({"image_id": im["id"], "category_id": cats[c], "score": float(s),
                         "bbox": [x0 / r, y0 / r, (x1 - x0) / r, (y1 - y0) / r]})
    e = COCOeval(gt, gt.loadRes(dets), "bbox")
    e.evaluate(), e.accumulate(), e.summarize()
    return e.stats[0], e.stats[1], float(np.median(ms))


def main(onnx: str, data_dir: str) -> None:
    onnx_path, data = Path(onnx).expanduser(), Path(data_dir).expanduser()
    out = onnx_path.parent / "tflite"
    calib = onnx_path.parent / "calib.npy"
    if not calib.exists():
        train = sorted((data / "train2017").iterdir())
        np.save(calib, np.stack([letterbox(p)[0] for p in train[:: len(train) // CALIB][:CALIB]]))
    # onnx2tf checks its outputs on this file from the working directory; its download is gone (404).
    sample = onnx_path.parent / "calibration_image_sample_data_20x128x128x3_float32.npy"
    if not sample.exists():
        x = np.load(calib)[:20]
        np.save(sample, np.stack([cv2.resize(i, (128, 128)) for i in x]).astype(np.float32) / 255)
    venv = str(Path(sys.executable).parent)  # onnx2tf runs onnxsim (pip onnxsim) from PATH
    subprocess.run([venv + "/onnx2tf", "-i", str(onnx_path), "-o", str(out), "-oiqt",
                    "-cind", "images", str(calib), "[[[[0,0,0]]]]", "[[[[1,1,1]]]]"], check=True,
                   cwd=onnx_path.parent, env={**os.environ, "PATH": venv + os.pathsep + os.environ["PATH"]})
    stem = onnx_path.stem
    rows = []
    for f in [onnx_path, out / f"{stem}_float32.tflite", out / f"{stem}_integer_quant.tflite"]:
        ap, ap50, ms = evaluate(f, data)
        rows.append(f"{f.name}\t{f.stat().st_size / 1e6:.1f} MB\tAP {ap:.3f}\tAP50 {ap50:.3f}\t{ms:.1f} ms")
    print("\n".join(rows))


if __name__ == "__main__":
    main(*sys.argv[1:3])
