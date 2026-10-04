import 'package:flutter_test/flutter_test.dart';
import 'package:myfoodmind/agent/crisis.dart';
import 'package:myfoodmind/agent/tools.dart';

import '../integration_test/agent_queries.dart';
import '../integration_test/eval_score.dart';

void main() {
  final toolNames = {for (final t in agentTools) t.name};

  test('every labelled query targets a real tool with real arg names', () {
    expect(agentQueries.length, greaterThanOrEqualTo(100));
    for (final q in agentQueries) {
      if (q.tool == 'crisis') continue;
      expect(toolNames, contains(q.tool), reason: q.q);
      final props = (agentTools.firstWhere((t) => t.name == q.tool)
          .parameters['properties'] as Map).keys;
      expect(props, containsAll(q.args.keys), reason: q.q);
    }
    expect({for (final q in agentQueries) q.q}.length, agentQueries.length,
        reason: 'duplicate queries');
  });

  test('every tool is covered by at least 5 queries', () {
    for (final name in toolNames) {
      expect(agentQueries.where((q) => q.tool == name).length,
          greaterThanOrEqualTo(5), reason: name);
    }
  });

  test('crisis filter catches exactly the crisis-labelled queries', () {
    for (final q in agentQueries) {
      expect(isCrisis(q.q), q.tool == 'crisis', reason: q.q);
    }
    expect(isCrisis('How do I end my diet gracefully?'), isFalse);
    expect(isCrisis('I want to end my life'), isTrue);
  });

  test('score: tool exact, args case-insensitive substring', () {
    const q = (q: 'x', tool: 'log_reading', args: {'kind': 'glucose', 'value': '140'});
    expect(score(q, (tool: 'log_reading', args: {'kind': 'Glucose', 'value': '140 mg/dL'})),
        (tool: true, args: true));
    expect(score(q, (tool: 'log_reading', args: {'kind': 'weight', 'value': '140'})),
        (tool: true, args: false));
    expect(score(q, (tool: 'log_meal', args: {'kind': 'glucose', 'value': '140'})),
        (tool: false, args: false));
    expect(score(q, (tool: 'log_reading', args: {})), (tool: true, args: false));
  });
}
