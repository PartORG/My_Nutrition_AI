import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart';
import '../l10n/app_localizations.dart';
import 'avatar.dart';
import 'kit.dart';
import 'recipe_screen.dart' show RecipeScreen;
import 'paywall_screen.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;

/// What was eaten day by day, and the recipes cooked, over a range the user picks. How far
/// back it reaches depends on the tier ([Tier.historyDays]); older logs are only hidden.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.data});
  final ProfileData data;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _lastDays = 7; // a quick choice; null = the picked [_range]
  DateTimeRange? _range;
  var _recipes = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: TierBuilder(builder: (context, tier) {
          final n = DateTime.now();
          final today = DateTime(n.year, n.month, n.day);
          final earliest = DateTime(today.year, today.month, today.day - tier.historyDays + 1);
          final picked = _range;
          var (from, to) = _lastDays != null || picked == null
              ? (DateTime(today.year, today.month, today.day - (_lastDays ?? 7) + 1), today)
              : (picked.start, picked.end);
          if (from.isBefore(earliest)) from = earliest; // e.g. after a downgrade
          if (to.isBefore(from)) to = from;
          final days = [
            for (var d = to; !d.isBefore(from); d = DateTime(d.year, d.month, d.day - 1))
              (day: d, meals: mealsOn(widget.data.user, d)),
          ].where((d) => d.meals.isNotEmpty).toList();
          // Each recipe once, the latest first: meals come oldest first within a day, days newest first.
          final cooked = <int, ({String title, int times, DateTime last})>{};
          for (final m in [for (final d in days) ...d.meals.reversed]) {
            final id = m.recipeId;
            if (id == null) continue;
            final seen = cooked[id];
            cooked[id] = (title: seen?.title ?? m.label, times: (seen?.times ?? 0) + 1, last: seen?.last ?? m.at);
          }
          final fmt = DateFormat.yMMMd();

          void open(int id) => Navigator.of(context)
              .push(MaterialPageRoute<void>(
                  builder: (_) => RecipeScreen(tools: widget.data.tools, recipeId: id, onLogged: widget.data.changed)))
              .then((_) => setState(() {}));

          Widget empty(String text) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: EvaNote(text),
              );

          return ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 24), children: [
            ScreenHeader(title: l.historyTitle, back: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PillTabs<bool>(
                  values: const [false, true],
                  selected: _recipes,
                  label: (r) => r ? l.historyRecipes : l.historyMeals,
                  onChanged: (r) => setState(() => _recipes = r),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final d in [7, 30, 90, 365])
                    if (d <= tier.historyDays)
                      Pill(label: l.lastDays(d), compact: true, selected: _lastDays == d,
                          onTap: () => setState(() => _lastDays = d)),
                  Pill(
                    icon: Icons.date_range,
                    compact: true,
                    label: _lastDays == null ? '${fmt.format(from)} – ${fmt.format(to)}' : l.pickDates,
                    selected: _lastDays == null,
                    onTap: () async {
                      final r = await showDateRangePicker(
                        context: context,
                        firstDate: earliest,
                        lastDate: today,
                        initialDateRange: DateTimeRange(start: from, end: to),
                      );
                      if (r != null) {
                        setState(() {
                          _range = r;
                          _lastDays = null;
                        });
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                if (!_recipes) ...[
                  if (days.isEmpty) empty(l.historyEmpty),
                  for (final d in days) ...[
                    _DayCard(day: d.day, meals: d.meals, onOpen: open),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  if (cooked.isEmpty) empty(l.historyRecipesEmpty),
                  for (final MapEntry(key: id, value: r) in cooked.entries) ...[
                    Panel(
                      padding: const EdgeInsets.all(10),
                      onTap: () => open(id),
                      child: Row(children: [
                        SizedBox.square(dimension: 64, child: RecipeArt(title: r.title, height: 64, radius: 14)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.ink)),
                            const SizedBox(height: 4),
                            Text('${l.cookedTimes(r.times)} · ${l.lastCooked(DateFormat.MMMd().format(r.last))}',
                                style: TextStyle(fontSize: 14, color: c.muted)),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: c.muted),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                if (tier != Tier.pro) ...[
                  const SizedBox(height: 8),
                  LockedCard(icon: Icons.history, title: l.historyLockedTitle(tier.historyDays), body: l.historyLockedBody),
                ],
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}

/// One day: the date and its calories, then each meal with Today's colour and icon;
/// a logged recipe opens its page.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.meals, required this.onOpen});
  final DateTime day;
  final List<MealEntry> meals;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final kcal = meals.fold(0.0, (s, m) => s + m.kcal).round();
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 6),
          child: Row(children: [
            Expanded(
              child: Text(DateFormat.MMMMEEEEd().format(day),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
            ),
            Tag('${NumberFormat.decimalPattern().format(kcal)} kcal'),
          ]),
        ),
        for (final m in meals)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: m.recipeId == null ? null : () => onOpen(m.recipeId!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                MealIcon(type: m.type ?? 'snack', icon: m.recipeId == null ? null : Icons.menu_book, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.label, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink)),
                    Text(
                      [
                        if (m.type != null) mealName(l, m.type!),
                        DateFormat.Hm().format(m.at),
                        if (m.grams != null) '${m.grams!.round()} g',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                // Flexible: at large text "≈ 600 kcal" wraps instead of pushing the row off screen.
                Flexible(
                  child: Text('${m.estimated ? '≈' : ''}${m.kcal.round()} kcal',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 14, color: c.ink2, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                SizedBox(
                  width: 28,
                  child: m.recipeId == null ? null : Icon(Icons.chevron_right, size: 20, color: c.muted),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
