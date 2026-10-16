import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../billing/billing.dart' show Tier;
import '../data/diary.dart';
import '../data/goals.dart';
import '../data/health_sync.dart';
import '../data/pin.dart' show isValidPin;
import '../data/profiles.dart';
import '../data/reminders.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart' show AiModelCard, DownloadBar, askNetwork;
import 'me_screen.dart' show TargetDialog;
import 'memory_screen.dart';
import 'nutrients.dart';
import 'kit.dart';
import 'paywall_screen.dart';
import 'theme.dart';

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
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: data.changes,
          builder: (context, _, _) {
            final c = context.colors;
            final body = loadBody(data.user);
            final adult = body == null || computeTargets(body, now: DateTime.now()) != null;
            final google = profiles.googleEmail(data.profile.id);
            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              ScreenHeader(title: l.settingsTitle, back: true),
              _Group(title: l.lookAndLanguage, children: [
                ListTile(
                  title: Text(l.language),
                  // Under the title, not trailing: at 200 % text it wouldn't fit beside it.
                  subtitle: DropdownButton<String>(
                    isExpanded: true,
                    value: ref.watch(languageProvider),
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(16),
                    items: [
                      for (final MapEntry(:key, :value) in languageOptions(l).entries)
                        DropdownMenuItem(value: key, child: Text(value)),
                    ],
                    onChanged: (code) => ref.read(languageProvider.notifier).set(code ?? ''),
                  ),
                ),
                const _Appearance(),
              ]),
              _Group(title: l.remindersTitle, children: [
                _Reminders(data: data),
                ListTile(
                  title: Text(l.waterGoal),
                  trailing: Text('${waterGoal(data.user).round()} ml', style: TextStyle(fontSize: 15, color: c.muted)),
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
                    title: Text(l.fastingSwitch),
                    subtitle: Text(l.fastingCaution),
                    value: pref(data.user, 'fasting') == '1',
                    onChanged: (on) {
                      setPref(data.user, 'fasting', on ? '1' : '0');
                      if (!on) endFast(data.user, DateTime.now());
                      data.changed();
                    },
                  ),
              ]),
              _Group(title: l.onDeviceAiAndData, children: [
                if (llmChoices().length > 1) const AiModelCard(),
                if (healthSupported)
                  SwitchListTile(
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
                _Products(data: data),
                ListTile(
                  title: Text(l.aiKnowsTitle),
                  subtitle: agent.hasValue ? null : Text(l.aiKnowsLoading),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: agent.hasValue,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => MemoryScreen(agent: agent.requireValue))),
                ),
              ]),
              _Group(title: l.settingsPrivacy, children: [
                if (ref.watch(biometricsAvailableProvider).value == true)
                  SwitchListTile(
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
                ListTile(
                  title: Text(l.changePin),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(context: context, builder: (_) => _ChangePinDialog(id: data.profile.id)),
                ),
                if (google != null || googleClientId.isNotEmpty)
                  ListTile(
                    title: Text(l.googleAccount),
                    subtitle: Text(google == null ? l.googleNotLinked : l.googleLinked(google)),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
                      onPressed: () async {
                        if (google != null) {
                          profiles.setGoogleEmail(data.profile.id, null);
                        } else if (await signInWithGoogle() case final account?) {
                          profiles.setGoogleEmail(data.profile.id, account.email);
                        }
                        data.changed();
                      },
                      child: Text(google == null ? l.link : l.unlink),
                    ),
                  ),
                // Visible without the PIN, so off until the owner says so.
                if (Platform.isAndroid)
                  SwitchListTile(
                    title: Text(l.widgetKcalTitle),
                    subtitle: Text(l.widgetKcalHint),
                    value: widgetShowsKcal(profiles),
                    onChanged: (on) {
                      profiles.setSetting('widget_kcal', on ? '1' : '0');
                      data.changed(); // redraws this switch and the widget
                    },
                  ),
              ]),
              _Group(title: l.settingsAbout, children: [
                ListTile(
                  title: Text(l.medicalDisclaimerTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l.medicalDisclaimerTitle),
                      content: SingleChildScrollView(child: Text(l.medicalDisclaimerBody)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(MaterialLocalizations.of(context).closeButtonLabel)),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  title: Text(l.licenses),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
                ),
                ListTile(
                  title: Text(l.privacyPolicy),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => openLegal('privacy.html'),
                ),
                ListTile(
                  title: Text(l.termsOfUse),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => openLegal('terms.html'),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Panel(
                  color: c.dangerBg,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SectionLabel(l.settingsDanger, color: c.danger, padding: EdgeInsets.zero),
                    const SizedBox(height: 8),
                    Text(l.deleteThisProfileBody, style: TextStyle(color: c.ink2)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: c.danger, side: BorderSide(color: c.danger)),
                      onPressed: () => _delete(context, ref, data),
                      child: Text(l.deleteThisProfile),
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
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

/// '' = follow the phone; each language named in itself, so it can be found from any other.
Map<String, String> languageOptions(AppLocalizations l) =>
    {'': l.themeSystem, 'en': 'English', 'uk': 'Українська', 'de': 'Deutsch', 'fr': 'Français'};

/// App bar: the same choice as in Settings.
class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      tooltip: l.language,
      icon: const Icon(Icons.translate),
      initialValue: ref.watch(languageProvider),
      onSelected: ref.read(languageProvider.notifier).set,
      itemBuilder: (_) => [
        for (final MapEntry(:key, :value) in languageOptions(l).entries) PopupMenuItem(value: key, child: Text(value)),
      ],
    );
  }
}

/// A caps label and its rows in one card.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel(title),
          PanelList(children: children),
        ]),
      );
}

/// Settings → Change PIN: the current one, then the new one twice.
class _ChangePinDialog extends ConsumerStatefulWidget {
  const _ChangePinDialog({required this.id});
  final int id;

  @override
  ConsumerState<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends ConsumerState<_ChangePinDialog> {
  final _current = TextEditingController(), _next = TextEditingController(), _again = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!isValidPin(_next.text)) return setState(() => _error = l.pinInvalid);
    if (_next.text != _again.text) return setState(() => _error = l.pinMismatch);
    setState(() => _busy = true);
    final r = await ref.read(profilesProvider).changePin(widget.id, _current.text, _next.text);
    if (!mounted) return;
    switch (r) {
      case PinOk():
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.pinChanged)));
      case PinWrong(:final attemptsLeft):
        setState(() {
          _busy = false;
          _error = l.pinWrong(attemptsLeft);
        });
      case PinLocked(:final until):
        setState(() {
          _busy = false;
          _error = l.pinLocked(until.difference(DateTime.now()).inSeconds + 1);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    TextField pin(TextEditingController c, String label) => TextField(
          controller: c,
          obscureText: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, counterText: ''),
        );
    return AlertDialog(
      title: Text(l.changePin),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          pin(_current, l.currentPin),
          const SizedBox(height: 10),
          pin(_next, l.pinLabel),
          const SizedBox(height: 10),
          pin(_again, l.pinConfirmLabel),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: TextStyle(color: context.colors.danger)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.confirmSave)),
      ],
    );
  }
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.appearance, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          PillTabs<ThemeMode>(
            values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
            selected: look.mode,
            label: (m) => switch (m) { ThemeMode.system => l.themeSystem, ThemeMode.light => l.themeLight, _ => l.themeDark },
            onChanged: (m) => set(mode: m),
          ),
        ]),
      ),
      SwitchListTile(
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
      TierBuilder(builder: (context, tier) {
        final times = waterTimes(waterGoal(data.user));
        String at((int, int) t) => TimeOfDay(hour: t.$1, minute: t.$2).format(context);
        if (!tier.includes(Tier.basic)) {
          return ListTile(
            title: Text(l.reminderWater),
            subtitle: Text(l.reminderWaterLocked),
            trailing: const Icon(Icons.lock_outline),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
          );
        }
        return SwitchListTile(
          title: Text(l.reminderWater),
          subtitle: Text(l.reminderWaterHint(times.length, at(times.first), at(times.last))),
          value: pref(data.user, waterReminderPref) == '1',
          onChanged: (on) async {
            final service = ref.read(remindersProvider);
            if (on && !await service.requestPermission()) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.notificationsDenied)));
              }
              return;
            }
            setPref(data.user, waterReminderPref, on ? '1' : '0');
            data.changed(); // HomeScreen schedules or cancels them

          },
        );
      }),
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
