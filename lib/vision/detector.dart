import 'dart:math' show exp, min;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:tflite_flutter/tflite_flutter.dart';

/// Pro: finds food in a camera frame. Everything found goes to the review
/// screen first; nothing is logged from a detection directly.

/// [box] is normalized 0..1 in the upright (display) image.
typedef Detection = ({String label, double score, Rect box});

abstract interface class Detector {
  /// [rgb] is [inputSize]² × 3 bytes, upright (see [yuvToRgb]).
  Future<List<Detection>> detect(Uint8List rgb);
  void close();
}

const inputSize = 320;

/// EfficientDet-Lite0 (COCO, Apache 2.0) class index → label, food classes
/// only. Labels are searched in nutri.db like typed text. The real food/dish
/// model (PLAN: D-FINE / RT-DETR / YOLOX) will label with foods.name directly.
const cocoFoods = {
  51: 'banana', 52: 'apple', 53: 'sandwich', 54: 'orange', 55: 'broccoli',
  56: 'carrot', 57: 'hot dog', 58: 'pizza', 59: 'donut', 60: 'cake',
};

/// Below this a box is noise. 0.4 is a guess; tune on real food photos.
const minScore = 0.4;

/// The model's four outputs (boxes [ymin, xmin, ymax, xmax], classes, scores,
/// count) → food detections, best first.
List<Detection> decodeDetections(List<List<double>> boxes, List<double> classes, List<double> scores, int count,
    {double threshold = minScore}) {
  final found = <Detection>[
    for (var i = 0; i < count; i++)
      if (scores[i] >= threshold && cocoFoods[classes[i].round()] != null)
        (
          label: cocoFoods[classes[i].round()]!,
          score: scores[i],
          box: Rect.fromLTRB(boxes[i][1].clamp(0, 1), boxes[i][0].clamp(0, 1), boxes[i][3].clamp(0, 1),
              boxes[i][2].clamp(0, 1)),
        )
  ];
  return found..sort((a, b) => b.score.compareTo(a.score));
}

/// YOLOX-Tiny on 164 food labels (step 7, tool/yolox_tiny_food.py); int8, val AP 30.9. Only the developer
/// benchmark uses it so far. Ports letterbox() and decode() of tool/detector_export.py.
const yoloxAsset = 'assets/models/yolox_tiny_food.tflite';
const yoloxLabelsAsset = 'db/detector_labels.tsv';
const yoloxSize = 416;

/// detector_labels.tsv → the labels in class order.
List<String> readYoloxLabels(String tsv) => [
      for (final line in tsv.split('\n'))
        if (line.trim().isNotEmpty && !line.startsWith('#') && !line.startsWith('label\t')) line.split('\t').first
    ];

/// RGBA of a photo already scaled to fit [yoloxSize] ([w]×[h]) → the model input as YOLOX trains it: BGR
/// 0-255, top-left, grey 114 padding.
Float32List letterboxBgr(Uint8List rgba, int w, int h) {
  final out = Float32List(yoloxSize * yoloxSize * 3)..fillRange(0, yoloxSize * yoloxSize * 3, 114);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4, o = (y * yoloxSize + x) * 3;
      out[o] = rgba[i + 2].toDouble();
      out[o + 1] = rgba[i + 1].toDouble();
      out[o + 2] = rgba[i].toDouble();
    }
  }
  return out;
}

/// The raw head (3549 anchors × [x, y, log w, log h, objectness, a score per label]) → detections, best
/// first, boxes normalized to the [w]×[h] photo area of the input. NMS per label, like YOLOX's eval.
List<Detection> decodeYolox(List<double> raw, List<String> labels, int w, int h,
    {double threshold = minScore, double nms = .65}) {
  final row = 5 + labels.length;
  final found = <(int, double, Rect)>[];
  var i = 0;
  for (final s in const [8, 16, 32]) {
    final n = yoloxSize ~/ s;
    for (var gy = 0; gy < n; gy++) {
      for (var gx = 0; gx < n; gx++, i++) {
        final r = i * row;
        if (raw[r + 4] < threshold) continue; // the score is at most the objectness
        var best = 0;
        for (var c = 1; c < labels.length; c++) {
          if (raw[r + 5 + c] > raw[r + 5 + best]) best = c;
        }
        final score = raw[r + 4] * raw[r + 5 + best];
        if (score < threshold) continue;
        final cx = (raw[r] + gx) * s, cy = (raw[r + 1] + gy) * s;
        final bw = exp(raw[r + 2]) * s, bh = exp(raw[r + 3]) * s;
        found.add(
            (best, score, Rect.fromLTRB((cx - bw / 2) / w, (cy - bh / 2) / h, (cx + bw / 2) / w, (cy + bh / 2) / h)));
      }
    }
  }
  found.sort((a, b) => b.$2.compareTo(a.$2));
  double iou(Rect a, Rect b) {
    final x = a.intersect(b);
    if (x.width <= 0 || x.height <= 0) return 0;
    final inter = x.width * x.height;
    return inter / (a.width * a.height + b.width * b.height - inter);
  }

  final kept = <(int, double, Rect)>[];
  for (final f in found) {
    if (!kept.any((k) => k.$1 == f.$1 && iou(k.$3, f.$3) > nms)) kept.add(f);
  }
  return [
    for (final (c, score, b) in kept)
      (
        label: labels[c],
        score: score,
        box: Rect.fromLTRB(b.left.clamp(0, 1), b.top.clamp(0, 1), b.right.clamp(0, 1), b.bottom.clamp(0, 1)),
      )
  ];
}

/// Photo mode: the whole photo plus four quarters overlapping by 20%, so small foods are 2× bigger to the
/// model (a flat-lay's 25 px item becomes 50 px). Live mode stays one pass. Normalized to the photo.
const photoTiles = [
  Rect.fromLTRB(0, 0, 1, 1),
  Rect.fromLTRB(0, 0, .6, .6), Rect.fromLTRB(.4, 0, 1, .6),
  Rect.fromLTRB(0, .4, .6, 1), Rect.fromLTRB(.4, .4, 1, 1),
];

/// A detection inside [tile] → the same one on the whole photo.
Detection fromTile(Detection d, Rect tile) => (
      label: d.label,
      score: d.score,
      box: Rect.fromLTRB(tile.left + d.box.left * tile.width, tile.top + d.box.top * tile.height,
          tile.left + d.box.right * tile.width, tile.top + d.box.bottom * tile.height),
    );

/// All tiles' detections → one list, best first. Same-label boxes that mostly overlap (most of the smaller
/// one inside the other: a tile's half plate and the whole photo's plate) become one: their combined box,
/// the higher score. Plain NMS would keep the half plate when it scores higher.
List<Detection> mergeTiles(List<Detection> all, {double overlap = .6}) {
  final kept = <Detection>[];
  for (final d in [...all]..sort((a, b) => b.score.compareTo(a.score))) {
    final i = kept.indexWhere((k) {
      if (k.label != d.label) return false;
      final x = k.box.intersect(d.box);
      if (x.width <= 0 || x.height <= 0) return false;
      final smaller = min(k.box.width * k.box.height, d.box.width * d.box.height);
      return x.width * x.height / smaller > overlap;
    });
    if (i < 0) {
      kept.add(d);
    } else {
      kept[i] = (label: kept[i].label, score: kept[i].score, box: kept[i].box.expandToInclude(d.box));
    }
  }
  return kept;
}

/// A YUV_420_888 camera frame → [outW]×[outH] RGB, rotated upright by
/// [rotation] degrees clockwise (the sensor orientation). The default squeezes
/// it to the [inputSize]² square EfficientDet expects. Nearest-neighbour: fast enough per frame.
Uint8List yuvToRgb({
  required int width,
  required int height,
  required Uint8List y,
  required Uint8List u,
  required Uint8List v,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  required int rotation,
  int outW = inputSize,
  int outH = inputSize,
}) {
  final out = Uint8List(outW * outH * 3);
  var o = 0;
  for (var oy = 0; oy < outH; oy++) {
    final fv = (oy + .5) / outH;
    for (var ox = 0; ox < outW; ox++) {
      final fu = (ox + .5) / outW;
      // Display (fu, fv) → sensor (fx, fy).
      final (fx, fy) = switch (rotation) {
        90 => (fv, 1 - fu),
        180 => (1 - fu, 1 - fv),
        270 => (1 - fv, fu),
        _ => (fu, fv),
      };
      final sx = (fx * width).floor().clamp(0, width - 1);
      final sy = (fy * height).floor().clamp(0, height - 1);
      final yy = y[sy * yRowStride + sx];
      final uvi = (sy >> 1) * uvRowStride + (sx >> 1) * uvPixelStride;
      final cb = u[uvi] - 128, cr = v[uvi] - 128;
      out[o++] = (yy + 1.402 * cr).round().clamp(0, 255);
      out[o++] = (yy - .344136 * cb - .714136 * cr).round().clamp(0, 255);
      out[o++] = (yy + 1.772 * cb).round().clamp(0, 255);
    }
  }
  return out;
}

/// EfficientDet-Lite0 on the CPU, in its own isolate so the preview stays smooth.
class TfliteDetector implements Detector {
  TfliteDetector._(this._interpreter, this._isolate);

  static const asset = 'assets/models/efficientdet_lite0.tflite';

  static Future<TfliteDetector> load() async {
    final interpreter = await Interpreter.fromAsset(asset, options: InterpreterOptions()..threads = 2);
    return TfliteDetector._(interpreter, await IsolateInterpreter.create(address: interpreter.address));
  }

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;
  Future<void>? _running;

  @override
  Future<List<Detection>> detect(Uint8List rgb) async {
    final boxes = [List.generate(25, (_) => List.filled(4, 0.0))];
    final classes = [List.filled(25, 0.0)], scores = [List.filled(25, 0.0)], count = [0.0];
    await (_running = _isolate.runForMultipleInputs([rgb], {0: boxes, 1: classes, 2: scores, 3: count}));
    return decodeDetections(boxes[0], classes[0], scores[0], count[0].round());
  }

  /// Waits for a run in flight: freeing the native interpreter under it
  /// crashed the app on leaving the camera (back, or after Continue).
  @override
  void close() {
    (_running ?? Future<void>.value()).then((_) {}, onError: (_) {}).whenComplete(() async {
      await _isolate.close();
      _interpreter.close();
    });
  }
}
