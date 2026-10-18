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
/// YOLOX-Tiny food detector on this phone's CPU, GPU and NNAPI (step 7), and YOLOX on a gallery photo.
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
      // 0.25, not the app's 0.4: shows what the model almost found.
      return (us, decodeYolox(it.getOutputTensor(0).data.buffer.asFloat32List(), labels, w, h, threshold: .25));
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
        // CPU at 2 threads (4 was slower on the Xiaomi 11T for both), the GPU delegate (runs the int8 model in
        // fp16) and NNAPI (the phone's AI chip; deprecated in Android 15, so measured, not relied on).
        for (final how in ['CPU', 'GPU', 'NNAPI']) {
          for (final asset in [TfliteDetector.asset, yoloxAsset]) {
            final name = '${asset.split('/').last}, $how';
            final gpu = how == 'GPU' ? GpuDelegateV2() : null;
            final options = InterpreterOptions()..threads = 2;
            if (gpu != null) options.addDelegate(gpu);
            if (how == 'NNAPI') options.useNnApiForAndroid = true;
            Interpreter? it;
            try {
              final sw = Stopwatch()..start();
              it = await Interpreter.fromAsset(asset, options: options);
              final load = sw.elapsedMilliseconds; // GPU: includes compiling its kernels
              final input = Uint8List(it.getInputTensor(0).numBytes());
              final us = (await _time(it.address, input, _warmup + _runs)).skip(_warmup).toList()..sort();
              String ms(double p) => (us[(p * (us.length - 1)).round()] / 1000).toStringAsFixed(1);
              _say('$name: median ${ms(.5)} ms, p90 ${ms(.9)} ms (load $load ms)');
            } catch (e) {
              _say('$name: failed: $e');
            } finally {
              it?.close();
              gpu?.delete(); // after the interpreter that uses it
            }
          }
        }
      });

  /// YOLOX on one photo, tiled ([photoTiles]), on the CPU and on NNAPI (the fastest in the benchmark: are its
  /// int8 results the same?). A screenshot of a web page still leaves the food tiny: take a real meal photo.
  Future<void> _tryPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280);
    if (file == null) return;
    await _guard(() async {
      final image = await decodeImageFromList(await file.readAsBytes());
      final labels = readYoloxLabels(await rootBundle.loadString(yoloxLabelsAsset));
      // Each tile cropped from the full photo and scaled to fit the model, once for both runs.
      final inputs = <(Rect, Uint8List, int, int)>[];
      for (final tile in photoTiles) {
        final src = Rect.fromLTRB(tile.left * image.width, tile.top * image.height, tile.right * image.width,
            tile.bottom * image.height);
        final r = min(yoloxSize / src.width, yoloxSize / src.height);
        final w = (src.width * r).floor(), h = (src.height * r).floor();
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(image, src, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
            Paint()..filterQuality = FilterQuality.medium);
        final crop = await rec.endRecording().toImage(w, h);
        final rgba = (await crop.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        crop.dispose();
        inputs.add((tile, letterboxBgr(rgba, w, h).buffer.asUint8List(), w, h));
      }
      var found = <Detection>[];
      for (final how in ['CPU', 'NNAPI']) {
        final options = InterpreterOptions()..threads = 2;
        if (how == 'NNAPI') options.useNnApiForAndroid = true;
        final it = await Interpreter.fromAsset(yoloxAsset, options: options);
        try {
          var us = 0, whole = 0;
          final all = <Detection>[];
          for (final (tile, input, w, h) in inputs) {
            final (t, d) = await _detect(it.address, input, labels, w, h);
            us += t;
            if (tile == photoTiles.first) whole = d.length;
            all.addAll(d.map((d) => fromTile(d, tile)));
          }
          final merged = mergeTiles(all);
          if (how == 'CPU') found = merged; // the boxes drawn: CPU is the reference
          final names = merged.map((d) => '${d.label} ${d.score.toStringAsFixed(2)}').join(', ');
          _say('$how: ${(us / 1000).toStringAsFixed(1)} ms for ${inputs.length} tiles, $whole found on the whole '
              'photo, ${merged.length} tiled: $names');
        } finally {
          it.close();
        }
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      _photo?.image.dispose();
      setState(() => _photo = (image: image, found: found));
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
        Text('CPU, GPU and NNAPI, $_runs runs after $_warmup warm-up runs. Close other apps first; a release build '
            'gives the real numbers.', style: TextStyle(color: c.muted)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _bench, child: const Text('Run benchmark')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: _busy ? null : () => _tryPhoto(ImageSource.camera), child: const Text('Take a photo'))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton(
                  onPressed: _busy ? null : () => _tryPhoto(ImageSource.gallery), child: const Text('Pick a photo'))),
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
