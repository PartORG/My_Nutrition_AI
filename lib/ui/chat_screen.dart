import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/agent.dart';
import '../agent/agent_tools.dart';
import '../data/diary.dart';
import '../l10n/app_localizations.dart';
import 'camera_screen.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'theme.dart';

/// Where "Report this response" drafts go (Play's AI-generated content policy).
// TODO(ievgen): real support address before release.
const supportEmail = 'peredereev.ievgen@gmail.com';

/// Recipe ideas for what the camera saw, or a note that there are none.
void cookOrSay(BuildContext context, Agent agent, List<String> names) {
  if (!agent.cookWith(names)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.cookNone)));
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.agent});
  final Agent agent;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _speech = SpeechToText();
  bool _listening = false;

  @override
  void dispose() {
    _speech.cancel();
    _input.dispose();
    super.dispose();
  }

  /// Big mic for users who can't type easily. On-device recognition only:
  /// falling back to online recognition would send their voice to a server.
  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final l = AppLocalizations.of(context)!;
    void unavailable() {
      if (!mounted) return;
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.voiceUnavailable)));
    }

    final ok = await _speech.initialize(
      onError: (_) => unavailable(),
      onStatus: (s) {
        if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    if (!ok) return unavailable();
    setState(() => _listening = true);
    await _speech.listen(
      // The text lands in the field for the user to check, then they tap Send.
      onResult: (r) => setState(() => _input.text = r.recognizedWords),
      listenOptions: SpeechListenOptions(onDevice: true, listenMode: ListenMode.dictation, partialResults: true),
    );
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty || widget.agent.busy) return;
    _input.clear();
    widget.agent.send(t);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.agent,
      builder: (context, _) {
        final items = widget.agent.items;
        return Column(children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // newest at the bottom, list sticks to it
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) => _item(context, items[items.length - 1 - i]),
            ),
          ),
          if (widget.agent.busy) const LinearProgressIndicator(minHeight: 2),
          if (!widget.agent.busy) _Suggestions(agent: widget.agent, onTap: _send),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: InputDecoration(hintText: l.chatHint),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l.cameraOpen,
                  iconSize: 28,
                  onPressed: widget.agent.busy
                      ? null
                      : () => openCamera(context, 'photo', onCook: (names) => cookOrSay(context, widget.agent, names)),
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                IconButton.filledTonal(
                  tooltip: _listening ? l.voiceStop : l.voiceInput,
                  iconSize: 28,
                  onPressed: widget.agent.busy ? null : _toggleVoice,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                ),
                IconButton.filled(
                  tooltip: l.send,
                  iconSize: 28, // large target: some users have limited hand movement (ALS, MS)
                  onPressed: widget.agent.busy ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _item(BuildContext context, ChatItem item) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return switch (item) {
      UserItem(:final text) => _Bubble(text: text, mine: true),
      ModelItem(:final text) => _Bubble(
          text: text,
          mine: false,
          onReport: () => launchUrl(Uri(
            scheme: 'mailto',
            path: supportEmail,
            query: 'subject=${Uri.encodeComponent('MyFoodMind: reported AI response')}'
                '&body=${Uri.encodeComponent('Response:\n$text\n\nWhat was wrong:\n')}',
          )),
        ),
      CardItem(:final card) => _CardView(card: card, agent: widget.agent),
      CrisisItem() => _Notice(
          color: scheme.errorContainer,
          title: l.crisisTitle,
          body: l.crisisBody,
          action: (l.crisisButton, () => launchUrl(Uri.parse('https://findahelpline.com'))),
        ),
      LimitItem(:final dailyFree) => _Notice(
          color: scheme.secondaryContainer,
          body: l.limitReached(dailyFree),
          action: (l.seePlans, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()))),
        ),
      ErrorItem() => _Notice(color: scheme.errorContainer, body: l.agentError),
    };
  }
}

/// Chat bubble with NutriAI's avatars: the mascot for the AI on the left,
/// a person icon for the user on the right, a sharp corner on the speaker's side.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, this.onReport});
  final String text;
  final bool mine;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final avatar = mine
        ? Container(
            margin: const EdgeInsets.only(left: 8, top: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
            child: Icon(Icons.person, size: 18, color: Theme.of(context).colorScheme.onPrimary),
          )
        : Container(
            margin: const EdgeInsets.only(right: 8, top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.colors.cardGreen, shape: BoxShape.circle),
            child: Image.asset('assets/icons/icon_chat.png', width: 40, height: 40),
          );
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: mine ? context.colors.primary : context.colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(text, style: TextStyle(color: mine ? Theme.of(context).colorScheme.onPrimary : context.colors.textPrimary)),
      ),
    );
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // One TalkBack node per message: "You said: …" / "MyFoodMind said: …".
      child: Semantics(
        label: mine ? l.youSaid(text) : l.aiSaid(text),
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: mine ? [bubble, avatar] : [avatar, bubble],
        ),
      ),
    ).withReport(context, onReport);
  }
}

extension on Widget {
  /// Long-press → "Report this response" (Play's AI-generated content policy),
  /// without an icon on every message.
  Widget withReport(BuildContext context, VoidCallback? onReport) => onReport == null
      ? this
      : GestureDetector(
          onLongPress: () => showModalBottomSheet<void>(
            context: context,
            builder: (c) => SafeArea(
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(AppLocalizations.of(context)!.reportResponse),
                onTap: () {
                  Navigator.pop(c);
                  onReport();
                },
              ),
            ),
          ),
          child: this,
        );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.body, this.title, this.action});
  final Color color;
  final String body;
  final String? title;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) => Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: Theme.of(context).textTheme.titleMedium),
            if (title != null) const SizedBox(height: 6),
            Text(body),
            if (action != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: action!.$2, child: Text(action!.$1)),
              ),
          ]),
        ),
      );
}

/// Cards carry the numbers: they come from the database, not the model's text.
class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.agent});
  final AgentCard card;
  final Agent agent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return switch (card) {
      RecipeListCard(:final recipes) => _Framed(
          icon: Icons.restaurant_menu,
          title: l.recipeIdeas,
          child: Column(children: [
            for (final (i, r) in recipes.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: Text('${i + 1}'),
                ),
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Wrap(spacing: 6, children: [
                  _Chip(icon: Icons.local_fire_department, color: nutrientColors['kcal']!,
                      label: '${r.kcal.round()} ${l.kcal}'),
                  if (r.minutes != null) _Chip(icon: Icons.schedule, color: context.colors.textSecondary,
                      label: '${r.minutes} min'),
                ]),
                trailing: Icon(Icons.chevron_right, color: context.colors.primary),
                onTap: () => agent.showRecipe(r.id),
              ),
          ]),
        ),
      RecipeCard c => RecipeView(card: c, tools: agent.tools, onAte: () => agent.ateRecipe(c.id)),
      NutritionCard c => _Framed(
          icon: Icons.pie_chart_outline,
          title: c.title,
          child: NutrientTiles(values: c.values, estimated: c.estimated),
        ),
      InfoCard(:final passages) => _Framed(
          icon: Icons.info_outline,
          title: l.healthInfo,
          color: nutrientColors['kcal']!,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in passages) ...[
              Text(p.text),
              Text('— ${p.source}', style: text.bodySmall),
              const SizedBox(height: 8),
            ],
            Text(l.notMedicalAdvice, style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ]),
        ),
      CameraCard c => _Framed(
          icon: Icons.photo_camera_outlined,
          title: l.cameraTitle,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo_camera),
              label: Text(l.cameraOpen),
              onPressed: () => openCamera(context, c.mode, onCook: (names) => cookOrSay(context, agent, names)),
            ),
          ),
        ),
      ConfirmCard c => _Framed(
          icon: switch (c.accepted) {
            null => Icons.pending_actions,
            true => Icons.check_circle,
            false => Icons.cancel_outlined,
          },
          title: c.title,
          color: c.accepted == false ? context.colors.textSecondary : context.colors.primary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (c.accepted == null && c.items.isNotEmpty) ...[
              // Chat guesses amounts: each one is editable before Save (0 = leave it out).
              for (final i in c.items) _MealItemRow(item: i, onGrams: (g) => agent.setGrams(c, i, g)),
              for (final line in c.lines.skip(c.items.length)) Text(line),
            ] else
              for (final line in c.lines) Text(line),
            if (c.mealType != null && c.accepted == null) ...[
              const SizedBox(height: 8),
              _MealTypePicker(card: c, agent: agent),
            ],
            const SizedBox(height: 8),
            switch (c.accepted) {
              // Wrap: at large text sizes the two buttons don't fit on one line.
              null => Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
                  TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: Text(l.confirmDiscard),
                    onPressed: () => agent.decide(c, false),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(l.confirmSave),
                    onPressed: () => agent.decide(c, true),
                  ),
                ]),
              true => Text('✓ ${l.confirmSaved}', style: text.labelLarge?.copyWith(color: context.colors.primary)),
              false => Text('✕ ${l.confirmDiscarded}', style: text.labelLarge),
            },
          ]),
        ),
    };
  }
}

/// A recipe with its 1-5 stars (a tap saves them; search uses them) and "I ate this".
/// In chat and on the recipe screen opened from Today.
class RecipeView extends StatefulWidget {
  const RecipeView({super.key, required this.card, required this.tools, required this.onAte});
  final RecipeCard card;
  final AgentTools tools;
  final VoidCallback onAte;

  @override
  State<RecipeView> createState() => _RecipeViewState();
}

class _RecipeViewState extends State<RecipeView> {
  late int? _stars = widget.tools.rating(widget.card.id);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final c = widget.card;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [context.colors.primaryDark, context.colors.primaryLight]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              if (c.minutes != null) _Chip(icon: Icons.schedule, label: '${c.minutes} min', onDark: true),
              _Chip(icon: Icons.people_outline, label: l.servingsCount(c.servings), onDark: true),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final w in c.cautions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w.allergen != null
                          ? l.cautionAllergy(w.food, w.allergen!)
                          : l.cautionCondition(w.food, conditionLabel(w.condition!, l)),
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            _Stars(stars: _stars, onRate: (n) {
              widget.tools.rate(c.id, n);
              setState(() => _stars = n);
            }),
            const SizedBox(height: 10),
            _Section(l.perServing),
            NutrientTiles(values: c.perServing),
            const SizedBox(height: 14),
            _Section(l.ingredients),
            for (final i in c.ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(Icons.check_circle, size: 18, color: context.colors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i.name)),
                  Text('${i.grams.round()} g', style: TextStyle(color: context.colors.textSecondary)),
                ]),
              ),
            const SizedBox(height: 14),
            _Section(l.steps),
            Text(c.instructions),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.restaurant),
                label: Text(l.iAteThis),
                onPressed: widget.onAte,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.stars, required this.onRate});
  final int? stars;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Wrap: at 200% text the label and five stars don't fit one line.
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(l.yourRating, style: TextStyle(color: context.colors.textSecondary)),
      for (var n = 1; n <= 5; n++)
        IconButton(
          tooltip: l.rateStars(n),
          visualDensity: VisualDensity.compact,
          icon: Icon(n <= (stars ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber.shade700),
          onPressed: () => onRate(n),
        ),
    ]);
  }
}

/// A recipe opened again from Today (a meal logged from it, or "Recipes you ate").
class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key, required this.tools, required this.recipeId, required this.onLogged});
  final AgentTools tools;
  final int recipeId;
  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final card = tools.showRecipeById(recipeId).card! as RecipeCard;
    return Scaffold(
      appBar: AppBar(title: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        RecipeView(
          card: card,
          tools: tools,
          // The button is the confirmation here, as on the Log tab.
          onAte: () {
            (tools.logRecipe(recipeId).card! as ConfirmCard).apply();
            onLogged();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.reviewLogged(1))));
          },
        ),
      ]),
    );
  }
}

/// A card with a tinted header strip: icon + title in the card's accent colour.
class _Framed extends StatelessWidget {
  const _Framed({required this.icon, required this.title, required this.child, this.color});
  final IconData icon;
  final String title;
  final Widget child;
  final Color? color; // default: the theme's primary

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colors.primary;
    return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            color: color.withValues(alpha: .12),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12), child: child),
        ]),
      );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.colors.textSecondary, letterSpacing: .8, fontWeight: FontWeight.w700)),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color, this.onDark = false});
  final IconData icon;
  final String label;
  final Color? color;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: .2) : (color ?? context.colors.primary).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: onDark ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: onDark ? Colors.white : context.colors.textPrimary)),
        ]),
      );
}

/// One-tap messages above the input: the food logged most ("I ate…" goes straight to a
/// card), an idea for the meal now, what's left today.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.agent, required this.onTap});
  final Agent agent;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final usual = recentFoods(agent.user, DateTime.now(), limit: 1).firstOrNull;
    final meal = switch (agent.tools.mealTypeNow()) {
      'breakfast' => l.mealBreakfast,
      'lunch' => l.mealLunch,
      'dinner' => l.mealDinner,
      _ => l.mealSnack,
    };
    final texts = [
      // Before the comma: "Bananas, raw" would split into two foods.
      if (usual != null) l.suggestAte('${usual.servingG!.round()} g ${usual.label.split(',').first}'),
      l.suggestIdea(inSentence(context, meal)),
      l.suggestLeft,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(children: [
        for (final t in texts)
          Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(t), onPressed: () => onTap(t))),
      ]),
    );
  }
}

/// A food on a meal card: name, grams (editable), kcal for those grams.
class _MealItemRow extends StatelessWidget {
  const _MealItemRow({required this.item, required this.onGrams});
  final MealItem item;
  final ValueChanged<double> onGrams;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(item.label)),
        SizedBox(
          width: 84,
          child: TextFormField(
            initialValue: '${item.grams.round()}',
            decoration: InputDecoration(isDense: true, suffixText: 'g', labelText: l.grams),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (t) => onGrams(double.tryParse(t.replaceAll(',', '.')) ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text('${item.estimated ? '≈' : ''}${item.values['kcal']!.round()} ${l.kcal}', textAlign: TextAlign.end),
        ),
      ]),
    );
  }
}

/// Breakfast · Lunch · Dinner · Snack on a meal card, before Save.
class _MealTypePicker extends StatelessWidget {
  const _MealTypePicker({required this.card, required this.agent});
  final ConfirmCard card;
  final Agent agent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: 'breakfast', label: Text(l.mealBreakfast)),
        ButtonSegment(value: 'lunch', label: Text(l.mealLunch)),
        ButtonSegment(value: 'dinner', label: Text(l.mealDinner)),
        ButtonSegment(value: 'snack', label: Text(l.mealSnack)),
      ],
      selected: {card.mealType!},
      onSelectionChanged: (s) => agent.setMealType(card, s.single),
    );
  }
}
