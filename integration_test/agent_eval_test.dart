// M0 / M2 routing gate. Runs the real model on the device (or Linux desktop).
//
//   flutter test --no-uninstall integration_test/agent_eval_test.dart -d <device> \
//     --dart-define=MODEL_PATH=<path to .litertlm> --dart-define=MODEL_TYPE=gemma4
//
// MODEL_TYPE: gemma4 | qwen3 | functionGemma | gemmaIt.  BACKEND: gpu | cpu (default).
// TOOL_CHOICE: required (default) | auto (use auto for gemma4).  VERBOSE=true dumps
// the native log. --no-uninstall keeps the app, and the models pushed into its folder.
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myfoodmind/agent/crisis.dart';
import 'package:myfoodmind/agent/tool_call_parser.dart';
import 'package:myfoodmind/agent/tools.dart';

import 'agent_queries.dart';
import 'device.dart';
import 'eval_score.dart';

const _path = String.fromEnvironment('MODEL_PATH');
const _type = String.fromEnvironment('MODEL_TYPE', defaultValue: 'gemma4');
const _backend = String.fromEnvironment('BACKEND', defaultValue: 'cpu');
const _choice = String.fromEnvironment('TOOL_CHOICE', defaultValue: 'required');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('agent routing accuracy >= 90%', () async {
    expect(_path, isNotEmpty, reason: 'pass --dart-define=MODEL_PATH=...');
    final type = ModelType.values.byName(_type);
    final rssBefore = rssMb();
    if (const bool.fromEnvironment('VERBOSE')) {
      FlutterGemma.logLevel = GemmaLogLevel.verbose;
    }

    await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
    final loadWatch = Stopwatch()..start();
    await FlutterGemma.installModel(modelType: type, fileType: ModelFileType.litertlm)
        .fromFile(_path)
        .install();
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.values.byName(_backend),
    );
    final loadMs = loadWatch.elapsedMilliseconds;
    final toolNames = {for (final t in agentTools) t.name};

    // A fresh chat per query keeps queries independent; the app reuses one
    // conversation instead (see agent_latency_test.dart for real latency).
    Future<Routed> ask(String text) async {
      final chat = await model.createChat(
        temperature: 0,
        topK: 1,
        tools: agentTools,
        supportsFunctionCalls: true,
        toolChoice: ToolChoice.values.byName(_choice),
        modelType: type,
        systemInstruction: agentSystemPrompt,
        maxOutputTokens: 128,
      );
      await chat.addQueryChunk(Message.text(text: text, isUser: true));
      final r = await chat.generateChatResponse();
      await chat.close();
      return switch (r) {
        FunctionCallResponse(:final name, :final args) => (tool: name, args: args),
        ParallelFunctionCallResponse(:final calls) when calls.isNotEmpty =>
          (tool: calls.first.name, args: calls.first.args),
        // Small models emit calls as text the plugin can't parse.
        TextResponse(:final token) => switch (parseToolCall(token, toolNames)) {
            (:final name, :final args) => (tool: name, args: args),
            null => (tool: 'reply', args: <String, dynamic>{'text': token}),
          },
        _ => (tool: 'reply', args: <String, dynamic>{}),
      };
    }

    var toolHits = 0, argHits = 0;
    final latencies = <int>[];
    final misses = <String>[];
    final perTool = <String, List<int>>{}; // tool -> [hits, total]

    for (final q in agentQueries) {
      Routed actual;
      if (isCrisis(q.q)) {
        actual = (tool: 'crisis', args: {});
      } else {
        final sw = Stopwatch()..start();
        actual = await ask(q.q);
        latencies.add(sw.elapsedMilliseconds);
      }
      final s = score(q, actual);
      final t = perTool.putIfAbsent(q.tool, () => [0, 0]);
      t[1]++;
      if (s.tool) {
        toolHits++;
        t[0]++;
      }
      if (s.args) {
        argHits++;
      } else {
        final raw = '${actual.args['text'] ?? ''}'.replaceAll('\n', ' ');
        misses.add('  want ${q.tool} ${q.args}, got ${actual.tool} ${actual.args}: "${q.q}"'
            '${raw.isEmpty ? '' : '\n      raw: ${raw.length > 300 ? raw.substring(0, 300) : raw}'}');
      }
    }
    final rssLoaded = rssMb();
    await model.close();

    latencies.sort();
    final n = agentQueries.length;
    final report = StringBuffer()
      ..writeln('=== $_type ($_backend, tools $_choice) on ${Platform.operatingSystem} ===')
      ..writeln('tool accuracy: $toolHits/$n = ${(100 * toolHits / n).toStringAsFixed(1)}%')
      ..writeln('args accuracy: $argHits/$n')
      ..writeln('load: ${loadMs}ms · per query p50 ${latencies[latencies.length ~/ 2]}ms'
          ' · p90 ${latencies[latencies.length * 9 ~/ 10]}ms')
      ..writeln('RSS: ${rssBefore}MB -> ${rssLoaded}MB with model')
      ..writeln('per tool: ${perTool.entries.map((e) => '${e.key} ${e.value[0]}/${e.value[1]}').join(', ')}')
      ..writeln('misses (tool or args):')
      ..writeAll(misses, '\n');
    // ignore: avoid_print
    print(report);

    expect(toolHits / n, greaterThanOrEqualTo(0.9));
  }, timeout: const Timeout(Duration(minutes: 30)));
}
