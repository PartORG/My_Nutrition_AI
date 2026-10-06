import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Gemma 4 E2B (Apache 2.0, ungated) downloads once from Hugging Face when the
/// user asks: at 2.2 GB compressed it is over Play's 1.5 GB asset-pack limit.
/// Same SHA-256 as the file measured in M0. Only the model comes over the
/// network; nothing about the user goes out.
const llmFile = 'gemma-4-E2B-it.litertlm';
const llmUrl = 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$llmFile';
const llmDownloadMb = 2468;

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
  final dev = File('${(await getExternalStorageDirectory())?.path}/models/$llmFile');
  if (dev.existsSync()) {
    await _llmInstall().fromFile(dev.path).install();
  } else if (await FlutterGemma.isModelInstalled(llmFile)) {
    await _llmInstall().fromNetwork(llmUrl).install(); // already downloaded: no network, just activates it
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
  Future<void> start() async {
    if (state != null) return;
    state = 0;
    _cancel = CancelToken();
    try {
      await ref.read(_gemmaReadyProvider.future);
      await _llmInstall().fromNetwork(llmUrl).withProgress((p) => state = p).withCancelToken(_cancel!).install();
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
  ref.onDispose(() {
    data.changes.dispose();
    nutri.close();
    user.close();
  });
  return data;
});

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
