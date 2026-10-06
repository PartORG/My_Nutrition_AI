import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/main.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_ui_');
    File('test/nutri_test.db').copySync('${tmp.path}/nutri.db'); // Today tab opens it on unlock
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// PIN hashing runs on a real isolate; let real time pass until it's done.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(); // not pumpAndSettle: the spinner animates until done
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  testWidgets('create, lock, wrong PIN, unlock, forgot PIN deletes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [appDirProvider.overrideWith((ref) async => tmp)],
      child: const MyFoodMindApp(),
    ));
    await settle(tester);
    expect(find.text("Who's eating?"), findsOneWidget);

    // Create → straight into the new profile.
    await tester.tap(find.text('Add profile'));
    await tester.pumpAndSettle();
    await enter(tester, 'Name', 'Anna');
    await enter(tester, 'PIN (4–6 digits)', '1234');
    await enter(tester, 'Repeat PIN', '1235');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text("PINs don't match"), findsOneWidget);
    await enter(tester, 'Repeat PIN', '1234');
    await tester.tap(find.text('Create'));
    await settle(tester);
    // Skippable onboarding comes first.
    expect(find.text('Your daily goals'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Anna'), findsOneWidget);
    expect(find.text('Set your daily goals'), findsOneWidget, reason: 'Today nudges until goals are set');

    // Lock → picker → wrong PIN → right PIN.
    await tester.tap(find.byTooltip('Lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await enter(tester, 'PIN for Anna', '0000');
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(find.text('Wrong PIN. 4 tries left before a pause.'), findsOneWidget);
    await enter(tester, 'PIN for Anna', '1234');
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(find.text('Hello, Anna'), findsOneWidget);

    // Forgot PIN → confirm → profile and its files are gone.
    await tester.tap(find.byTooltip('Lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot PIN?'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Anna?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsNothing);
    expect(Directory('${tmp.path}/profiles/1').existsSync(), isFalse);

  });
}
