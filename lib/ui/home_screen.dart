import 'dart:async';

import 'package:background_downloader/background_downloader.dart' show TaskStatus;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart' show pref, setPref, totalsOn, waterGoal, waterOn, weightTrend, weightsSince;
import '../data/goals.dart';
import '../data/plan.dart' show savedRecipeIds;
import '../data/reminders.dart' show waterReminderPref, waterScheduledSetting, waterTimes, waterTimesPref;
import '../l10n/app_localizations.dart';
import 'all_nutrients_screen.dart';
import 'avatar.dart';
import 'camera_screen.dart' show openCamera;
import 'chat_screen.dart';
import 'goals_screen.dart';
import 'health_screen.dart';
import 'history_screen.dart';
import 'kit.dart';
import 'log_screen.dart';
import 'me_screen.dart';
import 'memory_screen.dart';
import 'paywall_screen.dart' show PaywallScreen, tierName;
import 'plan_screen.dart';
import 'settings_screen.dart' show SettingsScreen;
import 'theme.dart';
import 'today_screen.dart';
import 'weight_screen.dart';

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

/// A home-screen widget button not acted on yet: 'log' or 'voice' (the mic). AppGate hears every tap, also
/// while the app is locked; the home screen takes 'log', the chat takes 'voice' once it shows.
typedef WidgetTap = ({String host, DateTime at});

final widgetTapProvider = NotifierProvider<WidgetTaps, WidgetTap?>(WidgetTaps.new);

class WidgetTaps extends Notifier<WidgetTap?> {
  @override
  WidgetTap? build() => null;

  void set(String? host) => state = host == null ? null : (host: host, at: DateTime.now());
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
  Billing? _billing;
  ProfileData? _data;

  @override
  void initState() {
    super.initState();
    // Profiles from before the picture existed: it follows the sex in their goals.
    // After the frame: Riverpod forbids changing a provider while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = mounted ? ref.read(profileDataProvider)?.user : null;
      if (user == null) return;
      if (loadBody(user)?.sex case final sex?) ref.read(avatarProvider.notifier).suggestFor(sex);
    });
    ref.read(billingProvider.future).then((b) {
      if (!mounted) return;
      _billing = b..tier.addListener(_tierChanged);
      _data = ref.read(profileDataProvider)?..changes.addListener(_syncWater);
      _tierChanged();
    }, onError: (_) {});
    // A widget button tapped before the PIN: its tab now.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fromWidget(mounted ? ref.read(widgetTapProvider) : null));
  }

  /// The widget's Log button opens the Log tab; its mic the chat, which starts listening.
  void _fromWidget(WidgetTap? tap) {
    if (tap == null || !mounted) return;
    if (tap.host == 'log') {
      ref.read(homeTabProvider.notifier).go(HomeTab.log);
      ref.read(widgetTapProvider.notifier).set(null);
    } else if (tap.host == 'voice') {
      ref.read(homeTabProvider.notifier).go(HomeTab.chat);
    }
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
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // Keep the profile's databases and the loaded AI alive across tab switches;
    // both are auto-dispose and close only when this screen goes (Lock).
    final data = ref.watch(profileDataProvider);
    ref.watch(agentProvider);
    ref.listen(widgetTapProvider, (_, tap) => _fromWidget(tap));
    final tab = ref.watch(homeTabProvider);
    final body = switch (tab) {
      HomeTab.today => TodayScreen(name: widget.name),
      HomeTab.chat => const _ChatTab(),
      HomeTab.log => const LogScreen(),
      HomeTab.plan => data == null ? const Center(child: CircularProgressIndicator()) : PlanScreen(data: data),
      _ => const MeScreen(),
    };
    return Scaffold(
      drawer: _Drawer(name: widget.name, data: data),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: _BottomBar(tab: tab, onTab: ref.read(homeTabProvider.notifier).go),
    );
  }
}

/// Today · Chat · + · Plan · Me. The selected tab sits in a mint pill; the + (log food) is a raised
/// green square.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    Widget item(int i, IconData icon, IconData selectedIcon, String label, {Widget? image}) {
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
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: image == null ? 4 : 2),
                  decoration: BoxDecoration(color: on ? c.mint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: image ?? Icon(on ? selectedIcon : icon, color: on ? c.primary : c.muted, size: 22),
                ),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: on ? c.primary : c.muted)),
              ]),
            ),
          ),
        ),
      );
    }

    final logOn = tab == HomeTab.log;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            item(HomeTab.today, Icons.calendar_today_outlined, Icons.calendar_today, l.tabToday),
            item(HomeTab.chat, Icons.chat_bubble_outline, Icons.chat_bubble, l.tabChat, image: const EvaAvatar(size: 26)),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: c.primary.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 4))],
                      ),
                      child: Material(
                        color: logOn ? c.primaryDark : c.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => onTab(HomeTab.log),
                          child: SizedBox.square(dimension: 56, child: Icon(Icons.add, size: 30, color: c.onPrimary)),
                        ),
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
      ),
    );
  }
}

/// Everywhere, one swipe from the left edge: who is signed in and today's numbers on top, then the tabs (Go to),
/// the screens a few taps deep (Track, Food), Settings and Lock at the foot.
class _Drawer extends ConsumerWidget {
  const _Drawer({required this.name, required this.data});
  final String name;
  final ProfileData? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final data = this.data;
    final nav = Navigator.of(context);
    final agent = ref.watch(agentProvider);
    void open(Widget screen) {
      nav.pop();
      nav.push(MaterialPageRoute<void>(builder: (_) => screen)).then((_) => data?.changed());
    }

    Widget plan(ProfileData data, PlanTab tab) =>
        Scaffold(body: SafeArea(child: PlanScreen(data: data, initialTab: tab, back: true)));

    final tab = ref.watch(homeTabProvider);
    final tier = ref.watch(billingProvider).value?.tier.value ?? Tier.free;
    void go(int to) {
      nav.pop();
      ref.read(homeTabProvider.notifier).go(to);
    }

    Widget item(IconData icon, String accent, String label, VoidCallback? onTap,
            {String? trailing, bool selected = false, Widget? leading}) => ListTile(
          leading: leading ?? IconTile(icon: icon, color: context.nutrientColor(accent), size: 32),
          selected: selected,
          selectedTileColor: c.mint,
          title: Text(label, style: AppText.body.copyWith(fontSize: 15, color: c.ink)),
          trailing: trailing == null ? null : Text(trailing, style: AppText.caption.copyWith(fontSize: 13, color: c.muted)),
          minLeadingWidth: 32,
          horizontalTitleGap: 14,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile)),
          onTap: onTap,
          enabled: onTap != null,
        );

    Widget footButton(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.tile),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.tile),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 18, color: c.ink),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: AppText.item.copyWith(color: c.ink))),
                ]),
              ),
            ),
          ),
        );

    return Drawer(
      backgroundColor: c.background,
      child: SafeArea(
        child: data == null
            ? const SizedBox.shrink()
            : ValueListenableBuilder(
                valueListenable: data.changes,
                builder: (context, _, _) => Column(children: [
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), children: [
                      _DrawerHeader(name: name, onPlans: () => open(const PaywallScreen())),
                      const SizedBox(height: 10),
                      _DrawerNumbers(data: data),
                      SectionLabel(l.drawerGo, padding: const EdgeInsets.fromLTRB(12, 18, 12, 6)),
                      item(Icons.calendar_today_outlined, 'kcal', l.tabToday, () => go(HomeTab.today),
                          selected: tab == HomeTab.today),
                      item(Icons.chat_bubble_outline, 'kcal', l.tabChat, () => go(HomeTab.chat),
                          selected: tab == HomeTab.chat, leading: const EvaAvatar(size: 32)),
                      item(Icons.add, 'kcal', l.logFoodTitle, () => go(HomeTab.log), selected: tab == HomeTab.log),
                      item(Icons.article_outlined, 'kcal', l.tabPlan, () => go(HomeTab.plan), selected: tab == HomeTab.plan),
                      item(Icons.person_outline, 'kcal', l.tabMe, () => go(HomeTab.me), selected: tab == HomeTab.me),
                      SectionLabel(l.drawerTrack, padding: const EdgeInsets.fromLTRB(12, 18, 12, 6)),
                      item(Icons.monitor_weight_outlined, 'kcal', l.weight, () => open(WeightScreen(data: data))),
                      item(Icons.history, 'water', l.historyAndYear, () => open(HistoryScreen(data: data))),
                      item(Icons.flag_outlined, 'carbs_g', l.goalsTitle, () => open(const GoalsScreen())),
                      item(Icons.favorite_border, 'fiber_g', l.healthTitle, () => open(const HealthScreen())),
                      // Basic, else the plans (as from Today's panel).
                      item(Icons.science_outlined, 'sodium_mg', l.allNutrientsTitle,
                          () => open(tier.includes(Tier.basic) ? AllNutrientsScreen(data: data) : const PaywallScreen())),
                      SectionLabel(l.drawerFood, padding: const EdgeInsets.fromLTRB(12, 18, 12, 6)),
                      item(Icons.photo_camera_outlined, 'water', l.snapPhoto, () {
                        nav.pop();
                        openCamera(nav.context, 'photo'); // the drawer's own context is gone once it closes
                      }),
                      item(Icons.bookmark_border, 'protein_g', l.savedRecipesTitle, () => open(plan(data, PlanTab.recipes)),
                          trailing: switch (savedRecipeIds(data.tools).length) { 0 => null, final n => '$n' }),
                      item(Icons.shopping_cart_outlined, 'fat_g', l.shoppingList, () => open(plan(data, PlanTab.shopping))),
                      item(Icons.lightbulb_outline, 'sugar_g', l.aiKnowsTitle,
                          agent.hasValue ? () => open(MemoryScreen(agent: agent.requireValue)) : null),
                    ]),
                  ),
                  Divider(indent: 16, endIndent: 16, color: c.divider),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(children: [
                      footButton(Icons.tune, l.settingsTitle, () => open(const SettingsScreen())),
                      const SizedBox(width: 10),
                      footButton(Icons.lock_outline, l.lock, () {
                        nav.pop();
                        ref.read(unlockedProvider.notifier).lock();
                      }),
                    ]),
                  ),
                ]),
              ),
      ),
    );
  }
}

/// Avatar, name and plan on the green hero; × closes the drawer.
class _DrawerHeader extends ConsumerWidget {
  const _DrawerHeader({required this.name, required this.onPlans});
  final String name;
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final billing = ref.watch(billingProvider).value;
    // Eva peeks up from the header's bottom edge, under the ×.
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: Stack(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          decoration: BoxDecoration(color: c.heroSurface, borderRadius: BorderRadius.circular(Radii.card)),
          child: Row(children: [
            const UserAvatar(radius: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppText.title.copyWith(color: c.ink), overflow: TextOverflow.ellipsis),
                if (billing != null)
                  ValueListenableBuilder(
                    valueListenable: billing.tier,
                    builder: (context, tier, _) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: onPlans,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        child: Tag(tierName(tier, l).toUpperCase(), tone: tier == Tier.free ? TagTone.neutral : TagTone.gold),
                      ),
                    ),
                  ),
              ]),
            ),
            Column(children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: Icon(Icons.close, color: c.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 30), // Eva's room
            ]),
          ]),
        ),
        const Positioned(right: 4, bottom: -14, child: EvaCutout(size: 56)),
      ]),
    );
  }
}

/// Left today · Water · Weight, three small tiles under the header.
class _DrawerNumbers extends StatelessWidget {
  const _DrawerNumbers({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final now = DateTime.now();
    final goal = currentTargets(data.user, nutri: data.nutri, now: now).values['kcal'];
    final left = goal == null ? null : goal - totalsOn(data.user, now)['kcal']!;
    final body = loadBody(data.user);
    final points = weightTrend(weightsSince(data.user, now.subtract(const Duration(days: 30))));
    final kg = points.isNotEmpty ? points.last.trend : body?.weightKg;
    final imperial = body?.imperial ?? false;
    final locale = Localizations.localeOf(context).toString();
    Widget tile(String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.tile)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, fontFeatures: AppText.tabular)),
              ),
            ]),
          ),
        );
    return Row(children: [
      tile(l.leftToday, left == null ? '–' : NumberFormat.decimalPattern(locale).format(left.round()), c.primary),
      const SizedBox(width: 6),
      tile(l.water, '${(waterOn(data.user, now) / 1000).toStringAsFixed(2)} ${l.litreUnit}', context.nutrientColor('water')),
      const SizedBox(width: 6),
      tile(l.weight, kg == null ? '–' : (imperial ? kgToLb(kg) : kg).toStringAsFixed(1), c.ink),
    ]);
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
              const SizedBox(height: 8),
              const _SearchInstead(),
            ]),
          ),
        ),
    };
  }
}

/// Standard / Larger model, as a tile: [trailing] is the button for it. Larger is the recommended one where it's
/// offered (12 GB phones): it sees foods on photos better.
// shortcut: recommended before its tool accuracy is measured; run integration_test/agent_eval_test.dart with E4B.
Widget _modelTile(AppLocalizations l, Llm m, Widget trailing) {
  final gb = (m.downloadMb / 1024).toStringAsFixed(1);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    title: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(m == e4b ? l.aiModelLarge(gb) : l.aiModelStandard(gb), style: const TextStyle(fontWeight: FontWeight.w600)),
      if (m == e4b) Tag(l.aiModelRecommended, tone: TagTone.gold),
    ]),
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
        // 12 GB phones choose, the recommended larger one first; the others get the one model that fits.
        if (choices.length > 1)
          for (final m in choices.reversed)
            _modelTile(l, m, ElevatedButton(onPressed: () => _start(m), child: Text(l.aiDownloadButton)))
        else
          ElevatedButton.icon(
              icon: const Icon(Icons.download), label: Text(l.aiDownloadButton), onPressed: () => _start(e2b)),
      ],
      const SizedBox(height: 12),
      const Center(child: _SearchInstead()),
    ]);
  }
}

/// Without the AI (downloading, starting): the Log tab logs a meal too, no AI needed.
class _SearchInstead extends ConsumerWidget {
  const _SearchInstead();

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
        icon: const Icon(Icons.search),
        label: Text(AppLocalizations.of(context)!.searchInsteadInLog),
        onPressed: () => ref.read(homeTabProvider.notifier).go(HomeTab.log),
      );
}
