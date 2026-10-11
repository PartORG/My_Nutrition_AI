import 'package:sqlite3/sqlite3.dart';

import 'diary.dart' show glassMl;

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

/// Water (Basic): one glass per reminder, spread evenly 9:00–21:00 so the day's goal is
/// reached by evening. EFSA puts adequate water at about 2–2.5 l a day; drinking little and
/// often through the waking day is the usual advice, rather than a lot at once.
List<(int, int)> waterTimes(double goalMl) {
  final n = (goalMl / glassMl).round().clamp(2, maxWaterReminders);
  const from = 9 * 60, to = 21 * 60;
  final minutes = [for (var i = 0; i < n; i++) from + (to - from) * i ~/ (n - 1)];
  return [for (final m in minutes) (m ~/ 60, m % 60)];
}

const maxWaterReminders = 12;

/// prefs keys: '1' = water reminders on; the times last scheduled, e.g. '(9, 0),(10, 42)'.
const waterReminderPref = 'water_reminder', waterTimesPref = 'water_times';

/// profiles.db setting: '1' = some profile on this phone has water reminders scheduled.
const waterScheduledSetting = 'water_scheduled';

/// Out of the meal reminders' range (profileId * 10 + slot).
int waterReminderId(int profileId, int i) => 1000000 + profileId * maxWaterReminders + i;
