"""~/src/tflite-export/.venv/bin/python -m pytest tool/test_detector_export.py (numpy and cv2 needed)"""

import numpy as np

import detector_export as de


def test_decode_grid_order_stride_and_nms():
    raw = np.zeros((3549, 5 + 3), np.float32)
    raw[52 * 2 + 3] = [0.5, 0.5, np.log(4), np.log(2), 0.9, 0, 0.8, 0]  # stride 8, row 2, column 3: 32x16 px
    raw[52 * 2 + 4] = [-0.5, 0.5, np.log(4), np.log(2), 0.8, 0, 0.8, 0]  # the same box one cell over: suppressed
    raw[52 * 52 + 26 * 26] = [0, 0, 0, 0, 0.5, 0.9, 0, 0]  # first stride-32 cell, another class: kept
    boxes, scores, classes = de.decode(raw)
    assert classes.tolist() == [1, 0] and np.allclose(scores, [0.72, 0.45])
    assert np.allclose(boxes[0], [28 - 16, 20 - 8, 28 + 16, 20 + 8]), boxes[0]
    assert np.allclose(boxes[1], [-16, -16, 16, 16])
