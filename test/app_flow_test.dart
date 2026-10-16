import 'dart:io';

import 'package:material_ui/material_ui.dart';
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
    // No profile yet: first run, step 1 your name, step 2 the PIN.
    expect(find.text('Eat well, privately'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Continue'), 200);
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
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
    await tester.ensureVisible(find.text('Later'));
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Anna'), findsOneWidget);
    expect(find.text('Set your daily goals'), findsOneWidget, reason: 'Today nudges until goals are set');

    // Lock → straight to the PIN: one profile per phone → wrong PIN → right PIN.
    await tester.tap(find.byTooltip('Lock'));
    await tester.pumpAndSettle();
    await enter(tester, 'PIN for Anna', '0000');
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(find.text('Wrong PIN. 4 tries left before a pause.'), findsOneWidget);
    await enter(tester, 'PIN for Anna', '1234');
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(find.text('Hello, Anna'), findsOneWidget);

    // The drawer: menu button → tabs and deeper screens → a tab closes it.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Health'), findsOneWidget);
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(find.text('Health'), findsNothing);

    // Forgot PIN → confirm → profile and its files are gone, back to sign-up.
    await tester.tap(find.byTooltip('Lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot PIN?'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Anna?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Eat well, privately'), findsOneWidget, reason: 'back to the first run');
    expect(Directory('${tmp.path}/profiles/1').existsSync(), isFalse);

  });
}
