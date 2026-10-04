import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/agent/chat_limit.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/ui/memory_screen.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_test.dart' show FakeModel;
import 'memory_test.dart' show fakeEmbed;

void main() {
  testWidgets('view, edit and delete what the AI knows; forget conversations', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('myfoodmind_memscreen_');
    final nutri = openNutriDb('assets/nutri.db');
    final user = openUserDb('${tmp.path}/user.db');
    final vectors = openVectorsDb('${tmp.path}/vectors.db');
    final profiles = sqlite3.openInMemory()..execute(profilesDbMigrations.single);
    addTearDown(() {
      for (final db in [nutri, user, vectors, profiles]) {
        db.close();
      }
      tmp.deleteSync(recursive: true);
    });
    final model = FakeModel([]);
    final agent = Agent(
      model: model,
      tools: AgentTools(nutri, user),
      memory: Memory(user, vectors, fakeEmbed),
      user: user,
      limit: ChatLimit(profiles),
      unlimited: () => true,
    );
    user.execute("INSERT INTO memory_facts (text, created_at) VALUES ('has an air fryer', 0), ('hates olives', 1)");
    user.execute("INSERT INTO user_allergens VALUES ('peanuts', 0), ('milk', 0)");
    user.execute('INSERT INTO meal_log (eaten_at, description, kcal, protein_g, fat_g, carbs_g) '
        "VALUES (?, 'banana', 105, 1, 0, 27)", [DateTime.now().millisecondsSinceEpoch]);
    await tester.runAsync(() async {
      await agent.send('hello there');
      await agent.memory.backfill();
    });
    expect(model.opens.length, 1);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MemoryScreen(agent: agent),
    ));
    expect(find.text('has an air fryer'), findsOneWidget);
    expect(find.text('1 message stored.'), findsOneWidget);

    // Edit a fact.
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'has an air fryer'), matching: find.byTooltip('Edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'has an air fryer and a slow cooker');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('has an air fryer and a slow cooker'), findsOneWidget);

    // Delete a fact and an allergy.
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'hates olives'), matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    expect(find.text('hates olives'), findsNothing);
    await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'milk'), matching: find.byTooltip('Delete')));
    await tester.pumpAndSettle();
    expect(agent.memory.allergies(), ['peanuts']);

    // Forget conversations: chat gone, meals remembered, model conversation reset.
    await tester.scrollUntilVisible(find.text('Forget past conversations'), 200);
    await tester.tap(find.text('Forget past conversations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('No messages stored.'), findsOneWidget);
    expect(user.select('SELECT 1 FROM chat_messages'), isEmpty);
    expect([for (final r in vectors.select('SELECT kind FROM events')) r['kind']], ['meal']);
    expect(agent.items, isEmpty);
    await tester.runAsync(() => agent.send('hi again'));
    expect(model.opens.length, 2, reason: 'a new conversation without the forgotten one');
    expect(model.opens.last, isEmpty);
  });
}
