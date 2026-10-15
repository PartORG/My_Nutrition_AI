import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../data/pin.dart';
import '../data/profiles.dart';
import '../l10n/app_localizations.dart';
import 'goals_screen.dart';

/// The lock: sign-up while the phone has no profile, else its unlock screen.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  Future<void> _create({String? name, String? googleEmail}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CreateProfileScreen(name: name, googleEmail: googleEmail)));
    if (mounted) setState(() {});
  }

  Future<void> _google() async {
    final account = await signInWithGoogle();
    if (account != null && mounted) await _create(name: account.displayName, googleEmail: account.email);
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(profilesProvider).owner;
    if (owner != null) return PinScreen(profile: owner, onDeleted: () => setState(() {}));
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return _Welcome(children: [
      const _Eva(),
      const SizedBox(height: 16),
      Text(l.appTitle, style: text.headlineMedium?.copyWith(color: scheme.onSurface), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      FilledButton.tonalIcon(
        icon: const Icon(Icons.person_add),
        label: Text(l.addProfile),
        onPressed: _create,
      ),
      if (googleClientId.isNotEmpty) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.account_circle),
          label: Text(l.continueWithGoogle),
          onPressed: _google,
        ),
      ],
    ]);
  }
}

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key, this.name, this.googleEmail});

  /// From the Google account, when signing up with it.
  final String? name, googleEmail;

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
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
    final id = await ref.read(profilesProvider).create(name, _pin.text, googleEmail: widget.googleEmail);
    if (!mounted) return;
    ref.read(unlockedProvider.notifier).unlock((id: id, name: name));
    // Skippable onboarding: straight to the goals form, with a "Later" button.
    Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const GoalsScreen(onboarding: true)));
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
  const PinScreen({super.key, required this.profile, required this.onDeleted});
  final ProfileInfo profile;

  /// After "Forgot PIN" deleted the profile.
  final VoidCallback onDeleted;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint straight away when this profile uses it.
    if (ref.read(profilesProvider).biometricEnabled(widget.profile.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fingerprint());
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _fingerprint() async {
    final l = AppLocalizations.of(context)!;
    if (!await authenticateFingerprint(ref, l.fingerprintReason(widget.profile.name)) || !mounted) return;
    ref.read(profilesProvider).unlockedOtherwise(widget.profile.id);
    ref.read(unlockedProvider.notifier).unlock(widget.profile);
  }

  Future<void> _google(String email) async {
    final l = AppLocalizations.of(context)!;
    final account = await signInWithGoogle();
    if (account == null || !mounted) return;
    if (account.email.toLowerCase() != email) {
      setState(() => _error = l.googleWrongAccount);
      return;
    }
    ref.read(profilesProvider).unlockedOtherwise(widget.profile.id);
    ref.read(unlockedProvider.notifier).unlock(widget.profile);
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
    unawaited(ref.read(remindersProvider).cancelProfile(widget.profile.id));
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final google = googleClientId.isEmpty ? null : ref.read(profilesProvider).googleEmail(widget.profile.id);
    return _Welcome(children: [
      _Avatar(profile: widget.profile),
      const SizedBox(height: 16),
      Text(widget.profile.name, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PinField(
            controller: _pin,
            label: l.enterPinFor(widget.profile.name),
            autofocus: true,
            errorText: _error,
            centered: true,
            onSubmitted: (_) => _busy ? null : _unlock(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _busy ? null : _unlock,
            child: _busy ? const _Spinner() : Text(l.unlock),
          ),
        ]),
      ),
      if (ref.read(profilesProvider).biometricEnabled(widget.profile.id)) ...[
        const SizedBox(height: 16),
        IconButton.filledTonal(
          iconSize: 32,
          tooltip: l.useFingerprint,
          icon: const Icon(Icons.fingerprint),
          onPressed: _busy ? null : _fingerprint,
        ),
      ],
      if (google != null) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.account_circle),
          label: Text(l.signInWithGoogle),
          onPressed: _busy ? null : () => _google(google),
        ),
      ],
      const SizedBox(height: 8),
      TextButton(onPressed: _busy ? null : _forgot, child: Text(l.forgotPin)),
    ]);
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.validator,
    this.errorText,
    this.autofocus = false,
    this.centered = false,
    this.onSubmitted,
  });

  final bool centered;

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
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: centered ? const TextStyle(letterSpacing: 8, fontSize: 20) : null,
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
  // No fixed colour: inside a disabled button white was invisible on the light theme.
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2));
}

/// The locked screens: a soft gradient from the theme's colours, content centred and
/// scrollable (200 % text), at most 420 dp wide.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primaryContainer, scheme.surface],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The assistant's face, as in the chat.
class _Eva extends StatelessWidget {
  const _Eva();

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 56,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Image.asset('assets/icons/icon_chat.png', width: 80, height: 80, excludeFromSemantics: true),
      );
}

/// A profile's initial.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});
  final ProfileInfo profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 48,
      backgroundColor: scheme.secondaryContainer,
      child: Text(profile.name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onSecondaryContainer, fontSize: 36)),
    );
  }
}
