import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      expect(find.text('banana'), findsOneWidget);
      expect(find.text('≈210 kcal'), findsOneWidget); // two bananas: 2 × 118 g × 89 kcal/100 g
      expect(find.text('broccoli'), findsOneWidget);
      // The user corrects the amount and removes broccoli before logging.
      await tester.enterText(find.widgetWithText(TextFormField, '236'), '200');
      await tester.tap(find.byTooltip('Delete').last);
      await tester.pump();
      await tester.tap(find.text('Lunch'));
      await tester.tap(find.textContaining('Log this meal'));
      await tester.pumpAndSettle();

      expect(meals().map((r) => (r['description'], r['grams'], r['estimated'])), [('banana', 200.0, 1)]);
      expect(data.user.select('SELECT meal_type FROM meal_log').single['meal_type'], 'lunch');
      expect(scans(), ['photo: banana']);
      expect(find.text('1 item logged'), findsOneWidget);
      // Episodic memory picks the scan up like a meal.
      expect(await Memory(data.user, vectors, fakeEmbed).backfill(), 2); // the meal + the scan
    });

    testWidgets('photo → What can I cook? shows recipes in the chat, logs nothing', (tester) async {
      final found = await FakeDetector().detect(Uint8List(0));
      capture = (_) => (found, true);
      await pumpChat(tester);
      await tester.tap(find.byTooltip('Open camera'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('What can I cook?'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('What can I cook?'));
      await tester.pumpAndSettle();

      final list = (agent.items.last as CardItem).card as RecipeListCard;
      expect(list.recipes.map((r) => r.title), contains('Chicken broccoli stir-fry'));
      expect(meals(), isEmpty);
      expect(scans(), ['live: banana, broccoli']);
    });

    testWidgets('barcode → product → log exact values', (tester) async {
      capture = (_) => '2000000000022';
      agent.items.add(CardItem(CameraCard('barcode')));
      await pumpChat(tester);
      await tester.tap(find.text('Scan barcode'));
      await tester.pumpAndSettle();
      expect(find.text('Dummy plain yogurt 2%'), findsOneWidget);
      expect(find.text('63 kcal'), findsOneWidget); // 100 g, no ≈: label values
      await tester.tap(find.textContaining('Log this meal'));
      await tester.pumpAndSettle();
      expect(meals().map((r) => (r['description'], r['grams'], r['estimated'])), [('Dummy plain yogurt 2%', 100.0, 0)]);
    });

    testWidgets('unknown barcode → find it by name, offline', (tester) async {
      capture = (_) => '4006381333931';
      agent.items.add(CardItem(CameraCard('barcode')));
      await pumpChat(tester);
      await tester.tap(find.text('Scan barcode'));
      await tester.pumpAndSettle();
      expect(find.text("Barcode 4006381333931 isn't in the food database."), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Log this meal')).onPressed, isNull);

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'apple');
      await tester.pump();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('apple')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Log this meal'));
      await tester.pumpAndSettle();
      expect(meals().map((r) => (r['description'], r['grams'])), [('apple', 180.0)]);
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
