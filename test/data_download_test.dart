import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/main.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('myfoodmind_data_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File gz(String name, List<int> bytes) => File('${tmp.path}/$name.gz')..writeAsBytesSync(gzip.encode(bytes));
  List<String> missing() => [for (final f in missingData(tmp)) f.name];

  test('first run: every file missing; each .gz unpacked and swapped in; then ready', () async {
    expect(missing(), ['health.db', 'nutri.db', embedderFile, tokenizerFile]);
    await installData(tmp, gz('health.db', File('test/health_test.db').readAsBytesSync()));
    expect(missing(), ['nutri.db', embedderFile, tokenizerFile]); // each file once: start() moves on
    await installData(tmp, gz('nutri.db', File('test/nutri_test.db').readAsBytesSync()));
    expect(missing(), [embedderFile, tokenizerFile]);
    expect(File('${tmp.path}/nutri.db.data_version').readAsStringSync(), '$nutriDataVersion');
    await installData(tmp, gz(embedderFile, [1, 2, 3]));
    await installData(tmp, gz(tokenizerFile, [4, 5]));
    expect(missing(), isEmpty);
    expect(File('${tmp.path}/$embedderFile').readAsBytesSync(), [1, 2, 3]);
    expect(tmp.listSync().where((e) => e.path.endsWith('.gz') || e.path.endsWith('.part')), isEmpty);

    // A new data version on the phone: the databases come again, the embedder stays.
    for (final db in ['health.db', 'nutri.db']) {
      File('${tmp.path}/$db.data_version').writeAsStringSync('${nutriDataVersion - 1}');
    }
    expect(missing(), ['health.db', 'nutri.db']);
    await installData(tmp, gz('health.db', File('test/health_test.db').readAsBytesSync()));
    expect(missing(), ['nutri.db']);
  });

  test('a corrupt nutri.db is thrown away with its .gz, so Resume downloads it again', () async {
    final file = gz('nutri.db', 'not a database'.codeUnits);
    await expectLater(installData(tmp, file), throwsA(anything));
    expect(file.existsSync(), isFalse);
    expect(File('${tmp.path}/nutri.db').existsSync(), isFalse);
    expect(File('${tmp.path}/nutri.db.part').existsSync(), isFalse);
    expect(File('${tmp.path}/nutri.db.data_version').existsSync(), isFalse);
  });

  testWidgets('until the data is on the phone the app shows its download, with the size', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appDirProvider.overrideWith((ref) async => tmp)],
      child: const MyFoodMindApp(),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Food data'), findsOneWidget);
    expect(find.text('Download ($dataDownloadMb MB)'), findsOneWidget);
  });
}
