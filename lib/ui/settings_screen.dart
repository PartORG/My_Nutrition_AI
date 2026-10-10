import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../data/health_sync.dart';
import '../data/reminders.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart' show AiModelCard, DownloadBar, askNetwork;
import 'me_screen.dart' show TargetDialog;
import 'memory_screen.dart';
import 'nutrients.dart';

/// Everything that is set once and rarely touched, out of the Me tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final data = ref.watch(profileDataProvider);
    if (data == null) return const SizedBox.shrink();
    final agent = ref.watch(agentProvider);
    final profiles = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ValueListenableBuilder(
        valueListenable: data.changes,
        builder: (context, _, _) {
          final body = loadBody(data.user);
          final adult = body == null || computeTargets(body, now: DateTime.now()) != null;
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            _Section(l.appearance),
            const _Appearance(),

            _Section(l.settingsAi),
            if (llmChoices().length > 1)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: AiModelCard()),
            _Products(data: data),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: Text(l.aiKnowsTitle),
              subtitle: agent.hasValue ? null : Text(l.aiKnowsLoading),
              trailing: const Icon(Icons.chevron_right),
              enabled: agent.hasValue,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => MemoryScreen(agent: agent.requireValue))),
            ),

            _Section(l.remindersTitle),
            _Reminders(data: data),

            _Section(l.settingsTracking),
            ListTile(
              leading: const Icon(Icons.water_drop_outlined),
              title: Text(l.waterGoal),
              trailing: Text('${waterGoal(data.user).round()} ml'),
              onTap: () async {
                // null = cancelled, -1 = back to the computed goal.
                final ml = await showDialog<double>(
                    context: context, builder: (_) => TargetDialog(title: l.waterGoal, initial: waterGoal(data.user)));
                if (ml == null) return;
                setPref(data.user, 'water_goal_ml', ml < 0 ? '' : '${ml.clamp(500, 6000)}');
                data.changed();
              },
            ),
            // Not offered under 18; the caution stays visible next to the switch.
            if (adult)
              SwitchListTile(
                secondary: const Icon(Icons.timer_outlined),
                title: Text(l.fastingSwitch),
                subtitle: Text(l.fastingCaution),
                value: pref(data.user, 'fasting') == '1',
                onChanged: (on) {
                  setPref(data.user, 'fasting', on ? '1' : '0');
                  if (!on) endFast(data.user, DateTime.now());
                  data.changed();
                },
              ),

            _Section(l.settingsPrivacy),
            if (profiles.biometricAllowed && ref.watch(biometricsAvailableProvider).value == true)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(l.fingerprintTitle),
                subtitle: Text(l.fingerprintHint),
                value: profiles.biometricEnabled(data.profile.id),
                onChanged: (on) async {
                  // Turning it on needs one successful scan, so it's the owner doing it.
                  if (on && !await authenticateFingerprint(ref, l.fingerprintReason(data.profile.name))) return;
                  profiles.setBiometric(data.profile.id, on);
                  data.changed();
                },
              ),
            // Visible without the PIN, so only on a single-profile phone, and off until the owner says so.
            if (Platform.isAndroid && profiles.biometricAllowed)
              SwitchListTile(
                secondary: const Icon(Icons.widgets_outlined),
                title: Text(l.widgetKcalTitle),
                subtitle: Text(l.widgetKcalHint),
                value: widgetShowsKcal(profiles),
                onChanged: (on) {
                  profiles.setSetting('widget_kcal', on ? '1' : '0');
                  data.changed(); // redraws this switch and the widget
                },
              ),
            if (healthSupported)
              SwitchListTile(
                secondary: const Icon(Icons.favorite_border),
                title: Text(Platform.isIOS ? l.appleHealth : l.healthConnect),
                subtitle: Text(l.healthSyncHint),
                value: healthSyncOn(data.user),
                onChanged: (on) async {
                  if (!on) {
                    disconnectHealth(data.user);
                  } else if (!await connectHealth(data.user) && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.healthSyncDenied)));
                  }
                  data.changed();
                },
              ),

            _Section(l.settingsAbout),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.licenses),
              onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l.privacyPolicy),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openLegal('privacy.html'),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l.termsOfUse),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openLegal('terms.html'),
            ),

            _Section(l.settingsDanger),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
              title: Text(l.deleteThisProfile, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _delete(context, ref, data),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ProfileData data) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteProfileTitle(data.profile.name)),
        content: Text(l.deleteThisProfileBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final id = data.profile.id;
    Navigator.of(context).pop();
    // Lock first: it closes the profile's databases before their files go.
    ref.read(unlockedProvider.notifier).lock();
    ref.read(profilesProvider).delete(id);
    unawaited(ref.read(remindersProvider).cancelProfile(id));
  }
}

/// M3 list section header: titleSmall in primary.
class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

/// System / light / dark, and the phone's wallpaper colours (Android 12+).
class _Appearance extends ConsumerWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final look = ref.watch(appearanceProvider);
    final set = ref.read(appearanceProvider.notifier).set;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // Scrolls at large text: "System" in German or French doesn't fit three segments.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
            ],
            selected: {look.mode},
            onSelectionChanged: (s) => set(mode: s.single),
          ),
        ),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.palette_outlined),
        title: Text(l.wallpaperColors),
        subtitle: Text(l.wallpaperColorsHint),
        value: look.wallpaper,
        onChanged: (on) => set(wallpaper: on),
      ),
    ]);
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final reminders = loadReminders(data.user, now: DateTime.now());
    final labels = {'breakfast': l.reminderBreakfast, 'lunch': l.reminderLunch, 'dinner': l.reminderDinner,
        'evening': l.reminderEvening};
    final meals = {'breakfast': l.mealBreakfast, 'lunch': l.mealLunch, 'dinner': l.mealDinner};
    final name = data.profile.name;
    String text(String slot) =>
        slot == 'evening' ? l.notifEvening(name) : l.notifMeal(name, meals[slot]!.toLowerCase());

    Future<void> update(Reminder r) async {
      final service = ref.read(remindersProvider);
      if (r.enabled && !await service.requestPermission()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.notificationsDenied)));
        }
        return;
      }
      saveReminder(data.user, r);
      data.changed();
      await service.apply(data.profile.id, loadReminders(data.user, now: DateTime.now()), text);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(l.remindersHint, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
      for (final r in reminders)
        SwitchListTile(
          title: Text(labels[r.slot]!),
          secondary: TextButton(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
              if (t != null) await update((slot: r.slot, enabled: r.enabled, hour: t.hour, minute: t.minute));
            },
            child: Text(TimeOfDay(hour: r.hour, minute: r.minute).format(context)),
          ),
          value: r.enabled,
          onChanged: (on) => update((slot: r.slot, enabled: on, hour: r.hour, minute: r.minute)),
        ),
    ]);
  }
}

/// Every packaged product from Open Food Facts (all countries), as an optional download.
class _Products extends ConsumerStatefulWidget {
  const _Products({required this.data});
  final ProfileData data;

  @override
  ConsumerState<_Products> createState() => _ProductsState();
}

class _ProductsState extends ConsumerState<_Products> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = ref.watch(productsDownloadProvider);
    final info = productsInfo(widget.data.tools.products);
    final download = ref.read(productsDownloadProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.productsTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(info == null ? l.productsNone : l.productsHave(NumberFormat.decimalPattern().format(info.rows), info.builtAt)),
        const SizedBox(height: 8),
        DownloadBar(productsDownloadProvider),
        Align(
          alignment: Alignment.centerRight,
          child: progress != null
              ? const SizedBox.shrink()
              : info == null
                  ? TextButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(l.productsDownload(productsDownloadMb)),
                      onPressed: () async {
                        final wifiOnly = await askNetwork(context, productsDownloadMb);
                        if (wifiOnly != null) await download.start(wifiOnly: wifiOnly, title: l.productsTitle);
                      },
                    )
                  : TextButton(onPressed: () => setState(download.remove), child: Text(l.productsRemove)),
        ),
      ]),
    );
  }
}
