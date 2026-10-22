import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../agent/agent_tools.dart' show Nutrients;
import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'theme.dart';
import 'today_screen.dart' show NutrientBar;

/// The whole panel for one period, grouped as in nutrients.tsv: goal bars, upper limits, ≈ and ≥ marks.
/// Single sugars and amino acids wait behind "More".
class NutrientTable extends StatefulWidget {
  const NutrientTable({super.key, required this.values, this.goals = const {}, this.limits = const {},
      this.limited = const {}, this.approx = const {}, this.partial = const {}});
  final Nutrients values, goals, limits;

  /// Goals a condition turned into ceilings.
  final Set<String> limited;
  final Set<String> approx, partial;

  @override
  State<NutrientTable> createState() => _NutrientTableState();
}

class _NutrientTableState extends State<NutrientTable> {
  var _more = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final w = widget;
    final over = {for (final (k, _, _) in overLimits(w.values, w.limits)) k};
    Widget row(String k) {
      final eaten = w.values[k] ?? 0;
      final mark = w.approx.contains(k) ? '≈' : w.partial.contains(k) ? '≥' : '';
      final ceiling = limitKeys.contains(k) || w.limited.contains(k);
      if (w.goals[k] case final goal? when goal > 0) {
        return NutrientBar(nutrient: k, eaten: eaten, goal: goal, limited: w.limited.contains(k), mark: mark,
            upper: ceiling ? null : w.limits[k], overUpper: over.contains(k));
      }
      if (w.limits[k] case final limit?) {
        return NutrientBar(nutrient: k, eaten: eaten, goal: limit, limited: true, mark: mark, overUpper: over.contains(k));
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(nutrientName(l, k), style: const TextStyle(fontSize: 14))),
          Text('$mark${formatNutrient(k, eaten, l)}', style: TextStyle(fontSize: 13, color: c.muted, fontFeatures: AppText.tabular)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final MapEntry(key: group, value: keys) in nutrientGroups.entries)
        if (_more || !moreGroups.contains(group)) ...[
          SectionLabel(l.nutrientGroup(group)),
          for (final k in keys) row(k),
        ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => setState(() => _more = !_more),
          child: Text(_more ? l.fewerNutrients : l.moreNutrients),
        ),
      ),
      Text(l.panelNote, style: AppText.caption.copyWith(color: c.muted)),
    ]);
  }
}

/// Basic: every nutrient of a day (back as far as the tier's history reaches) or of the week ending that day, as
/// daily averages over the days with logs.
class AllNutrientsScreen extends StatefulWidget {
  const AllNutrientsScreen({super.key, required this.data});
  final ProfileData data;

  @override
  State<AllNutrientsScreen> createState() => _AllNutrientsScreenState();
}

class _AllNutrientsScreenState extends State<AllNutrientsScreen> {
  var _week = false;
  var _back = 0; // days before today

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final data = widget.data;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      body: SafeArea(
        child: TierBuilder(builder: (context, tier) {
          if (!tier.includes(Tier.basic)) return const PaywallScreen();
          final now = DateTime.now();
          final step = _week ? 7 : 1;
          // The period's first day stays inside the tier's history (older logs are hidden, never deleted).
          final canGoBack = _back + step + step - 1 < tier.historyDays;
          final day = DateTime(now.year, now.month, now.day - _back);
          final (dayStart, end) = dayRange(day);
          final from = _week ? DateTime(day.year, day.month, day.day - 6) : dayStart;
          final p = panelTotals(data.user, data.nutri, from, end);
          final logged = _week ? dailyTotals(data.user, day, 7).where((d) => d.entries > 0).length : 1;
          final t = currentTargets(data.user, nutri: data.nutri, now: now);
          final title = _week
              ? '${DateFormat.MMMd(locale).format(from)} – ${DateFormat.MMMd(locale).format(day)}'
              : _back == 0
                  ? l.tabToday
                  : DateFormat.MMMEd(locale).format(day);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            ScreenHeader(title: l.allNutrientsTitle, back: true),
            PillTabs<bool>(
              values: const [false, true],
              selected: _week,
              label: (w) => w ? l.periodWeek : l.periodDay,
              onChanged: (w) => setState(() => _week = w),
            ),
            Row(children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                icon: const Icon(Icons.chevron_left),
                onPressed: canGoBack ? () => setState(() => _back += step) : null,
              ),
              Expanded(child: Text(title, textAlign: TextAlign.center, style: AppText.section)),
              IconButton(
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                icon: const Icon(Icons.chevron_right),
                onPressed: _back > 0 ? () => setState(() => _back = (_back - step).clamp(0, _back)) : null,
              ),
            ]),
            NutrientTable(
              values: {for (final e in p.totals.entries) e.key: e.value / (logged == 0 ? 1 : logged)},
              goals: t.values,
              limits: dayLimits(data.user, data.nutri, now: now),
              limited: t.limited.keys.toSet(),
              approx: p.approx,
              partial: p.partial,
            ),
          ]);
        }),
      ),
    );
  }
}
