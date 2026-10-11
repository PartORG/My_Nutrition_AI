import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' show TaskStatus;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart' show pref, setPref, waterGoal;
import '../data/reminders.dart' show waterReminderPref, waterScheduledSetting, waterTimes, waterTimesPref;
import '../l10n/app_localizations.dart';
import 'chat_screen.dart';
import 'health_screen.dart';
import 'history_screen.dart';
import 'log_screen.dart';
import 'me_screen.dart';
import 'memory_screen.dart';
import 'paywall_screen.dart';
import 'plan_screen.dart';
import 'settings_screen.dart' show LanguageMenu, SettingsScreen;
import 'theme.dart';
import 'today_screen.dart';

/// The selected tab: Today's buttons open Chat or Log.
final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class HomeTab extends Notifier<int> {
  static const today = 0, chat = 1, log = 2, me = 3;

  @override
  int build() => today;

  void go(int tab) => state = tab;
}

/// The unlocked profile: Today · Chat · Log · Me.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.name});
  final String name;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<Uri?>? _widgetTaps;
  Billing? _billing;
  ProfileData? _data;

  @override
  void initState() {
    super.initState();
    ref.read(billingProvider.future).then((b) {
      if (!mounted) return;
      _billing = b..tier.addListener(_tierChanged);
      _data = ref.read(profileDataProvider)?..changes.addListener(_syncWater);
      _tierChanged();
    }, onError: (_) {});
    // The widget's Log button opens the app on the Log tab (after the PIN).
    if (Platform.isAndroid) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_fromWidget, onError: (_) {});
      _widgetTaps = HomeWidget.widgetClicked.listen(_fromWidget, onError: (_) {});
    }
  }

  void _fromWidget(Uri? uri) {
    if (uri?.host == 'log' && mounted) ref.read(homeTabProvider.notifier).go(HomeTab.log);
  }

  /// Water reminders are Basic: without it they go off on every profile of the phone,
  /// cancelled by id so the other profiles' databases stay closed.
  void _tierChanged() {
    final data = _data;
    if (data == null || !mounted) return;
    final profiles = ref.read(profilesProvider);
    if (!_billing!.tier.value.includes(Tier.basic)) {
      if (profiles.setting(waterScheduledSetting) == '1') {
        final service = ref.read(remindersProvider);
        for (final p in profiles.list()) {
          service.applyWater(p.id, const [], '');
        }
        profiles.setSetting(waterScheduledSetting, '0');
      }
      setPref(data.user, waterReminderPref, '0');
      setPref(data.user, waterTimesPref, '');
    }
    _syncWater();
  }

  /// Reschedules when the times change: switched on or off in Settings, or a new water goal
  /// (own goal, or a new weight). Every write lands here, so it only acts on a real change.
  void _syncWater() {
    final data = _data;
    if (data == null || !mounted || !_billing!.tier.value.includes(Tier.basic)) return;
    final times = pref(data.user, waterReminderPref) == '1' ? waterTimes(waterGoal(data.user)) : const <(int, int)>[];
    final key = times.join(',');
    if ((pref(data.user, waterTimesPref) ?? '') == key) return; // never scheduled = ''
    setPref(data.user, waterTimesPref, key);
    if (times.isNotEmpty) ref.read(profilesProvider).setSetting(waterScheduledSetting, '1');
    ref.read(remindersProvider).applyWater(data.profile.id, times, AppLocalizations.of(context)!.notifWater(data.profile.name));
  }

  @override
  void dispose() {
    _billing?.tier.removeListener(_tierChanged);
    _data?.changes.removeListener(_syncWater);
    _widgetTaps?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Keep the profile's databases and the loaded AI alive across tab switches;
    // both are auto-dispose and close only when this screen goes (Lock).
    ref.watch(profileDataProvider);
    ref.watch(agentProvider);
    final tab = ref.watch(homeTabProvider);
    final body = switch (tab) {
      0 => const TodayScreen(),
      1 => const _ChatTab(),
      2 => const LogScreen(),
      _ => const MeScreen(),
    };
    return Scaffold(
      drawer: _Drawer(name: widget.name),
      appBar: AppBar(
        title: Text(l.hello(widget.name)),
        actions: [
          const LanguageMenu(),
          IconButton(
            tooltip: l.lock,
            icon: const Icon(Icons.lock),
            onPressed: () => ref.read(unlockedProvider.notifier).lock(),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: ref.read(homeTabProvider.notifier).go,
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

/// The main tabs again, then everything that isn't a tab: history, the plan and shopping
/// list, health, what the AI knows, settings. Each of those opens its own screen on top.
// A Drawer of ListTiles, not NavigationDrawer: its fixed 56 dp rows can't wrap at 200 % text.
class _Drawer extends ConsumerWidget {
  const _Drawer({required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final data = ref.watch(profileDataProvider);
    final agent = ref.watch(agentProvider);
    void open(Widget Function() screen) {
      Navigator.of(context).pop(); // the drawer
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen()))
          .then((_) => data?.changed()); // e.g. a new plan shows on Today
    }

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
        );
    Widget item(IconData icon, String label, VoidCallback? onTap) =>
        ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
    Widget tab(IconData icon, String label, int tab) => item(icon, label, () {
          Navigator.of(context).pop(); // the drawer
          ref.read(homeTabProvider.notifier).go(tab);
        });
    return Drawer(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Image.asset('assets/icons/icon_chat.png', width: 36, height: 36, excludeFromSemantics: true),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: Theme.of(context).textTheme.titleLarge)),
            ]),
          ),
          tab(Icons.today_outlined, l.tabToday, HomeTab.today),
          tab(Icons.chat_bubble_outline, l.tabChat, HomeTab.chat),
          tab(Icons.add_circle_outline, l.tabLog, HomeTab.log),
          if (data != null) ...[
            section(l.drawerFood),
            item(Icons.history, l.historyTitle, () => open(() => HistoryScreen(data: data))),
            item(Icons.event_note_outlined, l.mealPlan, () => open(() => PlanScreen(data: data))),
            item(Icons.shopping_cart_outlined, l.shoppingListNav,
                () => open(() => PlanScreen(data: data, initialTab: 1))),
          ],
          section(l.healthTitle),
          item(Icons.monitor_heart_outlined, l.healthJournalNav, () => open(() => const HealthScreen())),
          section(l.drawerAssistant),
          item(Icons.psychology_outlined, l.aiKnowsTitle,
              agent.hasValue ? () => open(() => MemoryScreen(agent: agent.requireValue)) : null),
          const Divider(indent: 16, endIndent: 16),
          item(Icons.settings_outlined, l.settingsTitle, () => open(() => const SettingsScreen())),
          item(Icons.workspace_premium_outlined, l.yourPlan, () => open(() => const PaywallScreen())),
          item(Icons.lock_outline, l.switchProfile, () {
            Navigator.of(context).pop();
            ref.read(unlockedProvider.notifier).lock();
          }),
        ]),
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

/// Before a big download: on Wi-Fi it goes ahead, Wi-Fi only. Otherwise asks: wait
/// for Wi-Fi, use mobile data, or cancel. Returns wifiOnly, or null = cancelled.
Future<bool?> askNetwork(BuildContext context, int mb) async {
  final net = await Connectivity().checkConnectivity();
  if (net.contains(ConnectivityResult.wifi) || net.contains(ConnectivityResult.ethernet)) return true;
  if (!context.mounted) return null;
  final l = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.signal_cellular_alt),
      title: Text(l.downloadNoWifiTitle),
      content: Text(l.downloadNoWifiBody(mb)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.downloadUseMobile)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.downloadWaitWifi)),
      ],
    ),
  );
}

/// A download's progress, what it's waiting for, and Pause / Resume / Cancel.
class DownloadBar extends ConsumerWidget {
  const DownloadBar(this.provider, {super.key});
  final NotifierProvider<FileDownload, Download?> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(provider);
    if (d == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final download = ref.read(provider.notifier);
    final failed = d.status == TaskStatus.failed || d.status == TaskStatus.notFound;
    final text = switch (d.status) {
      TaskStatus.enqueued => d.task.requiresWiFi ? l.downloadWaitingWifi : l.downloadWaitingNetwork,
      TaskStatus.waitingToRetry => l.downloadRetrying,
      TaskStatus.paused => l.downloadPaused,
      TaskStatus.complete => l.downloadInstalling,
      _ when failed => l.aiDownloadFailed,
      _ => l.aiDownloading,
    };
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LinearProgressIndicator(value: d.percent / 100, semanticsLabel: l.aiDownloading),
      const SizedBox(height: 8),
      Text('$text · ${d.percent} %', textAlign: TextAlign.center, style: failed ? error : null),
      if (!d.task.requiresWiFi) Text(l.downloadOnMobile, textAlign: TextAlign.center, style: error),
      if (d.status != TaskStatus.complete)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (d.status == TaskStatus.running) TextButton(onPressed: download.pause, child: Text(l.downloadPause)),
          if (d.status == TaskStatus.paused || failed)
            TextButton(onPressed: download.resume, child: Text(l.downloadResume)),
          TextButton(onPressed: download.cancel, child: Text(l.cancel)),
        ]),
    ]);
  }
}

Future<void> _startLlm(BuildContext context, WidgetRef ref, Llm m) async {
  final title = AppLocalizations.of(context)!.aiModelTitle;
  final wifiOnly = await askNetwork(context, m.downloadMb);
  if (wifiOnly != null) await ref.read(llmDownloadProvider.notifier).start(m, wifiOnly: wifiOnly, title: title);
}

/// Me tab, 12 GB phones only: which chat model is in use, and switching to the other.
class AiModelCard extends ConsumerStatefulWidget {
  const AiModelCard({super.key});

  @override
  ConsumerState<AiModelCard> createState() => _AiModelCardState();
}

class _AiModelCardState extends ConsumerState<AiModelCard> {
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
    if (ok == true && mounted) await _startLlm(context, ref, m);
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
                    ? Text(l.aiModelInUse, style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600))
                    : OutlinedButton(onPressed: progress == null ? () => _switch(m) : null, child: Text(l.aiModelSwitch)),
              ),
            DownloadBar(llmDownloadProvider),
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
  void _start(Llm m) => _startLlm(context, ref, m);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = ref.watch(llmDownloadProvider);
    final choices = llmChoices();
    return ListView(padding: const EdgeInsets.all(24), children: [
      Icon(Icons.download_for_offline_outlined, size: 48, color: context.colors.primary),
      const SizedBox(height: 12),
      Text(l.aiDownloadTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(l.aiDownloadBody([for (final m in choices) (m.downloadMb / 1024).toStringAsFixed(1)].join('–'))),
      const SizedBox(height: 16),
      if (progress != null)
        DownloadBar(llmDownloadProvider)
      else ...[
        const SizedBox(height: 8),
        // 12 GB phones choose; the others get the one model that fits.
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
