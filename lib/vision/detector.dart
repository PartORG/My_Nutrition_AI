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

  @override
  Future<List<Detection>> detect(Uint8List rgb) async {
    final boxes = [List.generate(25, (_) => List.filled(4, 0.0))];
    final classes = [List.filled(25, 0.0)], scores = [List.filled(25, 0.0)], count = [0.0];
    await _isolate.runForMultipleInputs([rgb], {0: boxes, 1: classes, 2: scores, 3: count});
    return decodeDetections(boxes[0], classes[0], scores[0], count[0].round());
  }

  @override
  void close() {
    _isolate.close();
    _interpreter.close();
  }
}
