import 'package:material_ui/material_ui.dart';

import '../agent/agent.dart';
import '../agent/memory.dart';
import '../l10n/app_localizations.dart';
import 'kit.dart';
import 'theme.dart';

/// "What the AI knows about you": every memory the agent is fed, editable.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, required this.agent});
  final Agent agent;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  Memory get _memory => widget.agent.memory;

  Future<void> _editFact(int id, String text) async {
    final result = await showDialog<String>(context: context, builder: (_) => _EditDialog(text));
    if (result == null) return;
    setState(() => result.trim().isEmpty ? _memory.deleteFact(id) : _memory.updateFact(id, result));
  }

  Future<void> _forget() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.forgetConversations),
        content: Text(l.forgetConversationsBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
            child: Text(l.forget),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.agent.forgetConversations();
    if (mounted) setState(() {});
  }

  Future<void> _addAllergy() async {
    final l = AppLocalizations.of(context)!;
    final text = await showDialog<String>(
        context: context, builder: (_) => _EditDialog('', title: l.addAllergyTitle, hint: l.addAllergyHint));
    if (text == null || text.trim().isEmpty || !mounted) return;
    final added = _memory.addAllergy(text);
    setState(() {});
    if (added == null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.allergyUnknown(text.trim()))));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final facts = _memory.facts();
    final allergies = _memory.allergies();
    final habits = _memory.habits();
    final messages = _memory.conversationCount();
    const diets = {'vegetarian', 'vegan', 'pescatarian'};
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Semantics(header: true, child: Text(l.aiKnowsTitle, style: Theme.of(context).textTheme.headlineLarge)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline, size: 18, color: c.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l.aiKnowsIntro, style: TextStyle(fontSize: 15, color: c.ink2))),
          ]),
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.factsSection, style: Theme.of(context).textTheme.titleMedium),
              if (facts.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.factsEmpty)),
              for (final (i, f) in facts.indexed) ...[
                if (i > 0) Divider(color: c.divider),
                Row(children: [
                  Expanded(child: Text(f.text, style: const TextStyle(fontSize: 16))),
                  IconButton(tooltip: l.edit, icon: const Icon(Icons.edit_outlined), onPressed: () => _editFact(f.id, f.text)),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.allergiesSection, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in allergies)
                  _RemovableChip(
                    label: a,
                    diet: diets.contains(a),
                    tooltip: l.delete,
                    onRemove: () => setState(() => _memory.removeAllergy(a)),
                  ),
                SizedBox(
                  width: 120,
                  child: DashedAdd(
                    radius: 26,
                    onTap: _addAllergy,
                    child: Center(
                      child: Text(l.addShort, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.primary)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: l.habitsSection, style: Theme.of(context).textTheme.titleMedium),
                TextSpan(text: ' · ${l.lastDays(30)}', style: TextStyle(fontSize: 14, color: c.muted)),
              ])),
              const SizedBox(height: 8),
              Text(habits?.replaceFirst('Habits (30 days): ', '') ?? l.habitsEmpty, style: TextStyle(fontSize: 15, color: c.ink2)),
            ]),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.conversationsSection, style: Theme.of(context).textTheme.titleMedium),
                  Text(l.conversationsCount(messages), style: TextStyle(color: c.muted)),
                ]),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: c.danger, side: BorderSide(color: c.danger)),
                onPressed: messages == 0 ? null : _forget,
                child: Text(l.forget),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// An allergy (red) or diet (green) with its × to remove it.
class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.diet, required this.tooltip, required this.onRemove});
  final String label, tooltip;
  final bool diet;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = diet ? (c.mint, c.onMint) : (c.dangerBg, c.danger);
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label[0].toUpperCase() + label.substring(1), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
        IconButton(tooltip: '$tooltip $label', icon: Icon(Icons.close, size: 18, color: fg), onPressed: onRemove),
      ]),
    );
  }
}

/// Owns its controller: disposing it when showDialog returns would crash,
/// because the dialog is still animating out and its TextField still uses it.
class _EditDialog extends StatefulWidget {
  const _EditDialog(this.text, {this.title, this.hint});
  final String text;
  final String? title, hint;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title ?? l.edit),
      content: TextField(
          controller: _controller, autofocus: true, maxLines: 3, minLines: 1, decoration: InputDecoration(hintText: widget.hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(l.confirmSave)),
      ],
    );
  }
}
