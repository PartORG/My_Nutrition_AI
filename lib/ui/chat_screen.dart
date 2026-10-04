import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/agent.dart';
import '../agent/agent_tools.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Where "Report this response" drafts go (Play's AI-generated content policy).
// TODO(ievgen): real support address before release.
const supportEmail = 'support@example.com';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.agent});
  final Agent agent;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
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
      CardItem(:final card) => _CardView(card: card, agent: widget.agent, onAsk: _send),
      CrisisItem() => _Notice(
          color: scheme.errorContainer,
          title: l.crisisTitle,
          body: l.crisisBody,
          action: (l.crisisButton, () => launchUrl(Uri.parse('https://findahelpline.com'))),
        ),
      LimitItem(:final dailyFree) => _Notice(color: scheme.secondaryContainer, body: l.limitReached(dailyFree)),
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
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.person, size: 18, color: Colors.white),
          )
        : Container(
            margin: const EdgeInsets.only(right: 8, top: 4),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.cardGreen, shape: BoxShape.circle),
            child: Image.asset('assets/icons/icon_chat.png', width: 40, height: 40),
          );
    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
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
        child: Text(text, style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mine ? [bubble, avatar] : [avatar, bubble],
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
  const _CardView({required this.card, required this.agent, required this.onAsk});
  final AgentCard card;
  final Agent agent;
  final ValueChanged<String> onAsk;

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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Text('${i + 1}'),
                ),
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Wrap(spacing: 6, children: [
                  _Chip(icon: Icons.local_fire_department, color: nutrientColors['kcal']!,
                      label: '${r.kcal.round()} ${l.kcal}'),
                  if (r.minutes != null) _Chip(icon: Icons.schedule, color: AppColors.textSecondary,
                      label: '${r.minutes} min'),
                ]),
                trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                onTap: () => onAsk('Show me recipe ${i + 1}'),
              ),
          ]),
        ),
      RecipeCard c => Card(
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryLight]),
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
                _Section(l.perServing),
                _Nutrients(values: c.perServing),
                const SizedBox(height: 14),
                _Section(l.ingredients),
                for (final i in c.ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const Icon(Icons.check_circle, size: 18, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.name)),
                      Text('${i.grams.round()} g', style: const TextStyle(color: AppColors.textSecondary)),
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
                    onPressed: () => agent.ateRecipe(c.id),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      NutritionCard c => _Framed(
          icon: Icons.pie_chart_outline,
          title: c.title,
          child: _Nutrients(values: c.values, estimated: c.estimated),
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
      CameraCard() => _Framed(icon: Icons.photo_camera_outlined, title: 'Camera', child: Text(l.cameraComing)),
      ConfirmCard c => _Framed(
          icon: switch (c.accepted) {
            null => Icons.pending_actions,
            true => Icons.check_circle,
            false => Icons.cancel_outlined,
          },
          title: c.title,
          color: c.accepted == false ? AppColors.textSecondary : AppColors.primary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final line in c.lines) Text(line),
            const SizedBox(height: 8),
            switch (c.accepted) {
              null => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: Text(l.confirmDiscard),
                    onPressed: () => agent.decide(c, false),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(l.confirmSave),
                    onPressed: () => agent.decide(c, true),
                  ),
                ]),
              true => Text('✓ ${l.confirmSaved}', style: text.labelLarge?.copyWith(color: AppColors.primary)),
              false => Text('✕ ${l.confirmDiscarded}', style: text.labelLarge),
            },
          ]),
        ),
    };
  }
}

/// A card with a tinted header strip: icon + title in the card's accent colour.
class _Framed extends StatelessWidget {
  const _Framed({required this.icon, required this.title, required this.child, this.color = AppColors.primary});
  final IconData icon;
  final String title;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
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
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12), child: child),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary, letterSpacing: .8, fontWeight: FontWeight.w700)),
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
          color: onDark ? Colors.white.withValues(alpha: .2) : (color ?? AppColors.primary).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: onDark ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: onDark ? Colors.white : AppColors.textPrimary)),
        ]),
      );
}

/// Nutrient tiles: a colour bar marks which nutrient, the number and label
/// stay in text colours (readable whatever the hue).
class _Nutrients extends StatelessWidget {
  const _Nutrients({required this.values, this.estimated = false});
  final Nutrients values;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = {
      'kcal': (l.kcal, ''), 'protein_g': (l.protein, 'g'), 'fat_g': (l.fat, 'g'), 'carbs_g': (l.carbs, 'g'),
      'fiber_g': (l.fiber, 'g'), 'sugar_g': (l.sugar, 'g'), 'sodium_mg': (l.sodium, 'mg'),
    };
    final approx = estimated ? '≈' : '';
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in labels.entries)
        if (values[e.key] != null)
          Container(
            width: 92,
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            // Not a one-sided Border: Flutter asserts on non-uniform borders with a radius.
            decoration: BoxDecoration(
              color: nutrientColors[e.key]!.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$approx${values[e.key]!.round()}${e.value.$2.isEmpty ? '' : ' ${e.value.$2}'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: nutrientColors[e.key], shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(child: Text(e.value.$1, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ]),
          ),
    ]);
  }
}
