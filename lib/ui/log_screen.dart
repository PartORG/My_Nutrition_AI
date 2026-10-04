import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_tools.dart';
import '../app_state.dart';
import '../l10n/app_localizations.dart';
import 'nutrients.dart';
import 'theme.dart';

/// Search the food database and log an amount, no AI involved.
class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  final _search = TextEditingController();
  List<FoodChoice> _results = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(FoodChoice food) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AmountSheet(food: food),
    );
    if (logged == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.loggedSnack(food.label))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tools = ref.watch(profileDataProvider)?.tools;
    if (tools == null) return const SizedBox.shrink();
    final kinds = {'food': (l.kindFood, Icons.eco_outlined), 'dish': (l.kindDish, Icons.dinner_dining_outlined),
        'recipe': (l.kindRecipe, Icons.menu_book_outlined), 'product': (l.kindProduct, Icons.qr_code_2)};
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.searchFood),
          textInputAction: TextInputAction.search,
          onChanged: (t) => setState(() => _results = t.trim().length < 2 ? [] : tools.searchFood(t)),
        ),
      ),
      Expanded(
        child: _results.isEmpty && _search.text.trim().length >= 2
            ? Center(child: Text(l.noResults))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final f = _results[i];
                  final (kind, icon) = kinds[f.kind]!;
                  final per = f.servingG == null
                      ? l.per100g(f.per100['kcal']!.round())
                      : l.perServing2((f.per100['kcal']! * f.servingG! / 100).round());
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.cardGreen,
                      child: Icon(icon, color: AppColors.primary),
                    ),
                    title: Text(f.label),
                    subtitle: Text('$kind · ${f.estimated ? '≈' : ''}$per'),
                    trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    onTap: () => _pick(f),
                  );
                },
              ),
      ),
    ]);
  }
}

class _AmountSheet extends ConsumerStatefulWidget {
  const _AmountSheet({required this.food});
  final FoodChoice food;

  @override
  ConsumerState<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends ConsumerState<_AmountSheet> {
  late final _grams = TextEditingController(text: '${(widget.food.servingG ?? 100).round()}');
  late String _meal = ref.read(profileDataProvider)?.tools.mealTypeNow() ?? 'snack';

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double get grams => double.tryParse(_grams.text.replaceAll(',', '.')) ?? 0;

  void _servings(double delta) {
    final s = widget.food.servingG!;
    final next = ((grams / s) + delta).clamp(.5, 20);
    setState(() => _grams.text = '${(next * s).round()}');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final food = widget.food;
    final values = food.per100.map((k, v) => MapEntry(k, v * grams / 100));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(food.label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(children: [
          if (food.servingG != null) ...[
            IconButton.filledTonal(
                tooltip: '−', iconSize: 28, onPressed: () => _servings(-.5), icon: const Icon(Icons.remove)),
            const SizedBox(width: 8),
            Text('${(grams / food.servingG!).toStringAsFixed(1)} × ${l.servings.toLowerCase()}'),
            const SizedBox(width: 8),
            IconButton.filledTonal(
                tooltip: '+', iconSize: 28, onPressed: () => _servings(.5), icon: const Icon(Icons.add)),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: TextField(
              controller: _grams,
              decoration: InputDecoration(labelText: l.grams, suffixText: 'g'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'breakfast', label: Text(l.mealBreakfast)),
            ButtonSegment(value: 'lunch', label: Text(l.mealLunch)),
            ButtonSegment(value: 'dinner', label: Text(l.mealDinner)),
            ButtonSegment(value: 'snack', label: Text(l.mealSnack)),
          ],
          selected: {_meal},
          onSelectionChanged: (s) => setState(() => _meal = s.single),
        ),
        const SizedBox(height: 12),
        NutrientTiles(values: values, estimated: food.estimated),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: Text(l.logButton),
            onPressed: grams <= 0
                ? null
                : () {
                    final data = ref.read(profileDataProvider);
                    if (data == null) return;
                    data.tools.logFood(food, grams, _meal);
                    data.changed();
                    Navigator.of(context).pop(true);
                  },
          ),
        ),
      ]),
    );
  }
}
