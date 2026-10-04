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
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/ui/chat_screen.dart';
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
    final nutri = openNutriDb('assets/nutri.db');
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
