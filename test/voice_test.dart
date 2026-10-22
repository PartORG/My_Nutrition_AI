import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/app_state.dart';
import 'package:myfoodmind/data/goals.dart' show Sex;
import 'package:material_ui/material_ui.dart';
import 'package:myfoodmind/ui/avatar.dart';
import 'package:myfoodmind/ui/theme.dart';
import 'package:myfoodmind/ui/voice.dart';

Map<String, String> voice(String name, String locale, {bool network = false, String features = ''}) =>
    {'name': name, 'locale': locale, 'network_required': network ? '1' : '0', 'features': features};

void main() {
  group('pickVoice', () {
    final google = [
      voice('en-gb-x-gbb-local', 'en-GB'),
      voice('en-us-x-iom-network', 'en-US', network: true),
      voice('en-us-x-iom-local', 'en-US'),
      voice('en-us-x-sfg-local', 'en-US'),
      voice('en-us-x-tpd-local', 'en-US', features: 'notInstalled'),
      voice('de-de-x-deb-local', 'de-DE'),
      voice('uk-ua-x-hfd-local', 'uk-UA'),
    ];

    test('a woman and a man of the main region, offline and installed only', () {
      expect(pickVoice(google, language: 'en', male: false), (name: 'en-us-x-sfg-local', locale: 'en-US', pitch: 1.0));
      expect(pickVoice(google, language: 'en', male: true), (name: 'en-us-x-iom-local', locale: 'en-US', pitch: 1.0));
    });

    test('one voice for the language: the man is the same voice, pitched down', () {
      expect(pickVoice(google, language: 'uk', male: false), (name: 'uk-ua-x-hfd-local', locale: 'uk-UA', pitch: 1.0));
      expect(pickVoice(google, language: 'uk', male: true), (name: 'uk-ua-x-hfd-local', locale: 'uk-UA', pitch: .75));
    });

    test('no offline voice for the language: none (the engine default is used)', () {
      expect(pickVoice(google, language: 'fr', male: false), isNull);
      expect(pickVoice([voice('fr-fr-x-frd-network', 'fr-FR', network: true)], language: 'fr', male: true), isNull);
    });
  });

  test('silence gate: ends after speech and a 2 s pause, or after 8 s of nothing', () {
    final gate = SilenceGate();
    expect(gate.quiet(-60, const Duration(seconds: 1)), isFalse, reason: 'not spoken yet');
    expect(gate.quiet(-20, const Duration(seconds: 2)), isFalse, reason: 'speaking');
    expect(gate.quiet(-55, const Duration(milliseconds: 3500)), isFalse, reason: 'a short pause');
    expect(gate.quiet(-55, const Duration(seconds: 4)), isTrue);
    expect(SilenceGate().quiet(-60, const Duration(seconds: 8)), isTrue, reason: 'never said a word');
  });

  test('transcript: the words only', () {
    expect(cleanTranscript('  "Two eggs and a coffee."  '), 'Two eggs and a coffee.');
    expect(cleanTranscript('Transcription: два яйця<end_of_turn>'), 'два яйця');
    expect(cleanTranscript('«Zwei Eier»'), 'Zwei Eier');
    expect(cleanTranscript(''), '');
  });

  group('avatar', () {
    late Directory tmp;
    late ProviderContainer container;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('nutrition_avatar_');
      container = ProviderContainer(overrides: [appDirProvider.overrideWith((ref) async => tmp)]);
      await container.read(appDirProvider.future);
      await container.read(profilesProvider).create('Sam', '1234');
    });
    tearDown(() {
      container.dispose();
      tmp.deleteSync(recursive: true);
    });

    test('follows the sex in the goals until the user picks one', () {
      final avatar = container.read(avatarProvider.notifier);
      expect(container.read(avatarProvider).kind, AvatarKind.neutral);
      avatar.suggestFor(Sex.male);
      expect(container.read(avatarProvider).kind, AvatarKind.man);
      avatar.set(kind: AvatarKind.neutral, color: 0xFF1565C0); // they/them, picked
      avatar.suggestFor(Sex.female);
      expect(container.read(avatarProvider), (kind: AvatarKind.neutral, color: 0xFF1565C0, photo: null,
          shape: AvatarShape.circle, style: AvatarStyle.solid, ring: AvatarRing.none));
    });

    test('shape, background and outline are kept; one changes, the rest stay', () {
      final avatar = container.read(avatarProvider.notifier);
      avatar.set(kind: AvatarKind.pets, shape: AvatarShape.flower, style: AvatarStyle.gradient, ring: AvatarRing.thick);
      avatar.set(style: AvatarStyle.soft);
      final a = container.read(avatarProvider);
      expect((a.kind, a.shape, a.style, a.ring), (AvatarKind.pets, AvatarShape.flower, AvatarStyle.soft, AvatarRing.thick));
    });

    testWidgets('every icon, shape, background and outline draws, also around a photo', (tester) async {
      final photo = File('${tmp.path}/p.png')..writeAsBytesSync([0]); // not an image: drawn without it
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Wrap(children: [
          for (final k in AvatarKind.values)
            for (final s in AvatarShape.values)
              for (final st in AvatarStyle.values)
                for (final r in AvatarRing.values)
                  UserAvatar(radius: 10, avatar: (kind: k, color: 0xFF1565C0, photo: k == AvatarKind.sun ? photo : null,
                      shape: s, style: st, ring: r), frame: r == AvatarRing.thin ? Colors.white : null),
        ]),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(UserAvatar), findsNWidgets(AvatarKind.values.length * 4 * 3 * 3));
    });

    test('a photo replaces the old one on disk; removing it and deleting the profile leave nothing', () {
      final avatar = container.read(avatarProvider.notifier);
      avatar.setPhoto(Uint8List.fromList([1, 2, 3]));
      final first = container.read(avatarProvider).photo!;
      expect(first.readAsBytesSync(), [1, 2, 3]);
      avatar.setPhoto(Uint8List.fromList([4]));
      final second = container.read(avatarProvider).photo!;
      expect(second.path, isNot(first.path), reason: 'a new name, so no cached old image');
      expect(first.existsSync(), isFalse);
      avatar.setPhoto(null);
      expect(container.read(avatarProvider).photo, isNull);
      expect(second.existsSync(), isFalse);

      avatar.set(kind: AvatarKind.woman);
      final profiles = container.read(profilesProvider);
      profiles.delete(profiles.owner!.id);
      expect(profiles.setting('avatar_kind'), isNull, reason: 'the next profile picks its own');
    });
  });
}
