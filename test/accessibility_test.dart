import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/main.dart';
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/ui/theme.dart';
import 'package:myfoodmind/agent/chat_limit.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/billing/billing.dart';
import 'package:myfoodmind/data/conditions.dart';
import 'package:myfoodmind/data/journal.dart';
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/vision/scan.dart';
import 'package:myfoodmind/ui/camera_screen.dart';
import 'package:myfoodmind/data/diary.dart' show logWeight, setPref, storeActiveKcal;
import 'package:myfoodmind/ui/chat_screen.dart';
import 'package:myfoodmind/ui/health_screen.dart';
import 'package:myfoodmind/ui/history_screen.dart';
import 'package:myfoodmind/ui/home_screen.dart';
import 'package:myfoodmind/ui/profile_screens.dart';
import 'package:myfoodmind/ui/settings_screen.dart';
import 'package:myfoodmind/ui/weight_screen.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_test.dart' show FakeModel;
import 'memory_test.dart' show fakeEmbed;

/// Large text (200 %) on a small phone (360 dp wide): no overflow anywhere,
/// and screen-reader labels that make sense.
void main() {
  late Directory tmp;
  late ProfileData data;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_a11y_');
    final nutri = openNutriDb('test/nutri_test.db');
    final user = openUserDb('${tmp.path}/user.db');
    data = ProfileData(profile: (id: 1, name: 'Anna'), nutri: nutri, user: user, tools: AgentTools(nutri, user));
    saveBody(user, (sex: Sex.female, birthYear: 1980, birthMonth: 3, heightCm: 165, weightKg: 62,
        activity: Activity.light, goal: Goal.lose, imperial: false), now: DateTime.now());
    for (final (q, g) in [('soy sauce', 60.0), ('lasagna', 350.0), ('banana', 118.0)]) {
      data.tools.logFood(data.tools.searchFood(q).first, g, 'lunch');
    }
  });
  tearDown(() {
    data.nutri.close();
    data.user.close();
    tmp.deleteSync(recursive: true);
  });

  Widget app(Widget home, {List overrides = const [], ThemeData? theme, Locale? locale}) => ProviderScope(
        overrides: [
          profileDataProvider.overrideWithValue(data),
          profilesProvider.overrideWithValue(Profiles.open(tmp)), // Me reads the profile list
          agentProvider.overrideWith((ref) => Completer<Agent>().future),
          ...overrides.cast(),
        ],
        child: MaterialApp(
          theme: theme,
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: home,
        ),
      );

  void smallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340); // 360 × 780 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Scrolls through every Scrollable, failing on the first layout error.
  Future<void> scrollAll(WidgetTester tester, String where) async {
    for (var i = 0; i < 10; i++) {
      expect(tester.takeException(), isNull, reason: '$where, scroll step $i');
      final lists = find.byType(Scrollable);
      if (lists.evaluate().isEmpty) return;
      await tester.drag(lists.first, const Offset(0, -400), warnIfMissed: false);
      await tester.pump();
    }
  }

  for (final lang in ['en', 'uk', 'de', 'fr']) {
    testWidgets('$lang: Plan tab opens the shopping list; Settings at 200 % text', (tester) async {
      smallPhone(tester);
      final settings = migrated(sqlite3.openInMemory(), profilesDbMigrations);
      addTearDown(settings.close);
      final billing = DevBilling(settings)..setTier(Tier.basic); // the shopping list is Basic
      await tester.pumpWidget(app(const HomeScreen(name: 'Anna'), locale: Locale(lang), overrides: [
        billingProvider.overrideWith((ref) async => billing),
      ]));
      await tester.pump();
      final l = lookupAppLocalizations(Locale(lang));
      await tester.tap(find.text(l.tabPlan));
      await tester.pumpAndSettle();
      await scrollAll(tester, 'Plan ($lang)');
      await tester.tap(find.text(l.shoppingList).first);
      await tester.pumpAndSettle();
      expect(find.text(l.shoppingEmpty), findsOneWidget, reason: 'the Shopping tab');
      await scrollAll(tester, 'Shopping ($lang)');

      await tester.pumpWidget(app(const SettingsScreen(), locale: Locale(lang), overrides: [
        billingProvider.overrideWith((ref) async => billing),
      ]));
      await tester.pumpAndSettle();
      expect(find.text(l.settingsDanger), findsNothing, reason: 'starts at the top');
      await scrollAll(tester, 'Settings ($lang)');
      await tester.scrollUntilVisible(find.text(l.deleteThisProfile), 400);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$lang: sign-up and PIN screen at 200 % text', (tester) async {
      smallPhone(tester);
      await tester.pumpWidget(app(const ProfilesScreen(), locale: Locale(lang)));
      await tester.pumpAndSettle();
      await scrollAll(tester, 'sign-up ($lang)');
      final profiles = Profiles.open(tmp);
      await tester.runAsync(() => profiles.create('Anna-Maria Kowalenko', '1234'));
      await tester.pumpWidget(app(ProfilesScreen(key: UniqueKey()), locale: Locale(lang))); // reads the same profiles.db
      await tester.pumpAndSettle();
      await scrollAll(tester, 'PIN ($lang)');
      expect(find.byType(FilledButton), findsOneWidget);
    });
  }

  testWidgets('home-screen widget: Log opens the Log tab, the mic the chat (which takes the tap)', (tester) async {
    await tester.pumpWidget(app(const HomeScreen(name: 'Anna')));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container.read(widgetTapProvider.notifier).set('log');
    await tester.pump();
    expect(container.read(homeTabProvider), HomeTab.log);
    expect(container.read(widgetTapProvider), isNull);

    container.read(widgetTapProvider.notifier).set('voice');
    await tester.pump();
    expect(container.read(homeTabProvider), HomeTab.chat);
    expect(container.read(widgetTapProvider)?.host, 'voice', reason: 'left for the chat, still loading here');
  });

  testWidgets('Today, Log and Me at 200 % text', (tester) async {
    smallPhone(tester);
    await tester.pumpWidget(app(const HomeScreen(name: 'Anna')));
    await tester.pump();
    await scrollAll(tester, 'Today');

    await tester.tap(find.byTooltip('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chicken');
    await tester.pump();
    await scrollAll(tester, 'Log');

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await scrollAll(tester, 'Me');
  });

  for (final lang in ['uk', 'de', 'fr']) {
    testWidgets('$lang: Today, Log and Me at 200 % text', (tester) async {
      smallPhone(tester);
      (data.tools.logRecipe(2).card! as ConfirmCard).apply();
      await tester.pumpWidget(app(const HomeScreen(name: 'Anna'), locale: Locale(lang)));
      await tester.pump();
      await scrollAll(tester, 'Today ($lang)');
      await tester.tap(find.byTooltip(lookupAppLocalizations(Locale(lang)).tabLog)); // the + in the bar
      await tester.pumpAndSettle();
      await scrollAll(tester, 'Log ($lang)');
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await scrollAll(tester, 'Me ($lang)');
    });
  }

  for (final lang in ['en', 'uk', 'de', 'fr']) {
    testWidgets('$lang: History (both tabs), Weight and Today with the burnt ring at 200 % text', (tester) async {
      smallPhone(tester);
      final l = lookupAppLocalizations(Locale(lang));
      (data.tools.logRecipe(2).card! as ConfirmCard).apply();
      final now = DateTime.now();
      for (final (i, kg) in [62.0, 61.6, 61.2].indexed) {
        logWeight(data.user, kg, imperial: false, at: now.subtract(Duration(days: 2 - i)));
      }
      setPref(data.user, 'health_sync', '1');
      storeActiveKcal(data.user, now, 240);
      await tester.pumpWidget(app(const HomeScreen(name: 'Anna'), locale: Locale(lang)));
      await tester.pump();
      expect(find.text(l.burntWord), findsOneWidget);
      await scrollAll(tester, 'Today with health ($lang)');

      await tester.pumpWidget(app(HistoryScreen(data: data), locale: Locale(lang)));
      await tester.pump();
      await scrollAll(tester, 'History meals ($lang)');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000)); // back up to the tabs
      await tester.pump();
      await tester.tap(find.text(l.historyRecipes));
      await tester.pump();
      expect(find.textContaining(l.cookedTimes(1)), findsWidgets); // lasagna (setUp) and recipe 2
      await scrollAll(tester, 'History recipes ($lang)');

      await tester.pumpWidget(app(WeightScreen(data: data), locale: Locale(lang)));
      await tester.pump();
      await scrollAll(tester, 'Weight ($lang)');
    });
  }

  testWidgets('dark theme: Today with meals, Log, Me', (tester) async {
    smallPhone(tester);
    (data.tools.logRecipe(2).card! as ConfirmCard).apply();
    data.tools.quickAdd('Restaurant pasta', {'kcal': 650}, 'dinner');
    await tester.pumpWidget(app(const HomeScreen(name: 'Anna'), theme: AppTheme.build(Brightness.dark)));
    await tester.pump();
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ?? Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor,
        AppPalette.night.background);
    await scrollAll(tester, 'Today (dark)');
    await tester.tap(find.byTooltip('Log'));
    await tester.pumpAndSettle();
    await scrollAll(tester, 'Log (dark)');
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await scrollAll(tester, 'Me (dark)');
  });

  testWidgets('Health, journal entry, timeline and report sheet at 200 % text (Medium)', (tester) async {
    smallPhone(tester);
    final settings = migrated(sqlite3.openInMemory(), profilesDbMigrations);
    addTearDown(settings.close);
    final billing = DevBilling(settings)..setTier(Tier.medium);
    final now = DateTime.now();
    for (final c in allConditions(data.nutri).take(2)) {
      setCondition(data.user, c, true, now: now);
    }
    logReading(data.user, 'glucose', 112, 'mg/dL', at: now.subtract(const Duration(days: 3)));
    logReading(data.user, 'glucose', 6.1, 'mmol/L', at: now.subtract(const Duration(days: 1)));
    logReading(data.user, 'blood_pressure', 131, 'mmHg', value2: 84, at: now.subtract(const Duration(days: 2)));
    logReading(data.user, 'blood_pressure', 125, 'mmHg', value2: 80, at: now.subtract(const Duration(hours: 2)));
    logSymptom(data.user, 'tingling in both feet after the evening walk', 3, at: now.subtract(const Duration(hours: 5)));
    await tester.pumpWidget(app(const HealthScreen(), overrides: [
      billingProvider.overrideWith((ref) async => billing),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Conditions'), findsOneWidget);
    await scrollAll(tester, 'Health');
    Future<void> tapText(String text, double delta) async {
      await tester.scrollUntilVisible(find.text(text), delta, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tapText('Symptom', -200);
    await tester.enterText(find.byType(TextField), 'Headache');
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'symptom dialog');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(symptomsBetween(data.user, now.subtract(const Duration(days: 1)), DateTime.now()).last,
        isA<Symptom>().having((s) => s.symptom, 'symptom', 'headache').having((s) => s.severity, 'severity', 4));

    await tapText('Create', 200); // on the "Report for your doctor" card
    expect(tester.takeException(), isNull, reason: 'report sheet');
    tester.state<NavigatorState>(find.byType(Navigator)).pop(); // close the sheet (it fills the screen at 200 %)
    await tester.pumpAndSettle();

    await tapText('Timeline', -200); // above the report card now
    // One unit per chart: the latest reading's.
    await tester.scrollUntilVisible(find.text('Blood glucose (mmol/L)'), 200, scrollable: find.byType(Scrollable).first);
    await scrollAll(tester, 'Timeline');
  });

  testWidgets('camera review at 200 % text', (tester) async {
    smallPhone(tester);
    final items = [
      ...itemsFromDetections(data.tools, [
        (label: 'banana', score: .9, box: Rect.zero),
        (label: 'hot dog', score: .8, box: Rect.zero), // not in the dummy db
      ]),
    ];
    await tester.pumpWidget(app(ReviewScreen(data: data, items: items, mode: 'photo', onCook: (_) {})));
    await tester.pump();
    await scrollAll(tester, 'Review');
  });

  testWidgets('Health shows the plans below Medium', (tester) async {
    smallPhone(tester);
    setCondition(data.user, allConditions(data.nutri).first, true, now: DateTime.now());
    await tester.pumpWidget(app(const HealthScreen())); // no store: Free
    await tester.pumpAndSettle();
    expect(find.text('Health tracking is part of Medium'), findsOneWidget);
    expect(find.textContaining('still filter recipes'), findsOneWidget);
    await scrollAll(tester, 'Health locked');
  });

  testWidgets('chat cards at 200 % text; bubbles read as whole sentences', (tester) async {
    smallPhone(tester);
    final vectors = openVectorsDb('${tmp.path}/vectors.db');
    final profiles = migrated(sqlite3.openInMemory(), profilesDbMigrations);
    addTearDown(() {
      vectors.close();
      profiles.close();
    });
    final agent = Agent(
      model: FakeModel([]),
      tools: data.tools,
      memory: Memory(data.user, vectors, fakeEmbed),
      user: data.user,
      limit: ChatLimit(profiles),
      unlimited: () => true,
    );
    final t = data.tools;
    agent.items.addAll([
      CardItem(t.run('search_recipes', {'query': 'dinner', 'ingredients': 'chicken'}).card!),
      CardItem(t.run('recipe', {'action': 'show', 'recipe': '1'}).card!),
      CardItem(t.run('nutrition_status', {'period': 'today'}).card!),
      CardItem(t.run('log_meal', {'items': '2 eggs, toast', 'meal_type': 'breakfast'}).card!),
      CrisisItem(),
      // Newest last = visible at the bottom without scrolling.
      UserItem('What can I cook?'),
      ModelItem('Here are some ideas.'),
    ]);
    final handle = tester.ensureSemantics(); // before building, so labels are created
    await tester.pumpWidget(app(Scaffold(body: ChatScreen(agent: agent))));
    await tester.pump();
    expect(find.bySemanticsLabel('You said: What can I cook?'), findsOneWidget);
    expect(find.bySemanticsLabel('My Nutrition AI said: Here are some ideas.'), findsOneWidget);
    expect(find.byTooltip('Speak'), findsOneWidget);
    handle.dispose();
    for (var i = 0; i < 14; i++) {
      expect(tester.takeException(), isNull, reason: 'chat, scroll step $i');
      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pump();
    }
  });
}
