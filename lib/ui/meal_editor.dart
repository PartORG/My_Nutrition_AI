import 'package:material_ui/material_ui.dart';

import '../agent/agent_tools.dart';
import '../app_state.dart';
import '../data/diary.dart' show undoMealsAfter;
import '../l10n/app_localizations.dart';
import 'nutrients.dart';
import 'theme.dart';

/// One food of a meal not saved yet (chat meal card, photo review): the matched food (tap to
/// change it), what the AI saw, ≈ grams with − / + by half servings when the food has a serving,
/// its kcal, and ×. Owns its grams field, so a swapped food or a removed row never leaves a
/// stale number on screen; give it a key per item.
class MealItemEditor extends StatefulWidget {
  const MealItemEditor({
    super.key,
    required this.label,
    required this.grams,
    required this.kcal,
    required this.onChange,
    required this.onGrams,
    required this.onRemove,
    this.seen,
    this.servingG,
    this.estimated = true,
  });

  /// The database food; null = nothing matched yet (only Change and × then).
  final String? label;

  /// What the AI read or saw ("boiled rice"); shown when it differs from [label].
  final String? seen;
  final double grams;
  final double? kcal, servingG;
  final bool estimated;
  final VoidCallback onChange, onRemove;
  final ValueChanged<double> onGrams;

  @override
  State<MealItemEditor> createState() => _MealItemEditorState();
}

class _MealItemEditorState extends State<MealItemEditor> {
  late final _grams = TextEditingController(text: _text(widget.grams));

  static String _text(double g) => '${g.round()}';
  double? get _typed => double.tryParse(_grams.text.replaceAll(',', '.'));

  @override
  void didUpdateWidget(MealItemEditor old) {
    super.didUpdateWidget(old);
    // Changed from outside (another food, a stepper): show it. Typing already matches.
    // An emptied field is 0 g while typing, so it isn't refilled.
    if ((widget.grams - (_typed ?? 0)).abs() > .5) _grams.text = _text(widget.grams);
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  void _step(double servings) {
    final s = widget.servingG!;
    widget.onGrams((((widget.grams / s) + servings).clamp(.5, 20)) * s);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final label = widget.label;
    final remove = IconButton(tooltip: l.removeItem, icon: const Icon(Icons.close), onPressed: widget.onRemove);
    if (label == null) {
      return Container(
        color: c.warm,
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(children: [
          Expanded(child: Text(l.notInDatabase(widget.seen ?? ''), style: TextStyle(fontSize: 15, color: c.onWarm))),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.dark, foregroundColor: c.background, minimumSize: const Size(64, 48)),
            onPressed: widget.onChange,
            child: Text(l.reviewChange),
          ),
          remove,
        ]),
      );
    }
    final seen = widget.seen;
    Widget step(IconData icon, String tooltip, double servings) => IconButton(
          tooltip: tooltip,
          style: IconButton.styleFrom(minimumSize: const Size(44, 44), side: BorderSide(color: c.outline), shape: const CircleBorder()),
          onPressed: () => _step(servings),
          icon: Icon(icon, size: 20),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Semantics(
              button: true,
              hint: l.changeFood,
              child: InkWell(
                onTap: widget.onChange,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.ink))),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined, size: 16, color: c.primary),
                    ]),
                    if (seen != null && seen.toLowerCase() != label.toLowerCase())
                      Text(l.seenAs(seen), style: TextStyle(fontSize: 13, color: c.muted)),
                  ]),
                ),
              ),
            ),
          ),
          remove,
        ]),
        // Wrap: at large text the kcal goes under the amount.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.servingG != null) ...[step(Icons.remove, l.lessServing, -.5), const SizedBox(width: 6)],
              SizedBox(
                width: 104 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
                child: TextField(
                  controller: _grams,
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: widget.estimated ? '≈ ' : null,
                    suffixText: 'g',
                    hintText: l.grams,
                    contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.pill)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.pill), borderSide: BorderSide(color: c.outline)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (t) => widget.onGrams(double.tryParse(t.replaceAll(',', '.')) ?? 0),
                ),
              ),
              if (widget.servingG != null) ...[const SizedBox(width: 6), step(Icons.add, l.moreServing, .5)],
            ]),
            if (widget.kcal != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('${widget.estimated ? '≈' : ''}${widget.kcal!.round()} ${l.kcal}',
                    style: TextStyle(fontSize: 15, color: c.ink2, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
          ],
        ),
      ]),
    );
  }
}

/// Search the food database and pick a food (owns its controller, see memory_screen.dart).
class PickFoodDialog extends StatefulWidget {
  const PickFoodDialog({super.key, required this.tools, required this.initial});
  final AgentTools tools;
  final String initial;

  @override
  State<PickFoodDialog> createState() => _PickFoodDialogState();
}

class _PickFoodDialogState extends State<PickFoodDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final results = _text.text.trim().length < 2 ? const <FoodChoice>[] : widget.tools.searchFood(_text.text, limit: 8);
    return AlertDialog(
      title: Text(l.searchFood),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _text, autofocus: true, onChanged: (_) => setState(() {})),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (results.isEmpty && _text.text.trim().length >= 2) ListTile(title: Text(l.noResults)),
              for (final f in results)
                ListTile(
                  title: Text(f.label),
                  subtitle: Text(formatNutrient('kcal', f.per100['kcal']!, l) + l.per100Suffix),
                  onTap: () => Navigator.pop(context, f),
                ),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))],
    );
  }
}

/// "Logged …" with Undo, which removes what was logged after [mark] (from lastMealId).
void showLoggedSnack(BuildContext context, ProfileData data, String text, int mark) {
  final l = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      persist: false, // an action makes it stay forever by default
      action: SnackBarAction(
        label: l.undo,
        onPressed: () {
          try {
            undoMealsAfter(data.user, mark);
            data.changed();
          } on Object catch (e) {
            debugPrint('undo after lock: $e'); // the profile was locked meanwhile: its database is closed
          }
        },
      ),
    ));
}
