import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../data/pin.dart';
import '../data/profiles.dart';
import '../l10n/app_localizations.dart';
import 'avatar.dart';
import 'goals_screen.dart';
import 'kit.dart';
import 'theme.dart';

/// The lock: first run while the phone has no profile, else its unlock screen.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(profilesProvider).owner;
    if (owner != null) return PinScreen(profile: owner, onDeleted: () => setState(() {}));
    return const FirstRunScreen();
  }
}

/// First run, three steps: your name (or Google's), a PIN and the fingerprint, then the goals form.
class FirstRunScreen extends ConsumerStatefulWidget {
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _googleEmail;
  AvatarKind? _kind; // null: follows the sex given for the goals
  var _step = 0;
  var _fingerprint = true;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    final account = await signInWithGoogle();
    if (account == null || !mounted) return;
    setState(() {
      _name.text = account.displayName ?? _name.text;
      _googleEmail = account.email;
      if (_name.text.trim().isNotEmpty) _step = 1;
    });
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final profiles = ref.read(profilesProvider);
    final id = await profiles.create(name, _pin.text, googleEmail: _googleEmail);
    if (!mounted) return;
    if (_kind case final kind?) ref.read(avatarProvider.notifier).set(kind: kind);
    // Turning fingerprint unlock on takes one scan, so it's the owner's finger.
    if (_fingerprint &&
        ref.read(biometricsAvailableProvider).value == true &&
        await authenticateFingerprint(ref, l.fingerprintReason(name))) {
      profiles.setBiometric(id, true);
    }
    if (!mounted) return;
    ref.read(unlockedProvider.notifier).unlock((id: id, name: name));
    // Step three: the goals form, with a "Later" button.
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GoalsScreen(onboarding: true))));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final progress = ExcludeSemantics(
      child: Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(color: i <= _step ? c.primary : c.outline, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ],
      ]),
    );
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) setState(() => _step = 0);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: [
                  progress,
                  const SizedBox(height: 24),
                  if (_step == 0) ..._nameStep(l, c) else ..._pinStep(l, c),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _nameStep(AppLocalizations l, AppPalette c) {
    Widget point(IconData icon, Color bg, Color fg, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: c.ink))),
          ]),
        );
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.eco_outlined, color: Colors.white, size: 34),
        ),
      ),
      const SizedBox(height: 20),
      Semantics(header: true, child: Text(l.welcomeHeadline, style: Theme.of(context).textTheme.headlineLarge)),
      const SizedBox(height: 10),
      Text(l.welcomeIntro, style: TextStyle(fontSize: 17, color: c.ink2, height: 1.4)),
      const SizedBox(height: 22),
      point(Icons.lock_outline, c.mint, c.primary, l.welcomePointPrivate),
      point(Icons.search, c.waterBg, c.water, l.welcomePointData),
      point(Icons.shield_outlined, c.warm, c.onWarm, l.welcomePointAllergens),
      const SizedBox(height: 28),
      Text(l.yourName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        decoration: InputDecoration(hintText: l.nameExample),
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        onSubmitted: (t) {
          if (t.trim().isNotEmpty) setState(() => _step = 1);
        },
      ),
      const SizedBox(height: 18),
      Text(l.avatarTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(l.avatarHint, style: TextStyle(fontSize: 14, color: c.muted)),
      AvatarKindPicker(selected: _kind, onSelected: (k) => setState(() => _kind = k)),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _name.text.trim().isEmpty ? null : () => setState(() => _step = 1),
        child: Text(l.continueButton),
      ),
      if (googleClientId.isNotEmpty) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(icon: const Icon(Icons.account_circle_outlined), label: Text(l.continueWithGoogle), onPressed: _google),
      ],
      const SizedBox(height: 12),
      Text(googleClientId.isEmpty ? l.firstRunNext : '${l.googleOnlyName} ${l.firstRunNext}',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.muted)),
    ];
  }

  List<Widget> _pinStep(AppLocalizations l, AppPalette c) {
    final biometrics = ref.watch(biometricsAvailableProvider).value == true;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => setState(() => _step = 0),
        ),
      ),
      Semantics(header: true, child: Text(l.lockItTitle, style: Theme.of(context).textTheme.headlineLarge)),
      const SizedBox(height: 10),
      Text(l.pinHint, style: TextStyle(fontSize: 16, color: c.ink2, height: 1.4)),
      const SizedBox(height: 20),
      _PinField(controller: _pin, label: l.pinLabel, validator: (v) => isValidPin(v!) ? null : l.pinInvalid),
      const SizedBox(height: 12),
      _PinField(controller: _pin2, label: l.pinConfirmLabel, validator: (v) => v == _pin.text ? null : l.pinMismatch),
      if (biometrics) ...[
        const SizedBox(height: 12),
        Panel(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            secondary: Icon(Icons.fingerprint, color: c.primary),
            title: Text(l.fingerprintTitle),
            subtitle: Text(l.fingerprintHint),
            value: _fingerprint,
            onChanged: (on) => setState(() => _fingerprint = on),
          ),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _create, child: _busy ? const _Spinner() : Text(l.create)),
    ];
  }
}

/// Unlock: the profile on deep green, the fingerprint first; the PIN, Google and "forgot" below.
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
  late bool _showPin = !ref.read(profilesProvider).biometricEnabled(widget.profile.id);

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint straight away when this profile uses it.
    if (!_showPin) WidgetsBinding.instance.addPostFrameCallback((_) => _fingerprint());
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
    final c = context.colors;
    const white = Colors.white;
    final google = googleClientId.isEmpty ? null : ref.read(profilesProvider).googleEmail(widget.profile.id);
    final biometric = ref.read(profilesProvider).biometricEnabled(widget.profile.id);
    // Fixed dark ink: c.ink is near-white in the dark theme, invisible on white or gold.
    final whiteButton = FilledButton.styleFrom(backgroundColor: white, foregroundColor: AppPalette.light.ink);
    final unlockButton = FilledButton.styleFrom(
        backgroundColor: c.gold, foregroundColor: AppPalette.light.ink, elevation: 2, shadowColor: Colors.black54);
    final outline = OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent, foregroundColor: white, side: BorderSide(color: white.withValues(alpha: .45)));
    return Scaffold(
      backgroundColor: c.hero,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 24),
                // The user's picture with Eva, the assistant, at its corner.
                Center(
                  child: Stack(clipBehavior: Clip.none, children: [
                    const CircleAvatar(radius: 52, backgroundColor: white, child: UserAvatar(radius: 48)),
                    Positioned(
                      right: -8,
                      bottom: -4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: white, width: 3)),
                        child: const EvaAvatar(size: 46),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(l.welcomeBack(widget.profile.name),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: white, letterSpacing: -0.5)),
                ),
                const SizedBox(height: 6),
                Text(l.dataLocked, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: white.withValues(alpha: .85))),
                const SizedBox(height: 40),
                if (_showPin) ...[
                  // Light theme whatever the app's: a white field needs dark text. The label stays
                  // inside the field: floated, it sat on the green background unreadable.
                  Theme(
                    data: AppTheme.build(Brightness.light).copyWith(
                      inputDecorationTheme: AppTheme.build(Brightness.light)
                          .inputDecorationTheme
                          .copyWith(fillColor: white, floatingLabelBehavior: FloatingLabelBehavior.never),
                    ),
                    child: _PinField(
                      controller: _pin,
                      label: l.enterPinFor(widget.profile.name),
                      autofocus: true,
                      centered: true,
                      onSubmitted: (_) => _busy ? null : _unlock(),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.gold, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 14),
                  FilledButton(style: unlockButton, onPressed: _busy ? null : _unlock, child: _busy ? const _Spinner() : Text(l.unlock)),
                  if (biometric) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: outline,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(l.useFingerprint),
                      onPressed: _busy ? null : _fingerprint,
                    ),
                  ],
                ] else ...[
                  Center(
                    child: Semantics(
                      button: true,
                      label: l.useFingerprint,
                      excludeSemantics: true,
                      child: Material(
                        color: white.withValues(alpha: .14),
                        shape: CircleBorder(side: BorderSide(color: white.withValues(alpha: .4), width: 2)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _fingerprint,
                          child: const SizedBox.square(dimension: 128, child: Icon(Icons.fingerprint, size: 56, color: white)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l.touchSensor,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: white)),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.gold, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 56),
                  FilledButton(style: whiteButton, onPressed: () => setState(() => _showPin = true), child: Text(l.usePin)),
                ],
                if (google != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: outline,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(l.signInWithGoogle),
                    onPressed: _busy ? null : () => _google(google),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: white),
                  onPressed: _busy ? null : _forgot,
                  child: Text(l.forgotPin, style: const TextStyle(decoration: TextDecoration.underline, decorationColor: white)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.validator,
    this.autofocus = false,
    this.centered = false,
    this.onSubmitted,
  });

  final bool centered;

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, counterText: ''),
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
