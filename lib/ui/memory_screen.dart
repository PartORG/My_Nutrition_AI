import 'package:flutter/material.dart';

import '../agent/agent.dart';
import '../agent/memory.dart';
import '../l10n/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final facts = _memory.facts();
    final allergies = _memory.allergies();
    final habits = _memory.habits();
    final messages = _memory.conversationCount();
    return Scaffold(
      appBar: AppBar(title: Text(l.aiKnowsTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.aiKnowsIntro, style: const TextStyle(color: AppColors.textSecondary)),
        _Section(icon: Icons.lightbulb_outline, title: l.factsSection, children: [
          if (facts.isEmpty) Text(l.factsEmpty),
          for (final f in facts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f.text),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: l.edit, icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editFact(f.id, f.text)),
                IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _memory.deleteFact(f.id))),
              ]),
            ),
        ]),
        _Section(icon: Icons.no_food_outlined, title: l.allergiesSection, children: [
          if (allergies.isEmpty) Text(l.allergiesEmpty),
          Wrap(spacing: 8, children: [
            for (final a in allergies)
              InputChip(
                label: Text(a),
                deleteButtonTooltipMessage: l.delete,
                onDeleted: () => setState(() => _memory.removeAllergy(a)),
              ),
          ]),
        ]),
        _Section(icon: Icons.insights_outlined, title: l.habitsSection, children: [
          Text(habits?.replaceFirst('Habits (30 days): ', '') ?? l.habitsEmpty),
        ]),
        _Section(icon: Icons.forum_outlined, title: l.conversationsSection, children: [
          Text(l.conversationsCount(messages)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(l.forgetConversations),
            onPressed: messages == 0 ? null : _forget,
          ),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );
}

/// Owns its controller: disposing it when showDialog returns would crash,
/// because the dialog is still animating out and its TextField still uses it.
class _EditDialog extends StatefulWidget {
  const _EditDialog(this.text);
  final String text;

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
      title: Text(l.edit),
      content: TextField(controller: _controller, autofocus: true, maxLines: 3, minLines: 1),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ElevatedButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(l.confirmSave)),
      ],
    );
  }
}
