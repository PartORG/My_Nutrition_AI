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
import 'log_screen.dart';
import 'me_screen.dart';
import 'plan_screen.dart';
import 'theme.dart';
import 'today_screen.dart';

/// The selected tab: Today's buttons open Chat or Log. Log has no tab of its own: the + opens it.
final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class HomeTab extends Notifier<int> {
  static const today = 0, chat = 1, log = 2, plan = 3, me = 4;

  @override
  int build() => today;

  void go(int tab) => state = tab;

  /// The + on a meal card: Log, already on that meal.
  void logMeal(String meal) {
    ref.read(logMealProvider.notifier).set(meal);
    state = log;
  }
}

/// The meal the Log tab opens on; null = the one for this time of day.
final logMealProvider = NotifierProvider<LogMeal, String?>(LogMeal.new);

class LogMeal extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? meal) => state = meal;
}

/// The unlocked profile: Today · Chat · (+ Log) · Plan · Me.
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
    // Keep the profile's databases and the loaded AI alive across tab switches;
    // both are auto-dispose and close only when this screen goes (Lock).
    final data = ref.watch(profileDataProvider);
    ref.watch(agentProvider);
    final tab = ref.watch(homeTabProvider);
    final body = switch (tab) {
      HomeTab.today => TodayScreen(name: widget.name),
      HomeTab.chat => const _ChatTab(),
      HomeTab.log => const LogScreen(),
      HomeTab.plan => data == null ? const Center(child: CircularProgressIndicator()) : PlanScreen(data: data),
      _ => const MeScreen(),
    };
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: _BottomBar(tab: tab, onTab: ref.read(homeTabProvider.notifier).go),
    );
  }
}

/// Today · Chat · + · Plan · Me. The selected tab sits in a mint pill; the + (log food) is raised,
/// near-black, and green while Log is open.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    Widget item(int i, IconData icon, IconData selectedIcon, String label) {
      final on = tab == i;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onTab(i),
            radius: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: Durations.short4,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  decoration: BoxDecoration(color: on ? c.mint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: Icon(on ? selectedIcon : icon, color: on ? c.primary : c.muted, size: 24),
                ),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on ? c.primary : c.muted)),
              ]),
            ),
          ),
        ),
      );
    }

    final logOn = tab == HomeTab.log;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          item(HomeTab.today, Icons.calendar_today_outlined, Icons.calendar_today, l.tabToday),
          item(HomeTab.chat, Icons.chat_bubble_outline, Icons.chat_bubble, l.tabChat),
          Expanded(
            // heightFactor 1: a plain Center grows to the bar's max height, i.e. the whole screen.
            child: Center(
              heightFactor: 1,
              child: Tooltip(
                message: l.tabLog,
                child: Semantics(
                  selected: logOn,
                  button: true,
                  label: l.tabLog,
                  excludeSemantics: true,
                  child: Material(
                    color: logOn ? c.primary : c.dark,
                    elevation: 6,
                    shadowColor: c.ink.withValues(alpha: .35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => onTab(HomeTab.log),
                      child: SizedBox.square(
                          dimension: 60, child: Icon(Icons.add, size: 30, color: logOn ? c.onPrimary : c.background)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          item(HomeTab.plan, Icons.article_outlined, Icons.article, l.tabPlan),
          item(HomeTab.me, Icons.person_outline, Icons.person, l.tabMe),
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
