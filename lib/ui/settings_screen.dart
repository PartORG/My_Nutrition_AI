import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
import 'avatar.dart';
import 'detector_bench_screen.dart';
import 'home_screen.dart' show AiModelCard, DownloadBar, askNetwork;
import 'nutrients.dart';
import 'kit.dart';
import 'paywall_screen.dart';
import 'theme.dart';
import 'voice.dart' show Speaker;

/// Everything that is set once and rarely touched, out of the Me tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final data = ref.watch(profileDataProvider);
    if (data == null) return const SizedBox.shrink();
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
              _Group(title: l.avatarTitle, children: const [_AvatarSettings()]),
              _Group(title: l.lookAndLanguage, children: [
                ListTile(
                  leading: _icon(context, Icons.language, 'water'),
                  title: Text(l.language),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // At 200 % text the name would squeeze the title: only the chevron then.
                    if (MediaQuery.textScalerOf(context).scale(10) <= 15)
                      Text(languageOptions(l)[ref.watch(languageProvider)] ?? '', style: TextStyle(fontSize: 14, color: c.muted)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: c.muted),
                  ]),
                  onTap: () async {
                    final current = ref.read(languageProvider);
                    final code = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(l.language),
                        children: [
                          for (final MapEntry(:key, :value) in languageOptions(l).entries)
                            ListTile(
                              title: Text(value),
                              trailing: key == current ? const Icon(Icons.check) : null,
                              onTap: () => Navigator.pop(context, key),
                            ),
                        ],
                      ),
                    );
                    if (code != null) ref.read(languageProvider.notifier).set(code);
                  },
                ),
                const _Appearance(),
              ]),
              _Group(title: l.voiceTitle, hint: l.voiceRepliesHint, children: const [_VoiceReplies()]),
              _Group(title: l.remindersTitle, hint: l.remindersHint, children: [
                _Reminders(data: data),
                // Not offered under 18; the caution stays visible next to the switch.
                if (adult)
                  SwitchListTile(
                    secondary: _icon(context, Icons.timer_outlined, 'carbs_g'),
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
                    secondary: _icon(context, Icons.favorite_border, 'fiber_g'),
                    title: Text(Platform.isIOS ? l.appleHealth : l.healthConnect),
                    subtitle: Text(l.healthSyncHint),
                    value: healthSyncOn(data.user),
                    onChanged: (on) async {
                      if (!on) {
                        await disconnectHealth(data.user);
                      } else if (!await connectHealth(data.user) && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.healthSyncDenied)));
                      }
                      data.changed();
                    },
                  ),
                _Products(data: data),
              ]),
              _Group(title: l.settingsPrivacy, children: [
                if (ref.watch(biometricsAvailableProvider).value == true)
                  SwitchListTile(
                    secondary: _icon(context, Icons.fingerprint, 'fat_g'),
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
                  leading: _icon(context, Icons.lock_outline, 'carbs_g'),
                  title: Text(l.changePin),
                  trailing: Icon(Icons.chevron_right, color: c.muted),
                  onTap: () => showDialog<void>(context: context, builder: (_) => _ChangePinDialog(id: data.profile.id)),
                ),
                if (google != null || googleClientId.isNotEmpty)
                  ListTile(
                    leading: _icon(context, Icons.account_circle_outlined, 'sodium_mg'),
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
                    secondary: _icon(context, Icons.widgets_outlined, 'kcal'),
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
                  leading: _icon(context, Icons.medical_information_outlined, 'protein_g'),
                  title: Text(l.medicalDisclaimerTitle),
                  trailing: Icon(Icons.chevron_right, color: c.muted),
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
                  leading: _icon(context, Icons.description_outlined, 'sodium_mg'),
                  title: Text(l.licenses),
                  trailing: Icon(Icons.chevron_right, color: c.muted),
                  onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
                ),
                ListTile(
                  leading: _icon(context, Icons.privacy_tip_outlined, 'kcal'),
                  title: Text(l.privacyPolicy),
                  trailing: Icon(Icons.open_in_new, color: c.muted),
                  onTap: () => openLegal('privacy.html'),
                ),
                ListTile(
                  leading: _icon(context, Icons.gavel_outlined, 'sugar_g'),
                  title: Text(l.termsOfUse),
                  trailing: Icon(Icons.open_in_new, color: c.muted),
                  onTap: () => openLegal('terms.html'),
                ),
                if (const bool.fromEnvironment('DEV_BILLING')) // developer builds only, English only
                  ListTile(
                    leading: _icon(context, Icons.speed_outlined, 'fiber_g'),
                    title: const Text('Detector benchmark'),
                    trailing: Icon(Icons.chevron_right, color: c.muted),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const DetectorBenchScreen())),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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

/// Settings → Voice: answers read aloud after a spoken message, in a woman's or a man's voice.
class _VoiceReplies extends ConsumerStatefulWidget {
  const _VoiceReplies();

  @override
  ConsumerState<_VoiceReplies> createState() => _VoiceRepliesState();
}

class _VoiceRepliesState extends ConsumerState<_VoiceReplies> {
  final _speaker = Speaker();

  @override
  void dispose() {
    _speaker.stop();
    super.dispose();
  }

  void _test(bool male) => _speaker.say(AppLocalizations.of(context)!.voiceSample,
      language: appLanguage(ref.read(languageProvider)), male: male);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final voice = ref.watch(voiceRepliesProvider);
    final set = ref.read(voiceRepliesProvider.notifier).set;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        secondary: _icon(context, Icons.record_voice_over_outlined, 'protein_g'),
        title: Text(l.voiceRepliesSwitch),
        value: voice.on,
        onChanged: (on) => set(on: on),
      ),
      Divider(indent: 16, endIndent: 16, color: context.colors.divider),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
        child: Row(children: [
          Expanded(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.voiceWoman)),
                ButtonSegment(value: true, label: Text(l.voiceMan)),
              ],
              selected: {voice.male},
              onSelectionChanged: (s) {
                set(male: s.single);
                _test(s.single); // hear the choice at once
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l.voiceTest,
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => _test(voice.male),
          ),
        ]),
      ),
    ]);
  }
}

/// Settings → Your picture: a photo from the phone, or an icon on a colour (solid, gradient or soft); either in a
/// shape, with or without an outline.
class _AvatarSettings extends ConsumerWidget {
  const _AvatarSettings();

  Future<void> _pickPhoto(WidgetRef ref) async {
    try {
      // The system photo picker: no storage permission. Small, so the unlock screen loads it at once.
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (f != null) ref.read(avatarProvider.notifier).setPhoto(await f.readAsBytes());
    } on Object catch (e) {
      debugPrint('avatar photo: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final a = ref.watch(avatarProvider);
    final avatar = ref.read(avatarProvider.notifier);
    final label = AppText.caption.copyWith(fontSize: 13, color: c.muted);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const UserAvatar(radius: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l.avatarPhoto),
                onPressed: () => _pickPhoto(ref),
              ),
              if (a.photo != null) TextButton(onPressed: () => avatar.setPhoto(null), child: Text(l.avatarRemovePhoto)),
            ]),
          ),
        ]),
        // A photo covers the icon, its colour and background: they're offered again once it's removed.
        if (a.photo == null) ...[
          const SizedBox(height: 12),
          AvatarChoices(values: personAvatars, selected: a.kind, label: (k) => avatarKindName(l, k),
              preview: (k) => copyAvatar(a, kind: k), onSelected: (k) => avatar.set(kind: k)),
          const SizedBox(height: 4),
          AvatarChoices(
              values: [for (final k in AvatarKind.values) if (!personAvatars.contains(k)) k],
              selected: a.kind, label: (k) => avatarKindName(l, k), captions: false,
              preview: (k) => copyAvatar(a, kind: k, ring: AvatarRing.none), onSelected: (k) => avatar.set(kind: k)),
          const SizedBox(height: 12),
          Text(l.avatarColor, style: label),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final (i, color) in avatarColors.indexed)
              Semantics(
                button: true,
                selected: color == a.color,
                label: '${l.avatarColor} ${i + 1}',
                excludeSemantics: true,
                child: InkResponse(
                  onTap: () => avatar.set(color: color),
                  radius: 26,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(color: color == a.color ? c.ink : Colors.transparent, width: 3),
                    ),
                    child: color == a.color ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Text(l.avatarBackground, style: label),
          AvatarChoices(values: AvatarStyle.values, selected: a.style, label: (s) => l.avatarStyleName(s.name),
              preview: (s) => copyAvatar(a, style: s), onSelected: (s) => avatar.set(style: s)),
        ],
        const SizedBox(height: 8),
        Text(l.avatarShape, style: label),
        AvatarChoices(values: AvatarShape.values, selected: a.shape, label: (s) => l.avatarShapeName(s.name),
            preview: (s) => copyAvatar(a, shape: s), onSelected: (s) => avatar.set(shape: s)),
        const SizedBox(height: 8),
        Text(l.avatarOutline, style: label),
        AvatarChoices(values: AvatarRing.values, selected: a.ring, label: (r) => l.avatarRingName(r.name),
            preview: (r) => copyAvatar(a, ring: r), onSelected: (r) => avatar.set(ring: r)),
      ]),
    );
  }
}

/// A caps label, an optional line under it, and its rows in one card.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.hint});
  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel(title, padding: EdgeInsets.fromLTRB(4, 20, 4, hint == null ? 8 : 4)),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(hint!, style: AppText.caption.copyWith(fontSize: 13, color: context.colors.muted)),
            ),
          PanelList(children: children),
        ]),
      );
}

/// A setting's icon: the design's tinted square, in one of the palette's colours.
Widget _icon(BuildContext context, IconData icon, String accent) =>
    IconTile(icon: icon, color: context.nutrientColor(accent), size: 36);

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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Divider(indent: 16, endIndent: 16, color: context.colors.divider),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _icon(context, Icons.dark_mode_outlined, 'fat_g'),
            const SizedBox(width: 16),
            Expanded(child: Text(l.appearance, style: Theme.of(context).listTileTheme.titleTextStyle)),
          ]),
          const SizedBox(height: 10),
          PillTabs<ThemeMode>(
            values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
            selected: look.mode,
            label: (m) => switch (m) { ThemeMode.system => l.themeSystem, ThemeMode.light => l.themeLight, _ => l.themeDark },
            onChanged: (m) => set(mode: m),
          ),
        ]),
      ),
      Divider(indent: 16, endIndent: 16, color: context.colors.divider),
      SwitchListTile(
        secondary: _icon(context, Icons.palette_outlined, 'fiber_g'),
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

    final divider = Divider(indent: 16, endIndent: 16, color: context.colors.divider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, r) in reminders.indexed) ...[
        if (i > 0) divider,
        SwitchListTile(
          title: Text(labels[r.slot]!),
          // The time in its meal's colour; tap to change it.
          secondary: () {
            final color = context.mealColor(r.slot == 'evening' ? 'snack' : r.slot);
            // Centered: the list tile would stretch it to the row's height.
            return Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Material(
              color: tint(context, color, alpha: .18),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
                  if (t != null) await update((slot: r.slot, enabled: r.enabled, hour: t.hour, minute: t.minute));
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36, minWidth: 60),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(TimeOfDay(hour: r.hour, minute: r.minute).format(context),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, fontFeatures: AppText.tabular)),
                    ),
                  ),
                ),
              ),
            ),
            );
          }(),
          value: r.enabled,
          onChanged: (on) => update((slot: r.slot, enabled: on, hour: r.hour, minute: r.minute)),
        ),
      ],
      divider,
      TierBuilder(builder: (context, tier) {
        final times = waterTimes(waterGoal(data.user));
        String at((int, int) t) => TimeOfDay(hour: t.$1, minute: t.$2).format(context);
        if (!tier.includes(Tier.basic)) {
          return ListTile(
            leading: _icon(context, Icons.water_drop_outlined, 'water'),
            title: Text(l.reminderWater),
            subtitle: Text(l.reminderWaterLocked),
            trailing: Icon(Icons.lock_outline, color: context.colors.muted),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
          );
        }
        return SwitchListTile(
          secondary: _icon(context, Icons.water_drop_outlined, 'water'),
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
    final c = context.colors;
    final green = context.nutrientColor('kcal');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _icon(context, Icons.inventory_2_outlined, 'kcal'),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.productsTitle, style: Theme.of(context).listTileTheme.titleTextStyle),
            const SizedBox(height: 2),
            Text(info == null ? l.productsNone : l.productsHave(NumberFormat.decimalPattern().format(info.rows), info.builtAt),
                style: Theme.of(context).listTileTheme.subtitleTextStyle),
            const SizedBox(height: 8),
            DownloadBar(productsDownloadProvider),
            if (progress == null)
              info == null
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: tint(context, green, alpha: .18), foregroundColor: green, minimumSize: const Size(48, 44)),
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(l.productsDownload(productsDownloadMb)),
                      onPressed: () async {
                        final wifiOnly = await askNetwork(context, productsDownloadMb);
                        if (wifiOnly != null) await download.start(wifiOnly: wifiOnly, title: l.productsTitle);
                      },
                    )
                  : TextButton(
                      style: TextButton.styleFrom(foregroundColor: c.danger),
                      onPressed: () => setState(download.remove),
                      child: Text(l.productsRemove)),
          ]),
        ),
      ]),
    );
  }
}
