import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../billing/billing.dart';
import '../data/diary.dart';
import '../l10n/app_localizations.dart';
import 'recipe_screen.dart' show RecipeScreen;
import 'paywall_screen.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;

/// What was logged, cooked and eaten, day by day, over a range the user picks. How far
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
  var _recipesOnly = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.historyTitle)),
      body: TierBuilder(builder: (context, tier) {
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
            (day: d, meals: [for (final m in mealsOn(widget.data.user, d)) if (!_recipesOnly || m.recipeId != null) m]),
        ].where((d) => d.meals.isNotEmpty).toList();
        final fmt = DateFormat.yMMMd();

        void open(int id) => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => RecipeScreen(tools: widget.data.tools, recipeId: id, onLogged: widget.data.changed)));

        return ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in [7, 30, 90, 365])
              if (d <= tier.historyDays)
                ChoiceChip(
                  label: Text(l.lastDays(d)),
                  selected: _lastDays == d,
                  onSelected: (_) => setState(() => _lastDays = d),
                ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(_lastDays == null ? '${fmt.format(from)} – ${fmt.format(to)}' : l.pickDates),
              selected: _lastDays == null,
              onSelected: (_) async {
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
            FilterChip(
              label: Text(l.recipesOnly),
              selected: _recipesOnly,
              onSelected: (on) => setState(() => _recipesOnly = on),
            ),
          ]),
          const SizedBox(height: 12),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l.historyEmpty, textAlign: TextAlign.center, style: TextStyle(color: context.colors.textSecondary)),
            ),
          for (final d in days)
            Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(
                  title: Text(DateFormat.yMMMEd().format(d.day), style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text('${d.meals.fold(0.0, (s, m) => s + m.kcal).round()} kcal'),
                ),
                for (final m in d.meals)
                  ListTile(
                    dense: true,
                    leading: Icon(m.recipeId == null ? Icons.restaurant : Icons.menu_book, color: context.colors.primary),
                    title: Text(m.label),
                    subtitle: Text([
                      if (m.type != null) mealName(l, m.type!),
                      DateFormat.Hm().format(m.at),
                      if (m.grams != null) '${m.grams!.round()} g',
                    ].join(' · ')),
                    trailing: Text('${m.estimated ? '≈' : ''}${m.kcal.round()} kcal'),
                    onTap: m.recipeId == null ? null : () => open(m.recipeId!),
                  ),
              ]),
            ),
          if (tier != Tier.pro) ...[
            const SizedBox(height: 8),
            LockedCard(icon: Icons.history, title: l.historyLockedTitle(tier.historyDays), body: l.historyLockedBody),
          ],
        ]);
      }),
    );
  }
}
