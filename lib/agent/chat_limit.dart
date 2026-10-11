import 'package:sqlite3/sqlite3.dart';

/// Free tier: [dailyFree] user messages per day, counted per PHONE (in the
/// shared profiles.db) so a new profile doesn't reset it.
// ponytail: clearing app data resets the count (and wipes all data); accepted in the plan.
class ChatLimit {
  ChatLimit(this.db, {this.dailyFree = 30, DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final Database db;
  final int dailyFree;
  final DateTime Function() _now;

  String get _day {
    final n = _now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  int get usedToday =>
      db.select('SELECT count FROM chat_usage WHERE day = ?', [_day]).firstOrNull?['count'] as int? ?? 0;

  /// Counts one message if allowed. Paid tiers pass [unlimited] and still get counted.
  bool tryConsume({required bool unlimited}) {
    if (!unlimited && usedToday >= dailyFree) return false;
    db.execute(
        'INSERT INTO chat_usage (day, count) VALUES (?, 1) ON CONFLICT (day) DO UPDATE SET count = count + 1',
        [_day]);
    return true;
  }
}
