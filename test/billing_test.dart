import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/main.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/billing/billing.dart';
import 'package:myfoodmind/data/diary.dart';
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/reminders.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/reminders_service.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/ui/home_screen.dart';

void main() {
  test('offer ids and tier order', () {
    expect(parseOfferId('pro_yearly'), (tier: Tier.pro, yearly: true));
    expect(parseOfferId('basic_monthly'), (tier: Tier.basic, yearly: false));
    expect(parseOfferId('gold_monthly'), isNull);
    expect(Tier.pro.includes(Tier.basic), isTrue);
    expect(Tier.basic.includes(Tier.medium), isFalse);
    expect(Tier.free.includes(Tier.free), isTrue);
  });

  test('a build without a store key never gets the dev switch', () async {
    final b = UnavailableBilling();
    expect(b.tier.value, Tier.free);
    expect(b.isDev, isFalse);
    expect(await b.offers(), isEmpty);
  });

  test('dev billing: six offers, trial only on Pro, tier survives a restart', () async {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_bill_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final profiles = Profiles.open(tmp);
    final billing = DevBilling(profiles.db);
    await billing.init();
    expect(billing.tier.value, Tier.free);
    final offers = await billing.offers();
    expect(offers.length, 6);
    expect(offers.where((o) => o.trial).map((o) => o.tier).toSet(), {Tier.pro});
    await billing.buy(offers.firstWhere((o) => o.id == 'medium_yearly'));
    expect(billing.tier.value, Tier.medium);
    final again = DevBilling(profiles.db);
    await again.init();
    expect(again.tier.value, Tier.medium);
    profiles.close();
  });

  group('screens', () {
    late Directory tmp;
    late ProfileData data;
    late Profiles profiles;

    late _FakeReminders reminders;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('myfoodmind_bill_ui_');
      reminders = _FakeReminders();
      final nutri = openNutriDb('test/nutri_test.db');
      final user = openUserDb('${tmp.path}/user.db');
      data = ProfileData(profile: (id: 1, name: 'Anna'), nutri: nutri, user: user, tools: AgentTools(nutri, user));
      profiles = Profiles.open(tmp);
      saveBody(user, (sex: Sex.male, birthYear: 1990, heightCm: 180, weightKg: 82,
          activity: Activity.moderate, goal: Goal.maintain, imperial: false), now: DateTime(2026, 9, 1));
      final now = DateTime.now();
      for (var d = 0; d < 9; d++) {
        if (d == 4) continue; // a gap: streak is 4 days
        final at = DateTime(now.year, now.month, now.day - d, 12);
        data.tools.logFood(data.tools.searchFood('lasagna').first, 350.0 + d * 40, 'lunch');
        user.execute('UPDATE meal_log SET eaten_at = ? WHERE id = (SELECT MAX(id) FROM meal_log)', [at.millisecondsSinceEpoch]);
        logWeight(user, 82 - d * 0.3, imperial: false, at: at.subtract(const Duration(hours: 4)));
      }
    });
    tearDown(() {
      data.nutri.close();
      data.user.close();
      profiles.close();
      tmp.deleteSync(recursive: true);
    });

    Widget app({double textScale = 1}) => ProviderScope(
          overrides: [
            profileDataProvider.overrideWithValue(data),
            profilesProvider.overrideWithValue(profiles),
            agentProvider.overrideWith((ref) => Completer<Agent>().future),
            billingProvider.overrideWith((ref) async => DevBilling(profiles.db)..init()),
            remindersProvider.overrideWithValue(reminders),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
            home: const HomeScreen(name: 'Anna'),
          ),
        );

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('free: Week shows calories, streak locked → plans → buy Basic → streak unlocks', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await settle(tester);
      await tester.tap(find.text('Week'));
      await settle(tester);
      expect(find.text('Calories per day'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('See plans'), 300);
      expect(find.text('More with Basic'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget, reason: 'the weight trend is free');
      expect(find.textContaining('-day logging streak'), findsNothing);
      await tester.ensureVisible(find.text('See plans'));
      await settle(tester);
      await tester.tap(find.text('See plans'));
      await settle(tester);

      expect(find.text('Developer mode: no real payment. Pick any plan to try it.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('7 days free, then €69.99 / year'), 300);
      expect(find.text('7 days free, then €69.99 / year'), findsOneWidget, reason: 'trial terms next to the price');
      await tester.scrollUntilVisible(find.text('Monthly'), -300);
      await tester.ensureVisible(find.text('Monthly'));
      await settle(tester);
      await tester.tap(find.text('Monthly'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('€3.99 / month'), -300);
      expect(find.text('€3.99 / month'), findsOneWidget);
      await tester.tap(find.text('Subscribe').first); // Basic monthly
      await settle(tester);

      await tester.scrollUntilVisible(find.textContaining('logging streak'), 300);
      expect(find.textContaining('logging streak'), findsOneWidget);
      expect(tester.widget<Text>(find.textContaining('logging streak')).data, '4-day logging streak');
      await tester.scrollUntilVisible(find.text('Weight'), 300);
      expect(find.text('Log your weight at least twice to see the trend.'), findsNothing);
    });

    testWidgets('Week and Month at 200 % text: no overflow', (tester) async {
      phone(tester);
      final billing = DevBilling(profiles.db)..setTier(Tier.basic);
      expect(billing.tier.value, Tier.basic);
      await tester.pumpWidget(app(textScale: 2));
      await settle(tester);
      for (final period in ['Week', 'Month']) {
        await tester.tap(find.text(period));
        await settle(tester);
        for (var i = 0; i < 8; i++) {
          expect(tester.takeException(), isNull, reason: '$period, scroll step $i');
          await tester.drag(find.byType(Scrollable).last, const Offset(0, -400), warnIfMissed: false);
          await tester.pump();
        }
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 4000), warnIfMissed: false);
        await settle(tester);
      }
    });

    testWidgets('Year is locked below Pro', (tester) async {
      phone(tester);
      DevBilling(profiles.db).setTier(Tier.medium);
      await tester.pumpWidget(app());
      await settle(tester);
      await tester.tap(find.text('Year'));
      await settle(tester);
      expect(find.text('The Year view is in Pro'), findsOneWidget);
    });

    testWidgets('Year (Pro) at 200 % text: every section, no overflow', (tester) async {
      phone(tester);
      DevBilling(profiles.db).setTier(Tier.pro);
      await tester.pumpWidget(app(textScale: 2));
      await settle(tester);
      await tester.tap(find.text('Year'));
      await settle(tester);
      expect(find.text('Calories per day, monthly average'), findsOneWidget);
      final seen = <String>{};
      for (var i = 0; i < 12; i++) {
        expect(tester.takeException(), isNull, reason: 'Year, scroll step $i');
        for (final t in ['Logging calendar', '8 days logged · best streak 4 days', 'Eaten most']) {
          if (find.text(t).evaluate().isNotEmpty) seen.add(t);
        }
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -400), warnIfMissed: false);
        await tester.pump();
      }
      expect(seen, {'Logging calendar', '8 days logged · best streak 4 days', 'Eaten most'});
    });

    testWidgets('History: meals per day within the Free window; recipes-only filter; plan is locked', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await settle(tester);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await settle(tester);
      await tester.tap(find.text('History'));
      await settle(tester);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('Last 90 days'), findsNothing, reason: 'Free reaches back 30 days');
      expect(find.textContaining('asagna'), findsWidgets);
      await tester.tap(find.text('Recipes only'));
      await settle(tester);
      expect(find.text('Nothing logged on these days.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('History shows the last 30 days'), 300);
      expect(find.text('History shows the last 30 days'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await settle(tester);
      await tester.tap(find.text('Meal plan'));
      await settle(tester);
      expect(find.text('The meal plan is in Basic'), findsOneWidget);
    });

    testWidgets('water reminders follow the water goal, rescheduled only on a change', (tester) async {
      phone(tester);
      DevBilling(profiles.db).setTier(Tier.basic);
      setPref(data.user, waterReminderPref, '1');
      await tester.pumpWidget(app());
      await settle(tester);
      expect(reminders.water.single, (1, 10), reason: '82 kg × 30 ml = 2.5 l = 10 glasses');

      setPref(data.user, 'water_goal_ml', '2000');
      data.changed();
      await settle(tester);
      data.changed(); // an unrelated write: nothing to reschedule
      await settle(tester);
      expect(reminders.water, [(1, 10), (1, 8)]);
      expect(profiles.setting(waterScheduledSetting), '1');
    });

    testWidgets('a downgrade cancels water reminders', (tester) async {
      phone(tester);
      final ids = await tester.runAsync(() async => [await profiles.create('Anna', '1234')]);
      profiles.setSetting(waterScheduledSetting, '1');
      setPref(data.user, waterReminderPref, '1');
      await tester.pumpWidget(app()); // Free
      await settle(tester);
      expect(reminders.water, [for (final id in ids!) (id, 0)]);
      expect(pref(data.user, waterReminderPref), '0');
      expect(profiles.setting(waterScheduledSetting), '0');
    });
  });
}

/// Records water schedules as (profile id, how many reminders).
class _FakeReminders extends RemindersService {
  final water = <(int, int)>[];

  @override
  Future<void> applyWater(int profileId, List<(int, int)> times, String body) async => water.add((profileId, times.length));
}
