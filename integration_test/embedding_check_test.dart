// M1 embedding check: speed of the 512- vs 256-token EmbeddingGemma builds on
// the phone, and whether they give the same vectors. Vectors are written to
// <external files>/embedding_check.json for the PC comparison
// (tool/compare_embeddings.py).
//
//   flutter test --no-uninstall integration_test/embedding_check_test.dart -d <phone> \
//     --dart-define=EMBEDDER_PATH=.../embeddinggemma-300M_seq512.tflite \
//     --dart-define=EMBEDDER256_PATH=.../embeddinggemma-300M_seq256.tflite \
//     --dart-define=TOKENIZER_PATH=.../embeddinggemma_sentencepiece.model
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _e512 = String.fromEnvironment('EMBEDDER_PATH');
const _e256 = String.fromEnvironment('EMBEDDER256_PATH');
const _tokenizer = String.fromEnvironment('TOKENIZER_PATH');

/// Short chat messages (the on-phone case) and one longer doc-like text.
const checkTexts = [
  'Hi!',
  'I had 2 eggs and toast for breakfast',
  'How much protein is in Greek yogurt?',
  'My glucose is 140',
  'what was that thing I made with the feta?',
  'Can I eat bananas if I have diabetes?',
  'Soft food recipes, I have trouble swallowing',
  'People with type 2 diabetes are often advised to limit added sugar and prefer '
      'high-fiber carbohydrates such as oats, lentils and whole grains, spread evenly '
      'across the day, together with regular physical activity.',
];

double _cos(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / sqrt(na * nb);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('embedding check', () async {
    await FlutterGemma.initialize(
      embeddingBackends: [LiteRtEmbeddingBackend()],
      embeddingTokenizers: [GemmaEmbeddingTokenizers()],
    );

    Future<({List<List<double>> vectors, List<int> ms})> run(String path) async {
      await FlutterGemma.installEmbedder().modelFromFile(path).tokenizerFromFile(_tokenizer).install();
      final embedder = await FlutterGemma.getActiveEmbedder();
      await embedder.generateEmbedding('warm up');
      final vectors = <List<double>>[], ms = <int>[];
      for (final t in checkTexts) {
        final sw = Stopwatch()..start();
        vectors.add(await embedder.generateEmbedding(t));
        ms.add(sw.elapsedMilliseconds);
      }
      return (vectors: vectors, ms: ms);
    }

    final a = await run(_e512);
    final b = await run(_e256);
    final out = StringBuffer('=== embedding check ===\n');
    for (var i = 0; i < checkTexts.length; i++) {
      final t = checkTexts[i];
      out.writeln('512: ${a.ms[i]}ms · 256: ${b.ms[i]}ms · cos ${_cos(a.vectors[i], b.vectors[i]).toStringAsFixed(4)}'
          ' · "${t.length > 40 ? '${t.substring(0, 40)}…' : t}"');
    }
    final dir = await getExternalStorageDirectory();
    File('${dir!.path}/embedding_check.json').writeAsStringSync(jsonEncode({
      'prefix': TaskType.retrievalQuery.prefix,
      'texts': checkTexts,
      'seq512': a.vectors,
      'seq256': b.vectors,
    }));
    out.writeln('vectors: ${dir.path}/embedding_check.json');
    // ignore: avoid_print
    print(out);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
