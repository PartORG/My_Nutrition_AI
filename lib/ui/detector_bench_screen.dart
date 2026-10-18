import 'dart:isolate';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../vision/detector.dart';
import 'theme.dart';

/// Developer only (DEV_BILLING builds, Settings → About), so English only: EfficientDet-Lite0 against the
/// YOLOX-Tiny food detector on this phone's CPU (step 7), and YOLOX on a gallery photo.
class DetectorBenchScreen extends StatefulWidget {
  const DetectorBenchScreen({super.key});

  @override
  State<DetectorBenchScreen> createState() => _DetectorBenchScreenState();
}

const _warmup = 3, _runs = 30;

/// [runs] invokes of the interpreter at [address] in a background isolate, as the camera runs it → µs each.
/// The input is set once: the speed doesn't depend on the picture. Times invoke() alone: the isolate
/// wrapper's output copy (2.4 MB a frame for YOLOX) would swamp it.
Future<List<int>> _time(int address, Uint8List input, int runs) => Isolate.run(() {
      final it = Interpreter.fromAddress(address, allocated: true)..getInputTensor(0).data = input;
      final us = <int>[];
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        it.invoke();
        us.add(sw.elapsedMicroseconds);
      }
      return us;
    });

/// One YOLOX run on a letterboxed photo → (µs, detections). Top level: a closure inside the screen could
/// capture the ui.Image, which can't cross to the isolate.
Future<(int, List<Detection>)> _detect(int address, Uint8List input, List<String> labels, int w, int h) =>
    Isolate.run(() {
      final it = Interpreter.fromAddress(address, allocated: true)..getInputTensor(0).data = input;
      final sw = Stopwatch()..start();
      it.invoke();
      final us = sw.elapsedMicroseconds;
      return (us, decodeYolox(it.getOutputTensor(0).data.buffer.asFloat32List(), labels, w, h));
    });

class _DetectorBenchScreenState extends State<DetectorBenchScreen> {
  final _lines = <String>[];
  bool _busy = false;
  ({ui.Image image, List<Detection> found})? _photo;

  void _say(String line) {
    if (mounted) setState(() => _lines.add(line));
  }

  Future<void> _guard(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      _say('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bench() => _guard(() async {
        _lines.clear();
        for (final (asset, threads) in [
          (TfliteDetector.asset, 2), (TfliteDetector.asset, 4), (yoloxAsset, 2), (yoloxAsset, 4)
        ]) {
          final sw = Stopwatch()..start();
          final it = await Interpreter.fromAsset(asset, options: InterpreterOptions()..threads = threads);
          final load = sw.elapsedMilliseconds;
          try {
            final input = Uint8List(it.getInputTensor(0).numBytes());
            final us = (await _time(it.address, input, _warmup + _runs)).skip(_warmup).toList()..sort();
            String ms(double p) => (us[(p * (us.length - 1)).round()] / 1000).toStringAsFixed(1);
            _say('${asset.split('/').last}, $threads threads: median ${ms(.5)} ms, p90 ${ms(.9)} ms '
                '(load $load ms)');
          } finally {
            it.close();
          }
        }
      });

  Future<void> _tryPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280);
    if (file == null) return;
    await _guard(() async {
      final desc = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes()));
      final r = min(yoloxSize / desc.width, yoloxSize / desc.height);
      final w = (desc.width * r).floor(), h = (desc.height * r).floor();
      final image = (await (await desc.instantiateCodec(targetWidth: w, targetHeight: h)).getNextFrame()).image;
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final input = letterboxBgr(rgba, w, h).buffer.asUint8List();
      final labels = readYoloxLabels(await rootBundle.loadString(yoloxLabelsAsset));
      final it = await Interpreter.fromAsset(yoloxAsset, options: InterpreterOptions()..threads = 4);
      try {
        final (us, found) = await _detect(it.address, input, labels, w, h);
        if (!mounted) {
          image.dispose();
          return;
        }
        _photo?.image.dispose();
        setState(() => _photo = (image: image, found: found));
        _say('Photo: ${(us / 1000).toStringAsFixed(1)} ms, ${found.length} found: '
            '${found.map((d) => '${d.label} ${d.score.toStringAsFixed(2)}').join(', ')}');
      } finally {
        it.close();
      }
    });
  }

  @override
  void dispose() {
    _photo?.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors, photo = _photo;
    return Scaffold(
      appBar: AppBar(title: const Text('Detector benchmark')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('CPU, $_runs runs after $_warmup warm-up runs. Close other apps first; a release build gives the '
            'real numbers.', style: TextStyle(color: c.muted)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton(onPressed: _busy ? null : _bench, child: const Text('Run benchmark'))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton(onPressed: _busy ? null : _tryPhoto, child: const Text('Try a photo'))),
        ]),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        for (final line in _lines) Padding(padding: const EdgeInsets.only(top: 12), child: SelectableText(line)),
        if (photo != null) ...[
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: photo.image.width / photo.image.height,
            child: LayoutBuilder(builder: (context, box) => Stack(children: [
                  Positioned.fill(child: RawImage(image: photo.image, fit: BoxFit.fill)),
                  for (final d in photo.found)
                    Positioned(
                      left: d.box.left * box.maxWidth,
                      top: d.box.top * box.maxHeight,
                      width: d.box.width * box.maxWidth,
                      height: d.box.height * box.maxHeight,
                      child: Container(
                        alignment: Alignment.topLeft,
                        decoration: BoxDecoration(border: Border.all(color: c.accent, width: 2)),
                        child: Container(
                          color: c.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          child: Text('${d.label} ${d.score.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.black, fontSize: 12)),
                        ),
                      ),
                    ),
                ])),
          ),
        ],
      ]),
    );
  }
}
