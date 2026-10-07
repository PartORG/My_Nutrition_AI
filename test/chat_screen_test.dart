import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/agent/chat_limit.dart';
import 'package:myfoodmind/agent/chat_model.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/ui/chat_screen.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_test.dart' show FakeModel;
import 'memory_test.dart' show fakeEmbed;

void main() {
  testWidgets('send → confirm card with database numbers → Save writes', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_chat_');
    final nutri = openNutriDb('test/nutri_test.db');
    final user = openUserDb('${tmp.path}/user.db');
    final vectors = openVectorsDb('${tmp.path}/vectors.db');
    final profiles = migrated(sqlite3.openInMemory(), profilesDbMigrations);
    addTearDown(() {
      for (final db in [nutri, user, vectors, profiles]) {
        db.close();
      }
      tmp.deleteSync(recursive: true);
    });
    final model = FakeModel([
      [ToolCall('log_meal', {'items': '2 eggs', 'meal_type': 'breakfast'})],
      [TextChunk('Please confirm your breakfast.')],
    ]);
    final agent = Agent(
      model: model,
      tools: AgentTools(nutri, user),
      memory: Memory(user, vectors, fakeEmbed),
      user: user,
      limit: ChatLimit(profiles),
      unlimited: () => false,
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ChatScreen(agent: agent)),
    ));
    await tester.enterText(find.byType(TextField), 'Breakfast was 2 eggs');
    await tester.tap(find.byTooltip('Send'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(find.text('Breakfast was 2 eggs'), findsOneWidget);
    expect(find.text('Log breakfast'), findsOneWidget);
    // Editable before Save: the amount is a field, kcal follows it.
    expect(find.text('egg'), findsOneWidget);
    expect(find.text('143 kcal'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '100'), '150');
    await tester.pump();
    expect(find.text('215 kcal'), findsOneWidget);
    expect(find.text('Please confirm your breakfast.'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsNothing, reason: 'no flag icon on messages');
    await tester.longPress(find.text('Please confirm your breakfast.'));
    await tester.pumpAndSettle();
    expect(find.text('Report this response'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();
    expect(user.select('SELECT 1 FROM meal_log'), isEmpty);

    await tester.tap(find.text('Save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('✓ Saved'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(user.select('SELECT description, grams FROM meal_log').single.values, ['egg', 150.0]);

    // Crisis text gets the helpline card, not the model.
    await tester.enterText(find.byType(TextField), "I don't want to live anymore");
    await tester.tap(find.byTooltip('Send'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text("You don't have to go through this alone"), findsOneWidget);
    expect(model.sent.length, 1);
  });

  testWidgets('every card type renders without layout errors', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_cards_');
    final nutri = openNutriDb('test/nutri_test.db');
    final user = openUserDb('${tmp.path}/user.db');
    final vectors = openVectorsDb('${tmp.path}/vectors.db');
    final profiles = migrated(sqlite3.openInMemory(), profilesDbMigrations);
    addTearDown(() {
      for (final db in [nutri, user, vectors, profiles]) {
        db.close();
      }
      tmp.deleteSync(recursive: true);
    });
    final tools = AgentTools(nutri, user);
    final agent = Agent(
      model: FakeModel([]),
      tools: tools,
      memory: Memory(user, vectors, fakeEmbed),
      user: user,
      limit: ChatLimit(profiles),
      unlimited: () => true,
    );
    AgentCard card(String tool, Map<String, dynamic> args) => tools.run(tool, args).card!;
    agent.items.addAll([
      CardItem(card('search_recipes', {'query': 'dinner', 'ingredients': 'chicken, rice'})),
      CardItem(card('show_recipe', {'recipe': '1'})),
      CardItem(card('lookup_nutrition', {'food': 'avocado'})),
      CardItem(card('nutrition_status', {'period': 'today'})),
      CardItem(card('condition_info', {'question': 'diabetes sugar'})),
      CardItem(card('open_camera', {'mode': 'photo'})),
      CardItem(card('log_meal', {'items': 'lasagna', 'meal_type': 'lunch'})),
      CrisisItem(),
      LimitItem(15),
      ErrorItem(),
    ]);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ChatScreen(agent: agent)),
    ));
    // The list builds lazily: scroll through so every card is laid out, and
    // check each step (off-screen cards are disposed again).
    const titles = ['Recipe ideas', 'INGREDIENTS', 'avocado / 100 g', 'Today', 'Health information',
        'Camera', 'Log lunch', "You don't have to go through this alone"];
    final seen = <String>{};
    for (var i = 0; i < 16; i++) {
      expect(tester.takeException(), isNull, reason: 'after scroll step $i');
      seen.addAll(titles.where((t) => find.text(t).evaluate().isNotEmpty));
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();
    }
    expect(seen, containsAll(titles));

    // "I ate this" on the recipe card → a log card appears at the bottom.
    // (Pressed directly: tapping inside the reversed, lazily built list is flaky in tests.)
    await tester.dragUntilVisible(find.text('I ate this'), find.byType(ListView), const Offset(0, 300));
    tester.widget<ButtonStyleButton>(
        find.ancestor(of: find.text('I ate this'), matching: find.bySubtype<ButtonStyleButton>())).onPressed!();
    await tester.pumpAndSettle();
    expect(agent.items.last, isA<CardItem>());
    expect(((agent.items.last as CardItem).card as ConfirmCard).lines.single,
        startsWith('Chicken broccoli stir-fry · '));
  });
}
