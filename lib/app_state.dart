import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart' hide Database;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode, WidgetsBinding, basicLocaleListResolution;
import 'package:flutter/services.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent/agent.dart';
import 'agent/agent_tools.dart';
import 'agent/chat_limit.dart';
import 'agent/chat_model.dart' show llmContextTokens;
import 'agent/gemma_chat_model.dart';
import 'agent/memory.dart';
import 'billing/billing.dart';
import 'billing/revenuecat_billing.dart';
import 'data/diary.dart';
import 'data/goals.dart';
import 'data/health_sync.dart' show syncHealthWeights;
import 'data/nutri_db.dart';
import 'data/profiles.dart';
import 'data/user_db.dart';
import 'l10n/app_localizations.dart';
import 'reminders_service.dart';

/// App-private data directory, with nutri.db installed from the bundled asset
/// when missing, unreadable by this build or older than [nutriDataVersion]. Overridden in tests.
final appDirProvider = FutureProvider<Directory>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final nutri = File('${dir.path}/nutri.db');
  // The data version installed last; a file, not nutri.db's meta, so an old bundle can't reinstall on every start.
  final installed = File('${dir.path}/nutri.db.data_version');
  try {
    openNutriDb(nutri.path).close();
    if ((int.tryParse(installed.existsSync() ? installed.readAsStringSync() : '') ?? 0) < nutriDataVersion) {
      throw NutriDbException('installed data older than $nutriDataVersion');
    }
  } on Object {
    // ponytail: bundled dummy db; the real one (≤ 300 MB) needs its own delivery, see docs/PLAN.md M7.
    final tmp = File('${dir.path}/nutri.db.download');
    final data = await rootBundle.load('assets/nutri.db');
    await tmp.writeAsBytes(data.buffer.asUint8List(), flush: true);
    installNutriDb(tmp, nutri);
    installed.writeAsStringSync('$nutriDataVersion');
  }
  return dir;
});

final profilesProvider = Provider<Profiles>((ref) {
  final profiles = Profiles.open(ref.watch(appDirProvider).requireValue);
  ref.onDispose(profiles.close);
  for (final id in profiles.keepOnlyFirst()) {
    unawaited(ref.read(remindersProvider).cancelProfile(id));
  }
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

/// The language the app shows for [code] ('' = the phone's, if the app has it).
String appLanguage(String code) => code.isNotEmpty
    ? code
    : basicLocaleListResolution(WidgetsBinding.instance.platformDispatcher.locales, AppLocalizations.supportedLocales)
        .languageCode;

/// The app's language code; '' = follow the phone. Per phone.
final languageProvider = NotifierProvider<LanguageSetting, String>(LanguageSetting.new);

class LanguageSetting extends Notifier<String> {
  @override
  String build() => (ref.watch(appDirProvider).hasValue ? ref.watch(profilesProvider).setting('language') : null) ?? '';

  void set(String code) {
    ref.read(profilesProvider).setSetting('language', code);
    state = code;
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

// ---- big downloads ------------------------------------------------------------

/// A download under way. [status]: enqueued (waiting for Wi-Fi or a network),
/// running, waitingToRetry (connection lost; it continues by itself), paused,
/// failed or notFound (Resume continues where it stopped), complete (installing).
typedef Download = ({DownloadTask task, TaskStatus status, int percent});

/// Called before runApp: a tracked group records the updates that arrive while
/// the app is closed, so a download started earlier shows up (or finishes) on the next start.
Future<void> trackDownloads() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  for (final g in ['llm', 'products']) {
    await FileDownloader().trackTasksInGroup(g);
  }
}

/// One big file the OS downloads in the background (Android WorkManager, iOS
/// URLSession): it keeps going on another screen or with the screen off, waits
/// out a lost connection, can be paused, and resumes where it stopped (HTTP
/// Range; Hugging Face and GitHub send the strong ETags that resuming needs).
abstract class FileDownload extends Notifier<Download?> {
  String get group;

  /// Installs the finished file at [path]. Throws if it's unusable.
  Future<void> finish(String path);

  var _finishing = false;

  @override
  Download? build() {
    if (!Platform.isAndroid && !Platform.isIOS) return null; // tests
    FileDownloader().registerCallbacks(group: group, taskStatusCallback: _onStatus, taskProgressCallback: _onProgress);
    unawaited(_reattach());
    return null;
  }

  /// Picks up a download from an earlier app run.
  Future<void> _reattach() async {
    await FileDownloader().resumeFromBackground();
    final r = (await FileDownloader().database.allRecords(group: group)).lastOrNull;
    if (r == null || state != null || r.task is! DownloadTask) return;
    _set(r.task, r.status, (r.progress * 100).round().clamp(0, 100));
    if (r.status == TaskStatus.complete) await _onStatus(TaskStatusUpdate(r.task, r.status));
    if (r.status == TaskStatus.canceled) await _forget(r.task);
  }

  void _set(Task task, TaskStatus status, [int? percent]) =>
      state = (task: task as DownloadTask, status: status, percent: percent ?? state?.percent ?? 0);

  void _onProgress(TaskProgressUpdate u) {
    if (u.progress >= 0) _set(u.task, TaskStatus.running, (u.progress * 100).round()); // < 0: a status, not progress
  }

  Future<void> _onStatus(TaskStatusUpdate u) async {
    if (u.status == TaskStatus.canceled) return _forget(u.task);
    if (u.status != TaskStatus.complete) return _set(u.task, u.status);
    if (_finishing) return;
    _finishing = true;
    _set(u.task, TaskStatus.complete, 100);
    try {
      await finish(await u.task.filePath());
      await _forget(u.task);
    } on Object catch (e) {
      debugPrint('$group download: $e');
      _set(u.task, TaskStatus.failed); // Resume downloads it again
    } finally {
      _finishing = false;
    }
  }

  Future<void> _forget(Task task) async {
    await FileDownloader().database.deleteRecordWithId(task.taskId);
    state = null;
  }

  /// [wifiOnly]: the OS holds the download until there is Wi-Fi, and pauses it when Wi-Fi goes.
  Future<void> download(String url, String filename, {required bool wifiOnly, required String title}) async {
    if (state != null) return;
    FileDownloader().configureNotificationForGroup(group,
        running: TaskNotification(title, '{progress}'), paused: TaskNotification(title, '{progress}'), progressBar: true);
    final task = DownloadTask(
      url: url,
      filename: filename,
      baseDirectory: BaseDirectory.applicationSupport,
      group: group,
      updates: Updates.statusAndProgress,
      requiresWiFi: wifiOnly,
      allowPause: true, // also how Android's 9-minute job limit is survived: pause, re-enqueue, go on
      retries: 10, // each one resumes; backoff 2 s .. 17 min, ~34 min in all
    );
    _set(task, TaskStatus.enqueued, 0);
    if (!await FileDownloader().enqueue(task)) _set(task, TaskStatus.failed);
  }

  Future<void> pause() async {
    if (state?.task case final t?) await FileDownloader().pause(t);
  }

  /// Continues where it stopped when the partial file is still there; otherwise starts over.
  Future<void> resume() async {
    final t = state?.task;
    if (t == null) return;
    _set(t, TaskStatus.enqueued);
    final resumed = await FileDownloader().taskCanResume(t) && await FileDownloader().resume(t);
    if (!resumed && !await FileDownloader().enqueue(t)) _set(t, TaskStatus.failed);
  }

  Future<void> cancel() async {
    final t = state?.task;
    if (t == null) return;
    await FileDownloader().cancel(t);
    await _forget(t);
  }
}

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

/// E4B: larger and smarter, ~3x slower prefill. An 8 GB phone (Xiaomi 11T, 2026-10-10)
/// couldn't run it, so it's offered from 12 GB (they report ~11.2-11.6 GB). Installing
/// E2B deletes an E4B already on the phone. The full file, not "-gpu": photo mode needs its vision part.
// ponytail: tool accuracy not measured yet; run integration_test/agent_eval_test.dart with MODEL_PATH on the phone.
const e4b = (
  file: 'gemma-4-E4B-it.litertlm',
  url: 'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
  downloadMb: 3490,
  minRamMb: 11000,
);

/// Models this phone can run, smallest first. Unknown RAM (not Android): E2B only.
List<Llm> llmChoices() {
  final ram = Platform.isAndroid ? totalRamMb() : null;
  return [e2b, if (ram != null && ram >= e4b.minRamMb) e4b];
}

/// The model the chat uses: the larger one the user downloaded, if this phone can run it.
Future<Llm?> installedLlm() async {
  for (final m in llmChoices().reversed) {
    if (await FlutterEdgeAi.isModelInstalled(m.file)) return m;
  }
  return null;
}

/// EmbeddingGemma is gated on Hugging Face (Gemma terms allow redistribution),
/// so it ships inside the app from git-ignored files in assets/models/.
const embedderAsset = 'assets/models/embeddinggemma-300M_seq256.tflite'; // M1: 2.5x faster than seq512, same vectors
const tokenizerAsset = 'assets/models/embeddinggemma_sentencepiece.model';

/// The chat model isn't on the phone yet: the Chat tab offers the download.
class LlmNotDownloaded implements Exception {}

final _gemmaReadyProvider = FutureProvider<void>((ref) => FlutterEdgeAi.initialize(
      inferenceEngines: [LiteRtLmEngine()],
      embeddingBackends: [LiteRtEmbeddingBackend()],
      embeddingTokenizers: [GemmaEmbeddingTokenizers()],
    ));

InferenceInstallationBuilder _llmInstall() =>
    FlutterEdgeAi.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm);

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
  } else if (installed != null && File(await _llmPath(installed)).existsSync()) {
    await _llmInstall().fromFile(await _llmPath(installed)).install();
  } else if (installed != null) {
    // Installed by an older version through the plugin's own downloader: no network, just activates it.
    await _llmInstall().fromNetwork(installed.url).install();
  } else {
    throw LlmNotDownloaded();
  }
  // supportImage: photo mode names the foods with the same model (vision encoder on the CPU).
  // GPU, falling back to CPU inside the plugin. MTP (speculative decoding): up to 2.2x faster
  // answers on mobile GPUs, same output (LiteRT-LM model card).
  // ponytail: also on after a CPU fallback, where Google calls it slightly slower for free text.
  final model = await FlutterEdgeAi.getActiveModel(
      maxTokens: llmContextTokens, preferredBackend: PreferredBackend.gpu, supportImage: true, maxNumImages: 1,
      enableSpeculativeDecoding: true);
  debugPrint('LLM running on ${model.activeBackend?.name ?? 'unknown'}');
  ref.onDispose(model.close);
  return model;
});

final llmDownloadProvider = NotifierProvider<LlmDownload, Download?>(LlmDownload.new);

class LlmDownload extends FileDownload {
  @override
  String get group => 'llm';

  Future<void> start(Llm model, {required bool wifiOnly, required String title}) =>
      download(model.url, model.file, wifiOnly: wifiOnly, title: title);

  /// Switching models: the other one is deleted once this one is in, so the
  /// phone never keeps 6 GB of models.
  @override
  Future<void> finish(String path) async {
    await ref.read(_gemmaReadyProvider.future);
    await _llmInstall().fromFile(path).install();
    // Delete first, so the reload can't pick the old one. A loaded model keeps
    // its open file until the reload closes it.
    for (final other in [e2b, e4b]) {
      if (path.endsWith('/${other.file}')) continue;
      if (await FlutterEdgeAi.isModelInstalled(other.file)) await FlutterEdgeAi.uninstallModel(other.file);
      final f = File(await _llmPath(other)); // uninstall leaves files it didn't download itself
      if (f.existsSync()) f.deleteSync();
    }
    ref.invalidate(llmProvider);
  }
}

/// Where [LlmDownload] puts a model.
Future<String> _llmPath(Llm m) =>
    DownloadTask(url: m.url, filename: m.file, baseDirectory: BaseDirectory.applicationSupport).filePath();

final embedderProvider = FutureProvider<EmbeddingModel>((ref) async {
  await ref.watch(_gemmaReadyProvider.future);
  await FlutterEdgeAi.installEmbedder().modelFromAsset(embedderAsset).tokenizerFromAsset(tokenizerAsset).install();
  return FlutterEdgeAi.getActiveEmbedder();
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
  fillMissingMicros(user, nutri, nutriDataVersion); // once per data release: past meals get vitamins too
  final data = ProfileData(profile: profile, nutri: nutri, user: user,
      tools: AgentTools(nutri, user, products: openProducts(dir)));
  // listen, not watch: a language switch must not reopen the databases.
  ref.listen(languageProvider, (_, code) => data.tools.language = appLanguage(code), fireImmediately: true);
  final profiles = ref.watch(profilesProvider);
  void sync() => unawaited(syncHomeWidget(data, show: widgetShowsKcal(profiles)));
  data.changes.addListener(sync);
  sync();
  // New weights from Health Connect / Apple Health (if connected) update the goals.
  unawaited(syncHealthWeights(user).then((n) {
    if (n > 0) data.changed();
  }));
  ref.onDispose(() {
    data.tools.products?.close();
    data.changes.dispose();
    nutri.close();
    user.close();
  });
  return data;
});

/// The home-screen widget shows today's calories only on a single-profile phone whose owner
/// turned it on (Me tab): it is visible without the PIN.
bool widgetShowsKcal(Profiles p) => p.setting('widget_kcal') == '1';

/// Pushes today's numbers to the Android widget (TodayWidget.kt); empty = hidden.
Future<void> syncHomeWidget(ProfileData data, {required bool show}) async {
  if (!Platform.isAndroid) return;
  try {
    final now = DateTime.now();
    final goal = currentTargets(data.user, nutri: data.nutri, now: now).values['kcal'];
    await HomeWidget.saveWidgetData('day', DateFormat('yyyy-MM-dd').format(now));
    final approx = mealsOn(data.user, now).any((m) => m.estimated) ? '≈' : ''; // as on Today
    await HomeWidget.saveWidgetData('kcal', show ? '$approx${totalsOn(data.user, now)['kcal']!.round()}' : '');
    await HomeWidget.saveWidgetData('goal', show && goal != null ? '${goal.round()}' : '');
    await HomeWidget.updateWidget(qualifiedAndroidName: 'io.github.partorg.myfoodmind.TodayWidget');
  } on Object catch (e) {
    debugPrint('home widget: $e'); // no widget placed, or the plugin isn't there: nothing to update
  }
}

// ---- all packaged products (optional download) -------------------------------

/// Built by tool/build_products_db.py from the current Open Food Facts dump (ODbL), gzipped.
// Release asset of github.com/PartORG/myfoodmind (published 2026-10-16, sha256 aebd412d…6a07).
const productsUrl = 'https://github.com/partorg/myfoodmind/releases/download/products-2026-10-16/products.db.gz';
const productsDownloadMb = 117; // products.db.gz of 2026-10-16: 2,034,064 products with label micros, 303 MB unpacked

File _productsFile(Directory dir) => File('${dir.path}/products.db');

/// The downloaded products.db, read-only; null when not downloaded or unreadable.
Database? openProducts(Directory dir) {
  final f = _productsFile(dir);
  if (!f.existsSync()) return null;
  try {
    final db = sqlite3.open(f.path, mode: OpenMode.readOnly);
    db.select('SELECT 1 FROM products_fts LIMIT 1');
    return db;
  } on Object catch (e) {
    debugPrint('products.db unreadable: $e');
    return null;
  }
}

/// How many products the download has and when it was built; null = not downloaded.
({int rows, String builtAt})? productsInfo(Database? db) {
  if (db == null) return null;
  String meta(String k) => db.select('SELECT value FROM meta WHERE key = ?', [k]).firstOrNull?['value'] as String? ?? '';
  return (rows: int.tryParse(meta('rows')) ?? 0, builtAt: meta('built_at'));
}

/// Unpacks the downloaded [gz], checks the file opens, then swaps it in. Throws on failure;
/// the .gz is gone either way, so a retry downloads it again.
Future<void> unpackProducts(Directory dir, File gz, AgentTools? tools) async {
  final part = File('${_productsFile(dir).path}.part');
  try {
    await gz.openRead().transform(gzip.decoder).pipe(part.openWrite());
    sqlite3.open(part.path, mode: OpenMode.readOnly)
      ..select('SELECT 1 FROM products_fts LIMIT 1')
      ..close();
    tools?.products?.close();
    part.renameSync(_productsFile(dir).path);
    tools?.products = openProducts(dir);
  } finally {
    if (part.existsSync()) part.deleteSync();
    if (gz.existsSync()) gz.deleteSync();
  }
}

final productsDownloadProvider = NotifierProvider<ProductsDownload, Download?>(ProductsDownload.new);

class ProductsDownload extends FileDownload {
  @override
  String get group => 'products';

  Future<void> start({required bool wifiOnly, required String title}) =>
      download(productsUrl, 'products.db.gz', wifiOnly: wifiOnly, title: title);

  @override
  Future<void> finish(String path) async =>
      unpackProducts(await ref.read(appDirProvider.future), File(path), ref.read(profileDataProvider)?.tools);

  /// Back to the 2019 products in nutri.db; frees the space.
  void remove() {
    final dir = ref.read(appDirProvider).requireValue;
    final tools = ref.read(profileDataProvider)?.tools;
    tools?.products?.close();
    tools?.products = null;
    if (_productsFile(dir).existsSync()) _productsFile(dir).deleteSync();
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

  // The language the app shows, so the agent answers in it.
  final language = appLanguage(ref.watch(languageProvider));

  final vectorsPath = profiles.vectorsDbPath(data.profile.id);
  File(vectorsPath).parent.createSync(recursive: true);
  final vectors = openVectorsDb(vectorsPath);
  final memory = Memory(data.user, vectors, embedder.generateEmbeddings,
      nutri: data.nutri, historyDays: () => billing.tier.value.historyDays);
  final agent = Agent(
    model: GemmaChatModel(llm),
    tools: data.tools,
    memory: memory,
    user: data.user,
    limit: ChatLimit(profiles.db),
    unlimited: () => billing.tier.value.includes(Tier.basic),
    onWrite: data.changed,
    language: language,
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

/// Web OAuth client id from Google Cloud Console; empty = no Google sign-in in this build.
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

// shortcut: Android only; iOS also needs its own clientId and URL scheme in Info.plist.
final _googleReady = GoogleSignIn.instance.initialize(serverClientId: googleClientId);

/// Shows Google's account picker; null on cancel or error.
Future<GoogleSignInAccount?> signInWithGoogle() async {
  try {
    await _googleReady;
    return await GoogleSignIn.instance.authenticate();
  } on Object catch (e) {
    debugPrint('Google sign-in: $e');
    return null;
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
