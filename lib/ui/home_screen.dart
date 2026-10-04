import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import 'chat_screen.dart';
import 'log_screen.dart';
import 'me_screen.dart';
import 'today_screen.dart';

/// The unlocked profile: Today · Chat · Log · Me.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Keep the profile's databases and the loaded AI alive across tab switches;
    // both are auto-dispose and close only when this screen goes (Lock).
    ref.watch(profileDataProvider);
    ref.watch(agentProvider);
    final body = switch (_tab) {
      0 => const TodayScreen(),
      1 => const _ChatTab(),
      2 => const LogScreen(),
      _ => const MeScreen(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l.hello(widget.name)),
        actions: [
          IconButton(
            tooltip: l.lock,
            icon: const Icon(Icons.lock),
            onPressed: () => ref.read(unlockedProvider.notifier).lock(),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: l.tabToday),
          NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), selectedIcon: const Icon(Icons.chat_bubble), label: l.tabChat),
          NavigationDestination(icon: const Icon(Icons.add_circle_outline), selectedIcon: const Icon(Icons.add_circle), label: l.tabLog),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.tabMe),
        ],
      ),
    );
  }
}

class _ChatTab extends ConsumerWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return switch (ref.watch(agentProvider)) {
      AsyncData(:final value) => ChatScreen(agent: value),
      AsyncError(error: ModelsMissing(:final dir, :final missing)) =>
        Padding(padding: const EdgeInsets.all(24), child: Text(l.modelsMissing(dir, missing.join(', ')))),
      AsyncError(:final error) => Center(child: Text('$error')),
      _ => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.preparingAi, textAlign: TextAlign.center),
            ]),
          ),
        ),
    };
  }
}
