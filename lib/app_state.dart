import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent/agent.dart';
import 'agent/agent_tools.dart';
import 'agent/chat_limit.dart';
import 'agent/gemma_chat_model.dart';
import 'agent/memory.dart';
import 'billing/billing.dart';
import 'billing/revenuecat_billing.dart';
import 'data/diary.dart';
import 'data/goals.dart';
import 'data/nutri_db.dart';
import 'data/profiles.dart';
import 'data/user_db.dart';
import 'reminders_service.dart';

/// App-private data directory, with nutri.db installed from the bundled asset
/// when missing or unreadable by this build. Overridden in tests.
final appDirProvider = FutureProvider<Directory>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final nutri = File('${dir.path}/nutri.db');
  try {
    openNutriDb(nutri.path).close();
  } on Object {
    // ponytail: bundled dummy db; the real one (≤ 300 MB) needs its own delivery, see docs/PLAN.md M7.
    final tmp = File('${dir.path}/nutri.db.download');
    final data = await rootBundle.load('assets/nutri.db');
    await tmp.writeAsBytes(data.buffer.asUint8List(), flush: true);
    installNutriDb(tmp, nutri);
  }
  return dir;
});

final profilesProvider = Provider<Profiles>((ref) {
  final profiles = Profiles.open(ref.watch(appDirProvider).requireValue);
  ref.onDispose(profiles.close);
  return profiles;
});

/// Light / dark / follow the phone, and wallpaper colours (Android 12+). Per phone.
typedef Appearance = ({ThemeMode mode, bool wallpaper});

final appearanceProvider = NotifierProvider<AppearanceSettings, Appearance>(AppearanceSettings.new);

class AppearanceSettings extends Notifier<Appearance> {
  @override
  Appearance build() {
    // Before the app folder is ready (first frames): follow the phone.
    final p = ref.watch(appDirProvider).hasValue ? ref.watch(profilesProvider) : null;
    return (
      mode: ThemeMode.values.asNameMap()[p?.setting('theme')] ?? ThemeMode.system,
      wallpaper: p?.setting('wallpaper_colors') == '1',
    );
  }

  void set({ThemeMode? mode, bool? wallpaper}) {
    final p = ref.read(profilesProvider);
    if (mode != null) p.setSetting('theme', mode.name);
    if (wallpaper != null) p.setSetting('wallpaper_colors', wallpaper ? '1' : '0');
    state = (mode: mode ?? state.mode, wallpaper: wallpaper ?? state.wallpaper);
  }
}

/// The profile currently unlocked with its PIN; null = locked.
final unlockedProvider =
    NotifierProvider<UnlockedProfile, ProfileInfo?>(UnlockedProfile.new);

class UnlockedProfile extends Notifier<ProfileInfo?> {
  @override
  ProfileInfo? build() => null;

  void unlock(ProfileInfo profile) => state = profile;
  void lock() => state = null;
}

/// Total RAM in MB from /proc/meminfo (Android); null where unavailable.
int? totalRamMb() {
  try {
    final line = File('/proc/meminfo')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('MemTotal:'));
    return int.parse(RegExp(r'\d+').firstMatch(line)![0]!) ~/ 1024;
  } on Object {
    return null;
  }
}

/// A "6 GB" phone reports ~5.4–5.7 GB after the kernel's share.
const minRamMb = 5000;

// ---- on-device AI -----------------------------------------------------------

/// A chat model the user can download. Both are Gemma 4 (Apache 2.0, ungated)
/// from Hugging Face, downloaded once when the user asks: over Play's 1.5 GB
/// asset-pack limit. Only the model comes over the network; nothing about the user goes out.
typedef Llm = ({String file, String url, int downloadMb, int minRamMb});

/// E2B: the default, measured in M0 (95.2% tool accuracy; same SHA-256 as that file).
const e2b = (
  file: 'gemma-4-E2B-it.litertlm',
  url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  downloadMb: 2468,
  minRamMb: minRamMb,
);

/// E4B: larger and smarter, ~3x slower prefill; offered on 8 GB phones only
/// (they report ~7.2-7.6 GB). The full file, not "-gpu": photo mode needs its vision part.
// ponytail: tool accuracy not measured yet; run integration_test/agent_eval_test.dart with MODEL_PATH on the phone.
const e4b = (
  file: 'gemma-4-E4B-it.litertlm',
  url: 'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
  downloadMb: 3490,
  minRamMb: 7000,
);

/// Models this phone can run, smallest first. Unknown RAM (not Android): E2B only.
List<Llm> llmChoices() {
  final ram = Platform.isAndroid ? totalRamMb() : null;
  return [e2b, if (ram != null && ram >= e4b.minRamMb) e4b];
}

/// The model the chat uses: the larger one the user downloaded, if this phone can run it.
Future<Llm?> installedLlm() async {
  for (final m in llmChoices().reversed) {
    if (await FlutterGemma.isModelInstalled(m.file)) return m;
  }
  return null;
}

/// EmbeddingGemma is gated on Hugging Face (Gemma terms allow redistribution),
/// so it ships inside the app from git-ignored files in assets/models/.
const embedderAsset = 'assets/models/embeddinggemma-300M_seq256.tflite'; // M1: 2.5x faster than seq512, same vectors
const tokenizerAsset = 'assets/models/embeddinggemma_sentencepiece.model';

/// The chat model isn't on the phone yet: the Chat tab offers the download.
class LlmNotDownloaded implements Exception {}

final _gemmaReadyProvider = FutureProvider<void>((ref) => FlutterGemma.initialize(
      inferenceEngines: [LiteRtLmEngine()],
      embeddingBackends: [LiteRtEmbeddingBackend()],
      embeddingTokenizers: [GemmaEmbeddingTokenizers()],
    ));

InferenceInstallationBuilder _llmInstall() =>
    FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm);

/// Loaded once per app run; first launch ~38 s (GPU setup), then ~3 s.
/// Development: a file `adb push`ed into the external files dir's models/ wins
/// (see integration_test/agent_latency_test.dart).
final llmProvider = FutureProvider<InferenceModel>((ref) async {
  await ref.watch(_gemmaReadyProvider.future);
  final devDir = (await getExternalStorageDirectory())?.path;
  final dev = [for (final m in llmChoices().reversed) File('$devDir/models/${m.file}')]
      .where((f) => f.existsSync())
      .firstOrNull;
  final installed = await installedLlm();
  if (dev != null) {
    await _llmInstall().fromFile(dev.path).install();
  } else if (installed != null) {
    await _llmInstall().fromNetwork(installed.url).install(); // already downloaded: no network, just activates it
  } else {
    throw LlmNotDownloaded();
  }
  // supportImage: photo mode names the foods with the same model (vision encoder on the CPU).
  final model = await FlutterGemma.getActiveModel(
      maxTokens: 4096, preferredBackend: PreferredBackend.gpu, supportImage: true, maxNumImages: 1);
  ref.onDispose(model.close);
  return model;
});

/// Download progress in % while the chat model downloads; null when idle.
final llmDownloadProvider = NotifierProvider<LlmDownload, int?>(LlmDownload.new);

class LlmDownload extends Notifier<int?> {
  CancelToken? _cancel;

  @override
  int? build() => null;

  /// Resumable (flutter_gemma's background downloader). Throws on failure.
  /// Switching models: the other one is deleted once [model] is in, so the
  /// phone never keeps 6 GB of models.
  Future<void> start([Llm model = e2b]) async {
    if (state != null) return;
    state = 0;
    _cancel = CancelToken();
    try {
      await ref.read(_gemmaReadyProvider.future);
      await _llmInstall().fromNetwork(model.url).withProgress((p) => state = p).withCancelToken(_cancel!).install();
      // Delete first, so the reload can't pick the old one. A loaded model keeps
      // its open file until the reload closes it.
      for (final other in [e2b, e4b]) {
        if (other != model && await FlutterGemma.isModelInstalled(other.file)) {
          await FlutterGemma.uninstallModel(other.file);
        }
      }
      ref.invalidate(llmProvider);
    } finally {
      state = null;
      _cancel = null;
    }
  }

  void cancel() => _cancel?.cancel('cancelled by the user');
}

final embedderProvider = FutureProvider<EmbeddingModel>((ref) async {
  await ref.watch(_gemmaReadyProvider.future);
  await FlutterGemma.installEmbedder().modelFromAsset(embedderAsset).tokenizerFromAsset(tokenizerAsset).install();
  return FlutterGemma.getActiveEmbedder();
});

/// The unlocked profile's databases, open as soon as the PIN is accepted so
/// Today/Log/Me don't wait ~40 s for the model. Closed on lock.
class ProfileData {
  ProfileData({required this.profile, required this.nutri, required this.user, required this.tools});
  final ProfileInfo profile;
  final Database nutri, user;
  final AgentTools tools;

  /// Bumped on every write, so the dashboard redraws after logging anywhere.
  final changes = ValueNotifier<int>(0);
  void changed() => changes.value++;
}

/// Null while locked. Auto-dispose: once no screen shows the profile (after
/// Lock), its databases close. Returning null instead of throwing matters: for
/// one frame during the switch the old screens still watch this.
final profileDataProvider = Provider.autoDispose<ProfileData?>((ref) {
  final profile = ref.watch(unlockedProvider);
  if (profile == null) return null;
  final dir = ref.watch(appDirProvider).requireValue;
  final nutri = openNutriDb('${dir.path}/nutri.db');
  final user = openUserDb(ref.watch(profilesProvider).userDbPath(profile.id));
  final data = ProfileData(profile: profile, nutri: nutri, user: user, tools: AgentTools(nutri, user));
  final profiles = ref.watch(profilesProvider);
  void sync() => unawaited(syncHomeWidget(data, show: widgetShowsKcal(profiles)));
  data.changes.addListener(sync);
  sync();
  ref.onDispose(() {
    data.changes.dispose();
    nutri.close();
    user.close();
  });
  return data;
});

/// The home-screen widget shows today's calories only on a single-profile phone whose owner
/// turned it on (Me tab): it is visible without the PIN.
bool widgetShowsKcal(Profiles p) => p.biometricAllowed && p.setting('widget_kcal') == '1';

/// Pushes today's numbers to the Android widget (TodayWidget.kt); empty = hidden.
Future<void> syncHomeWidget(ProfileData data, {required bool show}) async {
  if (!Platform.isAndroid) return;
  try {
    final now = DateTime.now();
    final goal = currentTargets(data.user, nutri: data.nutri, now: now).values['kcal'];
    await HomeWidget.saveWidgetData('day', DateFormat('yyyy-MM-dd').format(now));
    await HomeWidget.saveWidgetData('kcal', show ? '${totalsOn(data.user, now)['kcal']!.round()}' : '');
    await HomeWidget.saveWidgetData('goal', show && goal != null ? '${goal.round()}' : '');
    await HomeWidget.updateWidget(qualifiedAndroidName: 'io.github.partorg.myfoodmind.TodayWidget');
  } on Object catch (e) {
    debugPrint('home widget: $e'); // no widget placed, or the plugin isn't there: nothing to update
  }
}

/// The unlocked profile's agent, once the models are loaded.
final agentProvider = FutureProvider.autoDispose<Agent>((ref) async {
  final data = ref.watch(profileDataProvider);
  if (data == null) return Completer<Agent>().future; // locked: never resolves, disposed with the screen
  final profiles = ref.watch(profilesProvider);
  final billing = await ref.watch(billingProvider.future);
  final llm = await ref.watch(llmProvider.future);
  final embedder = await ref.watch(embedderProvider.future);

  final vectorsPath = profiles.vectorsDbPath(data.profile.id);
  File(vectorsPath).parent.createSync(recursive: true);
  final vectors = openVectorsDb(vectorsPath);
  final memory = Memory(data.user, vectors, embedder.generateEmbeddings, nutri: data.nutri);
  final agent = Agent(
    model: GemmaChatModel(llm),
    tools: data.tools,
    memory: memory,
    user: data.user,
    limit: ChatLimit(profiles.db),
    unlimited: () => billing.tier.value.includes(Tier.basic),
    onWrite: data.changed,
  )..loadHistory();
  ref.onDispose(() {
    agent.dispose();
    vectors.close();
  });
  // Background work may still run when the user locks and the dbs close; its
  // failure then is expected and harmless (backfill resumes next unlock).
  void quietly(Future<Object?> f) => unawaited(f.catchError((Object e) {
        debugPrint('background agent work stopped: $e');
        return null;
      }));
  quietly(agent.warmUp());
  quietly(memory.backfill()); // rebuilds episodic memory after a backup restore
  return agent;
});

final remindersProvider = Provider<RemindersService>((ref) => RemindersService());

final localAuthProvider = Provider<LocalAuthentication>((ref) => LocalAuthentication());

/// Device has a fingerprint (or other biometric) enrolled.
final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(localAuthProvider).canCheckBiometrics;
  } on Object {
    return false;
  }
});

/// Shows the system fingerprint prompt; false on cancel or error.
Future<bool> authenticateFingerprint(WidgetRef ref, String reason) async {
  try {
    return await ref.read(localAuthProvider).authenticate(localizedReason: reason, biometricOnly: true);
  } on Object {
    return false;
  }
}

/// Per phone. RevenueCat when the build has REVENUECAT_KEY (docs/BILLING_SETUP.md);
/// the developer tier switch only when built with DEV_BILLING=true; else Free only.
final billingProvider = FutureProvider<Billing>((ref) async {
  const key = String.fromEnvironment('REVENUECAT_KEY');
  final Billing billing = key.isNotEmpty
      ? RevenueCatBilling(key)
      : const bool.fromEnvironment('DEV_BILLING')
          ? DevBilling(ref.watch(profilesProvider).db)
          : UnavailableBilling();
  await billing.init();
  return billing;
});
