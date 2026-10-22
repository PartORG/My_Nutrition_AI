import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/agent.dart';
import '../agent/agent_tools.dart';
import '../app_state.dart' show llmHears, llmProvider, voiceRepliesProvider;
import '../data/diary.dart';
import '../l10n/app_localizations.dart';
import '../vision/scan.dart' show photoMeal;
import 'all_nutrients_screen.dart' show NutrientTable;
import 'avatar.dart';
import 'camera_screen.dart';
import 'home_screen.dart' show HomeTab, homeTabProvider, widgetTapProvider;
import 'kit.dart';
import 'meal_editor.dart';
import 'memory_screen.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'recipe_screen.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;
import 'voice.dart';

/// Where "Report this response" drafts go (Play's AI-generated content policy).
// TODO(ievgen): real support address before release.
const supportEmail = 'peredereev.ievgen@gmail.com';

/// A photo in the chat (Pro): the camera or a gallery picture, and what it saw comes back as a meal card to
/// check, change and save, or to cook from.
Future<void> photoToChat(BuildContext context, Agent agent, String mode) async {
  final shot = await capturePhoto(context, mode);
  if (shot != null) agent.addPhoto(photoMeal(shot.data.tools, shot.items, mode: shot.mode));
}

/// Recipe ideas for what the camera saw, or a note that there are none.
void cookOrSay(BuildContext context, Agent agent, List<String> names) {
  if (!agent.cookWith(names)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.cookNone)),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.agent});
  final Agent agent;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  // Android's recognizer: only while the AI can't listen (loaded without its audio part).
  late final _voice = Dictation(_input, _redraw);
  late final _recorder = VoiceRecorder(_redraw);
  final _speaker = Speaker();
  var _transcribing = false;

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenIfAsked());
  }

  @override
  void dispose() {
    _voice.dispose();
    _recorder.dispose();
    _speaker.stop();
    _input.dispose();
    super.dispose();
  }

  /// The home-screen widget's mic: listen at once (a tap from minutes ago is stale).
  void _listenIfAsked() {
    final tap = mounted ? ref.read(widgetTapProvider) : null;
    if (tap == null || tap.host != 'voice') return;
    ref.read(widgetTapProvider.notifier).set(null);
    if (DateTime.now().difference(tap.at) < const Duration(minutes: 2)) _mic();
  }

  Future<void> _send([String? text, bool spoken = false]) async {
    final t = text ?? _input.text;
    if (t.trim().isEmpty || widget.agent.busy) return;
    _input.clear();
    unawaited(_speaker.stop());
    final from = widget.agent.items.length;
    await widget.agent.send(t);
    if (spoken && mounted) _sayAnswer(from);
  }

  /// A spoken message gets a spoken answer: the replies and card captions since [from].
  void _sayAnswer(int from) {
    final voice = ref.read(voiceRepliesProvider);
    if (!voice.on) return;
    final l = AppLocalizations.of(context)!;
    final items = widget.agent.items;
    final said = [
      for (final item in items.skip(from.clamp(0, items.length)))
        switch (item) {
          ModelItem(check: ReplyCheck.unverified) => l.answerUnverified,
          ModelItem(:final text) => text,
          CardItem(:final card, caption: true) => _caption(l, card) ?? '',
          LimitItem(:final dailyFree) => l.limitReached(dailyFree),
          ErrorItem() => l.agentError,
          CrisisItem() => l.crisisBody,
          _ => '',
        }
    ].where((t) => t.trim().isNotEmpty).join('\n');
    unawaited(_speaker.say(said, language: widget.agent.language, male: voice.male));
  }

  /// Mic: Gemma listens (records until a tap or a pause, then writes it down and sends it).
  Future<void> _mic() async {
    unawaited(_speaker.stop());
    if (_recorder.recording) return _stopListening();
    final llm = ref.read(llmProvider).value;
    if (llm == null || !llmHears(llm)) return _voice.toggle(context);
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _recorder.start(onQuiet: _stopListening)) {
      messenger.showSnackBar(SnackBar(content: Text(l.micDenied)));
    }
  }

  Future<void> _stopListening() async {
    if (!_recorder.recording) return; // the pause and a tap can both end it
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final wav = await _recorder.stop();
    final llm = ref.read(llmProvider).value;
    if (wav == null || llm == null || !mounted) return;
    setState(() => _transcribing = true);
    try {
      await widget.agent.release();
      final text = await transcribe(llm, wav, widget.agent.language);
      if (!mounted) return;
      if (text.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l.voiceNothingHeard)));
      } else {
        setState(() => _transcribing = false);
        await _send(text, true);
      }
    } on Object catch (e) {
      debugPrint('transcribe: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.agentError))); // not "speak up": it heard, then failed
    } finally {
      if (mounted && _transcribing) setState(() => _transcribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final listening = _voice.listening || _recorder.recording;
    ref.listen(widgetTapProvider, (_, _) => _listenIfAsked()); // the widget's mic while the chat shows
    return ListenableBuilder(
      listenable: widget.agent,
      builder: (context, _) {
        final agent = widget.agent;
        final items = agent.items;
        final left = agent.unlimited()
            ? null
            : (agent.limit.dailyFree - agent.limit.usedToday).clamp(
                0,
                agent.limit.dailyFree,
              );
        // Large text: the header and the disclaimer scroll with the conversation instead of
        // staying fixed, else at 200 % they leave it a few lines. Chrome is at most 1.5× text.
        final big = MediaQuery.textScalerOf(context).scale(10) > 13;
        final header = MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: Column(
            children: [
              ScreenHeader(
                title: l.assistantTitle,
                trailing: RoundIconButton(
                  icon: Icons.lightbulb_outline,
                  tooltip: l.aiKnowsTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MemoryScreen(agent: agent),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: c.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.runsOnPhone,
                        style: TextStyle(fontSize: 14, color: c.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        final disclaimer = MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.chatDisclaimer,
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ),
                if (left != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    l.messagesLeft(left, agent.limit.dailyFree),
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ],
              ],
            ),
          ),
        );
        return Column(
          children: [
            if (!big) ...[header, Divider(color: c.border)],
            Expanded(
              child: ListView.builder(
                reverse: true, // newest at the bottom, list sticks to it
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                // Large text: the header and the disclaimer scroll with the conversation (last = top).
                itemCount: items.length + (big ? 2 : 0),
                itemBuilder: (_, i) => big && i == 0
                    ? disclaimer
                    : big && i == items.length + 1
                    ? header
                    : _item(
                        context,
                        items[items.length - 1 - (big ? i - 1 : i)],
                      ),
              ),
            ),
            // The input area too: at 200 % with the header it left the conversation nothing.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gemma hears the user: how loud, and that a tap (or a pause) ends it.
                  if (_recorder.recording)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
                      child: Row(children: [
                        Icon(Icons.graphic_eq, size: 18, color: c.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l.listening, style: TextStyle(fontSize: 14, color: c.muted))),
                        SizedBox(
                          width: 64,
                          child: LinearProgressIndicator(value: _recorder.level, color: c.primary, semanticsLabel: l.listening),
                        ),
                      ]),
                    )
                  // On-device answers take seconds: say so where the eye is, above the input.
                  else if (agent.busy || _transcribing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
                      child: Row(children: [
                        SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
                        const SizedBox(width: 10),
                        Text(_transcribing ? l.transcribing : l.thinking, style: TextStyle(fontSize: 14, color: c.muted)),
                      ]),
                    ),
                  if (!agent.busy && !_transcribing && !_recorder.recording) _Suggestions(agent: agent, onTap: _send),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: c.outline),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              decoration: InputDecoration(
                                hintText: l.chatHint,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                              textCapitalization: TextCapitalization.sentences,
                              minLines: 1,
                              maxLines: 4,
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          IconButton(
                            tooltip: listening
                                ? l.voiceStop
                                : l.voiceInput,
                            iconSize: 26,
                            onPressed: agent.busy || _transcribing
                                ? null
                                : _mic,
                            icon: Icon(
                              listening
                                  ? Icons.stop_circle_outlined
                                  : Icons.mic_none,
                              color: listening ? c.primary : c.ink2,
                            ),
                          ),
                          IconButton.filled(
                            tooltip: l.send,
                            iconSize:
                                26, // large target: some users have limited hand movement (ALS, MS)
                            style: IconButton.styleFrom(
                              backgroundColor: c.primary,
                              minimumSize: const Size(56, 56),
                            ),
                            onPressed: agent.busy || _transcribing || _recorder.recording ? null : _send,
                            icon: Icon(Icons.arrow_forward, color: c.onPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!big) disclaimer,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _item(BuildContext context, ChatItem item) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    return switch (item) {
      UserItem(:final text) => _Bubble(text: text, mine: true),
      ModelItem(check: ReplyCheck.unverified) => _Bubble(text: l.answerUnverified, mine: false),
      ModelItem(:final text, :final check) => _Bubble(
        text: text,
        mine: false,
        // The hidden second pass (docs/PLAN.md "All nutrients, patterns", 10).
        mark: switch (check) {
          ReplyCheck.checking => l.answerChecking,
          ReplyCheck.verified => '✓',
          _ => null,
        },
        onReport: () => launchUrl(
          Uri(
            scheme: 'mailto',
            path: supportEmail,
            query:
                'subject=${Uri.encodeComponent('My Nutrition AI: reported AI response')}'
                '&body=${Uri.encodeComponent('Response:\n$text\n\nWhat was wrong:\n')}',
          ),
        ),
      ),
      CardItem(:final card, caption: false) => _CardView(
        card: card,
        agent: widget.agent,
      ),
      CardItem(:final card) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_caption(l, card) case final text?)
            _Bubble(text: text, mine: false),
          _CardView(card: card, agent: widget.agent),
        ],
      ),
      CrisisItem() => _Notice(
        color: c.dangerBg,
        title: l.crisisTitle,
        body: l.crisisBody,
        action: (
          l.crisisButton,
          () => launchUrl(Uri.parse('https://findahelpline.com')),
        ),
      ),
      LimitItem(:final dailyFree) => _Notice(
        color: c.warm,
        body: l.limitReached(dailyFree),
        action: (
          l.seePlans,
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
          ),
        ),
      ),
      ErrorItem() => _Notice(color: c.dangerBg, body: l.agentError),
    };
  }
}

/// The user's words in a dark bubble on the right; the assistant's as plain text on the left.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, this.onReport, this.mark});
  final String text;
  final bool mine;
  final VoidCallback? onReport;

  /// Under a model answer: "checking…" or ✓.
  final String? mark;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      // One TalkBack node per message: "You said: …" / "My Nutrition AI said: …".
      child: Semantics(
        container: true,
        label: mine ? l.youSaid(text) : l.aiSaid(text),
        excludeSemantics: true,
        child: mine
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .74,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                        decoration: BoxDecoration(
                          color: c.dark,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(22),
                            topRight: Radius.circular(22),
                            bottomLeft: Radius.circular(22),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(fontSize: 16, color: c.background),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const UserAvatar(radius: 15),
                ],
              )
            : Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const EvaAvatar(size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          text,
                          style: TextStyle(fontSize: 16, color: c.ink2, height: 1.4),
                        ),
                        if (mark != null)
                          Text(mark!, style: AppText.caption.copyWith(color: c.muted)),
                      ]),
                    ),
                  ],
                ),
              ),
      ),
    ).withReport(context, onReport);
  }
}

extension on Widget {
  /// Long-press → "Report this response" (Play's AI-generated content policy),
  /// without an icon on every message.
  Widget withReport(BuildContext context, VoidCallback? onReport) =>
      onReport == null
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
  const _Notice({
    required this.color,
    required this.body,
    this.title,
    this.action,
  });
  final Color color;
  final String body;
  final String? title;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Panel(
      color: color,
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
          ],
          Text(body),
          if (action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: action!.$2, child: Text(action!.$1)),
            ),
        ],
      ),
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
      RecipeListCard(:final recipes) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          height: 190 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2), // room for wrapped tags at 200 %
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recipes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _IdeaCard(
              recipe: recipes[i],
              onTap: () => agent.showRecipe(recipes[i].id),
            ),
          ),
        ),
      ),
      RecipeCard c => _RecipeTeaser(card: c, agent: agent),
      NutritionCard c => _Framed(
        icon: Icons.pie_chart_outline,
        title: _nutritionTitle(l, c.title),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          NutrientTiles(values: c.values, estimated: c.estimated),
          if (c.values.keys.any(micronutrients.contains))
            ExpansionTile(
              title: Text(l.allNutrientsTitle),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                NutrientTable(values: c.values, goals: c.goals, limits: c.limits, approx: c.approx, partial: c.partial),
              ],
            ),
        ]),
      ),
      PatternsCard(:final patterns) => _Framed(
        icon: Icons.insights_outlined,
        title: l.patternsTitle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in patterns)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('•  ${patternText(l, p)}')),
        ]),
      ),
      InfoCard(:final passages) => _Framed(
        icon: Icons.info_outline,
        title: l.healthInfo,
        color: context.nutrientColor('kcal'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in passages) ...[
              Text(p.text),
              Text('— ${p.source}', style: text.bodySmall),
              const SizedBox(height: 8),
            ],
            Text(
              l.notMedicalAdvice,
              style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      CameraCard c => _Framed(
        icon: Icons.photo_camera_outlined,
        title: l.cameraTitle,
        child: Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.photo_camera),
            label: Text(l.cameraOpen),
            onPressed: () => photoToChat(context, agent, c.mode),
          ),
        ),
      ),
      ConfirmCard c when (c.items.isNotEmpty || c.photo) && c.accepted == null =>
        _MealConfirm(card: c, agent: agent),
      ConfirmCard c => _Framed(
        icon: switch (c.accepted) {
          null => Icons.pending_actions,
          true => Icons.check_circle,
          false => Icons.cancel_outlined,
        },
        title: _confirmTitle(l, c),
        color: c.accepted == false
            ? context.colors.muted
            : context.colors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in c.lines)
              Text(line, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 10),
            switch (c.accepted) {
              // Wrap: at large text sizes the two buttons don't fit on one line.
              null => Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => agent.decide(c, false),
                    child: Text(l.confirmDiscard),
                  ),
                  FilledButton(
                    onPressed: () => agent.decide(c, true),
                    child: Text(l.confirmSave),
                  ),
                ],
              ),
              true when c.undone => Text('↶ ${l.confirmUndone}', style: text.labelLarge),
              true => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '✓ ${l.confirmSaved}',
                    style: text.labelLarge?.copyWith(color: context.colors.primary),
                  ),
                  // A saved meal: undo it here, or fix it on Today (tap the meal there).
                  if (c.undoFrom != null) ...[
                    TextButton(onPressed: () => agent.undo(c), child: Text(l.undo)),
                    TextButton(
                      onPressed: () => ProviderScope.containerOf(context, listen: false)
                          .read(homeTabProvider.notifier)
                          .go(HomeTab.today),
                      child: Text(l.editOnToday),
                    ),
                  ],
                ],
              ),
              false => Text('✕ ${l.confirmDiscarded}', style: text.labelLarge),
            },
          ],
        ),
      ),
    };
  }
}

/// The line above a card shown without a model reply.
String? _caption(AppLocalizations l, AgentCard card) => switch (card) {
  ConfirmCard(photo: true) => l.captionPhoto,
  ConfirmCard() => l.captionConfirm,
  RecipeListCard(:final avoided) when avoided.isNotEmpty =>
    l.captionIdeasAvoiding(avoided.join(', ')),
  RecipeListCard() => l.captionIdeas,
  RecipeCard() => l.captionRecipe,
  NutritionCard() => l.captionNumbers,
  PatternsCard() => l.captionPatterns,
  CameraCard() => l.captionCamera,
  InfoCard() => null,
};

/// The tools write card titles in English (the model reads them too); shown in the app's language.
String _confirmTitle(AppLocalizations l, ConfirmCard c) {
  if (c.mealType != null) {
    final meal = switch (c.mealType) {
      'breakfast' => l.mealBreakfast,
      'lunch' => l.mealLunch,
      'dinner' => l.mealDinner,
      _ => l.mealSnack,
    };
    return l.cardLogMeal(
      l.localeName == 'de' ? meal : meal.toLowerCase(),
    ); // German nouns keep the capital
  }
  return switch (c.title) {
    'Save recipe' => l.cardSaveRecipe,
    'Rate recipe' => l.cardRateRecipe,
    'Remember' => l.cardRemember,
    'Add allergy' => l.cardAddAllergy,
    'Remove allergy' => l.cardRemoveAllergy,
    'Add diet' => l.cardAddDiet,
    'Remove diet' => l.cardRemoveDiet,
    'Log symptom' => l.cardLogSymptom,
    'Log glucose' => l.cardLogGlucose,
    'Log blood pressure' => l.cardLogBloodPressure,
    'Log weight' => l.logWeight,
    'Log water' => l.cardLogWater,
    _ => c.title,
  };
}

String _nutritionTitle(AppLocalizations l, String title) => switch (title) {
  'Today' => l.tabToday,
  'Last 7 days' => l.last7Days,
  _ when title.endsWith(' · per 100 g') =>
    '${title.substring(0, title.length - 12)}${l.per100Suffix}',
  _ => title,
};

/// A white card with an icon and title in the card's accent colour.
class _Framed extends StatelessWidget {
  const _Framed({
    required this.icon,
    required this.title,
    required this.child,
    this.color,
  });
  final IconData icon;
  final String title;
  final Widget child;
  final Color? color; // default: the theme's primary

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// A recipe idea in the side-scrolling row: title, kcal and protein pills, minutes.
class _IdeaCard extends StatelessWidget {
  const _IdeaCard({required this.recipe, required this.onTap});
  final RecipeSummary recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    return SizedBox(
      width: 236,
      child: Panel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recipe.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag('${recipe.kcal.round()} ${l.kcal}', tone: TagTone.water),
                Tag(
                  l.gramsProtein(recipe.protein.round()),
                  tone: TagTone.danger,
                ),
              ],
            ),
            const Spacer(),
            if (recipe.minutes != null)
              Text(
                l.minutesShort(recipe.minutes!),
                style: TextStyle(color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// A recipe the assistant showed: its numbers and the way into the full recipe.
class _RecipeTeaser extends StatelessWidget {
  const _RecipeTeaser({required this.card, required this.agent});
  final RecipeCard card;
  final Agent agent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    void open() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeScreen(
          tools: agent.tools,
          recipeId: card.id,
          onLogged: () {},
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        padding: EdgeInsets.zero,
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecipeArt(title: card.title, height: 96),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Tag(
                        '${card.perServing['kcal']!.round()} ${l.kcal}',
                        tone: TagTone.water,
                      ),
                      Tag(
                        l.gramsProtein(card.perServing['protein_g']!.round()),
                        tone: TagTone.danger,
                      ),
                      if (card.minutes != null)
                        Tag(
                          l.minutesShort(card.minutes!),
                          tone: TagTone.neutral,
                        ),
                    ],
                  ),
                  for (final w in card.cautions)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => agent.ateRecipe(card.id),
                        child: Text(l.iAteThis),
                      ),
                      FilledButton(onPressed: open, child: Text(l.openRecipe)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "I had 2 eggs and toast": the meal to log, every amount editable, the total, Discard or Save.
class _MealConfirm extends StatelessWidget {
  const _MealConfirm({required this.card, required this.agent});
  final ConfirmCard card;
  final Agent agent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final total = card.items.fold(0.0, (s, i) => s + i.values['kcal']!);
    final estimated = card.items.any((i) => i.estimated);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A photo's card: Eva with her camera, and how to check what she saw.
            if (card.photo) ...[
              Row(children: [
                const EvaCutout(size: 72, asset: evaCameraAsset),
                const SizedBox(width: 12),
                Expanded(child: Text(l.photoCardHint, style: TextStyle(fontSize: 15, color: c.ink2))),
              ]),
              const SizedBox(height: 12),
            ],
            if (card.mealType != null) ...[
              ChoicePills<String>(
                values: const ['breakfast', 'lunch', 'dinner', 'snack'],
                selected: card.mealType,
                label: (t) => mealName(l, t),
                scroll: true,
                onChanged: (t) => agent.setMealType(card, t),
              ),
              const SizedBox(height: 8),
            ],
            // Chat guesses foods and amounts: each can be changed, removed or added before Save.
            for (final i in card.items)
              MealItemEditor(
                key: ObjectKey(i),
                label: i.label,
                grams: i.grams,
                kcal: i.values['kcal'],
                servingG: i.servingG,
                estimated: i.estimated,
                seen: i.seen,
                check: i.check,
                onChange: () async {
                  final food = await showDialog<FoodChoice>(
                      context: context, builder: (_) => PickFoodDialog(tools: agent.tools, initial: i.label.split(',').first));
                  if (food != null) agent.setFood(card, i, food);
                },
                onGrams: (g) => agent.setGrams(card, i, g),
                onRemove: () => agent.setFood(card, i, null),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.reviewAdd),
                onPressed: () async {
                  final food = await showDialog<FoodChoice>(
                      context: context, builder: (_) => PickFoodDialog(tools: agent.tools, initial: ''));
                  if (food != null) agent.addFood(card, food);
                },
              ),
            ),
            if (card.notFound.isNotEmpty) Text(l.photoNotMatched(card.notFound.join(', ')), style: TextStyle(color: c.ink2)),
            if (card.photo && card.items.isEmpty && card.notFound.isEmpty) Text(l.reviewEmpty, style: TextStyle(color: c.ink2)),
            if (card.fat case final oil? when !card.items.any((i) => i.label == oil.label))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.water_drop_outlined),
                  label: Text(l.reviewAddFat),
                  onPressed: () => agent.addFood(card, oil),
                ),
              ),
            for (final line in card.lines.skip(card.items.length)) Text(line),
            const SizedBox(height: 6),
            Divider(color: c.divider, thickness: 2),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  '${estimated ? '≈ ' : ''}${total.round()} ${l.kcal}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (card.photo)
                      OutlinedButton(
                        onPressed: () => cookOrSay(context, agent, [...card.items.map((i) => i.label), ...card.notFound]),
                        child: Text(l.reviewCook),
                      ),
                    OutlinedButton(
                      onPressed: () => agent.decide(card, false),
                      child: Text(l.confirmDiscard),
                    ),
                    FilledButton(
                      onPressed: card.items.any((i) => i.grams > 0) ? () => agent.decide(card, true) : null,
                      child: Text(l.confirmSave),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
      if (usual != null)
        l.suggestAte(
          '${usual.servingG!.round()} g ${usual.label.split(',').first}',
        ),
      l.suggestIdea(inSentence(context, meal)),
      l.suggestLeft,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          // First: a photo of the meal (Pro), its foods back here as a card. Not in the input row: on a narrow
          // phone a fourth button there squeezes the field.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Pill(label: l.photoAttach, icon: Icons.photo_camera_outlined, onTap: () => photoToChat(context, agent, 'photo')),
          ),
          for (final t in texts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pill(label: t, onTap: () => onTap(t)),
            ),
        ],
      ),
    );
  }
}

