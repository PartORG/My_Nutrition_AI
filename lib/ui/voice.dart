import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/app_localizations.dart';

/// Dictation into a text field (chat, food search, shopping list). On-device recognition only:
/// falling back to online recognition would send the user's voice to a server.
class Dictation {
  Dictation(this.field, this.onChanged);
  final TextEditingController field;

  /// Listening started or stopped, or new words arrived.
  final VoidCallback onChanged;

  final _speech = SpeechToText();
  bool listening = false; // from the mic tap until the user taps again or stays quiet for _pause
  DateTime _heard = DateTime.now();
  // Android's recognizer ends a session after ~1-2 s of silence and often ignores pauseFor,
  // so we restart it and keep appending until the user has been quiet this long.
  static const _pause = Duration(seconds: 5);

  Future<void> toggle(BuildContext context) async {
    if (listening) {
      listening = false;
      onChanged();
      await _speech.stop();
      return;
    }
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    void unavailable() {
      listening = false;
      onChanged();
      messenger.showSnackBar(SnackBar(content: Text(l.voiceUnavailable)));
    }

    final ok = await _speech.initialize(
      onError: (e) {
        // A pause or nothing said is not "voice unavailable"; the done status handles it.
        if (e.errorMsg != 'error_no_match' && e.errorMsg != 'error_speech_timeout') unavailable();
      },
      onStatus: (s) {
        if (s == SpeechToText.doneStatus) _sessionEnded();
      },
    );
    if (!ok) return unavailable();
    listening = true;
    onChanged();
    _heard = DateTime.now();
    await _listen();
  }

  void _sessionEnded() {
    if (!listening) return;
    if (DateTime.now().difference(_heard) < _pause) {
      _listen();
    } else {
      listening = false;
      onChanged();
    }
  }

  Future<void> _listen() async {
    // Keep what is already in the field (typed or said before the pause) and append to it.
    final before = field.text.trim();
    await _speech.listen(
      onResult: (r) {
        if (!listening || r.recognizedWords.isEmpty) return;
        _heard = DateTime.now();
        field.text = '$before ${r.recognizedWords}'.trim();
        onChanged();
      },
      listenOptions:
          SpeechListenOptions(onDevice: true, listenMode: ListenMode.dictation, partialResults: true, pauseFor: _pause),
    );
  }

  void dispose() {
    listening = false;
    _speech.cancel();
  }
}

/// The mint mic button of the search fields and the shopping list.
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.dictation, required this.onPressed});
  final Dictation dictation;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: dictation.listening ? l.voiceStop : l.voiceInput,
      style: IconButton.styleFrom(
        backgroundColor: dictation.listening ? scheme.primary : scheme.primaryContainer,
        foregroundColor: dictation.listening ? scheme.onPrimary : scheme.primary,
        minimumSize: const Size(52, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      icon: Icon(dictation.listening ? Icons.stop : Icons.mic_none),
    );
  }
}
