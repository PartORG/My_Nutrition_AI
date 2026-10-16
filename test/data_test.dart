import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/pin.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('myfoodmind_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A copy of the dummy nutri.db test fixture with [meta] overrides applied.
  File nutriCopy(Map<String, String?> meta) {
    final f = File('test/nutri_test.db').copySync('${tmp.path}/candidate.db');
    final db = sqlite3.open(f.path);
    meta.forEach((k, v) => v == null
        ? db.execute('DELETE FROM meta WHERE key = ?', [k])
        : db.execute('UPDATE meta SET value = ? WHERE key = ?', [v, k]));
    db.close();
    return f;
  }

  group('nutri.db', () {
    test('dummy db opens; recipe nutrition is computed; FTS works', () {
      final db = openNutriDb('test/nutri_test.db');
      final stirFry = db.select(
          'SELECT kcal, protein_g FROM recipe_nutrition WHERE recipe_id = 1').single;
      // (300 g chicken*1.65 + 250 broccoli*.34 + 30 soy*.53 + 15 oil*8.84 + 300 rice*1.23) / 2
      expect(stirFry['kcal'] as double, closeTo(548.8, 0.1));
      expect(db.select("SELECT rowid FROM foods_fts WHERE foods_fts MATCH 'rice'").length, 2);
      expect(db.select("SELECT barcode FROM products_fts WHERE products_fts MATCH 'yogurt'")
          .single['barcode'], '2000000000022');
      expect(() => db.execute('DELETE FROM foods'), throwsA(isA<SqliteException>()),
          reason: 'opened read-only');
      db.close();
    });

    test('refuses wrong version, wrong embedder, or a non-nutri file', () {
      expect(() => openNutriDb(nutriCopy({'schema_version': '4'}).path),
          throwsA(isA<NutriDbException>()));
      // An older file (no foods.source, no dish micronutrients) is refused too, so the app reinstalls the bundled one.
      expect(() => openNutriDb(nutriCopy({'schema_version': '2'}).path),
          throwsA(isA<NutriDbException>()));
      expect(() => openNutriDb(nutriCopy({'schema_version': null}).path),
          throwsA(isA<NutriDbException>()));
      expect(() => openNutriDb(nutriCopy({'embedding_model': 'gecko'}).path),
          throwsA(isA<NutriDbException>()));
      final empty = sqlite3.open('${tmp.path}/empty.db')..close();
      expect(empty, isNotNull);
      expect(() => openNutriDb('${tmp.path}/empty.db'), throwsA(isA<NutriDbException>()));
    });

    test('install swaps in a valid file and keeps the old one otherwise', () {
      final target = File('test/nutri_test.db').copySync('${tmp.path}/nutri.db');
      final before = target.lengthSync();
      final bad = nutriCopy({'schema_version': '99'});
      expect(() => installNutriDb(bad, target), throwsA(isA<NutriDbException>()));
      expect(target.lengthSync(), before);
      installNutriDb(nutriCopy({}), target);
      expect(openNutriDb(target.path).select('SELECT 1 FROM meta').isNotEmpty, isTrue);
    });
  });

  group('migrate', () {
    test('applies missing steps once and records the version', () {
      final db = sqlite3.openInMemory();
      migrate(db, ['CREATE TABLE a (x)']);
      migrate(db, ['CREATE TABLE a (x)', 'CREATE TABLE b (y)']);
      migrate(db, ['CREATE TABLE a (x)', 'CREATE TABLE b (y)']); // no-op
      expect(db.userVersion, 2);
    });

    test('a failing step rolls back every step of that run', () {
      final db = sqlite3.openInMemory();
      migrate(db, ['CREATE TABLE a (x)']);
      expect(() => migrate(db, ['CREATE TABLE a (x)', 'CREATE TABLE b (y)', 'NOT SQL']),
          throwsA(isA<SqliteException>()));
      expect(db.userVersion, 1);
      expect(db.select("SELECT name FROM sqlite_master WHERE name = 'b'"), isEmpty);
    });

    test('refuses a database newer than the app', () {
      final db = sqlite3.openInMemory()..userVersion = 5;
      expect(() => migrate(db, ['CREATE TABLE a (x)']), throwsStateError);
    });

    test('user.db v1 has every table the agent tools write to', () {
      final db = openUserDb('${tmp.path}/user.db');
      final tables = {
        for (final r in db.select("SELECT name FROM sqlite_master WHERE type = 'table'"))
          r['name']
      };
      expect(tables, containsAll(['chat_messages', 'memory_facts', 'user_allergens',
          'saved_recipes', 'meal_log', 'symptoms', 'readings']));
      expect(db.userVersion, userDbMigrations.length);
    });
  });

  group('PIN', () {
    test('format, salted hash, constant-time compare', () {
      expect(['1234', '123456'].every(isValidPin), isTrue);
      expect(['123', '1234567', '12a4', ' 1234'].any(isValidPin), isFalse);
      final salt = newSalt();
      expect(sameBytes(hashPin('1234', salt), hashPin('1234', salt)), isTrue);
      expect(sameBytes(hashPin('1234', salt), hashPin('1235', salt)), isFalse);
      expect(sameBytes(hashPin('1234', salt), hashPin('1234', newSalt())), isFalse);
    });
  });

  group('profiles', () {
    test('create makes a private folder with a migrated user.db', () async {
      final p = Profiles.open(tmp);
      final id = await p.create('  Anna ', '1234');
      expect(p.list(), [(id: id, name: 'Anna')]);
      expect(sqlite3.open(p.userDbPath(id)).userVersion, userDbMigrations.length);
      await expectLater(p.create('Bob', '12'), throwsArgumentError);
      await expectLater(p.create(' ', '1234'), throwsArgumentError);
      p.close();
    });

    test('wrong PINs count down, then lock with growing delays', () async {
      final p = Profiles.open(tmp);
      final id = await p.create('Anna', '1234');
      final t0 = DateTime(2026, 10, 4, 12);
      for (var left = 4; left >= 1; left--) {
        expect(((await p.unlock(id, '0000', now: t0)) as PinWrong).attemptsLeft, left);
      }
      final first = (await p.unlock(id, '0000', now: t0)) as PinLocked; // 5th wrong
      expect(first.until, t0.add(const Duration(seconds: 30)));
      // The right PIN is not even checked while locked.
      expect(await p.unlock(id, '1234', now: t0.add(const Duration(seconds: 29))), isA<PinLocked>());
      final t1 = t0.add(const Duration(seconds: 31));
      final second = (await p.unlock(id, '0000', now: t1)) as PinLocked;
      expect(second.until, t1.add(const Duration(seconds: 60)));
      // Correct PIN after the lock ends unlocks and resets the counter.
      final t2 = t1.add(const Duration(seconds: 61));
      expect(await p.unlock(id, '1234', now: t2), isA<PinOk>());
      expect(((await p.unlock(id, '0000', now: t2)) as PinWrong).attemptsLeft, 4);
      p.close();
    });

    test('lockout is capped at one hour', () async {
      final p = Profiles.open(tmp);
      final id = await p.create('Anna', '1234');
      var t = DateTime(2026, 10, 4);
      PinResult r = PinOk();
      for (var i = 0; i < 20; i++) {
        r = await p.unlock(id, '0000', now: t);
        if (r is PinLocked) t = r.until.add(const Duration(seconds: 1));
      }
      final until = (r as PinLocked).until;
      expect(until.difference(t.subtract(const Duration(seconds: 1))).inMinutes,
          lessThanOrEqualTo(60));
      p.close();
    });

    test('delete removes the row and every file of the profile', () async {
      final p = Profiles.open(tmp);
      final anna = await p.create('Anna', '1234');
      File(p.vectorsDbPath(anna))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('quotes of Anna');
      p.delete(anna);
      expect(File(p.vectorsDbPath(anna)).existsSync(), isFalse, reason: 'vectors quote her messages');
      expect(p.owner, isNull);
      expect(Directory('${tmp.path}/profiles/$anna').existsSync(), isFalse);
      p.close();
    });

    test('one profile per phone, optionally linked to Google', () async {
      final p = Profiles.open(tmp);
      final anna = await p.create('Anna', '1234', googleEmail: 'Anna@Gmail.com');
      expect(p.googleEmail(anna), 'anna@gmail.com');
      await expectLater(p.create('Bob', '5678'), throwsStateError);
      p.setBiometric(anna, true);
      expect(p.biometricEnabled(anna), isTrue);
      p.close();
    });

    test('an old multi-profile phone keeps only the oldest profile', () async {
      final p = Profiles.open(tmp);
      final anna = await p.create('Anna', '1234');
      // Rows as an older version left them.
      p.db.execute("INSERT INTO profiles (name, pin_hash, pin_salt, created_at) VALUES ('Bob', x'00', x'00', 0)");
      final bob = p.db.lastInsertRowId;
      Directory('${tmp.path}/profiles/$bob').createSync(recursive: true);
      expect(p.keepOnlyFirst(), [bob]);
      expect(p.owner, (id: anna, name: 'Anna'));
      expect(Directory('${tmp.path}/profiles/$bob').existsSync(), isFalse);
      expect(File(p.userDbPath(anna)).existsSync(), isTrue);
      expect(p.keepOnlyFirst(), isEmpty);
      p.close();
    });

    test('change PIN needs the current one; Google can be linked and unlinked', () async {
      final p = Profiles.open(tmp);
      final anna = await p.create('Anna', '1234');
      expect(await p.changePin(anna, '0000', '5678'), isA<PinWrong>());
      expect(await p.unlock(anna, '1234'), isA<PinOk>(), reason: 'unchanged after a wrong current PIN');
      expect(await p.changePin(anna, '1234', '5678'), isA<PinOk>());
      expect(await p.unlock(anna, '1234'), isA<PinWrong>());
      expect(await p.unlock(anna, '5678'), isA<PinOk>());
      await expectLater(p.changePin(anna, '5678', '12'), throwsArgumentError);
      p.setGoogleEmail(anna, 'Anna@Gmail.com');
      expect(p.googleEmail(anna), 'anna@gmail.com');
      p.setGoogleEmail(anna, null);
      expect(p.googleEmail(anna), isNull);
      p.close();
    });

    test('data survives reopening', () async {
      final first = Profiles.open(tmp);
      await first.create('Anna', '1234');
      first.close();
      final p = Profiles.open(tmp);
      expect(await p.unlock(p.list().single.id, '1234'), isA<PinOk>());
      p.close();
    });
  });
}
