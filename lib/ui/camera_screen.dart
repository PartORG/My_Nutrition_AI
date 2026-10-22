import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' show InferenceModel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../agent/agent_tools.dart';
import '../app_state.dart';
import '../data/diary.dart' show lastMealId;
import '../billing/billing.dart';
import '../l10n/app_localizations.dart';
import '../vision/detector.dart';
import '../vision/scan.dart';
import 'avatar.dart';
import 'kit.dart';
import 'meal_editor.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;

/// Pro: camera (photo / live) → review → "What can I cook?" or
/// "Log this meal". [onCook] is null where cooking ideas can't be shown (Log tab).
Future<void> openCamera(BuildContext context, String mode, {void Function(List<String> names)? onCook}) async {
  final nav = Navigator.of(context);
  final shot = await capturePhoto(context, mode);
  if (shot == null || !context.mounted) return;
  await nav.push(MaterialPageRoute<void>(
    builder: (_) => ReviewScreen(data: shot.data, items: shot.items, mode: shot.mode, onCook: onCook),
  ));
}

/// Pro (else the plans): the camera, photo or live, or a gallery picture → the foods seen, matched in nutri.db, and
/// how they were taken ('photo' / 'live'). Null when cancelled, locked or not Pro. The review screen and the chat's
/// camera both start here.
Future<({ProfileData data, List<ScanItem> items, String mode})?> capturePhoto(BuildContext context, String mode) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final billing = await container.read(billingProvider.future);
  if (!context.mounted) return null;
  if (!billing.tier.value.includes(Tier.pro)) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));
    return null;
  }
  final data = container.read(profileDataProvider);
  if (data == null) return null;
  final captured = await container.read(captureProvider)(context, mode);
  if (captured == null || !context.mounted) return null;
  final rows = container.read(detectorRowsProvider).value ?? const {}; // loaded with the detector
  final (items, usedMode) = switch (captured) {
    (List<Detection> found, bool live) => (itemsFromDetections(data.tools, found, rows: rows), live ? 'live' : 'photo'),
    (List<ScanItem> items) => (items, 'photo'),
    (List<SeenFood> seen) => (itemsFromSeen(data.tools, seen), 'photo'),
    _ => throw ArgumentError('capture returned $captured'),
  };
  return (data: data, items: items, mode: usedMode);
}

/// What a capture returns: Gemma's foods from a photo, matched
/// (`List<ScanItem>`; tests may return `List<SeenFood>`), or detections and whether they came from live mode
/// (a `(List<Detection>, bool)` record); null = cancelled. Tests
/// replace it with a dummy detector, since there is no camera on the host.
typedef Capture = Future<Object?> Function(BuildContext context, String mode);

final captureProvider = Provider<Capture>((ref) => (context, mode) => Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => CameraScreen(live: mode == 'live')),
    ));

final detectorProvider = FutureProvider.autoDispose<Detector>((ref) async {
  await ref.read(detectorRowsProvider.future); // ready before any box can reach the review screen
  final d = await YoloxDetector.load();
  ref.onDispose(d.close);
  return d;
});

/// Each detector label's reviewed nutri.db row (db/detector_labels.tsv), so a box never goes through search.
final detectorRowsProvider =
    FutureProvider<Map<String, String>>((ref) async => readYoloxRows(await rootBundle.loadString(yoloxLabelsAsset)));

/// Preview with food boxes. Live: YOLOX's boxes twice a second; on the
/// button, in both modes, Gemma 4 names the foods (YOLOX's boxes, tiled in photo mode, until the chat
/// model is downloaded). A photo can also come from the gallery (Gemma only).
/// Frames stay in memory only — no picture is ever written.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, required this.live});
  final bool live;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

const _system = MethodChannel('myfoodmind/system');

/// The app's page in the phone's settings, where a denied permission is turned back on.
Future<void> openAppSettings() async {
  try {
    if (Platform.isIOS) {
      await launchUrl(Uri.parse('app-settings:'));
    } else {
      await _system.invokeMethod<void>('appSettings');
    }
  } on Object catch (e) {
    debugPrint('app settings: $e');
  }
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _cam;
  CameraImage? _frame;
  List<Detection> _found = [];
  late bool _live = widget.live;
  bool _busy = false, _naming = false, _cancelled = false, _fromGallery = false;
  Timer? _timer;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final cam = CameraController(back, ResolutionPreset.high, // ~1280×720: Gemma sees small ingredients
          enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
      await cam.initialize();
      await cam.startImageStream((img) => _frame = img);
      if (!mounted) return await cam.dispose();
      setState(() => _cam = cam);
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_live && !_naming) _detect(); // Gemma gets the CPU while it names
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e); // permission denied, no camera
    }
  }

  void _retry() {
    setState(() => _error = null);
    _start();
  }

  /// [frame] (its [area], upright) → upright RGB, [inputSize]² by default.
  Uint8List _rgb(CameraImage frame, int rotation,
      {int outW = inputSize, int outH = inputSize, Rect area = const Rect.fromLTRB(0, 0, 1, 1)}) {
    final p = frame.planes;
    return yuvToRgb(
      width: frame.width,
      height: frame.height,
      y: p[0].bytes,
      u: p[1].bytes,
      v: p[2].bytes,
      yRowStride: p[0].bytesPerRow,
      uvRowStride: p[1].bytesPerRow,
      uvPixelStride: p[1].bytesPerPixel ?? 1,
      rotation: rotation,
      outW: outW,
      outH: outH,
      area: area,
    );
  }

  /// The frame's foods; [tiled] (photo mode) also searches its four quarters, where small foods are 2× bigger.
  Future<void> _detect({bool tiled = false}) async {
    final frame = _frame, cam = _cam;
    final detector = ref.read(detectorProvider).value;
    if (_busy || frame == null || cam == null || detector == null) return;
    _busy = true;
    try {
      final rotation = cam.description.sensorOrientation;
      final (uw, uh) = rotation % 180 == 0 ? (frame.width, frame.height) : (frame.height, frame.width);
      final all = <Detection>[];
      for (final tile in tiled ? photoTiles : photoTiles.take(1)) {
        // Scaled to fit the model with its shape kept: YOLOX trained on letterboxed photos, not squeezed ones.
        final r = yoloxSize / max(uw * tile.width, uh * tile.height);
        final w = (uw * tile.width * r).floor(), h = (uh * tile.height * r).floor();
        // shortcut: converted on the UI isolate (~416×234 pixels a tile); move to the isolate if live mode stutters.
        final found = await detector.detect(_rgb(frame, rotation, outW: w, outH: h, area: tile), w, h);
        all.addAll(found.map((d) => fromTile(d, tile)));
      }
      if (mounted) setState(() => _found = tiled ? mergeTiles(all) : all);
    } finally {
      _busy = false;
    }
  }

  /// Gemma names the foods on [png], with a closer look around the detector's [boxes] (or the middle).
  /// Null when the chat model isn't downloaded.
  Future<List<ScanItem>?> _name(Future<Uint8List> Function() png, {List<Rect> boxes = const []}) async {
    setState(() {
      _naming = true;
      _cancelled = false;
    });
    try {
      final InferenceModel llm;
      try {
        llm = await ref.read(llmProvider.future);
      } on LlmNotDownloaded {
        return null;
      }
      final tools = ref.read(profileDataProvider)?.tools;
      if (tools == null) return null; // locked meanwhile
      final photo = await png();
      if (ref.exists(agentProvider)) await ref.read(agentProvider).value?.release();
      return await scanPhoto(llm, tools, photo, crop: await _cropPng(photo, closerLook(boxes)));
    } finally {
      if (mounted) setState(() => _naming = false);
    }
  }

  /// Photo: the frame at its own resolution, upright.
  Future<Uint8List> _framePng() async {
    final frame = _frame!, cam = _cam!;
    final rotation = cam.description.sensorOrientation;
    final (w, h) = rotation % 180 == 0 ? (frame.width, frame.height) : (frame.height, frame.width);
    return _png(_rgb(frame, rotation, outW: w, outH: h), w, h);
  }

  Future<void> _shoot(AppLocalizations l) async {
    if (_frame == null || _cam == null) return;
    // Both modes: Gemma names the foods and weighs them; YOLOX's boxes are the live preview and the fallback
    // when Gemma isn't downloaded, sees nothing, or the user stops waiting.
    try {
      if (!_live) await _detect(tiled: true); // its boxes aim Gemma's closer look
      final seen = await _name(_framePng, boxes: [for (final d in _found) d.box]);
      if (_cancelled || !mounted) return;
      if (seen != null && (seen.isNotEmpty || _found.isEmpty)) return Navigator.pop(context, seen);
    } on Object catch (e, st) {
      debugPrint('photo naming failed: $e\n$st');
      if (_cancelled || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cameraNamingFailed)));
    }
    if (mounted) Navigator.pop(context, (_found, _live));
  }

  /// "Choose photo": a picture from the gallery, read into memory; the picker's temporary copy is deleted.
  Future<void> _gallery(AppLocalizations l) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    try {
      await File(file.path).delete(); // the picker's copy in the app cache: the photo stays in memory only
    } on FileSystemException catch (e) {
      debugPrint('picked photo not deleted: $e');
    }
    _fromGallery = true;
    try {
      final seen = await _name(() => _encodePng(bytes));
      if (_cancelled || !mounted) return;
      if (seen == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cameraGalleryNeedsAi)));
        return;
      }
      Navigator.pop(context, seen);
    } on Object catch (e, st) {
      debugPrint('gallery naming failed: $e\n$st');
      if (mounted && !_cancelled) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cameraNamingFailed)));
    } finally {
      _fromGallery = false;
    }
  }

  /// Stop waiting for Gemma (it finishes in the background, its answer unused): a camera shot
  /// goes on with the detector's boxes, a gallery photo just returns to the camera.
  Future<void> _cancel() async {
    setState(() {
      _cancelled = true;
      _naming = false;
    });
    if (_fromGallery || _frame == null) return;
    if (!_live) await _detect(tiled: true);
    if (mounted) Navigator.pop(context, (_found, _live));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cam = _cam;
    final detector = ref.watch(detectorProvider);
    const white = Colors.white;
    final glass = white.withValues(alpha: .14);
    final denied = _error is CameraException &&
        (_error as CameraException).code.startsWith('CameraAccess'); // Denied, DeniedWithoutPrompt, Restricted
    final Widget body = _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.no_photography_outlined, color: white, size: 48),
                const SizedBox(height: 12),
                Text(denied ? l.cameraPermissionOff : l.cameraUnavailable,
                    textAlign: TextAlign.center, style: const TextStyle(color: white, fontSize: 16)),
                const SizedBox(height: 20),
                Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  if (denied)
                    FilledButton(onPressed: openAppSettings, child: Text(l.openSettings)),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: white, side: const BorderSide(color: white)),
                    onPressed: _retry,
                    child: Text(l.tryAgain),
                  ),
                ]),
              ]),
            ),
          )
        : cam == null || detector.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: AspectRatio(
                  // The sensor is landscape; the phone is held upright.
                  aspectRatio: 1 / cam.value.aspectRatio,
                  child: Stack(fit: StackFit.expand, children: [
                    CameraPreview(cam),
                    LayoutBuilder(builder: (context, box) => Stack(children: [
                          for (final d in _found)
                            Positioned(
                              left: d.box.left * box.maxWidth,
                              top: d.box.top * box.maxHeight,
                              width: d.box.width * box.maxWidth,
                              height: d.box.height * box.maxHeight,
                              child: Container(
                                alignment: Alignment.topLeft,
                                decoration: BoxDecoration(border: Border.all(color: context.colors.accent, width: 3)),
                                // The label only: a detector score looks more certain than it is.
                                child: Container(
                                  color: context.colors.accent,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(d.label,
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 15)),
                                ),
                              ),
                            ),
                        ])),
                  ]),
                ),
              );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(child: body),
          if (_naming)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .6),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(color: white),
                    const SizedBox(height: 16),
                    Text(l.cameraNaming, style: const TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: white, side: const BorderSide(color: white)),
                      onPressed: _cancel,
                      child: Text(l.cancel),
                    ),
                  ]),
                ),
              ),
            ),
          Positioned(
            left: 16,
            top: 12,
            right: 16,
            child: Row(children: [
              RoundIconButton(
                icon: Icons.arrow_back_ios_new,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                background: glass,
                foreground: white,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.cameraTitle,
                    style: const TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          if (_error == null && cam != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                PillTabs<bool>(
                  values: const [false, true],
                  selected: _live,
                  label: (live) => live ? l.cameraLive : l.cameraPhoto,
                  onChanged: _naming
                      ? (_) {}
                      : (live) => setState(() {
                            _live = live;
                            _found = [];
                          }),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  RoundIconButton(
                    icon: Icons.photo_library_outlined,
                    tooltip: l.cameraChoosePhoto,
                    size: 56,
                    background: glass,
                    foreground: white,
                    onPressed: _naming ? null : () => _gallery(l),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      icon: Icon(_live ? Icons.check : Icons.camera),
                      label: Text(_live ? l.cameraUseFound(_found.length) : l.cameraShoot),
                      onPressed: _naming ? null : () => _shoot(l),
                    ),
                  ),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Everything detected is checked here before use: rename (re-match), amount,
/// remove, add. Values are ≈ for photos. Nothing is saved before a button.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.data, required this.items, required this.mode, this.onCook});
  final ProfileData data;
  final List<ScanItem> items;
  final String mode;
  final void Function(List<String> names)? onCook;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // The ones with no match first: they need the user before anything can be logged.
  late final _items = [...widget.items.where((i) => i.food == null), ...widget.items.where((i) => i.food != null)];
  late String _meal = widget.data.tools.mealTypeNow();

  // Something was fried or roasted: oil or butter is likely, and no photo shows how much. Offered, not added.
  late final _fat = widget.items.any((i) => cookedInFat(i.cooking))
      ? widget.data.tools.staple('oil') ?? matchFood(widget.data.tools, 'oil')
      : null;
  ScanItem? _fatItem;

  Future<void> _pick(ScanItem? item) async {
    final food = await showDialog<FoodChoice>(
        context: context, builder: (_) => PickFoodDialog(tools: widget.data.tools, initial: item?.name ?? ''));
    if (food == null) return;
    setState(() {
      if (item == null) {
        _items.add(ScanItem(name: food.label, food: food, grams: food.servingG ?? 100));
      } else {
        // name stays what was seen: the row shows "seen: …" under the new food.
        item
          ..food = food
          ..grams = food.servingG ?? item.grams
          ..sure = true
          ..corrected = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.colors;
    final data = widget.data;
    final loggable = _items.where((i) => i.food != null && i.grams > 0).toList();
    final kcal = loggable.fold(0.0, (s, i) => s + i.food!.per100['kcal']! * i.grams / 100);
    final approx = loggable.any((i) => i.food!.estimated) ? '≈ ' : '';
    const tints = [Color(0xFF7FDDB6), Color(0xFFF7C74F), Color(0xFF9BC1EE), Color(0xFFF6A27F)];
    void log() {
      final mark = lastMealId(data.user);
      final now = DateTime.now();
      for (final i in _items) {
        if (i.corrected && i.food != null && i != _fatItem) rememberCorrection(data.user, i.name, i.food!, at: now);
      }
      final n = logScan(data.tools, _items, _meal);
      recordScan(data.user, widget.mode, loggable, at: DateTime.now());
      data.changed();
      showLoggedSnack(context, data, l.reviewLogged(n), mark);
      Navigator.pop(context);
    }

    return Scaffold(
      backgroundColor: c.dark,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // The photo is never stored: the band shows what was seen, by name.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RoundIconButton(
                icon: Icons.arrow_back_ios_new,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                background: Colors.white.withValues(alpha: .12),
                foreground: Colors.white,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (n, i) in _items.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: tints[n % tints.length], borderRadius: BorderRadius.circular(10)),
                      child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF16201A))),
                    ),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: c.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [
                Semantics(header: true, child: Text(l.reviewTitle, style: Theme.of(context).textTheme.headlineMedium)),
                const SizedBox(height: 6),
                Text(l.reviewHint, style: TextStyle(fontSize: 16, color: c.ink2)),
                const SizedBox(height: 16),
                if (_items.isEmpty) Panel(child: EvaNote(l.reviewEmpty, asset: evaCameraAsset)),
                if (_items.isNotEmpty)
                  PanelList(children: [
                    for (final i in _items)
                      MealItemEditor(
                        key: ObjectKey(i),
                        label: i.food?.label,
                        seen: i.name,
                        grams: i.grams,
                        servingG: i.food?.servingG,
                        check: !i.sure,
                        kcal: i.food == null ? null : i.food!.per100['kcal']! * i.grams / 100,
                        onChange: () => _pick(i),
                        onGrams: (g) => setState(() => i.grams = g),
                        onRemove: () => setState(() {
                          _items.remove(i);
                          if (i == _fatItem) _fatItem = null;
                        }),
                      ),
                  ]),
                if (_fat case final oil?) ...[
                  const SizedBox(height: 12),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: CheckboxListTile(
                      title: Text(l.reviewAddFat),
                      subtitle: Text(l.reviewAddFatHint),
                      value: _fatItem != null,
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _items.add(_fatItem = ScanItem(name: oil.label, food: oil, grams: oil.servingG ?? 14));
                        } else {
                          _items.remove(_fatItem);
                          _fatItem = null;
                        }
                      }),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 180,
                    child: DashedAdd(
                      radius: 26,
                      onTap: () => _pick(null),
                      child: Center(
                        child: Text('+ ${l.reviewAdd}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.primary)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ChoicePills<String>(
                  values: const ['breakfast', 'lunch', 'dinner', 'snack'],
                  selected: _meal,
                  scroll: true,
                  label: (t) => mealName(l, t),
                  onChanged: (t) => setState(() => _meal = t),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(l.estimatedTotal, style: TextStyle(fontSize: 16, color: c.ink2)),
                    Text('$approx${kcal.round()} ${l.kcal}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  ],
                ),
              ]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: BottomActions(children: [
        if (widget.onCook != null)
          Expanded(
            child: OutlinedButton(
              onPressed: _items.isEmpty
                  ? null
                  : () {
                      recordScan(data.user, widget.mode, _items, at: DateTime.now());
                      Navigator.pop(context);
                      widget.onCook!(cookNames(_items));
                    },
              child: Text(l.reviewCook, textAlign: TextAlign.center),
            ),
          ),
        Expanded(
          child: FilledButton(
            onPressed: loggable.isEmpty ? null : log,
            child: Text(l.logThisMeal(inSentence(context, mealName(l, _meal))), textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }
}

/// A gallery picture (JPEG, HEIC…) → PNG, as the camera frames are.
Future<Uint8List> _encodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  } finally {
    image.dispose();
    codec.dispose();
  }
}

/// RGB → PNG with the engine's own encoder (no image package).
Future<Uint8List> _png(Uint8List rgb, int w, int h) {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0, j = 0; i < rgb.length; i += 3, j += 4) {
    rgba
      ..[j] = rgb[i]
      ..[j + 1] = rgb[i + 1]
      ..[j + 2] = rgb[i + 2]
      ..[j + 3] = 255;
  }
  return _rgbaPng(rgba, w, h);
}

/// [box] (normalized) of a PNG, as a PNG: Gemma's closer look.
Future<Uint8List> _cropPng(Uint8List png, Rect box) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  try {
    final w = image.width, h = image.height;
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final x0 = (box.left * w).floor(), y0 = (box.top * h).floor();
    final cw = ((box.right * w).ceil() - x0).clamp(1, w - x0), ch = ((box.bottom * h).ceil() - y0).clamp(1, h - y0);
    final out = Uint8List(cw * ch * 4);
    for (var y = 0; y < ch; y++) {
      out.setRange(y * cw * 4, (y + 1) * cw * 4, rgba, ((y0 + y) * w + x0) * 4);
    }
    return await _rgbaPng(out, cw, ch);
  } finally {
    image.dispose();
    codec.dispose();
  }
}

Future<Uint8List> _rgbaPng(Uint8List rgba, int w, int h) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(buffer, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await descriptor.instantiateCodec();
  final image = (await codec.getNextFrame()).image;
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  } finally {
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}
