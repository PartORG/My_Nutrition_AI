// M0 steps 1 + 3: real chat latency with ONE reused conversation (as the app
// will run it), with EmbeddingGemma loaded alongside the LLM and embedding each
// message the way episodic memory will.
//
//   flutter test --no-uninstall integration_test/agent_latency_test.dart -d <phone> \
//     --dart-define=MODEL_PATH=.../gemma-4-E2B-it.litertlm \
//     --dart-define=EMBEDDER_PATH=.../embeddinggemma-300M_seq512.tflite \
//     --dart-define=TOKENIZER_PATH=.../embeddinggemma_sentencepiece.model
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myfoodmind/agent/tools.dart';

import 'device.dart';

const _model = String.fromEnvironment('MODEL_PATH');
const _embedder = String.fromEnvironment('EMBEDDER_PATH');
const _tokenizer = String.fromEnvironment('TOKENIZER_PATH');
const _backend = String.fromEnvironment('BACKEND', defaultValue: 'gpu');
const _embedBackend = String.fromEnvironment('EMBED_BACKEND', defaultValue: 'cpu');

/// A realistic session: small talk, a tool turn, follow-ups that need history.
const _script = [
  'Hi!',
  'I have chicken, rice and broccoli. What can I make?',
  'Show me recipe 1',
  'I had that for lunch',
  'How much protein do I have left today?',
  "I'm allergic to peanuts",
  'My glucose is 140',
  'Thanks, bye!',
];

/// Plausible tool results so the model can write its follow-up answer.
const _fakeResults = <String, Map<String, Object>>{
  'search_recipes': {
    'recipes': ['1. Chicken broccoli stir-fry, 520 kcal', '2. Chicken rice bowl, 610 kcal']
  },
  'recipe': {'title': 'Chicken broccoli stir-fry', 'minutes': 20, 'kcal': 520},
  'log_meal': {'status': 'waiting for user confirmation'},
  'nutrition_status': {'protein_left_g': 42, 'kcal_left': 780},
  'set_allergen': {'status': 'waiting for user confirmation'},
  'log_health': {'status': 'waiting for user confirmation'},
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('latency: one conversation, embedder + LLM loaded together', () async {
    final out = StringBuffer();
    final sw = Stopwatch()..start();
    int lap() {
      final ms = sw.elapsedMilliseconds;
      sw.reset();
      return ms;
    }

    final rss0 = rssMb();
    await FlutterGemma.initialize(
      inferenceEngines: [LiteRtLmEngine()],
      embeddingBackends: [LiteRtEmbeddingBackend()],
      embeddingTokenizers: [GemmaEmbeddingTokenizers()],
    );

    await FlutterGemma.installEmbedder()
        .modelFromFile(_embedder)
        .tokenizerFromFile(_tokenizer)
        .install();
    final embedder = await FlutterGemma.getActiveEmbedder(
        preferredBackend: PreferredBackend.values.byName(_embedBackend));
    out.writeln('embedder on ${embedder.activeBackend}');
    out.writeln('embedder ready: ${lap()}ms, RSS ${rssMb()}MB');

    await FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm)
        .fromFile(_model)
        .install();
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 4096,
      preferredBackend: PreferredBackend.values.byName(_backend),
    );
    out.writeln('LLM loaded: ${lap()}ms, RSS ${rssMb()}MB');

    final chat = await model.createChat(
      temperature: 0,
      topK: 1,
      tools: agentTools,
      supportsFunctionCalls: true,
      modelType: ModelType.gemma4,
      systemInstruction: agentSystemPrompt(),
      maxOutputTokens: 256,
    );
    out.writeln('chat created (13 tools): ${lap()}ms');

    var peak = rssMb();
    for (final text in _script) {
      await embedder.generateEmbedding(text);
      final embedMs = lap();

      await chat.addQueryChunk(Message.text(text: text, isUser: true));
      var r = await chat.generateChatResponse();
      final firstMs = lap();
      var called = '-';
      var answerMs = 0;
      if (r is FunctionCallResponse) {
        called = r.name;
        await chat.addQueryChunk(Message.toolResponse(
          toolName: r.name,
          response: _fakeResults[r.name] ?? {'status': 'ok'},
        ));
        r = await chat.generateChatResponse();
        answerMs = lap();
      }
      final reply = r is TextResponse ? r.token.replaceAll('\n', ' ') : '$r';
      peak = rssMb() > peak ? rssMb() : peak;
      out.writeln('"$text"\n'
          '   embed ${embedMs}ms · llm→$called ${firstMs}ms'
          '${answerMs > 0 ? ' · answer ${answerMs}ms' : ''}\n'
          '   ${reply.length > 140 ? '${reply.substring(0, 140)}…' : reply}');
    }
    out.writeln('RSS: start ${rss0}MB, peak ${peak}MB with both models');
    await model.close();
    // ignore: avoid_print
    print('=== latency (llm $_backend, embed $_embedBackend) ===\n$out');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
