import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// nutri.db schema versions this app build can read (see db/nutri_schema.sql).
// 2: micronutrients. 3: foods.source, micronutrients on dishes and products, dishes linked to foods and
// recipes. An older file on the phone fails the check and the bundled one is reinstalled.
const nutriSchemaMin = 3;
const nutriSchemaMax = 3;

/// nutri.db content release (meta.data_version). Bump it with db/medical.sql's data_version when
/// the data changes but the schema doesn't, so phones replace their installed copy once.
// 1: medical data from the guidelines (db/medical.sql). 2: translated ingredient names (food_names).
// 3: vitamins and minerals for the generic foods (foodstruct, NZ FOODfiles, FDC Foundation/Branded).
const nutriDataVersion = 3;

/// Vectors in docs.embedding are only comparable with the app's own embedder.
const nutriEmbeddingModel = 'embeddinggemma-300m';

class NutriDbException implements Exception {
  NutriDbException(this.message);
  final String message;
  @override
  String toString() => 'NutriDbException: $message';
}

/// Opens nutri.db read-only, refusing a file this build can't read.
Database openNutriDb(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    _check(db);
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

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
