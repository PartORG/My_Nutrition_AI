import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../data/reminders.dart';
import '../l10n/app_localizations.dart';
import 'goals_screen.dart';
import 'health_screen.dart';
import 'home_screen.dart' show AiModelCard;
import '../data/health_sync.dart';
import 'memory_screen.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'theme.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profileDataProvider);
    if (data == null) return const SizedBox.shrink();
    final agent = ref.watch(agentProvider);
    return ValueListenableBuilder(
      valueListenable: data.changes,
      builder: (context, _, _) {
        final l = AppLocalizations.of(context)!;
        final body = loadBody(data.user);
        final targets = currentTargets(data.user, nutri: data.nutri, now: DateTime.now());
        final adult = body == null || computeTargets(body, now: DateTime.now()) != null;
        void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.goalsTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(body == null ? l.setGoalsBody : _describe(body, l)),
                if (!adult) ...[const SizedBox(height: 8), Text(l.under18, style: TextStyle(color: context.colors.textSecondary))],
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(
                    onPressed: () => open(const GoalsScreen()),
                    child: Text(body == null ? l.setGoalsButton : l.editDetails),
                  ),
                  // Free: goals use the current weight. The trend chart is Basic.
                  OutlinedButton.icon(
                    icon: const Icon(Icons.monitor_weight_outlined),
                    label: Text(l.logWeight),
                    onPressed: () => _logWeight(context, data, body?.imperial ?? false),
                  ),
                ]),
              ]),
            ),
          ),
          _PlanCard(onOpen: () => open(const PaywallScreen())),
          Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListTile(title: Text(l.targetsTitle, style: Theme.of(context).textTheme.titleMedium)),
              if (targets.values.isEmpty && adult) ListTile(title: Text(l.targetsNone)),
              // Under 18 every target is manual, so all of them are listed for editing.
              for (final key in nutrientLabels(l).keys)
                if (targets.values[key] != null || !adult)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: nutrientColors[key], shape: BoxShape.circle),
                    ),
                    title: Text(nutrientLabels(l)[key]!.$1),
                    subtitle: targets.limited[key] != null
                        ? Text(l.limitFrom(conditionLabel(targets.limited[key]!, l)))
                        : targets.custom.contains(key) ? Text(l.custom) : null,
                    trailing: Text(targets.values[key] == null ? '—' : formatNutrient(key, targets.values[key]!, l)),
                    onTap: () => _editTarget(context, ref, key, targets.values[key]),
                  ),
            ]),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.monitor_heart_outlined, color: context.colors.primary),
              title: Text(l.healthTitle),
              subtitle: Text(l.healthMeHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const HealthScreen()),
            ),
          ),
          _RemindersCard(data: data),
          Card(
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.water_drop_outlined, color: context.colors.primary),
                title: Text(l.waterGoal),
                trailing: Text('${waterGoal(data.user).round()} ml'),
                onTap: () async {
                  // null = cancelled, -1 = back to the computed goal.
                  final ml = await showDialog<double>(
                      context: context,
                      builder: (_) => _TargetDialog(title: l.waterGoal, initial: waterGoal(data.user)));
                  if (ml == null) return;
                  setPref(data.user, 'water_goal_ml', ml < 0 ? '' : '${ml.clamp(500, 6000)}');
                  data.changed();
                },
              ),
              // Not offered under 18; the caution stays visible next to the switch.
              if (adult)
                SwitchListTile(
                  secondary: Icon(Icons.timer_outlined, color: context.colors.primary),
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
          ),
          if (llmChoices().length > 1) const AiModelCard(),
          const _AppearanceCard(),
          _ProductsCard(data: data),
          if (healthSupported)
            Card(
              child: SwitchListTile(
                secondary: Icon(Icons.favorite_border, color: context.colors.primary),
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
            ),
          // Visible without the PIN, so only on a single-profile phone, and off until the owner says so.
          if (Platform.isAndroid && ref.watch(profilesProvider).biometricAllowed)
            Card(
              child: SwitchListTile(
                secondary: Icon(Icons.widgets_outlined, color: context.colors.primary),
                title: Text(l.widgetKcalTitle),
                subtitle: Text(l.widgetKcalHint),
                value: widgetShowsKcal(ref.watch(profilesProvider)),
                onChanged: (on) {
                  ref.read(profilesProvider).setSetting('widget_kcal', on ? '1' : '0');
                  data.changed(); // redraws this switch and the widget
                },
              ),
            ),
          if (ref.watch(profilesProvider).biometricAllowed && ref.watch(biometricsAvailableProvider).value == true)
            Card(
              child: SwitchListTile(
                secondary: Icon(Icons.fingerprint, color: context.colors.primary),
                title: Text(l.fingerprintTitle),
                subtitle: Text(l.fingerprintHint),
                value: ref.watch(profilesProvider).biometricEnabled(data.profile.id),
                onChanged: (on) async {
                  // Turning it on needs one successful scan, so it's the owner doing it.
                  if (on && !await authenticateFingerprint(ref, l.fingerprintReason(data.profile.name))) return;
                  ref.read(profilesProvider).setBiometric(data.profile.id, on);
                  data.changed();
                },
              ),
            ),
          Card(
            child: ListTile(
              leading: Icon(Icons.psychology_outlined, color: context.colors.primary),
              title: Text(l.aiKnowsTitle),
              subtitle: agent.hasValue ? null : Text(l.aiKnowsLoading),
              trailing: const Icon(Icons.chevron_right),
              enabled: agent.hasValue,
              onTap: () => open(MemoryScreen(agent: agent.requireValue)),
            ),
          ),
          Card(
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: context.colors.primary),
                title: Text(l.licenses),
                onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
              ),
              legalLinks(context),
            ]),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline, color: context.colors.primary),
              title: Text(l.switchProfile),
              onTap: () => ref.read(unlockedProvider.notifier).lock(),
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _logWeight(BuildContext context, ProfileData data, bool imperial) async {
    final l = AppLocalizations.of(context)!;
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _TargetDialog(title: imperial ? l.weightLb : l.weightKg, initial: null, allowReset: false),
    );
    if (v == null || v <= 0) return;
    logWeight(data.user, v, imperial: imperial, at: DateTime.now());
    data.changed();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.weightLogged)));
  }

  static String _describe(Body b, AppLocalizations l) {
    final sex = {Sex.female: l.female, Sex.male: l.male, Sex.other: l.other}[b.sex]!;
    final fi = cmToFeetInches(b.heightCm);
    final height = b.imperial ? "${fi.feet}′ ${fi.inches.round()}″" : '${b.heightCm.round()} cm';
    final weight = b.imperial ? '${kgToLb(b.weightKg).round()} lb' : '${b.weightKg.toStringAsFixed(1)} kg';
    final goal = {Goal.lose: l.goalLose, Goal.maintain: l.goalMaintain, Goal.gain: l.goalGain}[b.goal]!;
    return '$sex · ${b.birthYear} · $height · $weight · $goal';
  }

  Future<void> _editTarget(BuildContext context, WidgetRef ref, String key, double? current) async {
    final l = AppLocalizations.of(context)!;
    final data = ref.read(profileDataProvider);
    if (data == null) return;
    // null = cancelled, -1 = back to computed.
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _TargetDialog(title: l.editTarget(nutrientLabels(l)[key]!.$1), initial: current),
    );
    if (result == null) return;
    setOverride(data.user, key, result < 0 ? null : result);
    data.changed();
  }
}

/// Owns its controller (see _EditDialog in memory_screen.dart for why).
class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.title, required this.initial, this.allowReset = true});
  final String title;
  final double? initial;
  final bool allowReset;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final _value = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.round()}');

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final v = double.tryParse(_value.text.replaceAll(',', '.'));
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _value,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        if (widget.allowReset) TextButton(onPressed: () => Navigator.pop(context, -1.0), child: Text(l.resetTarget)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ElevatedButton(
          onPressed: v == null || v <= 0 ? null : () => Navigator.pop(context, v),
          child: Text(l.confirmSave),
        ),
      ],
    );
  }
}

class _RemindersCard extends ConsumerWidget {
  const _RemindersCard({required this.data});
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

    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          title: Text(l.remindersTitle, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(l.remindersHint),
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
      ]),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final billing = ref.watch(billingProvider).value;
    if (billing == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: billing.tier,
      builder: (context, tier, _) => Card(
        child: ListTile(
          leading: Icon(Icons.workspace_premium_outlined, color: context.colors.primary),
          title: Text(l.yourPlan),
          subtitle: Text(tierName(tier, l)),
          trailing: TextButton(onPressed: onOpen, child: Text(l.seePlans)),
        ),
      ),
    );
  }
}

/// System / light / dark, and the phone's wallpaper colours (Android 12+).
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final look = ref.watch(appearanceProvider);
    final set = ref.read(appearanceProvider.notifier).set;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.appearance, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
            ],
            selected: {look.mode},
            onSelectionChanged: (s) => set(mode: s.single),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.wallpaperColors),
            subtitle: Text(l.wallpaperColorsHint),
            value: look.wallpaper,
            onChanged: (on) => set(wallpaper: on),
          ),
        ]),
      ),
    );
  }
}

/// Every packaged product from Open Food Facts (all countries), as an optional download.
class _ProductsCard extends ConsumerStatefulWidget {
  const _ProductsCard({required this.data});
  final ProfileData data;

  @override
  ConsumerState<_ProductsCard> createState() => _ProductsCardState();
}

class _ProductsCardState extends ConsumerState<_ProductsCard> {
  var _failed = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = ref.watch(productsDownloadProvider);
    final info = productsInfo(widget.data.tools.products);
    final download = ref.read(productsDownloadProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.productsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(info == null ? l.productsNone : l.productsHave(NumberFormat.decimalPattern().format(info.rows), info.builtAt)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress / 100, semanticsLabel: l.aiDownloading),
            Text('${l.aiDownloading} $progress %'),
          ],
          if (_failed) Text(l.aiDownloadFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Align(
            alignment: Alignment.centerRight,
            child: progress != null
                ? TextButton(onPressed: download.cancel, child: Text(l.cancel))
                : info == null
                    ? TextButton.icon(
                        icon: const Icon(Icons.download),
                        label: Text(l.productsDownload(productsDownloadMb)),
                        onPressed: () async {
                          setState(() => _failed = false);
                          try {
                            await download.start();
                          } on Object catch (e) {
                            debugPrint('products download: $e');
                            if (mounted) setState(() => _failed = true);
                          }
                          if (mounted) setState(() {});
                        },
                      )
                    : TextButton(
                        onPressed: () => setState(download.remove),
                        child: Text(l.productsRemove),
                      ),
          ),
        ]),
      ),
    );
  }
}
