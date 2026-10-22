import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// nutri.db schema versions this app build can read (see db/catalog/nutri.sql).
// 2: micronutrients. 3: foods.source, micronutrients on dishes and products, dishes linked to foods and
// recipes. 4: catalogue v4 (docs/PLAN.md "Catalogue v4"): new ids, the full nutrient panel, aliases, recipe lines and
// steps, health data in health.db. An older file on the phone fails the check and is downloaded again.
const nutriSchemaMin = 4;
const nutriSchemaMax = 4;

/// nutri.db content release (meta.data_version). Bump it when the data changes but the schema doesn't, so phones
/// replace their installed copy once.
// 1: medical data from the guidelines (db/medical.sql). 2: translated ingredient names (food_names).
// 3: vitamins and minerals for the generic foods (foodstruct, NZ FOODfiles, FDC Foundation/Branded). 4: CIQUAL (France)
// and CoFID (UK) foods and dishes. 5: catalogue v4 (tool/catalog). 6: chain menu items as foods (no products.db),
// plain milk's biotin from Staggs 2004. 7: toast aliases ("wholegrain toast" was gruel), a 25 g slice of toast.
const nutriDataVersion = 7;

/// Vectors in docs.embedding are only comparable with the app's own embedder.
const nutriEmbeddingModel = 'embeddinggemma-300m';

class NutriDbException implements Exception {
  NutriDbException(this.message);
  final String message;
  @override
  String toString() => 'NutriDbException: $message';
}

/// The health.db that belongs to [nutriPath]: the same folder, "nutri" → "health" in the name; null when the name
/// has no "nutri" (a candidate file being checked).
String? healthPath(String nutriPath) {
  final file = File(nutriPath);
  final name = file.uri.pathSegments.last;
  return name.contains('nutri') ? '${file.parent.path}/${name.replaceFirst('nutri', 'health')}' : null;
}

/// Opens nutri.db read-only, refusing a file this build can't read, with its health.db attached as `health`
/// (conditions, their rules and foods, reference intakes, passages) when it is there.
Database openNutriDb(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    _check(db);
    final health = healthPath(path);
    if (health != null && File(health).existsSync()) db.execute('ATTACH DATABASE ? AS health', [health]);
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

/// health.db is attached (tests and an install that hasn't copied it yet may lack it).
bool hasHealth(Database nutri) => nutri.select('PRAGMA database_list').any((r) => r['name'] == 'health');

/// Replaces [target] with [candidate] only if the candidate passes the checks.
/// The rename is atomic, so readers see the old file or the new one, never half.
void installNutriDb(File candidate, File target) {
  openNutriDb(candidate.path).close();
  candidate.renameSync(target.path);
}

void _check(Database db) {
  String? meta(String key) {
    try {
      return db.select('SELECT value FROM meta WHERE key = ?', [key])
          .firstOrNull?['value'] as String?;
    } on SqliteException {
      throw NutriDbException('not a nutri.db (no meta table)');
    }
  }

  final version = int.tryParse(meta('schema_version') ?? '');
  if (version == null || version < nutriSchemaMin || version > nutriSchemaMax) {
    throw NutriDbException(
        'schema_version $version, this app reads $nutriSchemaMin..$nutriSchemaMax');
  }
  final model = meta('embedding_model');
  if (model != nutriEmbeddingModel) {
    throw NutriDbException('embedding_model $model, expected $nutriEmbeddingModel');
  }
}
