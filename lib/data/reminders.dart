import 'package:sqlite3/sqlite3.dart';

const reminderSlots = ['breakfast', 'lunch', 'dinner', 'evening'];

typedef Reminder = ({String slot, bool enabled, int hour, int minute});

/// Used until the user has habits (or picks a time).
const _defaults = {'breakfast': (8, 30), 'lunch': (13, 0), 'dinner': (19, 0), 'evening': (21, 0)};

/// A meal reminder lands 30 min after the user's usual time for that meal
/// (from the last 30 days, needs 3+ logs), so it nudges when they forget.
(int, int)? _usualTime(Database user, String slot, DateTime now) {
  final r = user.select(
      "SELECT AVG(CAST(strftime('%H', eaten_at / 1000, 'unixepoch', 'localtime') AS INT) * 60 "
      "+ CAST(strftime('%M', eaten_at / 1000, 'unixepoch', 'localtime') AS INT)) AS m, COUNT(*) AS n "
      'FROM meal_log WHERE meal_type = ? AND eaten_at >= ?',
      [slot, now.subtract(const Duration(days: 30)).millisecondsSinceEpoch]).single;
  if ((r['n'] as int) < 3) return null;
  final m = ((r['m'] as num).round() + 30) % (24 * 60);
  return (m ~/ 60, m % 60);
}

List<Reminder> loadReminders(Database user, {required DateTime now}) {
  final saved = {for (final r in user.select('SELECT * FROM reminders')) r['slot'] as String: r};
  return [
    for (final slot in reminderSlots)
      if (saved[slot] case final r?)
        (slot: slot, enabled: r['enabled'] == 1, hour: r['hour'] as int, minute: r['minute'] as int)
      else
        () {
          final (h, m) = (slot == 'evening' ? null : _usualTime(user, slot, now)) ?? _defaults[slot]!;
          return (slot: slot, enabled: false, hour: h, minute: m);
        }()
  ];
}

void saveReminder(Database user, Reminder r) => user.execute(
    'INSERT OR REPLACE INTO reminders (slot, enabled, hour, minute) VALUES (?, ?, ?, ?)',
    [r.slot, r.enabled ? 1 : 0, r.hour, r.minute]);

/// Notification id: unique per profile and slot, so one profile's reminders
/// can be replaced without touching another's.
int reminderId(int profileId, String slot) => profileId * 10 + reminderSlots.indexOf(slot);
