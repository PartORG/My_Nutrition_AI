import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/data/diary.dart';
import 'package:myfoodmind/data/goals.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/ui/goals_screen.dart';
import 'package:myfoodmind/ui/home_screen.dart';
import 'package:myfoodmind/ui/me_screen.dart';

void main() {
  late Directory tmp;
  late ProfileData data;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('myfoodmind_m3_');
    final nutri = openNutriDb('test/nutri_test.db');
    final user = openUserDb('${tmp.path}/user.db');
    data = ProfileData(profile: (id: 1, name: 'Anna'), nutri: nutri, user: user, tools: AgentTools(nutri, user));
  });
  tearDown(() {
    data.nutri.close();
    data.user.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileDataProvider.overrideWithValue(data),
        profilesProvider.overrideWithValue(Profiles.open(tmp)), // Me reads the profile list
        agentProvider.overrideWith((ref) => Completer<Agent>().future), // model "still loading"
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pump();
  }

  /// To the end of the screen's list. ensureVisible stops short on long lazy lists: their
  /// extent is an estimate until the end is built.
  Future<void> toEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
  }

  testWidgets('goals form: imperial input is stored metric', (tester) async {
    await pumpApp(tester, const GoalsScreen(onboarding: true));
    expect(find.text('Later'), findsOneWidget);
    await tester.tap(find.text('Imperial'));
    await tester.pump();
    await tester.tap(find.text('Male'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Birth year'), '1996');
    await tester.enterText(find.widgetWithText(TextFormField, 'ft'), '5');
    await tester.enterText(find.widgetWithText(TextFormField, 'in'), '11');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight (lb)'), '176');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final b = loadBody(data.user)!;
    expect(b.heightCm, closeTo(180.34, .01)); // 71 in
    expect(b.weightKg, closeTo(79.83, .01)); // 176 lb
    expect((b.sex, b.imperial, b.activity, b.goal), (Sex.male, true, Activity.light, Goal.maintain));
  });

  testWidgets('goals form rejects impossible numbers', (tester) async {
    await pumpApp(tester, const GoalsScreen());
    await tester.enterText(find.widgetWithText(TextFormField, 'Birth year'), '1890');
    await tester.enterText(find.widgetWithText(TextFormField, 'Height (cm)'), '20');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a valid number'), findsNWidgets(3)); // year, height, empty weight
    expect(loadBody(data.user), isNull);
  });

  testWidgets('Today: nudge without goals; hero, bars, over-limit warning with goals; delete', (tester) async {
    await pumpApp(tester, const HomeScreen(name: 'Anna'));
    expect(find.text('Set your daily goals'), findsOneWidget);

    saveBody(data.user, (sex: Sex.male, birthYear: 1996, heightCm: 180, weightKg: 80,
        activity: Activity.moderate, goal: Goal.maintain, imperial: false), now: DateTime.now());
    final soy = data.tools.searchFood('soy sauce').firstWhere((f) => f.kind == 'food');
    data.tools.logFood(soy, 50, 'lunch'); // 2747 mg sodium: over the 2000 mg limit
    data.changed();
    await tester.pump();

    expect(find.text('27'), findsOneWidget, reason: 'hero: 26.5 kcal eaten, rounded');
    expect(find.text('of 2759 kcal'), findsOneWidget);
    expect(find.text('2733 kcal left'), findsOneWidget); // 2759 − 26.5 = 2732.5 → 2733
    expect(find.text('over by 747 mg'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget, reason: 'never colour alone');

    await toEnd(tester);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(mealsOn(data.user, DateTime.now()), isEmpty);
    expect(find.text('over by 747 mg'), findsNothing);
  });

  testWidgets('Today: day-one welcome; "Log it" opens the Log tab', (tester) async {
    await pumpApp(tester, const HomeScreen(name: 'Anna'));
    expect(find.text('Log your first meal'), findsOneWidget);
    await tester.tap(find.text('Log it'));
    await tester.pumpAndSettle();
    expect(find.text('Search foods, dishes, recipes…'), findsOneWidget);
  });

  testWidgets('Today: + adds a glass of water; fasting card only when turned on', (tester) async {
    await pumpApp(tester, const HomeScreen(name: 'Anna'));
    expect(find.text('Water 0 / 2000 ml'), findsOneWidget);
    await tester.tap(find.byTooltip('Add a glass (250 ml)'));
    await tester.pump();
    expect(find.text('Water 250 / 2000 ml'), findsOneWidget);
    expect(find.text('Fasting'), findsNothing);
    setPref(data.user, 'fasting', '1');
    data.changed();
    await tester.pump();
    await toEnd(tester);
    await tester.tap(find.text('Start now'));
    await tester.pump();
    expect(find.text('Fasting 0 h 0 min of 16 h'), findsOneWidget);
  });

  testWidgets('Meal plan: from Today, plan the week, shopping list from it', (tester) async {
    await pumpApp(tester, const HomeScreen(name: 'Anna'));
    await tester.scrollUntilVisible(find.text('Meal plan'), 200, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Meal plan')); // to the top, out from under the navigation bar
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meal plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan my week'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Another recipe'), findsWidgets);
    await toEnd(tester);
    await tester.tap(find.text('Shopping list'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsWidgets);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000)); // the shopping list's end
    await tester.pumpAndSettle();
    expect(find.text('Clear ticked'), findsOneWidget);
  });

  testWidgets('Today: a recipe meal opens the recipe; stars saved and shown', (tester) async {
    (data.tools.logRecipe(2).card! as ConfirmCard).apply(); // Shakshuka
    await pumpApp(tester, const HomeScreen(name: 'Anna'));
    await toEnd(tester);
    expect(find.text('Recipes you ate'), findsOneWidget);
    await tester.tap(find.text('Shakshuka').first);
    await tester.pumpAndSettle();
    expect(find.text('Your rating'), findsOneWidget);
    await tester.tap(find.byTooltip('Rate 4 stars'));
    await tester.pump();
    expect(data.tools.rating(2), 4);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('★★★★'), findsOneWidget);
  });

  testWidgets('Log tab: search → servings → Log → shows on Today', (tester) async {
    await pumpApp(tester, const HomeScreen(name: 'Anna'));
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pump();
    expect(find.text('Food · 105 kcal per serving'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'banana'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('+')); // 1.5 servings = 177 g
    await tester.pump();
    await tester.tap(find.text('Snack'));
    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();
    expect(find.text('Logged banana'), findsOneWidget);
    final m = mealsOn(data.user, DateTime.now()).single;
    expect((m.label, m.grams, m.type), ('banana', 177.0, 'snack'));

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Snack'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('158 kcal'), findsWidgets);
  });

  testWidgets('Me: About me shows the details; the daily goal is edited in Your daily goals', (tester) async {
    saveBody(data.user, (sex: Sex.female, birthYear: 1980, heightCm: 165, weightKg: 62,
        activity: Activity.light, goal: Goal.lose, imperial: false), now: DateTime.now());
    data.user.execute("INSERT INTO user_allergens (allergen, added_at) VALUES ('peanuts', 0)");
    await pumpApp(tester, const Scaffold(body: MeScreen()));
    for (final t in ['About me', 'Anna', 'Female', '1980', '165 cm', 'Weight: 62.0 kg', 'peanuts', 'Your daily goals']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.ensureVisible(find.text('Lose weight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lose weight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintain').last);
    await tester.pumpAndSettle();
    expect(loadBody(data.user)!.goal, Goal.maintain);
    expect(find.text('Maintain'), findsOneWidget);
  });
}
