import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/main.dart';
import 'package:myfoodmind/agent/agent.dart';
import 'package:myfoodmind/agent/agent_tools.dart';
import 'package:myfoodmind/agent/chat_limit.dart';
import 'package:myfoodmind/agent/memory.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/billing/billing.dart';
import 'package:myfoodmind/data/migrate.dart';
import 'package:myfoodmind/data/nutri_db.dart';
import 'package:myfoodmind/data/profiles.dart';
import 'package:myfoodmind/data/user_db.dart';
import 'package:myfoodmind/l10n/app_localizations.dart';
import 'package:myfoodmind/ui/camera_screen.dart';
import 'package:myfoodmind/ui/chat_screen.dart';
import 'package:myfoodmind/vision/detector.dart';
import 'package:myfoodmind/vision/scan.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'agent_test.dart' show FakeModel;
import 'memory_test.dart' show fakeEmbed;

/// The M6 gate's dummy detector: what EfficientDet would say about a fruit bowl.
class FakeDetector implements Detector {
  @override
  Future<List<Detection>> detect(Uint8List rgb) async => decodeDetections(
        [[.1, .1, .4, .4], [.5, .5, .9, .9], [.2, .6, .5, .9], [0, 0, 1, 1]],
        [51, 51, 55, 0], // banana, banana, broccoli, person
        [.9, .8, .7, .95],
        4,
      );
  @override
  void close() {}
}

void main() {
  group('detector pre/post-processing', () {
    test('only food classes above the threshold, best first, boxes as LTRB', () {
      final d = decodeDetections(
        [[.1, .2, .3, .4], [0, 0, 1, 1], [.5, .5, .6, .6], [.2, .2, .8, .8]],
        [55, 0, 58, 51],
        [.6, .99, .3, .8],
        4,
      );
      expect(d.map((e) => e.label), ['banana', 'broccoli']); // person: not food; pizza: below 0.4
      expect(d.last.box, const Rect.fromLTRB(.2, .1, .4, .3));
    });

    test('YUV frame is rotated upright: the sensor\'s top-left lands top-right at 90°', () {
      // 4×2 sensor, grey (no chroma), only the top-left pixel white.
      final y = Uint8List(8)..[0] = 255;
      final uv = Uint8List(4)..fillRange(0, 4, 128);
      Uint8List rgb(int rotation) => yuvToRgb(
          width: 4, height: 2, y: y, u: uv, v: uv, yRowStride: 4, uvRowStride: 2, uvPixelStride: 1, rotation: rotation);
      int at(Uint8List img, int x, int yy) => img[(yy * inputSize + x) * 3];
      expect(rgb(90).length, inputSize * inputSize * 3);
      expect(at(rgb(90), inputSize - 1, 0), 255);
      expect(at(rgb(90), 0, 0), 0);
      expect(at(rgb(0), 0, 0), 255);
      expect(at(rgb(270), 0, inputSize - 1), 255);
      // Photo mode keeps the frame's own upright size: 2×4 at 90°.
      expect(yuvToRgb(width: 4, height: 2, y: y, u: uv, v: uv, yRowStride: 4, uvRowStride: 2, uvPixelStride: 1,
              rotation: 90, outW: 2, outH: 4)
          .length, 2 * 4 * 3);
    });

    test("Gemma's photo reply → foods with portions; junk amounts become a serving", () {
      expect(parseSeenFoods('150 | Boiled rice\n- 120 g | grilled chicken breast\n\n* broccoli\n0 | apple\n99999 | bread'), [
        (name: 'boiled rice', grams: 150.0, cooking: null),
        (name: 'grilled chicken breast', grams: 120.0, cooking: null),
        (name: 'broccoli', grams: null, cooking: null),
        (name: 'apple', grams: null, cooking: null),
        (name: 'bread', grams: null, cooking: null),
      ]);
      expect(parseSeenFoods('none'), isEmpty);
      expect(parseSeenFoods('80,5 | banana'), [(name: 'banana', grams: 80.5, cooking: null)]);
      // The current prompt adds how it was cooked.
      expect(parseSeenFoods('120 | Chicken breast | Fried\n150 | rice | unknown'), [
        (name: 'chicken breast', grams: 120.0, cooking: 'fried'),
        (name: 'rice', grams: 150.0, cooking: null),
      ]);
    });

    test('two looks: the same food named two ways; sure when both saw it; the closer look adds what the whole missed', () {
      expect(sameFood('boiled rice', 'rice'), isTrue);
      expect(sameFood('white rice', 'rice'), isTrue);
      expect(sameFood('grilled chicken breast', 'chicken breast'), isTrue);
      expect(sameFood('tomatoes', 'tomato'), isTrue);
      expect(sameFood('chicken breast', 'turkey breast'), isFalse);
      SeenFood f(String name, [double? g]) => (name: name, grams: g, cooking: null);
      final merged = mergeLooks([f('boiled rice', 150), f('chicken breast', 120)], [f('rice', 80), f('sesame seeds', 5)]);
      expect([for (final m in merged) (m.food.name, m.food.grams, m.sure)], [
        ('boiled rice', 150.0, true),
        ('chicken breast', 120.0, false),
        ('sesame seeds', null, false), // a zoomed picture misleads portions: a serving
      ]);
      expect(mergeLooks([f('apple')], null).single.sure, isTrue, reason: 'one look only: as before');
    });

    test('closer look: around the foods found, or the middle when none or they fill the frame', () {
      const middle = Rect.fromLTRB(.2, .2, .8, .8);
      expect(closerLook([]), middle);
      expect(closerLook([const Rect.fromLTRB(0, 0, 1, 1)]), middle);
      final box = closerLook([const Rect.fromLTRB(.3, .3, .5, .5), const Rect.fromLTRB(.4, .4, .6, .6)]);
      expect(box.left, closeTo(.25, 1e-9));
      expect(box.bottom, closeTo(.65, 1e-9));
    });

    test('second question: Gemma picks a row by letter; none keeps the guess, marked to check', () {
      FoodChoice row(String label, double serving) =>
          (kind: 'food', id: label, label: label, servingG: serving, per100: const {'kcal': 100.0}, estimated: true);
      ScanMatch match(String name, List<FoodChoice> options, {double? grams}) => (
            item: ScanItem(name: name, food: options.first, grams: grams ?? options.first.servingG!),
            options: options,
            corrected: false,
            servingGrams: grams == null,
          );
      final items = [
        match('rice', [row('Rice, white', 150), row('Rice, brown', 160)], grams: 180),
        match('soup', [row('Soup, tomato', 250), row('Soup, lentil', 240)]),
        match('apple', [row('Apple', 180)]), // one row: nothing to ask
        match('stew', [row('Stew, beef', 250), row('Stew, lamb', 250)]),
      ];
      final q = pickQuestion(items)!;
      expect(q.options.keys, [1, 2, 3]);
      expect(q.text, contains('1. rice\n   a) Rice, white\n   b) Rice, brown'));
      expect(q.text, isNot(contains('apple')));
      expect(parsePicks('1 b\n2. b)\n3: none\nthanks'), {1: 1, 2: 1, 3: -1});
      applyPicks(items, q.options, parsePicks('1 b\n2. b)\n3: none'));
      expect((items[0].item.food!.label, items[0].item.grams), ('Rice, brown', 180.0), reason: "Gemma's grams stay");
      expect((items[1].item.food!.label, items[1].item.grams), ('Soup, lentil', 240.0), reason: 'a serving follows the row');
      expect((items[3].item.food!.label, items[3].item.sure), ('Stew, beef', false));
      expect(pickQuestion([items[2]]), isNull);
    });
  });

  group('full flow with the dummy detector and products', () {
    late Directory tmp;
    late ProfileData data;
    late Database vectors, settings;
    late Agent agent;
    late DevBilling billing;
    Object? Function(String mode) capture = (_) => null;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('myfoodmind_vision_');
      final nutri = openNutriDb('test/nutri_test.db');
      final user = openUserDb('${tmp.path}/user.db');
      data = ProfileData(profile: (id: 1, name: 'Anna'), nutri: nutri, user: user, tools: AgentTools(nutri, user));
      vectors = openVectorsDb('${tmp.path}/vectors.db');
      settings = migrated(sqlite3.openInMemory(), profilesDbMigrations);
      billing = DevBilling(settings)..setTier(Tier.pro);
      agent = Agent(
        model: FakeModel([]),
        tools: data.tools,
        memory: Memory(user, vectors, fakeEmbed),
        user: user,
        limit: ChatLimit(settings),
        unlimited: () => true,
      )..items.add(CardItem(CameraCard('photo')));
    });
    tearDown(() {
      for (final db in [data.nutri, data.user, vectors, settings]) {
        db.close();
      }
      tmp.deleteSync(recursive: true);
    });

    Future<void> pumpChat(WidgetTester tester) => tester.pumpWidget(ProviderScope(
          overrides: [
            profileDataProvider.overrideWithValue(data),
            billingProvider.overrideWith((ref) async => billing),
            captureProvider.overrideWithValue((context, mode) async => capture(mode)),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ChatScreen(agent: agent)),
          ),
        ));
    List<Map<String, Object?>> meals() => data.user.select('SELECT description, grams, estimated FROM meal_log ORDER BY id').toList();
    List<String> scans() => [for (final r in data.user.select('SELECT mode, text FROM scans')) '${r['mode']}: ${r['text']}'];

    testWidgets('photo → review → Log this meal', (tester) async {
      final found = await FakeDetector().detect(Uint8List(0));
      capture = (_) => (found, false);
      await pumpChat(tester);
      await tester.tap(find.text('Open camera').last);
      await tester.pumpAndSettle();

      expect(find.text('Check what was found'), findsOneWidget);
      expect(find.text('banana'), findsNWidgets(2)); // the band above and its row
      expect(find.text('broccoli'), findsNWidgets(2));
      // The user corrects the amount and removes broccoli before logging.
      await tester.enterText(find.widgetWithText(TextField, '236'), '200');
      await tester.tap(find.byTooltip('Remove').last);
      await tester.pump();
      expect(find.text('≈ 178 kcal'), findsOneWidget); // the total: 200 g × 89 kcal/100 g
      await tester.tap(find.text('Lunch'));
      await tester.pump();
      await tester.tap(find.text('Log this lunch'));
      await tester.pumpAndSettle();

      expect(meals().map((r) => (r['description'], r['grams'], r['estimated'])), [('banana', 200.0, 1)]);
      expect(data.user.select('SELECT meal_type FROM meal_log').single['meal_type'], 'lunch');
      expect(scans(), ['photo: banana']);
      expect(find.text('1 item logged'), findsOneWidget);
      // Episodic memory picks the scan up like a meal.
      expect(await Memory(data.user, vectors, fakeEmbed).backfill(), 2); // the meal + the scan
      // Undo on the snackbar takes the logged meal back out.
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(meals(), isEmpty);
    });

    testWidgets('Gemma photo → review with its portions; an unknown food waits for a match', (tester) async {
      capture = (_) => parseSeenFoods('150 | banana\n90 | broccoli\n200 | unicorn stew');
      await pumpChat(tester);
      await tester.tap(find.text('Open camera').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '150'), findsOneWidget); // Gemma's grams, not a serving
      expect(find.widgetWithText(TextField, '90'), findsOneWidget);
      expect(find.textContaining('unicorn stew'), findsNWidgets(2)); // not in nutri.db: shown, not loggable
      await tester.tap(find.textContaining('Log this'));
      await tester.pumpAndSettle();
      expect(meals().map((r) => (r['description'], r['grams'])), [('banana', 150.0), ('broccoli', 90.0)]);
      expect(scans(), ['photo: banana, broccoli']);
    });

    test('the foods this user logs come first among the matches', () {
      final brown = data.tools.searchFood('brown rice').firstWhere((f) => f.label == 'brown rice, cooked');
      data.tools.logFood(brown, 150, 'lunch');
      expect(matchOptions(data.tools, 'rice cooked').first.label, 'brown rice, cooked');
    });

    testWidgets('fried food offers oil; a changed food is remembered for that name next time', (tester) async {
      capture = (_) => parseSeenFoods('150 | banana | fried\n200 | unicorn stew | stewed');
      await pumpChat(tester);
      await tester.tap(find.text('Open camera').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cooked with oil or butter?'));
      await tester.pump();
      expect(find.widgetWithText(TextField, '14'), findsOneWidget, reason: 'a tablespoon, as its own editable row');
      await tester.tap(find.text('Change')); // the unicorn stew: not in nutri.db
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'lentils');
      await tester.pump();
      await tester.tap(find.text('lentils, cooked').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Log this'));
      await tester.pumpAndSettle();
      expect(meals().map((r) => r['description']), containsAll(['banana', 'olive oil', 'lentils, cooked']));
      // The next photo of a "unicorn stew" starts from what the user chose; the oil wasn't a correction.
      final next = itemsFromSeen(data.tools, parseSeenFoods('200 | unicorn stew'));
      expect(next.single.food?.label, 'lentils, cooked');
      expect(data.user.select('SELECT seen FROM food_corrections').map((r) => r['seen']), ['unicorn stew']);
    });

    testWidgets('review rows keep their own grams after a remove and follow a changed food', (tester) async {
      capture = (_) => parseSeenFoods('150 | banana\n90 | broccoli\n200 | unicorn stew');
      await pumpChat(tester);
      await tester.tap(find.text('Open camera').last);
      await tester.pumpAndSettle();
      // Unmatched first: it needs the user before it can be logged.
      expect(tester.getTopLeft(find.textContaining('unicorn stew').last).dy,
          lessThan(tester.getTopLeft(find.widgetWithText(TextField, '150')).dy));
      await tester.enterText(find.widgetWithText(TextField, '90'), '95');
      await tester.tap(find.byTooltip('Remove').at(1)); // banana's row
      await tester.pump();
      expect(find.widgetWithText(TextField, '95'), findsOneWidget, reason: 'broccoli keeps what was typed');
      expect(find.widgetWithText(TextField, '150'), findsNothing);
      // The unknown food gets a match: its row shows the new food and its serving, and what was seen.
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'banana');
      await tester.pump();
      await tester.tap(find.text('banana').last);
      await tester.pumpAndSettle();
      expect(find.text('seen: unicorn stew'), findsOneWidget);
      // What the fields show is what gets logged.
      final shown = {for (final f in tester.widgetList<TextField>(find.byType(TextField))) f.controller!.text};
      await tester.tap(find.textContaining('Log this'));
      await tester.pumpAndSettle();
      expect({for (final r in meals()) '${(r['grams'] as num).round()}'}, shown);
      expect(meals().map((r) => r['description']), containsAll(['banana', 'broccoli']));
    });

    testWidgets('photo → What can I cook? shows recipes in the chat, logs nothing', (tester) async {
      final found = await FakeDetector().detect(Uint8List(0));
      capture = (_) => (found, true);
      await pumpChat(tester);
      await tester.tap(find.text('Open camera').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('What can I cook?'));
      await tester.pumpAndSettle();

      final list = (agent.items.last as CardItem).card as RecipeListCard;
      expect(list.recipes.map((r) => r.title), contains('Chicken broccoli stir-fry'));
      expect(meals(), isEmpty);
      expect(scans(), ['live: banana, broccoli']);
    });

    testWidgets('below Pro the camera opens the plans instead', (tester) async {
      billing.setTier(Tier.medium);
      capture = (_) => fail('the camera must not open below Pro');
      await pumpChat(tester);
      await tester.tap(find.text('Open camera').last);
      await tester.pumpAndSettle();
      expect(find.text('Check what was found'), findsNothing);
      expect(find.text('Plans'), findsOneWidget); // the paywall
    });
  });
}
