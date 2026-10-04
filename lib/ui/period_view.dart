import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'today_screen.dart';

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
        final targets = currentTargets(data.user, now: now).values;
        // Averages over days that have logs: unlogged days aren't "0 kcal eaten".
        double avg(String k) => logged.isEmpty ? 0 : logged.fold(0.0, (s, d) => s + d.totals[k]!) / logged.length;
        final streak = loggingStreak(data.user, now);
        final body = loadBody(data.user);
        return ListView(padding: const EdgeInsets.all(16), children: [
          _Section(
            title: l.caloriesPerDay,
            child: SizedBox(height: 200, child: _CaloriesChart(series: series, goal: targets['kcal'])),
          ),
          if (logged.isNotEmpty)
            _Section(
              title: l.dailyAverage(logged.length),
              child: Column(children: [
                for (final k in ['kcal', 'protein_g', 'carbs_g', 'fat_g', 'fiber_g', 'sugar_g', 'sodium_mg'])
                  if (targets[k] != null) NutrientBar(nutrient: k, eaten: avg(k), goal: targets[k]!),
              ]),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_fire_department, color: Color(0xFFEB6834), size: 32),
              title: Text(l.streakDays(streak), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          _Section(
            title: l.weightTrend,
            child: _WeightChart(
              points: weightsSince(data.user, now.subtract(Duration(days: days < 30 ? 90 : 365))),
              imperial: body?.imperial ?? false,
            ),
          ),
        ]);
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
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

/// One series, so no legend box; the section title names it. Thin bars with
/// rounded tops, a dashed goal line with its label, a tooltip per bar.
class _CaloriesChart extends StatelessWidget {
  const _CaloriesChart({required this.series, required this.goal});
  final List<DayTotals> series;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = nutrientColors['kcal']!;
    final month = series.length > 7;
    final maxY = [goal ?? 0, ...series.map((d) => d.totals['kcal']!)].reduce((a, b) => a > b ? a : b) * 1.15;
    const muted = TextStyle(color: AppColors.textSecondary, fontSize: 11);
    return BarChart(BarChartData(
      maxY: maxY <= 0 ? 100 : maxY,
      alignment: BarChartAlignment.spaceBetween,
      barGroups: [
        for (final (i, d) in series.indexed)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: d.totals['kcal']!,
              color: color,
              width: month ? 6 : 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
      ],
      extraLinesData: ExtraLinesData(horizontalLines: [
        if (goal != null)
          HorizontalLine(
            y: goal!,
            color: AppColors.textSecondary,
            strokeWidth: 1.5,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: muted,
              labelResolver: (_) => l.goalLine(goal!.round()),
            ),
          ),
      ]),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.accent.withValues(alpha: .25), strokeWidth: 1),
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
              // Week: weekday letters; month: every 5th day number.
              if (month && (series.length - 1 - i) % 5 != 0) return const SizedBox.shrink();
              return Text(month ? '${day.day}' : DateFormat.E().format(day).substring(0, 2), style: muted);
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.textPrimary,
          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
            '${DateFormat('EEE d MMM').format(series[group.x].day)}\n${rod.toY.round()} ${l.kcal}',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ));
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.points, required this.imperial});
  final List<({DateTime at, double kg})> points;
  final bool imperial;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (points.length < 2) {
      return Text(l.weightTrendEmpty, style: const TextStyle(color: AppColors.textSecondary));
    }
    double shown(double kg) => imperial ? kgToLb(kg) : kg;
    final unit = imperial ? 'lb' : 'kg';
    final t0 = points.first.at;
    final spots = [
      for (final p in points) FlSpot(p.at.difference(t0).inHours / 24, shown(p.kg)),
    ];
    final ys = spots.map((s) => s.y);
    final (lo, hi) = (ys.reduce((a, b) => a < b ? a : b), ys.reduce((a, b) => a > b ? a : b));
    const muted = TextStyle(color: AppColors.textSecondary, fontSize: 11);
    return SizedBox(
      height: 180,
      child: LineChart(LineChartData(
        minY: (lo - 2).floorToDouble(),
        maxY: (hi + 2).ceilToDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: AppColors.primary,
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: 4, color: AppColors.primary, strokeWidth: 2, strokeColor: Colors.white),
            ),
          ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.accent.withValues(alpha: .25), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: const AxisTitles(),
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
            getTooltipColor: (_) => AppColors.textPrimary,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat('d MMM').format(points[s.spotIndex].at)}\n${s.y.toStringAsFixed(1)} $unit',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      )),
    );
  }
}
