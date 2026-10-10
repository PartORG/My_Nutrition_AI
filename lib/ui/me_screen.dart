import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../data/conditions.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import 'goals_screen.dart';
import 'health_screen.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'theme.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profileDataProvider);
    if (data == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: data.changes,
      builder: (context, _, _) {
        final l = AppLocalizations.of(context)!;
        final body = loadBody(data.user);
        final targets = currentTargets(data.user, nutri: data.nutri, now: DateTime.now());
        final adult = body == null || computeTargets(body, now: DateTime.now()) != null;
        void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
        final scheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final allergies = [for (final r in data.user.select('SELECT allergen FROM user_allergens ORDER BY 1')) r['allergen'] as String];
        final conditions = [for (final c in myConditions(data.user)) conditionLabel(c.name, l)];
        // Compact: label over value, as many per row as fit.
        Widget info(String label, String value) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              Text(value, style: textTheme.bodyMedium),
            ]);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _CardTitle(icon: Icons.person_outline, title: l.aboutMe)),
                  if (body != null)
                    IconButton(
                      tooltip: l.editDetails,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => open(const GoalsScreen()),
                    ),
                ]),
                if (body == null) ...[
                  Text(l.setGoalsBody),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => open(const GoalsScreen()), child: Text(l.setGoalsButton)),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Wrap(spacing: 24, runSpacing: 12, children: [
                    info(l.profileName, data.profile.name),
                    if (body != null) ...[
                      info(l.sexShort, {Sex.female: l.female, Sex.male: l.male, Sex.other: l.other}[body.sex]!),
                      info(l.birthYear, '${body.birthYear}'),
                      info(l.height, _height(body)),
                      info(l.activity, _activity(body.activity, l)),
                      info(l.units, body.imperial ? l.imperial : l.metric),
                    ],
                    info(l.allergiesSection, allergies.isEmpty ? l.allergiesEmpty : allergies.join(', ')),
                    info(l.conditionsTitle, conditions.isEmpty ? l.allergiesEmpty : conditions.join(', ')),
                  ]),
                ),
              ]),
            ),
          ),
          WeightCard(data: data),
          Card.outlined(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _CardTitle(icon: Icons.flag_outlined, title: l.goalsTitle),
              ),
              if (!adult)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(l.under18, style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
              if (targets.values.isEmpty && adult) ListTile(title: Text(l.targetsNone)),
              // One row per target, divided: label left, value right; tap to edit.
              // Under 18 every target is manual, so all of them are listed for editing.
              ...ListTile.divideTiles(context: context, color: scheme.outlineVariant, tiles: [
                if (body != null)
                  ListTile(
                    title: Text(l.goal, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    subtitle: Text(_goal(body.goal, l), style: textTheme.titleMedium),
                    trailing: Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
                    onTap: () => _editGoal(context, data, body),
                  ),
                for (final key in nutrientLabels(l).keys)
                  if (targets.values[key] != null || !adult) _targetRow(context, ref, l, key, targets),
              ]),
            ]),
          ),
          _PlanCard(onOpen: () => open(const PaywallScreen())),
          Card.outlined(
            child: ListTile(
              leading: Icon(Icons.monitor_heart_outlined, color: scheme.primary),
              title: Text(l.healthTitle, style: textTheme.titleMedium?.copyWith(color: scheme.primary)),
              subtitle: Text(l.healthMeHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const HealthScreen()),
            ),
          ),
        ]);
      },
    );
  }

  Widget _targetRow(BuildContext context, WidgetRef ref, AppLocalizations l, String key,
      ({Targets values, Set<String> custom, Map<String, String> limited}) targets) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final value = targets.values[key];
    final (n, unit) = value == null ? ('—', '') : formatNutrientParts(key, value, l);
    final note = targets.limited[key] != null
        ? l.limitFrom(conditionLabel(targets.limited[key]!, l))
        : targets.custom.contains(key) ? l.custom : null;
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: nutrientColors[key], shape: BoxShape.circle),
      ),
      title: Text(nutrientLabels(l)[key]!.$1, style: textTheme.bodyLarge),
      subtitle: note == null ? null : Text(note, style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: n, style: textTheme.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            if (unit.isNotEmpty)
              TextSpan(text: ' $unit', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          textAlign: TextAlign.end,
        ),
        const SizedBox(width: 8),
        Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
      ]),
      onTap: () => _editTarget(context, ref, key, value),
    );
  }

  static String _height(Body b) {
    final fi = cmToFeetInches(b.heightCm);
    return b.imperial ? "${fi.feet}′ ${fi.inches.round()}″" : '${b.heightCm.round()} cm';
  }

  static String _goal(Goal g, AppLocalizations l) =>
      {Goal.lose: l.goalLose, Goal.maintain: l.goalMaintain, Goal.gain: l.goalGain}[g]!;

  static String _activity(Activity a, AppLocalizations l) => {
        Activity.sedentary: l.activitySedentary, Activity.light: l.activityLight,
        Activity.moderate: l.activityModerate, Activity.active: l.activityActive,
        Activity.veryActive: l.activityVeryActive,
      }[a]!;

  /// Lose / maintain / gain: saved into the body row, so computed targets follow.
  Future<void> _editGoal(BuildContext context, ProfileData data, Body body) async {
    final l = AppLocalizations.of(context)!;
    final goal = await showDialog<Goal>(
      context: context,
      builder: (context) => SimpleDialog(title: Text(l.goal), children: [
        for (final g in Goal.values)
          ListTile(
            title: Text(_goal(g, l)),
            trailing: g == body.goal ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, g),
          ),
      ]),
    );
    if (goal == null || goal == body.goal) return;
    saveBody(data.user, (
      sex: body.sex, birthYear: body.birthYear, heightCm: body.heightCm, weightKg: body.weightKg,
      activity: body.activity, goal: goal, imperial: body.imperial,
    ), now: DateTime.now());
    data.changed();
  }

  Future<void> _editTarget(BuildContext context, WidgetRef ref, String key, double? current) async {
    final l = AppLocalizations.of(context)!;
    final data = ref.read(profileDataProvider);
    if (data == null) return;
    // null = cancelled, -1 = back to computed.
    final result = await showDialog<double>(
      context: context,
      builder: (_) => TargetDialog(title: l.editTarget(nutrientLabels(l)[key]!.$1), initial: current),
    );
    if (result == null) return;
    setOverride(data.user, key, result < 0 ? null : result);
    data.changed();
  }
}

/// Owns its controller (see _EditDialog in memory_screen.dart for why).
class TargetDialog extends StatefulWidget {
  const TargetDialog({super.key, required this.title, required this.initial, this.allowReset = true});
  final String title;
  final double? initial;
  final bool allowReset;

  @override
  State<TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<TargetDialog> {
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

/// The latest weight, its change over 30 days, and logging a new one. On Me and Today.
/// Free: goals use the current weight. The trend chart is Basic.
class WeightCard extends StatelessWidget {
  const WeightCard({super.key, required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final body = loadBody(data.user);
    final imperial = body?.imperial ?? false;
    final w = weightNow(data.user, DateTime.now().subtract(const Duration(days: 30)));
    final now = body?.weightKg ?? w?.kg; // the weight the goals use
    String kg(double v) => (imperial ? kgToLb(v) : v).toStringAsFixed(1);
    final unit = imperial ? 'lb' : 'kg';
    final change = w?.change;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          Icon(Icons.monitor_weight_outlined, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(now == null ? l.weight : '${l.weight}: ${kg(now)} $unit',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (change != null)
                Text('${change > 0 ? '+' : change < 0 ? '−' : '±'}${kg(change.abs())} $unit · ${l.days(30)}',
                    style: TextStyle(color: context.colors.textSecondary)),
            ]),
          ),
          IconButton.filledTonal(
            tooltip: l.logWeight,
            icon: const Icon(Icons.add),
            onPressed: () => _log(context, imperial),
          ),
        ]),
      ),
    );
  }

  Future<void> _log(BuildContext context, bool imperial) async {
    final l = AppLocalizations.of(context)!;
    final v = await showDialog<double>(
      context: context,
      builder: (_) => TargetDialog(title: imperial ? l.weightLb : l.weightKg, initial: null, allowReset: false),
    );
    if (v == null || v <= 0) return;
    logWeight(data.user, v, imperial: imperial, at: DateTime.now());
    data.changed();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.weightLogged)));
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
      builder: (context, tier, _) => Card.outlined(
        child: ListTile(
          leading: Icon(Icons.workspace_premium_outlined, color: Theme.of(context).colorScheme.primary),
          title: Text(l.yourPlan,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
          subtitle: Text(tierName(tier, l)),
          // The whole tile, not a trailing button: "See plans" translated doesn't fit there at large text.
          trailing: Icon(Icons.chevron_right, semanticLabel: l.seePlans),
          onTap: onOpen,
        ),
      ),
    );
  }
}

/// A card's heading: M3 titleMedium in primary, with its icon.
class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(children: [
      Icon(icon, size: 20, color: primary),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: primary))),
    ]);
  }
}
