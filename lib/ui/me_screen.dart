import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../billing/billing.dart' show Tier;
import '../data/diary.dart';
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import '../data/plan.dart' show savedRecipeIds;
import 'goals_screen.dart';
import 'health_screen.dart';
import 'history_screen.dart';
import 'kit.dart';
import 'memory_screen.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'plan_screen.dart';
import 'settings_screen.dart' show SettingsScreen;
import 'theme.dart';
import 'today_screen.dart' show limitNutrients;
import 'weight_screen.dart';

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
        final c = context.colors;
        final body = loadBody(data.user);
        final targets = currentTargets(
          data.user,
          nutri: data.nutri,
          now: DateTime.now(),
        );
        final adult =
            body == null || computeTargets(body, now: DateTime.now()) != null;
        void open(Widget screen) => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen))
            .then((_) => data.changed());
        final agent = ref.watch(agentProvider);
        final saved = savedRecipeIds(data.tools).length;
        final points = weightTrend(
          weightsSince(
            data.user,
            DateTime.now().subtract(const Duration(days: 30)),
          ),
        );
        final imperial = body?.imperial ?? false;
        final dark = Theme.of(context).brightness == Brightness.dark;
        // The boxes on the green hero: a little darker at night, lighter by day.
        final inner = Color.alphaBlend(
            dark ? c.background.withValues(alpha: .45) : c.surface.withValues(alpha: .7), c.heroSurface);
        Widget fact(String label, String value, {VoidCallback? onTap}) {
          final parts = value.split(' ');
          return Expanded(
            child: Material(
              color: inner,
              borderRadius: BorderRadius.circular(Radii.tile),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(Radii.tile),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(onTap == null ? label : '$label ›', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: c.muted)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      // One text ("165 cm"), the unit smaller.
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: parts.first),
                        if (parts.length > 1)
                          TextSpan(text: ' ${parts.skip(1).join(' ')}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                      ]), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.ink, fontFeatures: AppText.tabular)),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }

        final macros = [
          for (final key in ['protein_g', 'carbs_g', 'fat_g'])
            if (targets.values[key] != null || !adult) key,
        ];
        final others = [
          for (final key in ['fiber_g', 'sugar_g', 'sodium_mg'])
            if (targets.values[key] != null || !adult) key,
        ];
        final showEnergy = targets.values['kcal'] != null || !adult;
        // Large text: Edit goes under the name instead of squeezing it.
        final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
        final edit = Material(
          color: inner,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.tile),
            onTap: () => open(const GoalsScreen()),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 56),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l.edit, style: AppText.item.copyWith(color: c.ink)),
                ),
              ),
            ),
          ),
        );
        return Column(
          children: [
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: ScreenHeader(
                overline: l.meOverline,
                title: l.tabMe,
                trailing: RoundIconButton(
                  icon: Icons.tune,
                  tooltip: l.settingsTitle,
                  onPressed: () => open(const SettingsScreen()),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: c.heroSurface, borderRadius: BorderRadius.circular(Radii.hero)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: c.primary,
                          child: Text(
                            data.profile.name.characters.first.toUpperCase(),
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.onPrimary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Semantics(
                              header: true,
                              child: Text(data.profile.name, style: AppText.title.copyWith(color: c.ink)),
                            ),
                            const SizedBox(height: 4),
                            _PlanChip(onOpen: () => open(const PaywallScreen())),
                          ]),
                        ),
                        if (!stacked) const SizedBox(width: 8),
                        if (!stacked) edit,
                      ]),
                      if (stacked) ...[const SizedBox(height: 10), Align(alignment: AlignmentDirectional.centerStart, child: edit)],
                      const SizedBox(height: 14),
                      if (body == null) ...[
                        Text(l.setGoalsBody, style: TextStyle(color: c.ink2)),
                        const SizedBox(height: 10),
                        FilledButton(onPressed: () => open(const GoalsScreen()), child: Text(l.setGoalsButton)),
                      ] else ...[
                        IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            fact(l.height, _height(body)),
                            const SizedBox(width: 8),
                            fact(
                              l.weight,
                              points.isEmpty ? weightText(body.weightKg, imperial) : weightText(points.last.trend, imperial),
                              onTap: () => open(WeightScreen(data: data)),
                            ),
                            const SizedBox(width: 8),
                            fact(l.bornLabel, '${body.birthYear}'),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: inner,
                          borderRadius: BorderRadius.circular(Radii.tile + 2),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(Radii.tile + 2),
                            onTap: () => _editGoal(context, data, body),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                              child: Row(children: [
                                ExcludeSemantics(
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                                    child: Icon(
                                      switch (body.goal) {
                                        Goal.lose => Icons.trending_down,
                                        Goal.maintain => Icons.trending_flat,
                                        Goal.gain => Icons.trending_up,
                                      },
                                      color: c.onPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(l.goalIs(inSentence(context, _goal(body.goal, l))),
                                        style: AppText.item.copyWith(color: c.ink)),
                                    Text(_activity(body.activity, l), style: AppText.caption.copyWith(fontSize: 13, color: c.muted)),
                                  ]),
                                ),
                                Icon(Icons.chevron_right, color: c.muted),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  SectionTitle(
                    l.dailyTargets,
                    padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
                    trailing: Text(l.tapToOverride, textAlign: TextAlign.end, style: AppText.caption.copyWith(color: c.muted)),
                  ),
                  if (!adult)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l.under18, style: TextStyle(color: c.muted)),
                    ),
                  if (targets.values.isEmpty && adult && body != null)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.targetsNone)),
                  if (showEnergy) ...[
                    _energyCard(context, ref, l, targets),
                    const SizedBox(height: 8),
                  ],
                  if (macros.isNotEmpty) ...[
                    _Grid(per: 3, children: [for (final k in macros) _macroTile(context, ref, l, k, targets)]),
                    const SizedBox(height: 8),
                  ],
                  PanelList(
                    children: [
                      for (final k in others) _targetRow(context, ref, l, k, targets),
                      _TargetRow(
                        color: context.nutrientColor('water'),
                        label: l.water,
                        value: '${(waterGoal(data.user) / 1000).toStringAsFixed(1)} ${l.litreUnit}',
                        onTap: () => _editWater(context, data),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PanelList(
                    children: [
                      _Link(
                        icon: Icons.favorite_border,
                        color: context.nutrientColor('fiber_g'),
                        title: l.healthTitle,
                        subtitle: l.healthMeHint,
                        onTap: () => open(const HealthScreen()),
                      ),
                      _Link(
                        icon: Icons.history,
                        color: context.nutrientColor('water'),
                        title: l.historyAndYear,
                        onTap: () => open(HistoryScreen(data: data)),
                      ),
                      _Link(
                        icon: Icons.bookmark_border,
                        color: context.nutrientColor('protein_g'),
                        title: l.savedRecipesTitle,
                        trailing: '$saved',
                        onTap: () => open(
                          Scaffold(
                            body: SafeArea(
                              child: PlanScreen(
                                data: data,
                                initialTab: PlanTab.recipes,
                                back: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _Link(
                        icon: Icons.lightbulb_outline,
                        color: context.nutrientColor('sugar_g'),
                        title: l.aiKnowsTitle,
                        onTap: agent.hasValue ? () => open(MemoryScreen(agent: agent.requireValue)) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// "custom", "max" or nothing: why a target is what it is.
  static String? _note(AppLocalizations l, String key, ({Targets values, Set<String> custom, Map<String, String> limited}) t) =>
      t.limited[key] != null
          ? l.limitShort
          : t.custom.contains(key)
              ? l.custom
              : limitNutrients.contains(key)
                  ? l.limitShort
                  : null;

  /// Energy: the calorie target, and the macro split it's made of as one bar.
  Widget _energyCard(BuildContext context, WidgetRef ref, AppLocalizations l,
      ({Targets values, Set<String> custom, Map<String, String> limited}) targets) {
    final c = context.colors;
    final kcal = targets.values['kcal'];
    final note = _note(l, 'kcal', targets);
    final split = [
      for (final (k, perG) in [('protein_g', 4.0), ('carbs_g', 4.0), ('fat_g', 9.0)])
        if ((targets.values[k] ?? 0) > 0) (targets.values[k]! * perG, context.nutrientColor(k)),
    ];
    return Panel(
      onTap: () => _editTarget(context, ref, 'kcal', kcal),
      child: Row(children: [
        IconTile(icon: Icons.local_fire_department_outlined, color: context.nutrientColor('kcal'), size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note == null ? l.energy : '${l.energy} · $note', style: AppText.caption.copyWith(fontSize: 13, color: c.muted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: kcal == null ? '—' : NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(kcal.round())),
                TextSpan(text: ' ${l.kcal}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted)),
              ]), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.ink, fontFeatures: AppText.tabular)),
            ),
          ]),
        ),
        if (split.isNotEmpty) ...[
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: SizedBox(
              width: 96,
              child: Row(children: [
                for (final (i, (w, color)) in split.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: w.round().clamp(1, 1 << 20),
                    child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  /// Protein, carbs, fat: a small card each, the name in its colour, "CUSTOM" when overridden.
  Widget _macroTile(BuildContext context, WidgetRef ref, AppLocalizations l, String key,
      ({Targets values, Set<String> custom, Map<String, String> limited}) targets) {
    final c = context.colors;
    final value = targets.values[key];
    final (n, unit) = value == null ? ('—', '') : formatNutrientParts(key, value, l);
    final note = _note(l, key, targets);
    final color = context.nutrientColor(key);
    return Panel(
      radius: Radii.tile + 2,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      onTap: () => _editTarget(context, ref, key, value),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(nutrientLabels(l)[key]!.$1,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: n),
            if (unit.isNotEmpty) TextSpan(text: ' $unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
          ]), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink, fontFeatures: AppText.tabular)),
        ),
        if (note != null)
          Text(note.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6, color: color)),
      ]),
    );
  }

  /// Fiber, sugar, sodium: a row each in one card, "Sugar · max".
  Widget _targetRow(BuildContext context, WidgetRef ref, AppLocalizations l, String key,
      ({Targets values, Set<String> custom, Map<String, String> limited}) targets) {
    final value = targets.values[key];
    return _TargetRow(
      color: context.nutrientColor(key),
      label: nutrientLabels(l)[key]!.$1,
      note: _note(l, key, targets),
      value: value == null ? '—' : formatNutrient(key, value, l),
      onTap: () => _editTarget(context, ref, key, value),
    );
  }

  Future<void> _editWater(BuildContext context, ProfileData data) async {
    final l = AppLocalizations.of(context)!;
    final v = await showDialog<double>(
      context: context,
      builder: (_) => TargetDialog(
        title: '${l.waterGoal} (ml)',
        initial: waterGoal(data.user),
      ),
    );
    if (v == null) return;
    setPref(data.user, 'water_goal_ml', v < 0 ? '' : '${v.round().clamp(500, 6000)}');
    data.changed();
  }

  static String _height(Body b) {
    final fi = cmToFeetInches(b.heightCm);
    return b.imperial
        ? "${fi.feet}′ ${fi.inches.round()}″"
        : '${b.heightCm.round()} cm';
  }

  static String _goal(Goal g, AppLocalizations l) => {
    Goal.lose: l.goalLose,
    Goal.maintain: l.goalMaintain,
    Goal.gain: l.goalGain,
  }[g]!;

  static String _activity(Activity a, AppLocalizations l) => {
    Activity.sedentary: l.activitySedentary,
    Activity.light: l.activityLight,
    Activity.moderate: l.activityModerate,
    Activity.active: l.activityActive,
    Activity.veryActive: l.activityVeryActive,
  }[a]!;

  /// Lose / maintain / gain: saved into the body row, so computed targets follow.
  Future<void> _editGoal(
    BuildContext context,
    ProfileData data,
    Body body,
  ) async {
    final l = AppLocalizations.of(context)!;
    final goal = await showDialog<Goal>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.goal),
        children: [
          for (final g in Goal.values)
            ListTile(
              title: Text(_goal(g, l)),
              trailing: g == body.goal ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, g),
            ),
        ],
      ),
    );
    if (goal == null || goal == body.goal) return;
    saveBody(data.user, (
      sex: body.sex,
      birthYear: body.birthYear,
      heightCm: body.heightCm,
      weightKg: body.weightKg,
      activity: body.activity,
      goal: goal,
      imperial: body.imperial,
    ), now: DateTime.now());
    data.changed();
  }

  Future<void> _editTarget(
    BuildContext context,
    WidgetRef ref,
    String key,
    double? current,
  ) async {
    final l = AppLocalizations.of(context)!;
    final data = ref.read(profileDataProvider);
    if (data == null) return;
    // null = cancelled, -1 = back to computed.
    final result = await showDialog<double>(
      context: context,
      builder: (_) => TargetDialog(
        title: l.editTarget(nutrientLabels(l)[key]!.$1),
        initial: current,
      ),
    );
    if (result == null) return;
    setOverride(data.user, key, result < 0 ? null : result);
    data.changed();
  }
}

/// Owns its controller (see _EditDialog in memory_screen.dart for why).
class TargetDialog extends StatefulWidget {
  const TargetDialog({
    super.key,
    required this.title,
    required this.initial,
    this.allowReset = true,
    this.valid,
  });
  final String title;
  final double? initial;
  final bool allowReset;

  /// Extra check on the number; a failing one shows "Enter a valid number".
  final bool Function(double)? valid;

  @override
  State<TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<TargetDialog> {
  late final _value = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.round()}',
  );

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final parsed = double.tryParse(_value.text.replaceAll(',', '.'));
    final v = parsed != null && (widget.valid?.call(parsed) ?? true) ? parsed : null;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _value,
        autofocus: true,
        decoration: InputDecoration(errorText: _value.text.trim().isNotEmpty && v == null ? l.invalidNumber : null),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        if (widget.allowReset)
          TextButton(
            onPressed: () => Navigator.pop(context, -1.0),
            child: Text(l.resetTarget),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: v == null || v <= 0
              ? null
              : () => Navigator.pop(context, v),
          child: Text(l.confirmSave),
        ),
      ],
    );
  }
}

/// "PRO · See plans": the tier, and the way to the plans.
class _PlanChip extends ConsumerWidget {
  const _PlanChip({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final billing = ref.watch(billingProvider).value;
    if (billing == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: billing.tier,
      builder: (context, tier, _) => Semantics(
        button: true,
        label: l.planChip(tierName(tier, l)),
        excludeSemantics: true,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(Radii.chip),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Tag(tierName(tier, l).toUpperCase(), tone: tier == Tier.free ? TagTone.neutral : TagTone.gold),
              Text(l.seePlans,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.nutrientColor('carbs_g'))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// [per] tiles to a row (one at large text).
class _Grid extends StatelessWidget {
  const _Grid({required this.children, this.per = 2});
  final List<Widget> children;
  final int per;

  @override
  Widget build(BuildContext context) {
    final per = MediaQuery.textScalerOf(context).scale(10) > 15 ? 1 : this.per;
    return Column(
      children: [
        for (var i = 0; i < children.length; i += per) ...[
          if (i > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + per; j++) ...[
                  if (j > i) const SizedBox(width: 8),
                  Expanded(
                    child: j < children.length
                        ? children[j]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A target in the list card: its dot, name ("Sugar · max") and value; tap to override.
class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.color, required this.label, required this.value, required this.onTap, this.note});
  final Color color;
  final String label, value;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: label, style: AppText.body.copyWith(fontSize: 15, color: c.ink)),
                if (note != null) TextSpan(text: ' · $note', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.muted)),
              ])),
            ),
            const SizedBox(width: 8),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink, fontFeatures: AppText.tabular)),
          ]),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle, trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      leading: IconTile(icon: icon, color: color, size: 40),
      title: Text(title, style: AppText.item.copyWith(fontSize: 16, color: c.ink)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: AppText.caption.copyWith(fontSize: 13, color: c.muted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null && trailing != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: tint(context, color, alpha: .2), borderRadius: BorderRadius.circular(8)),
              child: Text(trailing!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: c.muted),
        ],
      ),
      onTap: onTap,
    );
  }
}
