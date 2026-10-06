import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
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
import 'package:myfoodmind/ui/chat_screen.dart';
import 'package:myfoodmind/ui/health_screen.dart';
import 'package:myfoodmind/ui/home_screen.dart';
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
    saveBody(user, (sex: Sex.female, birthYear: 1980, heightCm: 165, weightKg: 62,
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

  Widget app(Widget home, {List overrides = const []}) => ProviderScope(
        overrides: [
          profileDataProvider.overrideWithValue(data),
          profilesProvider.overrideWithValue(Profiles.open(tmp)), // Me reads the profile list
          agentProvider.overrideWith((ref) => Completer<Agent>().future),
          ...overrides.cast(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  testWidgets('Today, Log and Me at 200 % text', (tester) async {
    smallPhone(tester);
    await tester.pumpWidget(app(const HomeScreen(name: 'Anna')));
    await tester.pump();
    await scrollAll(tester, 'Today');

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chicken');
    await tester.pump();
    await scrollAll(tester, 'Log');

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await scrollAll(tester, 'Me');
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

    await tapText('Report for your doctor', 200);
    expect(tester.takeException(), isNull, reason: 'report sheet');
    tester.state<NavigatorState>(find.byType(Navigator)).pop(); // close the sheet (it fills the screen at 200 %)
    await tester.pumpAndSettle();

    await tapText('Timeline', 200);
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
    await tester.pumpWidget(app(ReviewScreen(data: data, items: items, mode: 'photo', unknownCode: '4006381333931',
        onCook: (_) {})));
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
      CardItem(t.run('show_recipe', {'recipe': '1'}).card!),
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
    expect(find.bySemanticsLabel('MyFoodMind said: Here are some ideas.'), findsOneWidget);
    expect(find.byTooltip('Speak'), findsOneWidget);
    handle.dispose();
    for (var i = 0; i < 14; i++) {
      expect(tester.takeException(), isNull, reason: 'chat, scroll step $i');
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();
    }
  });
}
