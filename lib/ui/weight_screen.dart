import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../data/health_sync.dart' show healthSyncOn, syncHealthWeights;
import '../l10n/app_localizations.dart';
import 'me_screen.dart' show TargetDialog;
import 'kit.dart';
import 'theme.dart';

/// Today's weight tile: the trend weight and its change over 30 days. Opens [WeightScreen];
/// with no reading yet it asks for one.
class WeightTile extends StatelessWidget {
  const WeightTile({super.key, required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final imperial = loadBody(data.user)?.imperial ?? false;
    final points = weightTrend(weightsSince(data.user, DateTime.now().subtract(const Duration(days: 30))));
    return Panel(
      radius: Radii.tile,
      padding: const EdgeInsets.all(12),
      onTap: points.isEmpty
          ? () => logWeightDialog(context, data)
          : () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => WeightScreen(data: data)))
              .then((_) => data.changed()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(l.weight, style: TextStyle(fontSize: 13, color: c.muted))),
          Icon(Icons.monitor_weight_outlined, size: 20, color: c.primary),
        ]),
        const SizedBox(height: 14),
        Text(points.isEmpty ? '–' : weightText(points.last.trend, imperial),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()])),
        Text(
          points.isEmpty
              ? l.logWeight
              : points.length > 1
                  ? '${signedWeight(points.last.trend - points.first.trend, imperial)} · ${l.days(30)}'
                  : l.legendTrend,
          style: TextStyle(fontSize: 13, color: points.isEmpty ? c.primary : c.muted),
        ),
      ]),
    );
  }
}

String weightText(double kg, bool imperial) => '${(imperial ? kgToLb(kg) : kg).toStringAsFixed(1)} ${imperial ? 'lb' : 'kg'}';

String signedWeight(double kg, bool imperial) {
  final v = imperial ? kgToLb(kg.abs()) : kg.abs();
  return '${kg > 0.05 ? '+' : kg < -0.05 ? '−' : '±'}${v.toStringAsFixed(1)} ${imperial ? 'lb' : 'kg'}';
}

Future<void> logWeightDialog(BuildContext context, ProfileData data) async {
  final l = AppLocalizations.of(context)!;
  final imperial = loadBody(data.user)?.imperial ?? false;
  final v = await showDialog<double>(
    context: context,
    builder: (_) => TargetDialog(
        title: imperial ? l.weightLb : l.weightKg,
        initial: null,
        allowReset: false,
        valid: (v) => plausibleWeight(v, imperial: imperial)),
  );
  if (v == null || !plausibleWeight(v, imperial: imperial)) return;
  final now = DateTime.now();
  final sameDay = weightsSince(data.user, DateTime(now.year, now.month, now.day)).isNotEmpty;
  logWeight(data.user, v, imperial: imperial, at: now);
  data.changed();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sameDay ? l.weightUpdatedToday : l.weightLogged)));
  }
}

/// The scale readings as dots and the trend as a line; [compact] for the card (no grid).
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.points, this.compact = false});
  final List<({DateTime at, double kg, double trend})> points;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final first = points.first.trend, last = points.last.trend;
    return Semantics(
      label: l.weightChartLabel(points.length, first.toStringAsFixed(1), last.toStringAsFixed(1)),
      child: CustomPaint(
        size: Size.infinite,
        painter: _WeightPainter(points, context.colors, compact),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(this.points, this.c, this.compact);
  final List<({DateTime at, double kg, double trend})> points;
  final AppPalette c;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = [for (final p in points) ...[p.kg, p.trend]];
    var lo = values.reduce((a, b) => a < b ? a : b), hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) {
      final mid = (hi + lo) / 2;
      lo = mid - .5;
      hi = mid + .5;
    }
    final t0 = points.first.at.millisecondsSinceEpoch, t1 = points.last.at.millisecondsSinceEpoch;
    final pad = compact ? 6.0 : 14.0;
    Offset at(DateTime t, double kg) => Offset(
          pad + (t1 == t0 ? 0 : (t.millisecondsSinceEpoch - t0) / (t1 - t0)) * (size.width - 2 * pad),
          pad + (hi - kg) / (hi - lo) * (size.height - 2 * pad),
        );
    if (!compact) {
      final grid = Paint()
        ..color = c.divider
        ..strokeWidth = 1;
      for (final f in [0.0, .5, 1.0]) {
        final y = pad + f * (size.height - 2 * pad);
        canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), grid);
      }
    }
    final dot = Paint()..color = c.primary.withValues(alpha: .35);
    for (final p in points) {
      canvas.drawCircle(at(p.at, p.kg), compact ? 2.5 : 3.5, dot);
    }
    final line = Path()..moveTo(at(points.first.at, points.first.trend).dx, at(points.first.at, points.first.trend).dy);
    for (final p in points.skip(1)) {
      final o = at(p.at, p.trend);
      line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = c.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 2.5 : 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    final end = at(points.last.at, points.last.trend);
    canvas.drawCircle(end, compact ? 4.5 : 6, Paint()..color = c.primary);
    canvas.drawCircle(end, compact ? 4.5 : 6, Paint()
      ..color = c.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_WeightPainter old) => old.points != points || old.c != c;
}

/// The trend weight over 1, 3, 6 or 12 months, the scale readings around it, and logging.
class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key, required this.data});
  final ProfileData data;

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  var _months = 1;
  var _syncing = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final data = widget.data;
    return ValueListenableBuilder(
      valueListenable: data.changes,
      builder: (context, _, _) {
        final body = loadBody(data.user);
        final imperial = body?.imperial ?? false;
        final now = DateTime.now();
        final from = DateTime(now.year, now.month - _months, now.day);
        // A month's trend is warmed up on the readings before it, so it doesn't start on one day's scale.
        final all = weightTrend(weightsSince(data.user, DateTime(from.year, from.month - 1, from.day)));
        final points = [for (final p in all) if (!p.at.isBefore(from)) p];
        final perWeek = trendPerWeek(points);
        final unit = imperial ? 'lb' : 'kg';
        return Scaffold(
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 24), children: [
              ScreenHeader(
                title: l.weight,
                back: true,
                trailing: healthSyncOn(data.user)
                    ? TextButton.icon(
                        icon: _syncing
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync, size: 18),
                        label: Text(l.healthConnect),
                        onPressed: _syncing
                            ? null
                            : () async {
                                setState(() => _syncing = true);
                                final n = await syncHealthWeights(data.user);
                                if (!mounted) return;
                                setState(() => _syncing = false);
                                if (n > 0) data.changed();
                                ScaffoldMessenger.of(this.context)
                                    .showSnackBar(SnackBar(content: Text(l.healthSyncedWeights(n))));
                              },
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 8),
                  Text(l.trendWeight, style: TextStyle(color: c.muted, fontSize: 15)),
                  if (points.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(l.weightTrendEmpty))
                  else
                    Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: (imperial ? kgToLb(points.last.trend) : points.last.trend).toStringAsFixed(1),
                            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -2, color: c.ink,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                        TextSpan(text: ' $unit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.ink)),
                      ])),
                      if (points.length > 1)
                        Tag(l.weightChangeIn(signedWeight(points.last.trend - points.first.trend, imperial),
                            now.difference(points.first.at).inDays.clamp(1, 400)), big: true),
                    ]),
                  const SizedBox(height: 16),
                  // Four equal pills across, as in the design.
                  Row(children: [
                    for (final (i, m) in const [1, 3, 6, 12].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Pill(
                          label: m == 12 ? l.rangeYear : l.rangeMonths(m),
                          selected: m == _months,
                          onTap: () => setState(() => _months = m),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 16),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        height: 220,
                        child: points.length < 2
                            ? Center(child: Text(l.weightTrendEmpty, textAlign: TextAlign.center))
                            : WeightChart(points: points),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 20, children: [
                        _Legend(dot: true, label: l.legendScale),
                        _Legend(dot: false, label: l.legendTrend),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: StatTile(
                          value: perWeek == null
                              ? '–'
                              : () {
                                  final w = imperial ? kgToLb(perWeek) : perWeek;
                                  return '${w > 0.005 ? '+' : w < -0.005 ? '−' : '±'}${w.abs().toStringAsFixed(2)}';
                                }(),
                          label: l.perWeek(unit)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                          value: points.isEmpty ? '–' : (imperial ? kgToLb(points.last.kg) : points.last.kg).toStringAsFixed(1),
                          label: l.latestScale),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                          value: switch (body?.goal) {
                            Goal.lose => l.goalLose,
                            Goal.gain => l.goalGain,
                            Goal.maintain => l.goalMaintain,
                            null => '–',
                          },
                          label: l.goal),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(l.weightTrendNote, style: TextStyle(color: c.muted, fontSize: 15)),
                ]),
              ),
            ]),
          ),
          bottomNavigationBar: BottomActions(children: [
            Expanded(child: FilledButton(onPressed: () => logWeightDialog(context, data), child: Text(l.logWeight))),
          ]),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.dot, required this.label});
  final bool dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      dot
          ? Container(width: 10, height: 10, decoration: BoxDecoration(color: c.primary.withValues(alpha: .35), shape: BoxShape.circle))
          : Container(width: 16, height: 4, decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: c.ink2)),
    ]);
  }
}
