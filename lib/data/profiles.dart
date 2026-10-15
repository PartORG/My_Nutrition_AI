import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'migrate.dart';
import 'pin.dart';
import 'user_db.dart';

/// profiles.db — shared, holds no personal data beyond names and PIN hashes.
const profilesDbMigrations = <String>[
  // v1
  '''
  CREATE TABLE profiles (
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    pin_hash        BLOB NOT NULL,
    pin_salt        BLOB NOT NULL,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until    INTEGER NOT NULL DEFAULT 0,
    created_at      INTEGER NOT NULL
  );
  CREATE TABLE chat_usage (
    day   TEXT PRIMARY KEY,   -- local date yyyy-mm-dd; per phone, not per profile
    count INTEGER NOT NULL
  );
  ''',
  // v2 (M3): fingerprint unlock, allowed only while there is one profile.
  'ALTER TABLE profiles ADD COLUMN biometric INTEGER NOT NULL DEFAULT 0;',
  // v3 (M4): per-phone settings (the developer tier switch lives here).
  'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);',
  // v4: one profile per phone; optionally linked to a Google account.
  'ALTER TABLE profiles ADD COLUMN google_email TEXT;',
];

/// Wrong PINs allowed before lockout starts.
const freePinAttempts = 5;

sealed class PinResult {}

class PinOk extends PinResult {}

class PinWrong extends PinResult {
  PinWrong(this.attemptsLeft);
  final int attemptsLeft; // before lockout starts
}

class PinLocked extends PinResult {
  PinLocked(this.until);
  final DateTime until;
}

typedef ProfileInfo = ({int id, String name});

class Profiles {
  Profiles._(this._db, this._root);

  /// [dir] is the app's private data directory.
  factory Profiles.open(Directory dir) {
    final db = sqlite3.open('${dir.path}/profiles.db');
    migrate(db, profilesDbMigrations);
    return Profiles._(db, Directory('${dir.path}/profiles'));
  }

  final Database _db;
  final Directory _root;

  /// For the per-phone chat counter (chat_usage).
  Database get db => _db;

  List<ProfileInfo> list() => [
        for (final r in _db.select('SELECT id, name FROM profiles ORDER BY id'))
          (id: r['id'] as int, name: r['name'] as String),
      ];

  String userDbPath(int id) => '${_root.path}/$id/user.db';

  /// The phone's one profile; null before sign-up.
  ProfileInfo? get owner => list().firstOrNull;

  /// Phones from before v0.7 may hold several profiles: keeps the oldest and
  /// deletes the rest with all their files. Returns the deleted ids.
  List<int> keepOnlyFirst() => [for (final p in list().skip(1)) p.id]..forEach(delete);

  /// Creates the profile row, its folder and its migrated user.db.
  /// [googleEmail] links a Google account that can unlock it instead of the PIN.
  Future<int> create(String name, String pin, {String? googleEmail}) async {
    name = name.trim();
    if (name.isEmpty) throw ArgumentError('name is empty');
    if (!isValidPin(pin)) throw ArgumentError('PIN must be 4-6 digits');
    if (owner != null) throw StateError('this phone already has a profile');
    final salt = newSalt();
    final hash = await _hash(pin, salt);
    _db.execute(
      'INSERT INTO profiles (name, pin_hash, pin_salt, created_at, google_email) VALUES (?, ?, ?, ?, ?)',
      [name, hash, salt, DateTime.now().millisecondsSinceEpoch, googleEmail?.toLowerCase()],
    );
    final id = _db.lastInsertRowId;
    Directory('${_root.path}/$id').createSync(recursive: true);
    openUserDb(userDbPath(id)).close();
    return id;
  }

  /// Checks [pin]. After [freePinAttempts] wrong tries each further wrong try
  /// locks the profile for 30 s, doubling, capped at 1 h. While locked the PIN
  /// is not even checked, so guessing can't continue in the background.
  Future<PinResult> unlock(int id, String pin, {DateTime? now}) async {
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final r = _db.select(
        'SELECT pin_hash, pin_salt, failed_attempts, locked_until FROM profiles WHERE id = ?',
        [id]).single;
    final lockedUntil = r['locked_until'] as int;
    if (t < lockedUntil) {
      return PinLocked(DateTime.fromMillisecondsSinceEpoch(lockedUntil));
    }
    if (sameBytes(await _hash(pin, r['pin_salt'] as Uint8List), r['pin_hash'] as Uint8List)) {
      _db.execute('UPDATE profiles SET failed_attempts = 0, locked_until = 0 WHERE id = ?', [id]);
      return PinOk();
    }
    final failed = (r['failed_attempts'] as int) + 1;
    final over = failed - freePinAttempts;
    final until = over < 0 ? 0 : t + min<int>(30000 << min(over, 7), 3600000);
    _db.execute('UPDATE profiles SET failed_attempts = ?, locked_until = ? WHERE id = ?',
        [failed, until, id]);
    return until > 0
        ? PinLocked(DateTime.fromMillisecondsSinceEpoch(until))
        : PinWrong(freePinAttempts - failed);
  }

  /// Per-phone settings (theme, …); null = never set.
  String? setting(String key) =>
      _db.select('SELECT value FROM settings WHERE key = ?', [key]).firstOrNull?['value'] as String?;

  void setSetting(String key, String value) =>
      _db.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', [key, value]);

  bool biometricEnabled(int id) =>
      _db.select('SELECT biometric FROM profiles WHERE id = ?', [id]).single['biometric'] == 1;

  void setBiometric(int id, bool on) =>
      _db.execute('UPDATE profiles SET biometric = ? WHERE id = ?', [on ? 1 : 0, id]);

  /// The linked Google account (lower case); null = PIN and fingerprint only.
  String? googleEmail(int id) =>
      _db.select('SELECT google_email FROM profiles WHERE id = ?', [id]).single['google_email'] as String?;

  /// A fingerprint or the linked Google account also clears PIN failures, like a correct PIN.
  void unlockedOtherwise(int id) =>
      _db.execute('UPDATE profiles SET failed_attempts = 0, locked_until = 0 WHERE id = ?', [id]);

  /// Episodic memory index; lives outside profiles/ so backup skips it.
  String vectorsDbPath(int id) => '${_root.parent.path}/vectors/$id.db';

  /// "Forgot PIN" path: removes the profile and every file it owns,
  /// including its vectors (they quote the user's messages).
  void delete(int id) {
    _db.execute('DELETE FROM profiles WHERE id = ?', [id]);
    final dir = Directory('${_root.path}/$id');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final vectors = File(vectorsDbPath(id));
    if (vectors.existsSync()) vectors.deleteSync();
  }

  void close() => _db.close();

  /// ~0.25 s on a PC, more on a phone: keep it off the UI thread.
  static Future<Uint8List> _hash(String pin, Uint8List salt) =>
      Isolate.run(() => hashPin(pin, salt));
}
