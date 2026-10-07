import 'dart:io';

import 'package:flutter/material.dart';
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
      appBar: AppBar(title: Text(l.healthTitle)),
      body: data == null || billing == null
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder(
              valueListenable: billing.tier,
              builder: (context, tier, _) => ValueListenableBuilder(
                valueListenable: data.changes,
                builder: (context, _, _) =>
                    tier.includes(Tier.medium) ? _Health(data: data) : _LockedHealth(data: data),
              ),
            ),
    );
  }
}

class _Health extends StatelessWidget {
  const _Health({required this.data});
  final ProfileData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final mine = {for (final c in myConditions(data.user)) c.id};
    final limits = conditionLimits(data.nutri, data.user);
    final avoid = avoidedFoods(data.nutri, data.user);
    final avoidNames = avoid.isEmpty
        ? const <String>[]
        : [
            for (final r in data.nutri.select('SELECT name FROM foods WHERE id IN (${avoid.keys.join(',')}) ORDER BY name'))
              r['name'] as String
          ];
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.conditionsTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.conditionsHint, style: TextStyle(color: context.colors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in allConditions(data.nutri))
                FilterChip(
                  label: Text(conditionLabel(c.name, l)),
                  selected: mine.contains(c.id),
                  onSelected: (on) {
                    setCondition(data.user, c, on, now: DateTime.now());
                    data.changed();
                  },
                ),
            ]),
            if (limits.isNotEmpty || avoidNames.isNotEmpty) const SizedBox(height: 12),
            for (final MapEntry(key: k, value: v) in limits.entries)
              Text(l.limitLine(nutrientLabels(l)[k]!.$1, formatNutrient(k, v.max, l), conditionLabel(v.condition, l))),
            if (avoidNames.isNotEmpty) Text(l.avoidLine(avoidNames.join(', '))),
          ]),
        ),
      ),
      _JournalCard(data: data, now: now),
      Card(
        child: ListTile(
          leading: Icon(Icons.timeline, color: context.colors.primary),
          title: Text(l.timelineTitle),
          subtitle: Text(l.timelineHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(TimelineScreen(data: data)),
        ),
      ),
      Card(
        child: ListTile(
          leading: Icon(Icons.description_outlined, color: context.colors.primary),
          title: Text(l.reportButton),
          subtitle: Text(l.reportHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showModalBottomSheet<void>(
              context: context, isScrollControlled: true, builder: (_) => _ReportSheet(data: data)),
        ),
      ),
    ]);
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.data, required this.now});
  final ProfileData data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final from = now.subtract(const Duration(days: 14));
    final entries = [
      for (final s in symptomsBetween(data.user, from, now.add(const Duration(minutes: 1))))
        (at: s.at, icon: Icons.healing_outlined,
            text: s.severity == null ? s.symptom : '${s.symptom} · ${s.severity}/5',
            delete: () => deleteSymptom(data.user, s.id)),
      for (final r in readingsBetween(data.user, from, now.add(const Duration(minutes: 1))))
        (at: r.at, icon: _icons[r.kind]!, text: '${_kindName(r.kind, l)} · ${readingText(r)}',
            delete: () => deleteReading(data.user, r.id)),
    ]..sort((a, b) => b.at.compareTo(a.at));

    Future<void> add(String kind) async {
      final saved = await showDialog<bool>(context: context, builder: (_) => _EntryDialog(kind: kind, data: data));
      if (saved == true) data.changed();
    }

    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          title: Text(l.journalTitle, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(l.journalHint),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(icon: const Icon(Icons.healing_outlined), label: Text(l.symptom), onPressed: () => add('symptom')),
            OutlinedButton.icon(icon: Icon(_icons['glucose']), label: Text(l.glucose), onPressed: () => add('glucose')),
            OutlinedButton.icon(
                icon: Icon(_icons['blood_pressure']), label: Text(l.bloodPressure), onPressed: () => add('blood_pressure')),
          ]),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          ListTile(title: Text(l.journalEmpty, style: TextStyle(color: context.colors.textSecondary))),
        for (final e in entries)
          ListTile(
            dense: true,
            leading: Icon(e.icon, color: context.colors.primary),
            title: Text(e.text),
            subtitle: Text(DateFormat('EEE d MMM, HH:mm').format(e.at)),
            trailing: IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(l.deleteEntryTitle),
                    content: Text(e.text),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
                    ],
                  ),
                );
                if (ok == true) {
                  e.delete();
                  data.changed();
                }
              },
            ),
          ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

const _icons = {
  'glucose': Icons.water_drop_outlined,
  'blood_pressure': Icons.favorite_border,
  'weight': Icons.monitor_weight_outlined,
};

String _kindName(String kind, AppLocalizations l) =>
    {'glucose': l.glucose, 'blood_pressure': l.bloodPressure, 'weight': l.weightTrend}[kind] ?? kind;

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
  late String _unit = readingsBetween(widget.data.user, DateTime(2000), DateTime.now().add(const Duration(minutes: 1)),
              kind: 'glucose')
          .lastOrNull
          ?.unit ??
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
      'symptom' when _a.text.trim().isNotEmpty => () => logSymptom(user, _a.text, _severity, at: now),
      'glucose' when _num(_a) != null => () => logReading(user, 'glucose', _num(_a)!, _unit, at: now),
      'blood_pressure' when _num(_a) != null && _num(_b) != null =>
        () => logReading(user, 'blood_pressure', _num(_a)!, 'mmHg', value2: _num(_b)!, at: now),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final save = _save;
    InputDecoration label(String text, [String? suffix]) => InputDecoration(labelText: text, suffixText: suffix);
    const number = TextInputType.numberWithOptions(decimal: true);
    void changed(_) => setState(() {});
    return AlertDialog(
      title: Text(switch (widget.kind) { 'symptom' => l.symptom, 'glucose' => l.glucose, _ => l.bloodPressure }),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...switch (widget.kind) {
            'symptom' => [
                TextField(controller: _a, autofocus: true, decoration: label(l.symptomHint), onChanged: changed),
                const SizedBox(height: 12),
                Text(l.severity),
                Wrap(spacing: 6, children: [
                  for (var s = 1; s <= 5; s++)
                    ChoiceChip(
                      label: Text('$s'),
                      selected: _severity == s,
                      onSelected: (on) => setState(() => _severity = on ? s : null),
                    ),
                ]),
                Text(l.severityHint, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
              ],
            'glucose' => [
                TextField(controller: _a, autofocus: true, keyboardType: number, decoration: label(l.reportValue), onChanged: changed),
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
                TextField(controller: _a, autofocus: true, keyboardType: number,
                    decoration: label(l.systolic, 'mmHg'), onChanged: changed),
                TextField(controller: _b, keyboardType: number, decoration: label(l.diastolic, 'mmHg'), onChanged: changed),
              ],
          },
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
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
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: context.colors.cardGreen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.monitor_heart_outlined, color: context.colors.primary, size: 32),
            const SizedBox(height: 8),
            Text(l.healthLockedTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l.healthLockedBody),
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l.conditionsStillApply(mine.map((c) => conditionLabel(c.name, l)).join(', '))),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen())),
              child: Text(l.seePlans),
            ),
          ]),
        ),
      ),
    ]);
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
    final targets = currentTargets(user, nutri: widget.data.nutri, now: now).values;
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
      appBar: AppBar(title: Text(l.timelineTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
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
            child: SizedBox(height: 160, child: DailyBarChart(series: series, nutrient: k, goal: targets[k])),
          ),
        ChartSection(
          title: '${l.glucose}${glucose.isEmpty ? '' : ' (${mmol ? 'mmol/L' : 'mg/dL'})'}',
          child: TrendChart(
            lines: [[for (final r in glucose) (at: r.at, y: gl(r))]],
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
              [for (final r in bp) if (r.value2 != null) (at: r.at, y: r.value2!)],
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
              [for (final p in weightsSince(user, from)) (at: p.at, y: body?.imperial == true ? kgToLb(p.kg) : p.kg)]
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
              ? Text(l.timelineEmpty, style: TextStyle(color: context.colors.textSecondary))
              : Column(children: [
                  for (final s in symptoms)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.severity == null ? s.symptom : '${s.symptom} · ${s.severity}/5'),
                      trailing: Text(DateFormat('d MMM').format(s.at)),
                    ),
                ]),
        ),
      ]),
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
      final pdf = await reportPdf(data.user, data.nutri,
          name: data.profile.name,
          now: now,
          days: _days,
          l: l,
          regular: pw.Font.ttf(font),
          bold: pw.Font.ttf(bold),
          conditionName: (c) => conditionLabel(c, l),
          nutrientNames: {for (final e in nutrientLabels(l).entries) e.key: e.value.$1});
      // Cache dir: not backed up; the previous report is replaced, not kept.
      final dir = Directory('${(await getTemporaryDirectory()).path}/report');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final stamp = DateFormat('yyyy-MM-dd').format(now);
      final pdfFile = File('${dir.path}/myfoodmind-report-$stamp.pdf')..writeAsBytesSync(pdf);
      final csvFile = File('${dir.path}/myfoodmind-data-$stamp.csv')
        ..writeAsStringSync(reportCsv(data.user, now: now, days: _days));
      await SharePlus.instance.share(ShareParams(
        subject: l.reportSubject,
        files: [XFile(pdfFile.path, mimeType: 'application/pdf'), XFile(csvFile.path, mimeType: 'text/csv')],
      ));
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      debugPrint('report failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.reportFailed)));
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
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            label: Text(l.reportShare),
            onPressed: _busy ? null : _share,
          ),
        ),
      ]),
    );
  }
}
