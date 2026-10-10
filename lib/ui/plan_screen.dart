import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../data/plan.dart';
import '../l10n/app_localizations.dart';
import 'chat_screen.dart' show RecipeScreen;
import 'theme.dart';

/// The week's plan (tap a meal to see it, swap it) and the shopping list made from it.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.data, this.initialTab = 0});
  final ProfileData data;

  /// 1 opens the shopping list.
  final int initialTab;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _item = TextEditingController();

  @override
  void dispose() {
    _item.dispose();
    super.dispose();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _meal(AppLocalizations l, String t) => switch (t) {
        'breakfast' => l.mealBreakfast,
        'lunch' => l.mealLunch,
        _ => l.mealDinner,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tools = widget.data.tools;
    final plan = plannedMealsFor(tools, _today);
    final list = shoppingList(tools);
    void update(void Function() f) => setState(() {
          f();
          widget.data.changed();
        });
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.mealPlan),
          bottom: TabBar(
            labelColor: Theme.of(context).appBarTheme.foregroundColor,
            unselectedLabelColor: Theme.of(context).appBarTheme.foregroundColor?.withValues(alpha: .7),
            indicatorColor: Theme.of(context).appBarTheme.foregroundColor,
            tabs: [Tab(text: l.planTab), Tab(text: l.shoppingList)],
          ),
        ),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(12), children: [
            if (plan.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(l.planEmpty)),
            for (final (i, p) in plan.indexed) ...[
              if (i == 0 || plan[i - 1].day != p.day)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text(DateFormat('EEEE d MMM', Localizations.localeOf(context).toString()).format(p.day),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
              Card(
                child: ListTile(
                  title: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${_meal(l, p.mealType)} · ${p.kcal.round()} ${l.kcal}'),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(
                          builder: (_) => RecipeScreen(tools: tools, recipeId: p.recipeId, onLogged: widget.data.changed)))
                      .then((_) => setState(() {})), // stars may have changed what is planned next
                  trailing: IconButton(
                    tooltip: l.planSwap,
                    icon: const Icon(Icons.shuffle),
                    onPressed: () => update(() => swapPlanned(tools, p.day, p.mealType)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text(plan.isEmpty ? l.planWeek : l.planAgain),
                onPressed: () => update(() => planWeek(tools, _today)),
              ),
              if (plan.isNotEmpty)
                // Builder: the tab controller is below this State's own context.
                Builder(
                  builder: (context) => OutlinedButton.icon(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: Text(l.makeShoppingList),
                    onPressed: () {
                      update(() => shoppingFromPlan(tools, _today));
                      DefaultTabController.of(context).animateTo(1);
                    },
                  ),
                ),
            ]),
          ]),
          ListView(padding: const EdgeInsets.all(12), children: [
            TextField(
              controller: _item,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.add), hintText: l.shoppingAdd),
              textInputAction: TextInputAction.done,
              onSubmitted: (t) {
                if (t.trim().isEmpty) return;
                update(() => addShoppingItem(tools, t));
                _item.clear();
              },
            ),
            const SizedBox(height: 8),
            if (list.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(l.shoppingEmpty)),
            for (final i in list)
              CheckboxListTile(
                value: i.checked,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(i.name,
                    style: i.checked
                        ? TextStyle(decoration: TextDecoration.lineThrough, color: context.colors.textSecondary)
                        : null),
                secondary: i.grams == null ? null : Text('${i.grams!.round()} g'),
                onChanged: (on) => update(() => checkShoppingItem(tools, i.id, on ?? false)),
              ),
            if (list.any((i) => i.checked))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => update(() => clearCheckedShopping(tools)), child: Text(l.clearTicked)),
              ),
          ]),
        ]),
      ),
    );
  }
}
