import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../data/pin.dart';
import '../data/profiles.dart';
import '../l10n/app_localizations.dart';

/// "Who's eating?" — pick a profile or add one.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {}); // list may have changed
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final profiles = ref.watch(profilesProvider).list();
    return Scaffold(
      appBar: AppBar(title: Text(l.whoIsEating)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in profiles)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(p.name.characters.first.toUpperCase())),
                title: Text(p.name),
                onTap: () => _open(PinScreen(profile: p)),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add),
            label: Text(l.addProfile),
            onPressed: () => _open(const CreateProfileScreen()),
          ),
        ],
      ),
    );
  }
}

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final id = await ref.read(profilesProvider).create(name, _pin.text);
    if (!mounted) return;
    ref.read(unlockedProvider.notifier).unlock((id: id, name: name));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.addProfile)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.profileName),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? l.nameRequired : null,
            ),
            const SizedBox(height: 12),
            _PinField(controller: _pin, label: l.pinLabel,
                validator: (v) => isValidPin(v!) ? null : l.pinInvalid),
            const SizedBox(height: 12),
            _PinField(controller: _pin2, label: l.pinConfirmLabel,
                validator: (v) => v == _pin.text ? null : l.pinMismatch),
            const SizedBox(height: 12),
            Text(l.pinHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _create,
              child: _busy ? const _Spinner() : Text(l.create),
            ),
          ],
        ),
      ),
    );
  }
}

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key, required this.profile});
  final ProfileInfo profile;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final r = await ref.read(profilesProvider).unlock(widget.profile.id, _pin.text);
    if (!mounted) return;
    _pin.clear();
    switch (r) {
      case PinOk():
        ref.read(unlockedProvider.notifier).unlock(widget.profile);
        Navigator.of(context).pop();
        return;
      case PinWrong(:final attemptsLeft):
        _error = l.pinWrong(attemptsLeft);
      case PinLocked(:final until):
        _error = l.pinLocked(until.difference(DateTime.now()).inSeconds + 1);
    }
    setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteProfileTitle(widget.profile.name)),
        content: Text(l.deleteProfileBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(profilesProvider).delete(widget.profile.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.profile.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PinField(
            controller: _pin,
            label: l.enterPinFor(widget.profile.name),
            autofocus: true,
            errorText: _error,
            onSubmitted: (_) => _busy ? null : _unlock(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _unlock,
            child: _busy ? const _Spinner() : Text(l.unlock),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : _forgot, child: Text(l.forgotPin)),
        ],
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.validator,
    this.errorText,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, errorText: errorText, counterText: ''),
        obscureText: true,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 6,
        validator: validator,
        onFieldSubmitted: onSubmitted,
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
      dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
}
