import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/diary.dart' show logWeight;
import '../data/goals.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'theme.dart';

/// Body details → computed targets. [onboarding] adds a "Later" button.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key, this.onboarding = false});
  final bool onboarding;

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _form = GlobalKey<FormState>();
  final _year = TextEditingController();
  final _cm = TextEditingController();
  final _ft = TextEditingController();
  final _in = TextEditingController();
  final _weight = TextEditingController();
  int? _month;
  var _sex = Sex.female;
  var _activity = Activity.light;
  var _goal = Goal.maintain;
  var _imperial = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(profileDataProvider)?.user;
    final b = user == null ? null : loadBody(user);
    if (b == null) return;
    _sex = b.sex;
    _activity = b.activity;
    _goal = b.goal;
    _imperial = b.imperial;
    _year.text = '${b.birthYear}';
    _month = b.birthMonth;
    _setHeight(b.heightCm);
    _weight.text = _fmt(b.imperial ? kgToLb(b.weightKg) : b.weightKg);
  }

  @override
  void dispose() {
    for (final c in [_year, _cm, _ft, _in, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  void _setHeight(double cm) {
    _cm.text = _fmt(cm);
    final fi = cmToFeetInches(cm);
    _ft.text = '${fi.feet}';
    _in.text = _fmt(fi.inches);
  }

  double? get _heightCm => _imperial
      ? (_num(_ft) == null ? null : feetInchesToCm(_num(_ft)!.toInt(), _num(_in) ?? 0))
      : _num(_cm);

  /// Switching units converts what's already typed instead of clearing it.
  void _switchUnits(bool imperial) {
    final h = _heightCm, w = _num(_weight);
    setState(() => _imperial = imperial);
    if (h != null) _setHeight(h);
    if (w != null) _weight.text = _fmt(imperial ? kgToLb(w) : w * lbToKg);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final data = ref.read(profileDataProvider);
    if (data == null) return;
    final w = _num(_weight)!;
    final kg = _imperial ? w * lbToKg : w;
    // A new weight here is a reading too, or the weight trend never sees it.
    final before = loadBody(data.user)?.weightKg;
    if (before == null || (before - kg).abs() >= .05) logWeight(data.user, w, imperial: _imperial, at: DateTime.now());
    saveBody(data.user, (
      sex: _sex,
      birthYear: int.parse(_year.text),
      birthMonth: _month,
      heightCm: _heightCm!,
      weightKg: kg,
      activity: _activity,
      goal: _goal,
      imperial: _imperial,
    ), now: DateTime.now());
    ref.read(avatarProvider.notifier).suggestFor(_sex);
    data.changed();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final year = DateTime.now().year;
    final locale = Localizations.localeOf(context).toString();
    final h = _heightCm, w = _num(_weight);
    final thin = h != null && w != null && h > 0 && underweight(h, _imperial ? w * lbToKg : w);
    String? range(String? v, double min, double max) {
      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
      return n == null || n < min || n > max ? l.invalidNumber : null;
    }

    InputDecoration label(String text) => InputDecoration(labelText: text);
    const gap = SizedBox(height: 16);
    final activities = {
      Activity.sedentary: l.activitySedentary, Activity.light: l.activityLight,
      Activity.moderate: l.activityModerate, Activity.active: l.activityActive,
      Activity.veryActive: l.activityVeryActive,
    };
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          ScreenHeader(
            title: l.goalsTitle,
            back: !widget.onboarding,
            // Beside the title, not under the form: skipping must be visible without scrolling.
            trailing: widget.onboarding
                ? TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.later))
                : null,
          ),
          Expanded(
            child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
          Text(l.goalsIntro, style: TextStyle(color: context.colors.textSecondary)),
          gap,
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l.metric)),
              ButtonSegment(value: true, label: Text(l.imperial)),
            ],
            selected: {_imperial},
            onSelectionChanged: (s) => _switchUnits(s.single),
          ),
          gap,
          Text(l.sex),
          const SizedBox(height: 6),
          SegmentedButton<Sex>(
            segments: [
              ButtonSegment(value: Sex.female, label: Text(l.female)),
              ButtonSegment(value: Sex.male, label: Text(l.male)),
              ButtonSegment(value: Sex.other, label: Text(l.other)),
            ],
            selected: {_sex},
            onSelectionChanged: (s) => setState(() => _sex = s.single),
          ),
          gap,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _month,
                isExpanded: true,
                decoration: label(l.birthMonth),
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text(DateFormat.MMMM(locale).format(DateTime(2000, m)))),
                ],
                validator: (m) => m == null ? l.chooseMonth : null,
                onChanged: (m) => setState(() => _month = m),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _year,
                decoration: label(l.birthYear),
                keyboardType: TextInputType.number,
                validator: (v) => range(v, year - 120.0, year - 1.0),
              ),
            ),
          ]),
          gap,
          if (_imperial)
            Row(children: [
              Expanded(child: TextFormField(controller: _ft, decoration: label(l.heightFt),
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number, validator: (v) => range(v, 2, 8))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _in, decoration: label(l.heightIn),
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => range(v, 0, 11.99))),
            ])
          else
            TextFormField(controller: _cm, onChanged: (_) => setState(() {}), decoration: label(l.heightCm),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => range(v, 50, 250)),
          gap,
          TextFormField(
            controller: _weight,
            onChanged: (_) => setState(() {}), // the underweight note follows
            decoration: label(_imperial ? l.weightLb : l.weightKg),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _imperial ? range(v, 44, 660) : range(v, 20, 300),
          ),
          gap,
          DropdownButtonFormField<Activity>(
            initialValue: _activity,
            isExpanded: true,
            decoration: label(l.activity),
            items: [for (final e in activities.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (a) => setState(() => _activity = a!),
          ),
          gap,
          Text(l.goal),
          const SizedBox(height: 6),
          SegmentedButton<Goal>(
            segments: [
              ButtonSegment(value: Goal.lose, label: Text(l.goalLose)),
              ButtonSegment(value: Goal.maintain, label: Text(l.goalMaintain)),
              ButtonSegment(value: Goal.gain, label: Text(l.goalGain)),
            ],
            selected: {_goal},
            onSelectionChanged: (s) => setState(() => _goal = s.single),
          ),
          if (_goal == Goal.lose && thin) ...[
            const SizedBox(height: 8),
            Text(l.underweightNoLose, style: TextStyle(color: context.colors.danger)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _save, child: Text(l.confirmSave)),
        ]),
            ),
          ),
        ]),
      ),
    );
  }
}
