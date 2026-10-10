import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import 'nutrients.dart';
import 'theme.dart';
import 'home_screen.dart' show HomeTab, homeTabProvider;
import 'today_screen.dart';

/// The week in a few lines, computed from the logs; "Ideas for next week" asks the
/// assistant about the weakest point.
class _WeekReviewCard extends ConsumerWidget {
  const _WeekReviewCard({required this.review});
  final WeekReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final r = review;
    final names = nutrientLabels(l);
    final lines = [
      l.reviewLoggedDays(r.logged),
      if (r.avgKcal != null && r.kcalGoal != null) l.reviewKcal(r.avgKcal!.round(), r.kcalGoal!.round()),
      if (r.lowProtein > 0) l.reviewUnder(names['protein_g']!.$1, r.lowProtein),
      if (r.lowFiber > 0) l.reviewUnder(names['fiber_g']!.$1, r.lowFiber),
      if (r.overSugar > 0) l.reviewOver(names['sugar_g']!.$1, r.overSugar),
      if (r.overSodium > 0) l.reviewOver(names['sodium_mg']!.$1, r.overSodium),
      l.reviewWater(r.avgWater.round(), r.waterGoal.round()),
      if (r.topFood != null) l.reviewTop(r.topFood!),
    ];
    final focus = r.focus;
    return Card(
      color: context.colors.cardGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.weekReviewTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final t in lines) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• $t')),
          if (focus != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(l.reviewIdeas),
                onPressed: () {
                  final name = inSentence(context, names[focus]!.$1);
                  ref.read(homeTabProvider.notifier).go(HomeTab.chat);
                  ref.read(agentProvider).value?.send(
                      focus == 'sugar_g' || focus == 'sodium_mg' ? l.reviewAskLow(name) : l.reviewAskHigh(name));
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// Basic: the last [days] days — calories per day, daily averages vs goals,
/// streak, weight trend.
class PeriodView extends StatelessWidget {
  const PeriodView({super.key, required this.data, required this.days});
  final ProfileData data;
  final int days;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: data.changes,
      builder: (context, _, _) {
        final l = AppLocalizations.of(context)!;
        final now = DateTime.now();
        final series = dailyTotals(data.user, now, days);
        final logged = series.where((d) => d.entries > 0).toList();
        final t = currentTargets(data.user, nutri: data.nutri, now: now);
        final targets = t.values;
        // Averages over days that have logs: unlogged days aren't "0 kcal eaten".
        double avg(String k) => logged.isEmpty ? 0 : logged.fold(0.0, (s, d) => s + d.totals[k]!) / logged.length;
        final streak = loggingStreak(data.user, now);
        final body = loadBody(data.user);
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (days == 7) _WeekReviewCard(review: weeklyReview(data.user, targets, now)),
          ChartSection(
            title: l.caloriesPerDay,
            child: SizedBox(height: 200, child: DailyBarChart(series: series, nutrient: 'kcal', goal: targets['kcal'])),
          ),
          if (logged.isNotEmpty)
            ChartSection(
              title: l.dailyAverage(logged.length),
              child: Column(children: [
                for (final k in ['kcal', 'protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg'])
                  if (targets[k] != null)
                    NutrientBar(nutrient: k, eaten: avg(k), goal: targets[k]!, limited: t.limited.containsKey(k)),
              ]),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_fire_department, color: Color(0xFFEB6834), size: 32),
              title: Text(l.streakDays(streak), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          ChartSection(
            title: l.weightTrend,
            child: weightChart(
              weightsSince(data.user, now.subtract(Duration(days: days < 30 ? 90 : 365))),
              imperial: body?.imperial ?? false,
              l: l,
            ),
          ),
        ]);
      },
    );
  }
}

class ChartSection extends StatelessWidget {
  const ChartSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

/// One nutrient per day, so no legend box; the section title names it. Thin
/// bars with rounded tops, a dashed goal line with its label, a tooltip per bar.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({super.key, required this.series, required this.nutrient, required this.goal});
  final List<DayTotals> series;
  final String nutrient;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = nutrientColors[nutrient]!;
    final month = series.length > 7;
    final quarter = series.length > 31;
    final maxY = [goal ?? 0, ...series.map((d) => d.totals[nutrient]!)].reduce((a, b) => a > b ? a : b) * 1.15;
    final muted = TextStyle(color: context.colors.textSecondary, fontSize: 11);
    return BarChart(BarChartData(
      maxY: maxY <= 0 ? 100 : maxY,
      alignment: BarChartAlignment.spaceBetween,
      barGroups: [
        for (final (i, d) in series.indexed)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: d.totals[nutrient]!,
              color: color,
              width: quarter ? 2 : month ? 6 : 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
      ],
      extraLinesData: ExtraLinesData(horizontalLines: [
        if (goal != null)
          HorizontalLine(
            y: goal!,
            color: context.colors.textSecondary,
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: muted,
              labelResolver: (_) => nutrient == 'kcal' ? l.goalLine(goal!.round()) : formatNutrient(nutrient, goal!, l),
            ),
          ),
      ]),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: context.colors.accent.withValues(alpha: .25), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) =>
                v == meta.max ? const SizedBox.shrink() : Text('${v.round()}', style: muted),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= series.length) return const SizedBox.shrink();
              final day = series[i].day;
              // Week: weekday letters; month: every 5th day number; 90 days: every 15th.
              if (month && (series.length - 1 - i) % (quarter ? 15 : 5) != 0) return const SizedBox.shrink();
              return Text(month ? '${day.day}' : DateFormat.E().format(day).substring(0, 2), style: muted);
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => context.colors.textPrimary,
          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
            '${DateFormat('EEE d MMM').format(series[group.x].day)}\n${formatNutrient(nutrient, rod.toY, l)}',
            TextStyle(color: context.colors.surface, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }
}

Widget weightChart(List<({DateTime at, double kg})> points, {required bool imperial, required AppLocalizations l}) =>
    TrendChart(
      lines: [
        [for (final p in points) (at: p.at, y: imperial ? kgToLb(p.kg) : p.kg)]
      ],
      unit: imperial ? 'lb' : 'kg',
      empty: l.weightTrendEmpty,
    );

typedef TrendPoint = ({DateTime at, double y});

/// Values over time, one line per series. With [from]/[days] every chart
/// spans the same dates, so charts stacked on the timeline line up.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.lines, required this.unit, required this.empty,
      this.colors, this.from, this.days});
  final List<List<TrendPoint>> lines;
  final List<Color>? colors; // default: the theme's primary, then orange
  final String unit, empty;
  final DateTime? from;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final all = lines.expand((l) => l).toList();
    if (all.length < 2) {
      return Text(empty, style: TextStyle(color: context.colors.textSecondary));
    }
    final t0 = from ?? all.map((p) => p.at).reduce((a, b) => a.isBefore(b) ? a : b);
    double x(DateTime at) => at.difference(t0).inMinutes / (24 * 60);
    final ys = all.map((p) => p.y);
    final (lo, hi) = (ys.reduce((a, b) => a < b ? a : b), ys.reduce((a, b) => a > b ? a : b));
    final pad = ((hi - lo) * .1).clamp(2, double.infinity);
    final muted = TextStyle(color: context.colors.textSecondary, fontSize: 11);
    final palette = colors ?? [context.colors.primary, const Color(0xFFEB6834)];
    return SizedBox(
      height: 180,
      child: LineChart(LineChartData(
        minX: from == null ? null : 0,
        maxX: days?.toDouble(),
        minY: (lo - pad).floorToDouble(),
        maxY: (hi + pad).ceilToDouble(),
        lineBarsData: [
          for (final (i, line) in lines.indexed)
            LineChartBarData(
              spots: [for (final p in line) FlSpot(x(p.at), p.y)],
              color: palette[i % palette.length],
              barWidth: 2,
              dotData: FlDotData(
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4, color: palette[i % palette.length], strokeWidth: 2, strokeColor: context.colors.surface),
              ),
            ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: context.colors.accent.withValues(alpha: .25), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: from != null && days != null,
              interval: days == null ? null : (days! / 4).ceilToDouble(),
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text(DateFormat('d MMM').format(t0.add(Duration(days: v.round()))), style: muted),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) =>
                  v == meta.max || v == meta.min ? const SizedBox.shrink() : Text('${v.round()}', style: muted),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.colors.textPrimary,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat('d MMM').format(lines[s.barIndex][s.spotIndex].at)}\n${s.y.toStringAsFixed(s.y % 1 == 0 ? 0 : 1)} $unit',
                  TextStyle(color: context.colors.surface, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      )),
    );
  }
}
