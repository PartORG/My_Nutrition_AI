import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'l10n/app_localizations.dart';
import 'ui/home_screen.dart';
import 'ui/profile_screens.dart';
import 'ui/theme.dart';

void main() => runApp(const ProviderScope(child: MyFoodMindApp()));

class MyFoodMindApp extends StatelessWidget {
  const MyFoodMindApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppGate(),
      );
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
      AsyncData() => switch (ref.watch(unlockedProvider)) {
          null => const ProfilesScreen(),
          final profile => HomeScreen(name: profile.name),
        },
      AsyncError(:final error) => Scaffold(body: Center(child: Text('$error'))),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
