import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('products download: the .gz unpacked, checked, swapped in; remove goes back', () async {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_products_');
    final src = '${tmp.path}/src.db';
    sqlite3.open(src)
      ..execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL); '
          "INSERT INTO meta VALUES ('rows', '1'), ('built_at', '2026-10-07'); "
          'CREATE TABLE products (barcode TEXT PRIMARY KEY, name TEXT NOT NULL, kcal REAL NOT NULL, '
          'protein_g REAL NOT NULL, fat_g REAL NOT NULL, carbs_g REAL NOT NULL, fiber_g REAL, sugar_g REAL, sodium_mg REAL); '
          "CREATE VIRTUAL TABLE products_fts USING fts5 (name, barcode UNINDEXED, content = 'products'); "
          "INSERT INTO products VALUES ('4000417326102', 'Ritter Sport Alpenmilch', 532, 8, 32, 53, 2, 50, 100); "
          "INSERT INTO products_fts(products_fts) VALUES ('rebuild');")
      ..close();
    final gz = File('${tmp.path}/products.db.gz')..writeAsBytesSync(gzip.encode(File(src).readAsBytesSync()));
    final nutri = openNutriDb('test/nutri_test.db');
    final user = openUserDb('${tmp.path}/user.db');
    final data = ProfileData(profile: (id: 1, name: 'Anna'), nutri: nutri, user: user, tools: AgentTools(nutri, user));
    final c = ProviderContainer(overrides: [
      appDirProvider.overrideWith((ref) async => tmp),
      profileDataProvider.overrideWithValue(data),
    ]);
    await c.read(appDirProvider.future);

    await unpackProducts(tmp, gz, data.tools);
    expect(File('${tmp.path}/products.db').existsSync(), isTrue);
    expect(File('${tmp.path}/products.db.part').existsSync(), isFalse);
    expect(gz.existsSync(), isFalse);
    expect(productsInfo(data.tools.products), (rows: 1, builtAt: '2026-10-07'));
    expect(data.tools.searchFood('ritter').map((f) => f.label), contains('Ritter Sport Alpenmilch'));
    expect(c.read(productsDownloadProvider), isNull);

    c.read(productsDownloadProvider.notifier).remove();
    expect(data.tools.products, isNull);
    expect(File('${tmp.path}/products.db').existsSync(), isFalse);

    c.dispose();
    nutri.close();
    user.close();
    tmp.deleteSync(recursive: true);
  });

  test('a corrupt download is thrown away, so Resume downloads it again', () async {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_products_');
    final gz = File('${tmp.path}/products.db.gz')..writeAsBytesSync(gzip.encode('not a database'.codeUnits));
    await expectLater(unpackProducts(tmp, gz, null), throwsA(anything));
    expect(gz.existsSync(), isFalse);
    expect(File('${tmp.path}/products.db').existsSync(), isFalse);
    expect(File('${tmp.path}/products.db.part').existsSync(), isFalse);
    tmp.deleteSync(recursive: true);
  });
}
