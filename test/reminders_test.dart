import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/reminders.dart';
import 'package:myfoodmind/data/user_db.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('myfoodmind_rem_'));
  tearDown(() => tmp.deleteSync(recursive: true));
  final now = DateTime(2026, 10, 4, 12);

  test('off by default, at default times until there are habits', () {
    final user = openUserDb('${tmp.path}/user.db');
    expect([for (final r in loadReminders(user, now: now)) (r.slot, r.enabled, r.hour, r.minute)], [
      ('breakfast', false, 8, 30), ('lunch', false, 13, 0), ('dinner', false, 19, 0), ('evening', false, 21, 0),
    ]);
    user.close();
  });

  test('meal reminder = usual time + 30 min after 3+ logs; evening stays fixed', () {
    final user = openUserDb('${tmp.path}/user.db');
    for (final d in [1, 2, 3]) {
      user.execute('INSERT INTO meal_log (eaten_at, meal_type, description, kcal, protein_g, fat_g, carbs_g) '
          "VALUES (?, 'lunch', 'x', 1, 1, 1, 1)", [DateTime(2026, 10, d, 12, 10 * d).millisecondsSinceEpoch]);
    }
    final lunch = loadReminders(user, now: now).firstWhere((r) => r.slot == 'lunch');
    expect((lunch.hour, lunch.minute), (12, 50)); // avg 12:20 + 30 min
    expect(loadReminders(user, now: now).firstWhere((r) => r.slot == 'breakfast').hour, 8, reason: 'no habit yet');
    user.close();
  });

  test('a saved choice wins over the suggestion', () {
    final user = openUserDb('${tmp.path}/user.db');
    saveReminder(user, (slot: 'evening', enabled: true, hour: 22, minute: 15));
    final evening = loadReminders(user, now: now).last;
    expect((evening.enabled, evening.hour, evening.minute), (true, 22, 15));
    user.close();
  });

  test('ids never collide across profiles and slots', () {
    final ids = {for (final p in [1, 2, 3]) for (final s in reminderSlots) reminderId(p, s)};
    expect(ids.length, 12);
  });
}
