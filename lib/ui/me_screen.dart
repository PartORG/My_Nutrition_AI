import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
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
        Widget fact(
          String label,
          String value, {
          VoidCallback? onTap,
          Widget? under,
        }) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onTap == null ? label : '$label ›',
                    style: TextStyle(fontSize: 14, color: c.muted),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ?under,
                ],
              ),
            ),
          ),
        );
        final tiles = [
          if (body != null || !adult)
            for (final key in [...nutrientLabels(l).keys])
              if (targets.values[key] != null || !adult)
                _targetTile(context, ref, l, key, targets),
          StatTile(
            labelFirst: true,
            value:
                '${(waterGoal(data.user) / 1000).toStringAsFixed(1)} ${l.litreUnit}',
            label: l.water,
            onTap: () => _editWater(context, data),
          ),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                const MenuButton(),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 34,
                  backgroundColor: c.hero,
                  child: Text(
                    data.profile.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          data.profile.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _PlanChip(onOpen: () => open(const PaywallScreen())),
                    ],
                  ),
                ),
                RoundIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: l.settingsTitle,
                  onPressed: () => open(const SettingsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.aboutMe,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Flexible(
                        child: Material(
                          color: c.mint,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => open(const GoalsScreen()),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 44,
                                minWidth: 64,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  child: Text(
                                    l.edit,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: c.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (body == null) ...[
                    Text(l.setGoalsBody),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => open(const GoalsScreen()),
                      child: Text(l.setGoalsButton),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        fact(l.height, _height(body)),
                        fact(
                          l.weight,
                          points.isEmpty
                              ? weightText(body.weightKg, imperial)
                              : weightText(points.last.trend, imperial),
                          onTap: () => open(WeightScreen(data: data)),
                          under: points.length < 2
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    right: 12,
                                  ),
                                  child: SizedBox(
                                    height: 24,
                                    child: WeightChart(
                                      points: points,
                                      compact: true,
                                    ),
                                  ),
                                ),
                        ),
                        fact(
                          l.goal,
                          _goal(body.goal, l),
                          onTap: () => _editGoal(context, data, body),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_activity(body.activity, l)} · ${l.bornIn(body.birthYear)}',
                      style: TextStyle(color: c.muted, fontSize: 15),
                    ),
                  ],
                ],
              ),
            ),
            SectionTitle(
              l.dailyTargets,
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
              trailing: Text(
                l.tapToOverride,
                style: TextStyle(fontSize: 14, color: c.muted),
              ),
            ),
            if (!adult)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.under18, style: TextStyle(color: c.muted)),
              ),
            if (targets.values.isEmpty && adult && body != null)
              Text(l.targetsNone),
            _Grid(children: tiles),
            const SizedBox(height: 16),
            PanelList(
              children: [
                _Link(
                  icon: Icons.monitor_heart_outlined,
                  title: l.healthTitle,
                  subtitle: l.healthMeHint,
                  onTap: () => open(const HealthScreen()),
                ),
                _Link(
                  icon: Icons.history,
                  title: l.historyAndYear,
                  onTap: () => open(HistoryScreen(data: data)),
                ),
                _Link(
                  icon: Icons.bookmark_border,
                  title: l.savedRecipesTitle,
                  trailing: '$saved',
                  onTap: () => open(
                    Scaffold(
                      body: SafeArea(
                        child: PlanScreen(
                          data: data,
                          initialTab: PlanTab.recipes,
                        ),
                      ),
                    ),
                  ),
                ),
                _Link(
                  icon: Icons.lightbulb_outline,
                  title: l.aiKnowsTitle,
                  onTap: agent.hasValue
                      ? () => open(MemoryScreen(agent: agent.requireValue))
                      : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _targetTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    String key,
    ({Targets values, Set<String> custom, Map<String, String> limited}) targets,
  ) {
    final value = targets.values[key];
    final (n, unit) = value == null
        ? ('—', '')
        : formatNutrientParts(key, value, l);
    final note = targets.limited[key] != null
        ? l.limitShort
        : targets.custom.contains(key)
        ? l.custom
        : limitNutrients.contains(key)
        ? l.limitShort
        : null;
    return StatTile(
      labelFirst: true,
      dot: nutrientColors[key],
      value: unit.isEmpty ? n : '$n $unit',
      label: note == null
          ? nutrientLabels(l)[key]!.$1
          : '${nutrientLabels(l)[key]!.$1} · $note',
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
    setPref(data.user, 'water_goal_ml', v < 0 ? '' : '${v.round()}');
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

/// "Free plan · See plans": the tier, and the way to the plans.
class _PlanChip extends ConsumerWidget {
  const _PlanChip({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final billing = ref.watch(billingProvider).value;
    if (billing == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: billing.tier,
      builder: (context, tier, _) => Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: c.warm,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                l.planChip(tierName(tier, l)),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.onWarm,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two tiles per row (one at large text).
class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final per = MediaQuery.textScalerOf(context).scale(10) > 15 ? 1 : 2;
    return Column(
      children: [
        for (var i = 0; i < children.length; i += per) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + per; j++) ...[
                  if (j > i) const SizedBox(width: 10),
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

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle, trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
    leading: Icon(icon, color: context.colors.primary, size: 26),
    title: Text(title, style: const TextStyle(fontSize: 17)),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(fontSize: 15, color: context.colors.muted),
          ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ],
    ),
    onTap: onTap,
  );
}
