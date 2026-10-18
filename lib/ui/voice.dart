import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../l10n/app_localizations.dart';

/// Dictation into a text field (food search, shopping list; the chat until the AI is loaded). On-device
/// recognition only: falling back to online recognition would send the user's voice to a server.
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

// ---- the chat: Gemma 4 listens, the phone's voice answers ----------------------------------------

/// Chat voice input: records the user, then Gemma 4 (already on the phone) writes down what was said. It
/// knows food names better than Android's recognizer and needs no offline speech pack. The recording is a
/// temporary file, deleted as soon as it's read.
class VoiceRecorder {
  VoiceRecorder(this.onChanged);

  /// Started, stopped, or the level changed.
  final VoidCallback onChanged;

  AudioRecorder? _recorder; // made on the first tap: it opens a native recorder
  AudioRecorder get _rec => _recorder ??= AudioRecorder();
  StreamSubscription<Amplitude>? _levels;
  bool recording = false;

  /// Loudness for the UI, 0..1.
  double level = 0;

  /// Gemma takes up to 30 s of audio per clip.
  static const maxLength = Duration(seconds: 30);

  /// Starts recording; [onQuiet] runs once the user has spoken and gone quiet (or after [maxLength]).
  /// False when the microphone isn't allowed.
  Future<bool> start({required VoidCallback onQuiet}) async {
    if (recording) return true;
    if (!await _rec.hasPermission()) return false;
    final path = '${(await getTemporaryDirectory()).path}/voice.wav';
    // 16 kHz mono WAV is what Gemma's audio encoder takes. The voice-recognition source: no loudness tricks.
    await _rec.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1,
            androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition)),
        path: path);
    recording = true;
    final gate = SilenceGate();
    final started = DateTime.now();
    _levels = _rec.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((a) {
      level = ((a.current + 50) / 50).clamp(0, 1);
      onChanged();
      final t = DateTime.now().difference(started);
      if (gate.quiet(a.current, t) || t >= maxLength) onQuiet();
    });
    onChanged();
    return true;
  }

  /// Stops and returns the recording (then deleted from disk); null when too short to hold words.
  Future<Uint8List?> stop() async {
    if (!recording) return null;
    recording = false;
    level = 0;
    await _levels?.cancel();
    final path = await _rec.stop();
    onChanged();
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final wav = file.readAsBytesSync();
    file.deleteSync();
    return wav.length > 44 + 16000 * 2 ~/ 2 ? wav : null; // under half a second: a mis-tap
  }

  void dispose() {
    _levels?.cancel();
    final rec = _recorder;
    if (rec == null) return;
    if (recording) unawaited(rec.cancel()); // cancel deletes the file
    unawaited(rec.dispose());
  }
}

/// Ends a recording once the user has spoken and then been quiet for [pause]; or after [nothing] without
/// a word. Levels in dBFS, as the recorder reports them.
// shortcut: thresholds picked for a phone held in the hand, not measured on many phones; tune if it cuts people off.
class SilenceGate {
  static const speech = -35.0;
  static const pause = Duration(seconds: 2);
  static const nothing = Duration(seconds: 8);

  Duration? _lastLoud;

  bool quiet(double dbfs, Duration t) {
    if (dbfs > speech) {
      _lastLoud = t;
      return false;
    }
    final last = _lastLoud;
    return last == null ? t >= nothing : t - last >= pause;
  }
}

const _languageNames = {'en': 'English', 'uk': 'Ukrainian', 'de': 'German', 'fr': 'French'};

/// Gemma 4 writes down [wav] in the app's [language]. Its own session, so the chat's conversation is untouched.
Future<String> transcribe(InferenceModel model, Uint8List wav, String language) async {
  final name = _languageNames[language] ?? 'English';
  final session = await model.openSession(temperature: 0, topK: 1, enableAudioModality: true, maxOutputTokens: 256);
  try {
    await session.addQueryChunk(Message.withAudio(
        text: 'Transcribe the following speech segment in $name into $name text. Write only the transcription; '
            'if nothing is said, write nothing.',
        audioBytes: wav,
        isUser: true));
    return cleanTranscript(await session.getResponse());
  } finally {
    await session.close();
  }
}

/// The words only: no quotes, labels or the model's end-of-turn marks.
String cleanTranscript(String reply) => reply
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceFirst(RegExp(r'^\s*(transcription|transcript)\s*:\s*', caseSensitive: false), '')
    .trim()
    .replaceAll(RegExp(r'^["“«„]+|["”»“]+$'), '')
    .trim();

/// A voice of the phone's text-to-speech engine; [pitch] makes a woman or man of the only voice there is.
typedef VoicePick = ({String name, String locale, double pitch});

/// Google's on-device voices that sound male, by the code in their name ("en-us-x-iom-local").
const _maleVoices = {'iol', 'iom', 'tpd', 'gbb', 'gbd', 'rjs', 'deg', 'frb', 'frd'};

/// The region tried first for each app language.
const _mainLocale = {'en': 'en-us', 'uk': 'uk-ua', 'de': 'de-de', 'fr': 'fr-fr'};

/// The installed, offline voice for [language] that is a man or a woman; null = the engine's default
/// voice for the language. [voices] as flutter_tts reports them (name, locale, network_required, features).
VoicePick? pickVoice(List<Map<String, String>> voices, {required String language, required bool male}) {
  String locale(Map<String, String> v) => (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
  final main = _mainLocale[language];
  final local = [
    for (final v in voices)
      if (locale(v).split('-').first == language &&
          v['network_required'] != '1' && // never send the text to a server
          !(v['features'] ?? '').contains('notInstalled') &&
          v['name'] != null)
        v
  ]..sort((a, b) {
      final byRegion = (locale(a) == main ? 0 : 1) - (locale(b) == main ? 0 : 1);
      return byRegion != 0 ? byRegion : a['name']!.compareTo(b['name']!);
    });
  if (local.isEmpty) return null;
  bool isMale(Map<String, String> v) => _maleVoices.any((code) => v['name']!.contains('-x-$code'));
  final match = local.where((v) => isMale(v) == male).firstOrNull;
  // None of that kind for this language (Ukrainian has one voice): the other one, pitched.
  final v = match ?? local.first;
  return (name: v['name']!, locale: v['locale']!, pitch: match != null ? 1.0 : (male ? .75 : 1.2));
}

/// Reads the assistant's answers aloud with the phone's own voices, offline ones only.
class Speaker {
  final _tts = FlutterTts();

  Future<void> say(String text, {required String language, required bool male}) async {
    text = text.replaceAll(RegExp(r'[*#_`]'), '').trim(); // markdown marks would be read out
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      final voices = [
        for (final v in (await _tts.getVoices as List?) ?? const [])
          if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'}
      ];
      final voice = pickVoice(voices, language: language, male: male);
      await _tts.setLanguage(voice?.locale ?? language);
      if (voice != null) await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      await _tts.setPitch(voice?.pitch ?? (male ? .75 : 1.0));
      await _tts.speak(text);
    } on Object catch (e) {
      debugPrint('tts: $e'); // no engine or no voice for the language: the answer is still on screen
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (_) {}
  }
}
