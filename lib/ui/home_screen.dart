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

/// Standard / Larger model, as a tile: [trailing] is the button for it.
Widget _modelTile(AppLocalizations l, Llm m, Widget trailing) {
  final gb = (m.downloadMb / 1024).toStringAsFixed(1);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(m == e4b ? l.aiModelLarge(gb) : l.aiModelStandard(gb), style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(m == e4b ? l.aiModelLargeHint : l.aiModelStandardHint),
    trailing: trailing,
  );
}

Widget _progress(AppLocalizations l, WidgetRef ref, int progress) => Column(children: [
      LinearProgressIndicator(value: progress / 100, semanticsLabel: l.aiDownloading),
      const SizedBox(height: 8),
      Text('${l.aiDownloading} $progress %', textAlign: TextAlign.center),
      TextButton(onPressed: () => ref.read(llmDownloadProvider.notifier).cancel(), child: Text(l.cancel)),
    ]);

/// Me tab, 8 GB phones only: which chat model is in use, and switching to the other.
class AiModelCard extends ConsumerStatefulWidget {
  const AiModelCard({super.key});

  @override
  ConsumerState<AiModelCard> createState() => _AiModelCardState();
}

class _AiModelCardState extends ConsumerState<AiModelCard> {
  var _failed = false;

  Future<void> _switch(Llm m) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.aiModelSwitch),
        content: Text(l.aiModelSwitchBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.aiDownloadButton)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _failed = false);
    try {
      await ref.read(llmDownloadProvider.notifier).start(m);
    } on Object catch (e) {
      debugPrint('model switch stopped: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = ref.watch(llmDownloadProvider);
    ref.watch(llmProvider); // re-check what's installed after a switch
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: FutureBuilder(
          future: installedLlm(),
          builder: (context, snap) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.aiModelTitle, style: Theme.of(context).textTheme.titleMedium),
            for (final m in llmChoices())
              _modelTile(
                l,
                m,
                snap.data == m
                    ? Text(l.aiModelInUse, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))
                    : OutlinedButton(onPressed: progress == null ? () => _switch(m) : null, child: Text(l.aiModelSwitch)),
              ),
            if (progress != null) _progress(l, ref, progress),
            if (_failed) Text(l.aiDownloadFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
    );
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

  Future<void> _start(Llm model) async {
    setState(() => _failed = false);
    try {
      await ref.read(llmDownloadProvider.notifier).start(model);
    } on Object catch (e) {
      debugPrint('model download stopped: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = ref.watch(llmDownloadProvider);
    final choices = llmChoices();
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.download_for_offline_outlined, size: 48, color: AppColors.primary),
      const SizedBox(height: 12),
      Text(l.aiDownloadTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(l.aiDownloadBody([for (final m in choices) (m.downloadMb / 1024).toStringAsFixed(1)].join('–'))),
      const SizedBox(height: 16),
      if (progress != null)
        _progress(l, ref, progress)
      else ...[
        if (_failed) Text(l.aiDownloadFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        // 8 GB phones choose; the others get the one model that fits.
        if (choices.length > 1)
          for (final m in choices)
            _modelTile(l, m, ElevatedButton(onPressed: () => _start(m), child: Text(l.aiDownloadButton)))
        else
          ElevatedButton.icon(
              icon: const Icon(Icons.download), label: Text(l.aiDownloadButton), onPressed: () => _start(e2b)),
      ],
    ]);
  }
}
