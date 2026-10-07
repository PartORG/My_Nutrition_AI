import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A repeated key in an .arb file silently replaces the earlier text (it once turned the
/// camera review title into "Your week"); a translation must have every English key.
void main() {
  final files = Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList();

  /// Top-level message keys, in file order (two-space indent; @-metadata and nested fields skipped).
  /// Not jsonDecode: it keeps only the last of two equal keys, which is the bug to catch.
  List<String> keysOf(File f) =>
      [for (final m in RegExp(r'^  "([^"@][^"]*)":', multiLine: true).allMatches(f.readAsStringSync())) m[1]!];

  for (final f in files) {
    test('${f.path}: no key twice', () {
      final keys = keysOf(f);
      final seen = <String>{};
      expect([for (final k in keys) if (!seen.add(k)) k], isEmpty);
    });
  }

  test('every translation has exactly the English keys', () {
    final en = keysOf(File('lib/l10n/app_en.arb')).toSet()..remove('@@locale');
    for (final f in files.where((f) => !f.path.endsWith('app_en.arb'))) {
      final keys = keysOf(f).toSet()..remove('@@locale');
      expect(en.difference(keys), isEmpty, reason: '${f.path} misses these');
      expect(keys.difference(en), isEmpty, reason: '${f.path} has extra keys');
    }
  });
}
