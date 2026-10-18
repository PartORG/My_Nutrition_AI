import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'data/reminders.dart';

/// Daily local notifications. Inexact on purpose: ±15 min is fine for a meal
/// nudge and needs no exact-alarm permission. The plugin re-arms them after a
/// reboot (receivers in AndroidManifest.xml).
class RemindersService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  /// Android 13+ asks the user; asked only when they turn a reminder on.
  Future<bool> requestPermission() async {
    await _init();
    return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
  }

  /// Replaces this profile's reminders with [reminders]. [text] gives the body
  /// per slot; it must not contain health details (shared phone, lock screen).
  Future<void> apply(int profileId, List<Reminder> reminders, String Function(String slot) text) async {
    await _init();
    for (final r in reminders) {
      final id = reminderId(profileId, r.slot);
      await _plugin.cancel(id: id);
      if (r.enabled) await _daily(id, r.hour, r.minute, text(r.slot));
    }
  }

  /// Replaces this profile's water reminders with one a day at each of [times] (empty = off).
  Future<void> applyWater(int profileId, List<(int, int)> times, String body) async {
    await _init();
    for (var i = 0; i < maxWaterReminders; i++) {
      await _plugin.cancel(id: waterReminderId(profileId, i));
    }
    for (final (i, (h, m)) in times.indexed) {
      await _daily(waterReminderId(profileId, i), h, m, body);
    }
  }

  Future<void> _daily(int id, int hour, int minute, String body) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      title: 'My Nutrition AI',
      body: body,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          channelDescription: 'Meal logging, water and evening check-in reminders',
          visibility: NotificationVisibility.private, // lock screen: "contents hidden"
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // every day at this time
    );
  }

  /// "Forgot PIN → delete profile" also removes its reminders.
  Future<void> cancelProfile(int profileId) async {
    await _init();
    for (final slot in reminderSlots) {
      await _plugin.cancel(id: reminderId(profileId, slot));
    }
    await applyWater(profileId, const [], '');
  }
}
