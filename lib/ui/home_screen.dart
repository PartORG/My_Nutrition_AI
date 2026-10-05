import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import 'chat_screen.dart';
import 'log_screen.dart';
import 'me_screen.dart';
import 'theme.dart';
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
      AsyncError(error: LlmNotDownloaded()) => const _DownloadAi(),
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

/// First use: the chat model (2.5 GB) downloads once, only when the user asks.
/// Everything else in the app already works without it.
class _DownloadAi extends ConsumerStatefulWidget {
  const _DownloadAi();

  @override
  ConsumerState<_DownloadAi> createState() => _DownloadAiState();
}

class _DownloadAiState extends ConsumerState<_DownloadAi> {
  var _failed = false;

  Future<void> _start() async {
    setState(() => _failed = false);
    try {
      await ref.read(llmDownloadProvider.notifier).start();
    } on Object catch (e) {
      debugPrint('model download stopped: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = ref.watch(llmDownloadProvider);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.download_for_offline_outlined, size: 48, color: AppColors.primary),
      const SizedBox(height: 12),
      Text(l.aiDownloadTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(l.aiDownloadBody((llmDownloadMb / 1024).toStringAsFixed(1))),
      const SizedBox(height: 16),
      if (progress != null) ...[
        LinearProgressIndicator(value: progress / 100, semanticsLabel: l.aiDownloading),
        const SizedBox(height: 8),
        Text('${l.aiDownloading} $progress %', textAlign: TextAlign.center),
        TextButton(onPressed: () => ref.read(llmDownloadProvider.notifier).cancel(), child: Text(l.cancel)),
      ] else ...[
        if (_failed) Text(l.aiDownloadFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        ElevatedButton.icon(icon: const Icon(Icons.download), label: Text(l.aiDownloadButton), onPressed: _start),
      ],
    ]);
  }
}
