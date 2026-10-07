import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_tools.dart';
import '../app_state.dart';
import '../data/diary.dart';
import '../l10n/app_localizations.dart';
import 'camera_screen.dart';
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
        'recipe': (l.kindRecipe, Icons.menu_book_outlined), 'product': (l.kindProduct, Icons.qr_code_2),
        'recent': (l.kindRecent, Icons.history)};
    final data = ref.watch(profileDataProvider)!;
    final searching = _search.text.trim().length >= 2;
    final now = DateTime.now();
    // Empty search: what the user eats most, and yesterday's meals to repeat in one tap.
    final list = searching ? _results : recentFoods(data.user, now);
    final yesterday = searching ? const <String, double>{} : mealTotalsOn(data.user, now.subtract(const Duration(days: 1)));
    String meal(String t) => switch (t) {
          'breakfast' => l.mealBreakfast,
          'lunch' => l.mealLunch,
          'dinner' => l.mealDinner,
          _ => l.mealSnack,
        };
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.searchFood),
              textInputAction: TextInputAction.search,
              onChanged: (t) => setState(() => _results = t.trim().length < 2 ? [] : tools.searchFood(t)),
            ),
          ),
          // Pro: log from a photo. The paywall opens below Pro.
          IconButton(
            tooltip: l.cameraOpen,
            iconSize: 28,
            icon: Icon(Icons.photo_camera_outlined, color: context.colors.primary),
            onPressed: () => openCamera(context, 'photo'),
          ),
          IconButton(
            tooltip: l.quickAdd,
            iconSize: 28,
            icon: Icon(Icons.bolt, color: context.colors.primary),
            onPressed: () => showDialog<void>(context: context, builder: (_) => _QuickAddDialog(data: data)),
          ),
        ]),
      ),
      if (yesterday.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final type in ['breakfast', 'lunch', 'dinner', 'snack'])
              if (yesterday[type] case final kcal?)
                ActionChip(
                  avatar: const Icon(Icons.replay, size: 18),
                  label: Text(l.repeatYesterday(meal(type), kcal.round())),
                  onPressed: () {
                    final n = repeatMeal(data.user, now.subtract(const Duration(days: 1)), type, DateTime.now());
                    data.changed();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.reviewLogged(n))));
                  },
                ),
          ]),
        ),
      if (!searching && list.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l.recentFoods, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
      Expanded(
        child: list.isEmpty && searching
            ? Center(child: Text(l.noResults))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final f = list[i];
                  final (kind, icon) = kinds[f.kind]!;
                  final per = f.servingG == null
                      ? l.per100g(f.per100['kcal']!.round())
                      : l.perServing2((f.per100['kcal']! * f.servingG! / 100).round());
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.colors.cardGreen,
                      child: Icon(icon, color: context.colors.primary),
                    ),
                    title: Text(f.label),
                    subtitle: Text('$kind · ${f.estimated ? '≈' : ''}$per'),
                    trailing: Icon(Icons.add_circle_outline, color: context.colors.primary),
                    onTap: () => _pick(f),
                  );
                },
              ),
      ),
    ]);
  }
}

/// "Just 350 kcal" for a meal no search finds; macros optional.
class _QuickAddDialog extends StatefulWidget {
  const _QuickAddDialog({required this.data});
  final ProfileData data;

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  final _name = TextEditingController();
  final _values = {for (final k in ['kcal', 'protein_g', 'carbs_g', 'fat_g']) k: TextEditingController()};
  late String _meal = widget.data.tools.mealTypeNow();

  @override
  void dispose() {
    _name.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String k) => double.tryParse(_values[k]!.text.replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = nutrientLabels(l);
    final kcal = _num('kcal');
    return AlertDialog(
      title: Text(l.quickAdd),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: l.quickAddName)),
          for (final k in _values.keys)
            TextField(
              controller: _values[k],
              decoration: InputDecoration(labelText: labels[k]!.$1, suffixText: labels[k]!.$2.isEmpty ? l.kcal : labels[k]!.$2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: _meal,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'breakfast', child: Text(l.mealBreakfast)),
              DropdownMenuItem(value: 'lunch', child: Text(l.mealLunch)),
              DropdownMenuItem(value: 'dinner', child: Text(l.mealDinner)),
              DropdownMenuItem(value: 'snack', child: Text(l.mealSnack)),
            ],
            onChanged: (m) => setState(() => _meal = m!),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        TextButton(
          onPressed: kcal == null || kcal <= 0 || kcal > 5000
              ? null
              : () {
                  final name = _name.text.trim();
                  widget.data.tools.quickAdd(name.isEmpty ? l.quickAdd : name,
                      {for (final k in _values.keys) k: _num(k) ?? 0}, _meal);
                  widget.data.changed();
                  Navigator.pop(context);
                },
          child: Text(l.logButton),
        ),
      ],
    );
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
