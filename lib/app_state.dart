import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'agent/agent.dart';
import 'agent/agent_tools.dart';
import 'agent/chat_limit.dart';
import 'agent/gemma_chat_model.dart';
import 'agent/memory.dart';
import 'data/nutri_db.dart';
import 'data/profiles.dart';
import 'data/user_db.dart';

/// App-private data directory, with nutri.db installed from the bundled asset
/// when missing or unreadable by this build. Overridden in tests.
final appDirProvider = FutureProvider<Directory>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final nutri = File('${dir.path}/nutri.db');
  try {
    openNutriDb(nutri.path).close();
  } on Object {
    // ponytail: bundled dummy db; real nutri.db arrives via Asset Delivery in M7.
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

/// Where the model files are. Dev: `adb push` into the app's external files
/// dir (see integration_test/agent_latency_test.dart); M7 replaces this with
/// Play Asset Delivery / download.
const llmFile = 'gemma-4-E2B-it.litertlm';
const embedderFile = 'embeddinggemma-300M_seq256.tflite'; // M1: 2.5x faster than seq512, same vectors
const tokenizerFile = 'embeddinggemma_sentencepiece.model';

class ModelsMissing implements Exception {
  ModelsMissing(this.dir, this.missing);
  final String dir;
  final List<String> missing;
}

final modelDirProvider = FutureProvider<Directory>((ref) async {
  final dir = Directory('${(await getExternalStorageDirectory())!.path}/models');
  final missing = [
    for (final f in [llmFile, embedderFile, tokenizerFile])
      if (!File('${dir.path}/$f').existsSync()) f
  ];
  if (missing.isNotEmpty) throw ModelsMissing(dir.path, missing);
  await FlutterGemma.initialize(
    inferenceEngines: [LiteRtLmEngine()],
    embeddingBackends: [LiteRtEmbeddingBackend()],
    embeddingTokenizers: [GemmaEmbeddingTokenizers()],
  );
  return dir;
});

/// Loaded once per app run; first launch ~38 s (GPU setup), then ~3 s.
final llmProvider = FutureProvider<InferenceModel>((ref) async {
  final dir = await ref.watch(modelDirProvider.future);
  await FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm)
      .fromFile('${dir.path}/$llmFile')
      .install();
  final model = await FlutterGemma.getActiveModel(maxTokens: 4096, preferredBackend: PreferredBackend.gpu);
  ref.onDispose(model.close);
  return model;
});

final embedderProvider = FutureProvider<EmbeddingModel>((ref) async {
  final dir = await ref.watch(modelDirProvider.future);
  await FlutterGemma.installEmbedder()
      .modelFromFile('${dir.path}/$embedderFile')
      .tokenizerFromFile('${dir.path}/$tokenizerFile')
      .install();
  return FlutterGemma.getActiveEmbedder();
});

/// The unlocked profile's agent. Rebuilt per profile and torn down on lock,
/// closing that profile's databases.
final agentProvider = FutureProvider<Agent>((ref) async {
  final profile = ref.watch(unlockedProvider);
  if (profile == null) throw StateError('locked');
  final dir = ref.watch(appDirProvider).requireValue;
  final profiles = ref.watch(profilesProvider);
  final llm = await ref.watch(llmProvider.future);
  final embedder = await ref.watch(embedderProvider.future);

  final nutri = openNutriDb('${dir.path}/nutri.db');
  final user = openUserDb(profiles.userDbPath(profile.id));
  final vectorsPath = profiles.vectorsDbPath(profile.id);
  File(vectorsPath).parent.createSync(recursive: true);
  final vectors = openVectorsDb(vectorsPath);
  final memory = Memory(user, vectors, embedder.generateEmbeddings);
  final agent = Agent(
    model: GemmaChatModel(llm),
    tools: AgentTools(nutri, user),
    memory: memory,
    user: user,
    limit: ChatLimit(profiles.db),
    // ponytail: no tiers until M4 (RevenueCat); dev builds can pass DEV_UNLIMITED=true.
    unlimited: () => const bool.fromEnvironment('DEV_UNLIMITED'),
  )..loadHistory();
  ref.onDispose(() {
    agent.dispose();
    for (final db in [nutri, user, vectors]) {
      db.close();
    }
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
