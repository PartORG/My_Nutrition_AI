import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'nutrients.dart';
import 'period_view.dart';
import 'theme.dart';
import 'today_screen.dart' show NutrientBar, limitNutrients;

/// Pro: the last 12 calendar months — calories per month vs goal, a logging calendar,
/// nutrient averages with the best and worst month, weight, and what was eaten most.
class YearView extends StatelessWidget {
  const YearView({super.key, required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: data.changes,
      builder: (context, _, _) {
        final l = AppLocalizations.of(context)!;
        final now = DateTime.now();
        final first = DateTime(now.year, now.month - 11);
        // UTC dates: a DST change would make a local difference one hour short of a day.
        final days = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(first.year, first.month)).inDays + 1;
        final series = dailyTotals(data.user, now, days);
        final months = monthlyAverages(series);
        final logged = months.where((m) => m.logged > 0).toList();
        final t = currentTargets(data.user, nutri: data.nutri, now: now);
        final targets = t.values;
        final names = nutrientLabels(l);
        final imperial = loadBody(data.user)?.imperial ?? false;
        final weights = weightsSince(data.user, first);
        final top = topFoods(data.user, first);
        final loggedDays = series.where((d) => d.entries > 0).toList();
        double yearAvg(String k) =>
            loggedDays.isEmpty ? 0 : loggedDays.fold(0.0, (s, d) => s + d.totals[k]!) / loggedDays.length;
        String kg(double v) => (imperial ? kgToLb(v) : v).toStringAsFixed(1);

        final change = weights.length < 2 ? null : weights.last.kg - weights.first.kg;
        return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: StatTile(value: '${loggedDays.length}', label: l.daysLogged)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: '${bestStreak(series)}', label: l.bestStreak)),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  value: change == null ? '–' : '${change >= 0 ? '+' : '−'}${kg(change.abs())} ${imperial ? 'lb' : 'kg'}',
                  label: l.sinceMonth(DateFormat.MMM(Localizations.localeOf(context).toString()).format(first)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          ChartSection(
            title: l.yearCalendar,
            child: _YearCalendar(series: series, goal: targets['kcal']),
          ),
          if (top.isNotEmpty)
            ChartSection(
              title: l.yearTopFoods,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in top) Tag('${f.label} · ${f.times}×', tone: TagTone.neutral, big: true),
              ]),
            ),
          ChartSection(
            title: l.yearCalories,
            child: SizedBox(
              height: 200,
              child: DailyBarChart(
                series: [for (final m in months) (day: m.month, totals: m.avg, entries: m.logged)],
                nutrient: 'kcal',
                goal: targets['kcal'],
                monthly: true,
              ),
            ),
          ),
          if (logged.isNotEmpty)
            ChartSection(
              title: l.yearNutrients,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final k in ['protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg'])
                  if (targets[k] case final goal?) ...[
                    NutrientBar(nutrient: k, eaten: yearAvg(k), goal: goal, limited: t.limited.containsKey(k)),
                    if (logged.length >= 2)
                      () {
                        // A ceiling is best low; a target is best close to the goal.
                        final ceiling = limitNutrients.contains(k) || t.limited.containsKey(k);
                        double off(MonthStats m) => ceiling ? m.avg[k]! : (m.avg[k]! - goal).abs();
                        final sorted = [...logged]..sort((a, b) => off(a).compareTo(off(b)));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l.yearBestWorst(names[k]!.$1, DateFormat.MMM().format(sorted.first.month),
                                DateFormat.MMM().format(sorted.last.month)),
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                          ),
                        );
                      }(),
                  ],
              ]),
            ),
          ChartSection(
            title: l.weightTrend,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              weightChart(weights, imperial: imperial, l: l),
              if (weights.length >= 2) ...[
                const SizedBox(height: 8),
                Text('${kg(weights.first.kg)} → ${kg(weights.last.kg)} ${imperial ? 'lb' : 'kg'} '
                    '(${weights.last.kg >= weights.first.kg ? '+' : '−'}${kg((weights.last.kg - weights.first.kg).abs())})'),
              ],
            ]),
          ),
        ]);
      },
    );
  }
}

/// One row per month, one cell per day, coloured by how close the day's calories were to the goal.
class _YearCalendar extends StatelessWidget {
  const _YearCalendar({required this.series, required this.goal});
  final List<DayTotals> series;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final byDay = {for (final d in series) DateTime(d.day.year, d.day.month, d.day.day): d};
    final first = series.first.day;
    final on = context.colors.primary, near = on.withValues(alpha: .5), far = const Color(0xFFEB6834);
    final empty = context.colors.accent.withValues(alpha: .2);
    Color? color(DayTotals? d) {
      if (d == null) return null; // not in the range (future, or no such day)
      if (d.entries == 0) return empty;
      if (goal == null) return on;
      final off = (d.totals['kcal']! / goal! - 1).abs();
      return off <= .1 ? on : off <= .25 ? near : far;
    }

    Widget swatch(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 11))),
        ]);
    final muted = TextStyle(color: context.colors.textSecondary, fontSize: 11);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(
        child: Column(children: [
          for (var m = 0; m < 12; m++)
            () {
              final month = DateTime(first.year, first.month + m);
              return Row(children: [
                SizedBox(width: 18, child: Text(DateFormat.MMM().format(month).substring(0, 1), style: muted)),
                for (var day = 1; day <= 31; day++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(.75),
                        decoration: BoxDecoration(
                          // DateTime(y, m, 31) in a 30-day month rolls over into the next one.
                          color: DateTime(month.year, month.month, day).month == month.month
                              ? color(byDay[DateTime(month.year, month.month, day)])
                              : null,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ),
              ]);
            }(),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 4, children: [
        if (goal != null) ...[
          swatch(on, l.calendarOnGoal),
          swatch(near, l.calendarNear),
          swatch(far, l.calendarFar),
        ],
        swatch(empty, l.calendarNotLogged),
      ]),
    ]);
  }
}
