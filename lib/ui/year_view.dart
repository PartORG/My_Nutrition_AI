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

/// Pro: this calendar year — a logging calendar, calories per month vs goal,
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
        final first = DateTime(now.year);
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
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
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

/// Jan–Dec in a 4 × 3 grid, each month a block of week rows; a cell per day, coloured by how close
/// the day's calories were to the goal. Days still to come are faint.
class _YearCalendar extends StatelessWidget {
  const _YearCalendar({required this.series, required this.goal});
  final List<DayTotals> series;
  final double? goal;

  static const _far = Color(0xFFE9A15A);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final byDay = {for (final d in series) DateTime(d.day.year, d.day.month, d.day.day): d};
    final year = series.first.day.year;
    // Near: the green faded toward the card, so it stays apart from "on" in both themes.
    final on = c.primary, near = Color.lerp(on, c.surface, .45)!, empty = c.border, future = empty.withValues(alpha: .4);
    Color color(DayTotals? d) {
      if (d == null) return future;
      if (d.entries == 0) return empty;
      if (goal == null) return on;
      final off = (d.totals['kcal']! / goal! - 1).abs();
      return off <= .1 ? on : off <= .25 ? near : _far;
    }

    Widget month(int m) {
      // Day 0 of the next month is this month's last day.
      final days = DateTime(year, m + 1, 0).day;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat.MMM(locale).format(DateTime(year, m)), style: TextStyle(fontSize: 13, color: c.ink2)),
        const SizedBox(height: 6),
        for (var week = 0; week * 7 < days; week++)
          Row(children: [
            for (var i = 1; i <= 7; i++)
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: week * 7 + i > days
                      ? null
                      : Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: color(byDay[DateTime(year, m, week * 7 + i)]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                ),
              ),
          ]),
      ]);
    }

    Widget swatch(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(color: c.ink2, fontSize: 13))),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(
        child: Column(children: [
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var col = 0; col < 4; col++) ...[
                if (col > 0) const SizedBox(width: 14),
                Expanded(child: month(row * 4 + col + 1)),
              ],
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 6, children: [
        if (goal != null) ...[
          swatch(on, l.calendarOnGoal),
          swatch(near, l.calendarNear),
          swatch(_far, l.calendarFar),
        ],
        swatch(empty, l.calendarNotLogged),
      ]),
    ]);
  }
}
