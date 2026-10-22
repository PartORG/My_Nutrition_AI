import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../agent/agent.dart';
import '../agent/agent_tools.dart';
import '../agent/recipe_translation.dart' show savedTranslation;
import '../app_state.dart' show agentProvider;
import '../billing/billing.dart' show Tier;
import '../data/cook.dart';
import '../data/plan.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'nutrients.dart';
import 'paywall_screen.dart' show TierBuilder;
import 'theme.dart';

/// A recipe: servings that scale amounts and nutrition, ingredients, steps, and the ways to use it:
/// add to the plan, log a serving, start cooking.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({
    super.key,
    required this.tools,
    required this.recipeId,
    required this.onLogged,
  });
  final AgentTools tools;
  final int recipeId;
  final VoidCallback onLogged;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  late final RecipeCard _card =
      widget.tools.showRecipeById(widget.recipeId).card! as RecipeCard;
  late int _servings = _card.servings;
  late int? _stars = widget.tools.rating(widget.recipeId);
  late bool _saved = savedRecipeIds(widget.tools).contains(widget.recipeId);

  /// Each ingredient with the database's English name (Cook mode matches it in the steps).
  late final List<({String name, String english, double grams})>
  _ingredients = [
    for (final r in widget.tools.nutri.select(
      'SELECT ${widget.tools.foodNameColumn} AS name, f.name AS english, ri.grams FROM recipe_ingredients ri '
      'JOIN foods f ON f.id = ri.food_id ${widget.tools.foodNameJoin} WHERE ri.recipe_id = ? ORDER BY ri.grams DESC',
      [widget.recipeId],
    ))
      (
        name: r['name'] as String,
        english: r['english'] as String,
        grams: (r['grams'] as num).toDouble(),
      ),
  ];

  double get _factor => _servings / _card.servings;

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _addToPlan() async {
    final picked = await showModalBottomSheet<(DateTime, String)>(
      context: context,
      builder: (_) => const _PlanSheet(),
    );
    if (picked == null) return;
    planRecipe(widget.tools, picked.$1, picked.$2, widget.recipeId);
    widget.onLogged();
    if (mounted) _say(AppLocalizations.of(context)!.addedToPlan);
  }

  void _logServing() {
    (widget.tools.logRecipe(widget.recipeId).card! as ConfirmCard).apply();
    widget.onLogged();
    _say(AppLocalizations.of(context)!.reviewLogged(1));
    setState(() {});
  }

  String _instructions() {
    final t = widget.tools.language == 'en'
        ? null
        : savedTranslation(
            widget.tools.user,
            widget.recipeId,
            widget.tools.language,
          );
    return t ?? _card.instructions;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final card = _card;
    final cooked = timesCooked(widget.tools, widget.recipeId);
    final values = card.perServing.map((k, v) => MapEntry(k, v * _servings));
    final meta = [
      if (card.minutes != null && card.minutes! > 0)
        l.minutesShort(card.minutes!),
      if (cooked > 0) l.cookedTimes(cooked),
    ];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                RecipeArt(
                  title: card.title,
                  height: 220 + MediaQuery.paddingOf(context).top,
                ),
                // The sheet's rounded top, drawn over the art (no transform: taps and scrolling stay true).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -1,
                  child: Container(
                    height: 29,
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_ios_new,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      Material(
                        color: c.surface,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () {
                            setRecipeSaved(
                              widget.tools,
                              widget.recipeId,
                              !_saved,
                            );
                            setState(() => _saved = !_saved);
                          },
                          child: Semantics(
                            toggled: _saved,
                            button: true,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _saved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      color: c.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _saved ? l.savedLabel : l.cardSaveRecipe,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: c.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: c.background,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      card.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (meta.isNotEmpty)
                        Text(
                          meta.join(' · '),
                          style: TextStyle(fontSize: 15, color: c.ink2),
                        ),
                      _Stars(
                        stars: _stars,
                        onRate: (n) {
                          widget.tools.rate(widget.recipeId, n);
                          setState(() => _stars = n);
                        },
                      ),
                    ],
                  ),
                  for (final w in card.cautions)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Panel(
                        color: c.dangerBg,
                        border: false,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: c.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                w.allergen != null
                                    ? l.cautionAllergy(w.food, w.allergen!)
                                    : l.cautionCondition(
                                        w.food,
                                        conditionLabel(w.condition!, l),
                                      ),
                                style: TextStyle(
                                  color: c.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.servingsLabel,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                l.servingsHint,
                                style: TextStyle(fontSize: 13, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                        _Round(
                          icon: Icons.remove,
                          tooltip: l.fewerServings,
                          onPressed: _servings > 1
                              ? () => setState(() => _servings--)
                              : null,
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '$_servings',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _Round(
                          icon: Icons.add,
                          tooltip: l.moreServings,
                          onPressed: _servings < 24
                              ? () => setState(() => _servings++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MacroTiles(values: values),
                  if (headlineMicros.where((k) => card.perServing[k] != null).toList()
                      case final micros when micros.isNotEmpty)
                    TierBuilder(
                      // micronutrients are Basic
                      builder: (context, tier) => !tier.includes(Tier.basic)
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                micros
                                    .map((k) => '${nutrientName(l, k)} ${formatMicro(values[k]!, nutrientUnit(k))}')
                                    .join(' · '),
                                style: TextStyle(fontSize: 13, color: c.muted),
                              ),
                            ),
                    ),
                  SectionTitle(
                    l.ingredients,
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
                    trailing: TierBuilder(
                      // the shopping list belongs to the meal plan (Basic)
                      builder: (context, tier) => !tier.includes(Tier.basic)
                          ? const SizedBox.shrink()
                          : TextButton(
                              onPressed: () {
                                addRecipeToShopping(
                                  widget.tools,
                                  widget.recipeId,
                                  servings: _servings,
                                );
                                _say(l.addedToShopping);
                              },
                              child: Text(l.addToShoppingShort),
                            ),
                    ),
                  ),
                  PanelList(
                    children: [
                      for (final i in _ingredients)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  i.name,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              Text(
                                '${(i.grams * _factor).round()} g',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: c.muted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (card.translatedNames)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l.machineTranslated,
                        style: TextStyle(fontSize: 13, color: c.muted),
                      ),
                    ),
                  SectionTitle(
                    l.steps,
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
                  ),
                  _Steps(
                    recipeId: widget.recipeId,
                    instructions: card.instructions,
                    tools: widget.tools,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActions(
        children: [
          TierBuilder(
            builder: (context, tier) => tier.includes(Tier.basic)
                ? _Round(
                    icon: Icons.edit_calendar_outlined,
                    tooltip: l.addToPlan,
                    onPressed: _addToPlan,
                    size: 56,
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: _logServing,
              child: Text(l.logServing, textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(l.startCooking),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CookScreen(
                    title: card.title,
                    steps: recipeSteps(_instructions()),
                    ingredients: [
                      for (final i in _ingredients)
                        (
                          name: i.name,
                          english: i.english,
                          grams: i.grams * _factor,
                        ),
                    ],
                    servings: _servings,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 52,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    style: IconButton.styleFrom(
      minimumSize: Size(size, size),
      side: BorderSide(color: context.colors.outline),
      shape: const CircleBorder(),
    ),
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

/// kcal · protein · carbs · fat for the chosen servings, each with its colour dot.
class _MacroTiles extends StatelessWidget {
  const _MacroTiles({required this.values});
  final Nutrients values;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = nutrientLabels(l);
    final tiles = [
      for (final k in ['kcal', 'protein_g', 'carbs_g', 'fat_g'])
        StatTile(
          value: k == 'kcal'
              ? '${values[k]!.round()}'
              : '${values[k]!.round()} g',
          label: k == 'kcal' ? l.kcal : labels[k]!.$1,
          dot: context.nutrientColor(k),
        ),
    ];
    // Four across, two by two at large text.
    return MediaQuery.textScalerOf(context).scale(10) > 13
        ? Column(
            children: [
              Row(
                children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 8),
                  Expanded(child: tiles[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: tiles[2]),
                  const SizedBox(width: 8),
                  Expanded(child: tiles[3]),
                ],
              ),
            ],
          )
        : Row(
            children: [
              for (final (i, t) in tiles.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: t),
              ],
            ],
          );
  }
}

/// Day and meal for "Add to plan".
class _PlanSheet extends StatefulWidget {
  const _PlanSheet();

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  var _day = DateUtils.dateOnly(DateTime.now());
  var _meal = 'dinner';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final today = DateUtils.dateOnly(DateTime.now());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.addToPlan, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ChoicePills<DateTime>(
              values: [
                for (var i = 0; i < 7; i++) today.add(Duration(days: i)),
              ],
              selected: _day,
              scroll: true,
              label: (d) => DateFormat.MEd(locale).format(d),
              onChanged: (d) => setState(() => _day = d),
            ),
            const SizedBox(height: 12),
            ChoicePills<String>(
              values: plannedMeals,
              selected: _meal,
              label: (t) => switch (t) {
                'breakfast' => l.mealBreakfast,
                'lunch' => l.mealLunch,
                _ => l.mealDinner,
              },
              onChanged: (t) => setState(() => _meal = t),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, (_day, _meal)),
              child: Text(l.addToPlan),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five stars (a tap saves them; ideas follow them) and "you rated N".
class _Stars extends StatelessWidget {
  const _Stars({required this.stars, required this.onRate});
  final int? stars;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var n = 1; n <= 5; n++)
          IconButton(
            tooltip: l.rateStars(n),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              n <= (stars ?? 0)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: const Color(0xFFB8860B),
            ),
            onPressed: () => onRate(n),
          ),
        Text(
          stars == null ? l.yourRating : l.youRated(stars!),
          style: TextStyle(fontSize: 15, color: context.colors.ink2),
        ),
      ],
    );
  }
}

/// The steps, numbered. In another app language, a tap translates them with the on-phone model,
/// saved for next time and labelled, with the original one tap away.
class _Steps extends ConsumerStatefulWidget {
  const _Steps({
    required this.recipeId,
    required this.instructions,
    required this.tools,
    required this.onChanged,
  });
  final int recipeId;
  final String instructions;
  final AgentTools tools;
  final VoidCallback onChanged;

  @override
  ConsumerState<_Steps> createState() => _StepsState();
}

class _StepsState extends ConsumerState<_Steps> {
  late String? _translated = widget.tools.language == 'en'
      ? null
      : savedTranslation(
          widget.tools.user,
          widget.recipeId,
          widget.tools.language,
        );
  var _original = false;
  StreamSubscription<String>? _run;

  @override
  void dispose() {
    _run?.cancel(); // a half translation is not saved
    super.dispose();
  }

  void _translate(Agent agent, AppLocalizations l) {
    void say(String text) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
    if (agent.busy) return say(l.translateBusy);
    setState(() => _translated = '');
    _run = agent
        .translateRecipe(widget.recipeId, widget.instructions)
        .listen(
          (t) => setState(() => _translated = t),
          onError: (Object e) {
            debugPrint('translate error: $e');
            setState(() {
              _translated = null;
              _run = null;
            });
            say(l.translateFailed);
          },
          onDone: () {
            setState(() {
              _run = null;
              // The chat took the model first.
              if (_translated?.isEmpty ?? false) _translated = null;
            });
            widget.onChanged(); // Cook mode uses the translation now
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final agent = ref.watch(agentProvider).value;
    final translated = _translated;
    final running = _run != null;
    final text = translated == null || _original
        ? widget.instructions
        : (translated.isEmpty ? '…' : translated);
    final steps = recipeSteps(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.mint,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.onMint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        if (running)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(),
          ),
        if (widget.tools.language != 'en' && !running)
          if (translated == null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.translate),
                label: Text(l.translateSteps),
                onPressed: agent == null ? null : () => _translate(agent, l),
              ),
            ),
            if (agent == null)
              Text(
                l.translateNeedsAi,
                style: TextStyle(fontSize: 13, color: c.muted),
              ),
          ] else
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.machineTranslatedSteps,
                    style: TextStyle(fontSize: 14, color: c.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _original = !_original),
                  child: Text(_original ? l.showTranslation : l.showOriginal),
                ),
              ],
            ),
      ],
    );
  }
}

// ---- cook mode --------------------------------------------------------------------------

const _screen = MethodChannel('myfoodmind/screen');

/// Keeps the screen on (Android; elsewhere a no-op).
Future<void> keepScreenOn(bool on) async {
  try {
    await _screen.invokeMethod<void>('keepOn', on);
  } on MissingPluginException {
    // iOS and tests: no channel.
  } on PlatformException {
    // ignore: the screen may still turn off, cooking goes on
  }
}

/// One step at a time, big type on a dark screen that stays on, the step's ingredients, and a
/// timer when the step names a time.
class CookScreen extends StatefulWidget {
  const CookScreen({
    super.key,
    required this.title,
    required this.steps,
    required this.ingredients,
    required this.servings,
  });
  final String title;
  final List<String> steps;
  final List<({String name, String english, double grams})> ingredients;
  final int servings;

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> {
  var _step = 0;
  Timer? _timer;
  Duration? _left; // the running timer; null = none
  var _rang = false;

  static const _bg = Color(0xFF121A15),
      _chip = Color(0xFF1E2A23),
      _mint = Color(0xFF7FDDB6),
      _gold = Color(0xFFF7C74F);

  @override
  void initState() {
    super.initState();
    keepScreenOn(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    keepScreenOn(false);
    super.dispose();
  }

  void _go(int step) => setState(() {
    _step = step;
    _timer?.cancel();
    _left = null;
    _rang = false;
  });

  void _startTimer(Duration d) {
    _timer?.cancel();
    setState(() {
      _left = d;
      _rang = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = _left! - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        t.cancel();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        setState(() {
          _left = null;
          _rang = true;
        });
        SemanticsService.sendAnnouncement(
          View.of(context),
          AppLocalizations.of(context)!.timerDone,
          Directionality.of(context),
        );
      } else {
        setState(() => _left = left);
      }
    });
  }

  static String _clock(Duration d) =>
      '${d.inHours > 0 ? '${d.inHours}:' : ''}${(d.inMinutes % 60).toString().padLeft(d.inHours > 0 ? 2 : 1, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final steps = widget.steps.isEmpty ? [l.noSteps] : widget.steps;
    final step = steps[_step];
    final timer = stepTimer(step);
    final uses = stepIngredients(step, widget.ingredients);
    final last = _step == steps.length - 1;
    const white = Colors.white;
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.close,
                      tooltip: l.close,
                      background: _chip,
                      foreground: white,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            l.cookSubtitle(widget.servings),
                            style: TextStyle(
                              color: white.withValues(alpha: .65),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < steps.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: i <= _step ? _mint : _chip,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 24),
                    children: [
                      Text(
                        l.stepOf(_step + 1, steps.length).toUpperCase(),
                        style: const TextStyle(
                          color: _mint,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          step,
                          style: const TextStyle(
                            color: white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      if (uses.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          l.forThisStep,
                          style: TextStyle(
                            color: white.withValues(alpha: .65),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final i in uses)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _chip,
                                  borderRadius: BorderRadius.circular(
                                    Radii.pill,
                                  ),
                                ),
                                child: Text(
                                  '${i.name} ${i.grams.round()} g',
                                  style: const TextStyle(
                                    color: white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (timer != null || _left != null || _rang) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: const Color(0xFF16201A),
                            minimumSize: const Size.fromHeight(64),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Onest',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: Icon(
                            _left != null
                                ? Icons.stop_circle_outlined
                                : Icons.timer_outlined,
                            size: 26,
                          ),
                          label: Text(
                            _left != null
                                ? l.timerRunning(_clock(_left!))
                                : _rang
                                ? l.timerDone
                                : l.startTimer(_clock(timer!)),
                          ),
                          onPressed: () {
                            if (_left != null) {
                              _timer?.cancel();
                              setState(() => _left = null);
                            } else if (timer != null) {
                              _startTimer(timer);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: white,
                          side: BorderSide(color: white.withValues(alpha: .35)),
                          minimumSize: const Size.fromHeight(60),
                        ),
                        onPressed: _step == 0 ? null : () => _go(_step - 1),
                        child: Text(l.back),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _mint,
                          foregroundColor: const Color(0xFF0F2A1E),
                          minimumSize: const Size.fromHeight(60),
                        ),
                        onPressed: last
                            ? () => Navigator.of(context).pop()
                            : () => _go(_step + 1),
                        child: Text(last ? l.doneCooking : l.nextStep),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
