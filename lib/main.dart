import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app_state.dart';
import 'l10n/app_localizations.dart';
import 'ui/home_screen.dart';
import 'ui/profile_screens.dart';
import 'ui/theme.dart';

Future<void> main() async {
  // The doctor report embeds Noto Sans; OFL asks for its licence to ship along.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Noto Sans'], await rootBundle.loadString('assets/fonts/OFL.txt'));
    // Apache 2.0 (Gemma 4, EfficientDet) and the Gemma Terms notice EmbeddingGemma requires.
    yield LicenseEntryWithLineBreaks(
        ['Gemma 4 E2B', 'EmbeddingGemma', 'EfficientDet-Lite0'], await rootBundle.loadString('assets/licenses/models.txt'));
    yield const LicenseEntryWithLineBreaks(['Open Food Facts'],
        'Product data from Open Food Facts (https://world.openfoodfacts.org), available under the Open Database '
        'License (ODbL) v1.0: https://opendatacommons.org/licenses/odbl/1-0/. Individual contents under the '
        'Database Contents License.');
  });
  WidgetsFlutterBinding.ensureInitialized();
  await trackDownloads();
  runApp(const ProviderScope(child: MyFoodMindApp()));
}

class MyFoodMindApp extends ConsumerWidget {
  const MyFoodMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(appearanceProvider);
    // Null schemes below Android 12: the app's own green then.
    return DynamicColorBuilder(builder: (light, dark) => MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
        theme: AppTheme.build(Brightness.light, system: look.wallpaper ? light : null),
        darkTheme: AppTheme.build(Brightness.dark, system: look.wallpaper ? dark : null),
        themeMode: look.mode,
        // Dates and numbers (DateFormat, NumberFormat) in the app's language, not always English.
        builder: (context, child) {
          Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
          return child!;
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppGate(),
      ));
  }
}

/// Unsupported phone → loading → profile picker (locked) → home (unlocked).
/// Locks again after [autoLockAfter] in the background.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  static const autoLockAfter = Duration(minutes: 5);

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: () {
        final hiddenAt = _hiddenAt;
        _hiddenAt = null;
        if (hiddenAt != null && DateTime.now().difference(hiddenAt) >= AppGate.autoLockAfter) {
          ref.read(unlockedProvider.notifier).lock();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ram = Platform.isAndroid ? totalRamMb() : null;
    if (ram != null && ram < minRamMb) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(l.deviceUnsupportedTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l.deviceUnsupportedBody((ram / 1024).toStringAsFixed(1))),
          ]),
        ),
      );
    }
    return switch (ref.watch(appDirProvider)) {
      // Unlocking fades and grows the home screen in; locking fades it out.
      AsyncData() => AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Durations.medium4,
          switchInCurve: Easing.emphasizedDecelerate,
          switchOutCurve: Easing.emphasizedAccelerate,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(animation), child: child),
          ),
          child: switch (ref.watch(unlockedProvider)) {
            null => const ProfilesScreen(key: ValueKey('locked')),
            final profile => HomeScreen(key: ValueKey(profile.id), name: profile.name),
          },
        ),
      AsyncError(:final error) => Scaffold(body: Center(child: Text('$error'))),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
