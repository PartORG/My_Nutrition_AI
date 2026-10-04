import 'package:sqlite3/sqlite3.dart';

/// Brings [db] up to `steps.length` using PRAGMA user_version.
///
/// Rules: steps are append-only, an old step is never edited, and each run
/// applies the missing steps in ONE transaction, so a failure leaves the
/// database exactly as it was.
void migrate(Database db, List<String> steps) {
  final from = db.userVersion;
  if (from > steps.length) {
    throw StateError('database is v$from, this app knows v${steps.length}');
  }
  if (from == steps.length) return;
  db.execute('BEGIN');
  try {
    for (var v = from; v < steps.length; v++) {
      db.execute(steps[v]);
    }
    db.userVersion = steps.length;
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
