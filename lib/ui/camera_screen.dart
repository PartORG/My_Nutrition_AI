import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' show InferenceModel;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_tools.dart';
import '../app_state.dart';
import '../billing/billing.dart';
import '../l10n/app_localizations.dart';
import '../vision/detector.dart';
import '../vision/scan.dart';
import 'kit.dart';
import 'nutrients.dart';
import 'paywall_screen.dart';
import 'theme.dart';
import 'today_screen.dart' show mealName;

/// Pro: camera (photo / live) → review → "What can I cook?" or
/// "Log this meal". [onCook] is null where cooking ideas can't be shown (Log tab).
Future<void> openCamera(BuildContext context, String mode, {void Function(List<String> names)? onCook}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final billing = await container.read(billingProvider.future);
  if (!context.mounted) return;
  final nav = Navigator.of(context);
  if (!billing.tier.value.includes(Tier.pro)) {
    await nav.push(MaterialPageRoute<void>(builder: (_) => const PaywallScreen()));
    return;
  }
  final data = container.read(profileDataProvider);
  if (data == null) return;
  final captured = await container.read(captureProvider)(context, mode);
  if (captured == null || !context.mounted) return;
  final (items, usedMode) = switch (captured) {
    (List<Detection> found, bool live) => (itemsFromDetections(data.tools, found), live ? 'live' : 'photo'),
    (List<SeenFood> seen) => (itemsFromSeen(data.tools, seen), 'photo'),
    _ => throw ArgumentError('capture returned $captured'),
  };
  await nav.push(MaterialPageRoute<void>(
    builder: (_) => ReviewScreen(data: data, items: items, mode: usedMode, onCook: onCook),
  ));
}

/// What a capture returns: Gemma's foods from a photo
/// (`List<SeenFood>`), or detections and whether they came from live mode
/// (a `(List<Detection>, bool)` record); null = cancelled. Tests
/// replace it with a dummy detector, since there is no camera on the host.
typedef Capture = Future<Object?> Function(BuildContext context, String mode);

final captureProvider = Provider<Capture>((ref) => (context, mode) => Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => CameraScreen(live: mode == 'live')),
    ));

final detectorProvider = FutureProvider.autoDispose<Detector>((ref) async {
  final d = await TfliteDetector.load();
  ref.onDispose(d.close);
  return d;
});

/// Preview with food boxes. Live: EfficientDet's boxes twice a second; on the
/// button, in both modes, Gemma 4 names the foods (EfficientDet until the chat
/// model is downloaded). Frames stay in memory only — no picture is ever written.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, required this.live});
  final bool live;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _cam;
  CameraImage? _frame;
  List<Detection> _found = [];
  late bool _live = widget.live;
  bool _busy = false, _naming = false;
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

  /// [frame] → upright RGB, [inputSize]² by default.
  Uint8List _rgb(CameraImage frame, int rotation, {int outW = inputSize, int outH = inputSize}) {
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
    );
  }

  Future<void> _detect() async {
    final frame = _frame, cam = _cam;
    final detector = ref.read(detectorProvider).value;
    if (_busy || frame == null || cam == null || detector == null) return;
    _busy = true;
    try {
      // ponytail: converted on the UI isolate (~320² pixels); move to an isolate if live mode stutters.
      final found = await detector.detect(_rgb(frame, cam.description.sensorOrientation));
      if (mounted) setState(() => _found = found);
    } finally {
      _busy = false;
    }
  }

  /// Photo: the frame at its own resolution, upright, to Gemma. Null when the
  /// chat model isn't downloaded (the caller falls back to EfficientDet).
  Future<List<SeenFood>?> _nameFoods() async {
    final frame = _frame, cam = _cam;
    if (frame == null || cam == null) return const [];
    setState(() => _naming = true);
    try {
      final InferenceModel llm;
      try {
        llm = await ref.read(llmProvider.future);
      } on LlmNotDownloaded {
        return null;
      }
      final rotation = cam.description.sensorOrientation;
      final (w, h) = rotation % 180 == 0 ? (frame.width, frame.height) : (frame.height, frame.width);
      return await nameFoods(llm, await _png(_rgb(frame, rotation, outW: w, outH: h), w, h));
    } finally {
      if (mounted) setState(() => _naming = false);
    }
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l.cameraTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l.cameraPhoto)),
                ButtonSegment(value: true, label: Text(l.cameraLive)),
              ],
              selected: {_live},
              onSelectionChanged: (s) => setState(() {
                _live = s.single;
                _found = [];
              }),
            ),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.cameraUnavailable, style: const TextStyle(color: Colors.white))))
          : cam == null || detector.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Expanded(
                    child: Center(
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
                                      child: Container(
                                        color: context.colors.accent,
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text('${d.label} ${(d.score * 100).round()}%',
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                              ])),
                        ]),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(_live ? Icons.check : Icons.camera),
                          label: Text(_naming
                              ? l.cameraNaming
                              : _live
                                  ? l.cameraUseFound(_found.length)
                                  : l.cameraShoot),
                          onPressed: _naming
                              ? null
                              : () async {
                                  // Both modes: Gemma names the foods. EfficientDet knows only 10 COCO
                                  // foods (phone test: "only apples and pizzas"), so its boxes are a live
                                  // preview and the fallback when Gemma isn't downloaded or sees nothing.
                                  try {
                                    final seen = await _nameFoods();
                                    if (seen != null && (seen.isNotEmpty || _found.isEmpty)) {
                                      if (context.mounted) Navigator.pop(context, seen);
                                      return;
                                    }
                                  } on Object catch (e, st) {
                                    // Gemma failed: fall through to EfficientDet's items rather than doing nothing.
                                    debugPrint('photo naming failed: $e\n$st');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text(l.cameraNamingFailed)));
                                    }
                                  }
                                  if (!_live) await _detect();
                                  if (context.mounted) Navigator.pop(context, (_found, _live));
                                },
                        ),
                      ),
                    ),
                  ),
                ]),
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
  late final _items = [...widget.items];
  late String _meal = widget.data.tools.mealTypeNow();

  Future<void> _pick(ScanItem? item) async {
    final food = await showDialog<FoodChoice>(
        context: context, builder: (_) => _PickFoodDialog(tools: widget.data.tools, initial: item?.name ?? ''));
    if (food == null) return;
    setState(() {
      if (item == null) {
        _items.add(ScanItem(name: food.label, food: food, grams: food.servingG ?? 100));
      } else {
        item
          ..name = food.label
          ..food = food
          ..grams = food.servingG ?? item.grams;
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
      final n = logScan(data.tools, _items, _meal);
      recordScan(data.user, widget.mode, loggable, at: DateTime.now());
      data.changed();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.reviewLogged(n))));
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
                if (_items.isEmpty) Panel(child: Text(l.reviewEmpty)),
                if (_items.isNotEmpty)
                  PanelList(children: [
                    for (final i in _items)
                      i.food == null
                          ? Container(
                              color: c.warm,
                              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                              child: Row(children: [
                                Expanded(child: Text(l.notInDatabase(i.name), style: TextStyle(fontSize: 15, color: c.onWarm))),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: c.dark, foregroundColor: c.background,
                                      minimumSize: const Size(64, 48)),
                                  onPressed: () => _pick(i),
                                  child: Text(l.reviewChange),
                                ),
                              ]),
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                              child: Row(children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pick(i),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(i.food!.label, style: const TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 104,
                                  child: TextFormField(
                                    initialValue: '${i.grams.round()}',
                                    textAlign: TextAlign.end,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '≈ ',
                                      suffixText: 'g',
                                      hintText: l.grams,
                                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.pill)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(Radii.pill), borderSide: BorderSide(color: c.outline)),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (t) => setState(() => i.grams = double.tryParse(t.replaceAll(',', '.')) ?? 0),
                                  ),
                                ),
                                IconButton(tooltip: l.delete, icon: const Icon(Icons.close), onPressed: () => setState(() => _items.remove(i))),
                              ]),
                            ),
                  ]),
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

/// Search nutri.db and pick a food (owns its controller, see memory_screen.dart).
class _PickFoodDialog extends StatefulWidget {
  const _PickFoodDialog({required this.tools, required this.initial});
  final AgentTools tools;
  final String initial;

  @override
  State<_PickFoodDialog> createState() => _PickFoodDialogState();
}

class _PickFoodDialogState extends State<_PickFoodDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final results = _text.text.trim().length < 2 ? const <FoodChoice>[] : widget.tools.searchFood(_text.text, limit: 8);
    return AlertDialog(
      title: Text(l.searchFood),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _text, autofocus: true, onChanged: (_) => setState(() {})),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (results.isEmpty && _text.text.trim().length >= 2) ListTile(title: Text(l.noResults)),
              for (final f in results)
                ListTile(
                  title: Text(f.label),
                  subtitle: Text(formatNutrient('kcal', f.per100['kcal']!, l) + l.per100Suffix),
                  onTap: () => Navigator.pop(context, f),
                ),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))],
    );
  }
}

/// RGB → PNG with the engine's own encoder (no image package).
Future<Uint8List> _png(Uint8List rgb, int w, int h) async {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0, j = 0; i < rgb.length; i += 3, j += 4) {
    rgba
      ..[j] = rgb[i]
      ..[j + 1] = rgb[i + 1]
      ..[j + 2] = rgb[i + 2]
      ..[j + 3] = 255;
  }
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
