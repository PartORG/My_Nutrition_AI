// M6: the real EfficientDet-Lite0 on the phone (tflite has no host build).
// IMAGE_PATH is a raw 320×320 RGB file of a banana photo; make one on the PC:
//   PIL: Image.open(jpg).convert('RGB').resize((320, 320)).tobytes()
// then `adb push` it into the app's external files dir.
//
//   flutter test --no-uninstall integration_test/detector_test.dart -d <phone> \
//     --dart-define=IMAGE_PATH=/sdcard/Android/data/io.github.partorg.myfoodmind/files/banana_320.rgb
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myfoodmind/vision/detector.dart';

const _image = String.fromEnvironment('IMAGE_PATH');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EfficientDet-Lite0 finds the banana, fast enough for live mode', (tester) async {
    await tester.runAsync(() async {
      final load = Stopwatch()..start();
      final detector = await TfliteDetector.load();
      debugPrint('detector loaded in ${load.elapsedMilliseconds} ms');
      final rgb = File(_image).readAsBytesSync();
      expect(rgb.length, inputSize * inputSize * 3);

      final times = <int>[];
      late List<Detection> found;
      for (var i = 0; i < 10; i++) {
        final t = Stopwatch()..start();
        found = await detector.detect(rgb);
        times.add(t.elapsedMilliseconds);
      }
      times.sort();
      debugPrint('detect p50 ${times[5]} ms, max ${times.last} ms; found $found');
      expect(found.first.label, 'banana');
      expect(times[5], lessThan(500), reason: 'live mode detects every 500 ms');
      detector.close();
    });
  });
}
