import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../billing/billing.dart';
import '../data/conditions.dart';
import '../data/diary.dart';
import '../data/goals.dart';
import '../data/journal.dart';
import '../l10n/app_localizations.dart';
import '../report.dart';
import 'kit.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'period_view.dart';
import 'theme.dart';

/// Medium: conditions, symptom + reading journal, timeline, doctor report.
/// Records, never interprets: values are shown as logged, limits come from
/// nutri.db rules, and the wording stays "suggestions" and "limits".
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final data = ref.watch(profileDataProvider);
    final billing = ref.watch(billingProvider).value;
    return Scaffold(
      body: SafeArea(
        child: data == null || billing == null
            ? const Center(child: CircularProgressIndicator())
            : ValueListenableBuilder(
                valueListenable: billing.tier,
                builder: (context, tier, _) => ValueListenableBuilder(
                  valueListenable: data.changes,
                  builder: (context, _, _) => Column(
                    children: [
                      ScreenHeader(title: l.healthTitle, back: true),
                      Expanded(
                        child: tier.includes(Tier.medium)
                            ? _Health(data: data)
                            : _LockedHealth(data: data),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _Health extends StatefulWidget {
  const _Health({required this.data});
  final ProfileData data;

  @override
  State<_Health> createState() => _HealthState();
}

class _HealthState extends State<_Health> {
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final data = widget.data;
    final now = DateTime.now();
    final mine = {for (final c in myConditions(data.user)) c.id};
    final limits = conditionLimits(data.nutri, data.user);
    final avoid = avoidedFoods(data.nutri, data.user);
    final avoidNames = avoid.isEmpty
        ? const <String>[]
        : [
            for (final r in data.nutri.select(
              'SELECT name FROM foods WHERE id IN (${avoid.keys.join(',')}) ORDER BY name',
            ))
              r['name'] as String,
          ];
    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    Future<void> add(String kind) async {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _EntryDialog(kind: kind, data: data),
      );
      if (saved == true) data.changed();
    }

    Widget record(IconData icon, String label, String kind) => Expanded(
      child: Panel(
        radius: Radii.tile,
        onTap: () => add(kind),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: c.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.conditionsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Flexible(
                    child: Material(
                      color: c.mint,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => setState(() => _editing = !_editing),
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
                                _editing ? l.doneCooking : l.edit,
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
              const SizedBox(height: 10),
              if (_editing || mine.isEmpty) ...[
                Text(l.conditionsHint, style: TextStyle(color: c.muted)),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cond in allConditions(data.nutri))
                    if (_editing || mine.contains(cond.id))
                      Pill(
                        label: conditionLabel(cond.name, l),
                        selected: mine.contains(cond.id),
                        compact: true,
                        onTap: _editing
                            ? () {
                                setCondition(
                                  data.user,
                                  cond,
                                  !mine.contains(cond.id),
                                  now: DateTime.now(),
                                );
                                data.changed();
                              }
                            : null,
                      ),
                ],
              ),
              if (limits.isNotEmpty || avoidNames.isNotEmpty)
                const SizedBox(height: 12),
              for (final MapEntry(key: k, value: v) in limits.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    l.limitLine(
                      nutrientLabels(l)[k]!.$1,
                      formatNutrient(k, v.max, l),
                      conditionLabel(v.condition, l),
                    ),
                    style: TextStyle(fontSize: 15, color: c.ink2),
                  ),
                ),
              if (avoidNames.isNotEmpty)
                Text(
                  l.avoidLine(avoidNames.join(', ')),
                  style: TextStyle(fontSize: 15, color: c.ink2),
                ),
            ],
          ),
        ),
        SectionTitle(l.recordTitle),
        Row(
          children: [
            record(Icons.sentiment_dissatisfied_outlined, l.symptom, 'symptom'),
            const SizedBox(width: 10),
            record(_icons['glucose']!, l.glucose, 'glucose'),
            const SizedBox(width: 10),
            record(
              Icons.monitor_heart_outlined,
              l.bloodPressure,
              'blood_pressure',
            ),
          ],
        ),
        SectionTitle(
          l.journalTitle,
          trailing: Text(
            l.lastDays(14),
            style: TextStyle(fontSize: 14, color: c.muted),
          ),
        ),
        _Journal(data: data, now: now),
        const SizedBox(height: 12),
        Panel(
          onTap: () => open(TimelineScreen(data: data)),
          child: Row(
            children: [
              Icon(Icons.timeline, color: c.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.timelineTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l.timelineHint,
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          color: c.dark,
          border: false,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.reportButton,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.background,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.reportHintShort,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.background.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.background,
                  foregroundColor: c.ink,
                  minimumSize: const Size(80, 52),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ReportSheet(data: data),
                ),
                child: Text(l.create),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.recordsNotInterprets,
          style: TextStyle(fontSize: 14, color: c.muted),
        ),
      ],
    );
  }
}

/// The last 14 days of symptoms and readings, newest first: when · what · value; tap to delete.
class _Journal extends StatelessWidget {
  const _Journal({required this.data, required this.now});
  final ProfileData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final from = now.subtract(const Duration(days: 14));
    final entries = [
      for (final s in symptomsBetween(
        data.user,
        from,
        now.add(const Duration(minutes: 1)),
      ))
        (
          at: s.at,
          what: s.symptom,
          value: s.severity == null ? '' : l.severityN(s.severity!),
          delete: () => deleteSymptom(data.user, s.id),
        ),
      for (final r in readingsBetween(
        data.user,
        from,
        now.add(const Duration(minutes: 1)),
      ))
        (
          at: r.at,
          what: _kindName(r.kind, l),
          value: readingText(r),
          delete: () => deleteReading(data.user, r.id),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    if (entries.isEmpty) {
      return Panel(child: Text(l.journalEmpty, style: TextStyle(color: c.muted)));
    }
    return PanelList(
      children: [
        for (final e in entries)
          InkWell(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dc) => AlertDialog(
                  title: Text(l.deleteEntryTitle),
                  content: Text('${e.what} ${e.value}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dc, false),
                      child: Text(l.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dc, true),
                      child: Text(l.delete),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                e.delete();
                data.changed();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${DateUtils.isSameDay(e.at, now) ? l.tabToday : DateFormat.E(locale).format(e.at)}\n${DateFormat.Hm().format(e.at)}',
                      style: TextStyle(fontSize: 14, color: c.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(e.what, style: const TextStyle(fontSize: 16)),
                  ),
                  Flexible(
                    child: Text(
                      e.value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const _icons = {
  'glucose': Icons.water_drop_outlined,
  'blood_pressure': Icons.favorite_border,
  'weight': Icons.monitor_weight_outlined,
};

String _kindName(String kind, AppLocalizations l) =>
    {
      'glucose': l.glucose,
      'blood_pressure': l.bloodPressure,
      'weight': l.weightTrend,
    }[kind] ??
    kind;

/// Adds one symptom, glucose or blood pressure entry. Owns its controllers
/// (see _EditDialog in memory_screen.dart for why).
class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.kind, required this.data});
  final String kind;
  final ProfileData data;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _a = TextEditingController(), _b = TextEditingController();
  int? _severity;
  // The unit of the last glucose reading, so a mmol/L user isn't asked every time.
  late String _unit =
      readingsBetween(
        widget.data.user,
        DateTime(2000),
        DateTime.now().add(const Duration(minutes: 1)),
        kind: 'glucose',
      ).lastOrNull?.unit ??
      'mg/dL';

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v != null && v > 0 ? v : null;
  }

  /// Null while the input is incomplete; otherwise writes the entry.
  VoidCallback? get _save {
    final user = widget.data.user;
    final now = DateTime.now();
    return switch (widget.kind) {
      'symptom' when _a.text.trim().isNotEmpty => () => logSymptom(
        user,
        _a.text,
        _severity,
        at: now,
      ),
      'glucose' when _num(_a) != null => () => logReading(
        user,
        'glucose',
        _num(_a)!,
        _unit,
        at: now,
      ),
      'blood_pressure' when _num(_a) != null && _num(_b) != null =>
        () => logReading(
          user,
          'blood_pressure',
          _num(_a)!,
          'mmHg',
          value2: _num(_b)!,
          at: now,
        ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final save = _save;
    InputDecoration label(String text, [String? suffix]) =>
        InputDecoration(labelText: text, suffixText: suffix);
    const number = TextInputType.numberWithOptions(decimal: true);
    void changed(_) => setState(() {});
    return AlertDialog(
      title: Text(switch (widget.kind) {
        'symptom' => l.symptom,
        'glucose' => l.glucose,
        _ => l.bloodPressure,
      }),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...switch (widget.kind) {
              'symptom' => [
                TextField(
                  controller: _a,
                  autofocus: true,
                  decoration: label(l.symptomHint),
                  onChanged: changed,
                ),
                const SizedBox(height: 12),
                Text(l.severity),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var s = 1; s <= 5; s++)
                      ChoiceChip(
                        label: Text('$s'),
                        selected: _severity == s,
                        onSelected: (on) =>
                            setState(() => _severity = on ? s : null),
                      ),
                  ],
                ),
                Text(
                  l.severityHint,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              'glucose' => [
                TextField(
                  controller: _a,
                  autofocus: true,
                  keyboardType: number,
                  decoration: label(l.reportValue),
                  onChanged: changed,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mg/dL', label: Text('mg/dL')),
                    ButtonSegment(value: 'mmol/L', label: Text('mmol/L')),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (s) => setState(() => _unit = s.single),
                ),
              ],
              _ => [
                TextField(
                  controller: _a,
                  autofocus: true,
                  keyboardType: number,
                  decoration: label(l.systolic, 'mmHg'),
                  onChanged: changed,
                ),
                TextField(
                  controller: _b,
                  keyboardType: number,
                  decoration: label(l.diastolic, 'mmHg'),
                  onChanged: changed,
                ),
              ],
            },
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        ElevatedButton(
          onPressed: save == null
              ? null
              : () {
                  save();
                  Navigator.pop(context, true);
                },
          child: Text(l.confirmSave),
        ),
      ],
    );
  }
}

/// Free/Basic: what Medium adds. Conditions already set keep filtering
/// recipes and limiting targets after a downgrade (safety never switches off).
class _LockedHealth extends StatelessWidget {
  const _LockedHealth({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mine = myConditions(data.user);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: context.colors.cardGreen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  color: context.colors.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  l.healthLockedTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(l.healthLockedBody),
                if (mine.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.conditionsStillApply(
                      mine.map((c) => conditionLabel(c.name, l)).join(', '),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PaywallScreen(),
                    ),
                  ),
                  child: Text(l.seePlans),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything on one date axis: limited nutrients per day, readings, symptoms.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.data});
  final ProfileData data;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  var _days = 30;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = widget.data.user;
    final now = DateTime.now();
    final (from, to) = reportRange(now, _days);
    final series = dailyTotals(user, now, _days);
    final targets = currentTargets(
      user,
      nutri: widget.data.nutri,
      now: now,
    ).values;
    // The nutrients the conditions limit; sugar and sodium when there are none.
    final limited = conditionLimits(widget.data.nutri, user).keys.toList();
    final shown = limited.isEmpty ? ['sugar_g', 'sodium_mg'] : limited;
    final glucose = readingsBetween(user, from, to, kind: 'glucose');
    // One unit per chart: the latest reading's.
    final mmol = glucose.lastOrNull?.unit == 'mmol/L';
    double gl(Reading r) => switch ((r.unit == 'mmol/L', mmol)) {
      (true, false) => r.value * glucoseMgPerMmol,
      (false, true) => r.value / glucoseMgPerMmol,
      _ => r.value,
    };
    final bp = readingsBetween(user, from, to, kind: 'blood_pressure');
    final body = loadBody(user);
    final symptoms = symptomsBetween(user, from, to).reversed.toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          ScreenHeader(title: l.timelineTitle, back: true),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 30, label: Text(l.days(30))),
              ButtonSegment(value: 90, label: Text(l.days(90))),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.single),
          ),
          const SizedBox(height: 8),
          for (final k in shown)
            ChartSection(
              title: '${nutrientLabels(l)[k]!.$1} ${l.perDay}',
              child: SizedBox(
                height: 160,
                child: DailyBarChart(
                  series: series,
                  nutrient: k,
                  goal: targets[k],
                ),
              ),
            ),
          ChartSection(
            title:
                '${l.glucose}${glucose.isEmpty ? '' : ' (${mmol ? 'mmol/L' : 'mg/dL'})'}',
            child: TrendChart(
              lines: [
                [for (final r in glucose) (at: r.at, y: gl(r))],
              ],
              unit: mmol ? 'mmol/L' : 'mg/dL',
              empty: l.timelineEmpty,
              from: from,
              days: _days,
            ),
          ),
          ChartSection(
            title: '${l.bloodPressure} (mmHg)',
            child: TrendChart(
              lines: [
                [for (final r in bp) (at: r.at, y: r.value)],
                [
                  for (final r in bp)
                    if (r.value2 != null) (at: r.at, y: r.value2!),
                ],
              ],
              unit: 'mmHg',
              empty: l.timelineEmpty,
              from: from,
              days: _days,
            ),
          ),
          ChartSection(
            title: l.weightTrend,
            child: TrendChart(
              lines: [
                [
                  for (final p in weightsSince(user, from))
                    (at: p.at, y: body?.imperial == true ? kgToLb(p.kg) : p.kg),
                ],
              ],
              unit: body?.imperial == true ? 'lb' : 'kg',
              empty: l.timelineEmpty,
              from: from,
              days: _days,
            ),
          ),
          ChartSection(
            title: l.symptomsTitle,
            child: symptoms.isEmpty
                ? Text(
                    l.timelineEmpty,
                    style: TextStyle(color: context.colors.textSecondary),
                  )
                : Column(
                    children: [
                      for (final s in symptoms)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            s.severity == null
                                ? s.symptom
                                : '${s.symptom} · ${s.severity}/5',
                          ),
                          trailing: Text(DateFormat('d MMM').format(s.at)),
                        ),
                    ],
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Builds the PDF + CSV and hands them to the Android share sheet. The app
/// sends nothing itself; the user picks where the files go.
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.data});
  final ProfileData data;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  var _days = 90;
  var _busy = false;

  Future<void> _share() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final data = widget.data;
      final now = DateTime.now();
      final font = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final pdf = await reportPdf(
        data.user,
        data.nutri,
        name: data.profile.name,
        now: now,
        days: _days,
        l: l,
        regular: pw.Font.ttf(font),
        bold: pw.Font.ttf(bold),
        conditionName: (c) => conditionLabel(c, l),
        nutrientNames: {
          for (final e in nutrientLabels(l).entries) e.key: e.value.$1,
        },
      );
      // Cache dir: not backed up; the previous report is replaced, not kept.
      final dir = Directory('${(await getTemporaryDirectory()).path}/report');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final stamp = DateFormat('yyyy-MM-dd').format(now);
      final pdfFile = File('${dir.path}/myfoodmind-report-$stamp.pdf')
        ..writeAsBytesSync(pdf);
      final csvFile = File('${dir.path}/myfoodmind-data-$stamp.csv')
        ..writeAsStringSync(reportCsv(data.user, now: now, days: _days));
      await SharePlus.instance.share(
        ShareParams(
          subject: l.reportSubject,
          files: [
            XFile(pdfFile.path, mimeType: 'application/pdf'),
            XFile(csvFile.path, mimeType: 'text/csv'),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      debugPrint('report failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.reportFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Scrolls: at 200 % text the sheet is taller than the screen.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.reportButton, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l.reportSheetHint),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 30, label: Text(l.days(30))),
              ButtonSegment(value: 90, label: Text(l.days(90))),
              ButtonSegment(value: 365, label: Text(l.days(365))),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.single),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: Text(l.reportShare),
              onPressed: _busy ? null : _share,
            ),
          ),
        ],
      ),
    );
  }
}
