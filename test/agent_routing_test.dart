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
      if (q.tool == 'crisis' || q.tool == 'reply') continue;
      final tools = q.tool.split('+');
      expect(toolNames, containsAll(tools), reason: q.q);
      final props = {
        for (final t in agentTools.where((t) => tools.contains(t.name)))
          ...(t.parameters['properties'] as Map).keys
      };
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
    expect(isCrisis('хочу померти'), isTrue);
    expect(isCrisis('ХОЧУ ВМЕРТИ'), isTrue);
    expect(isCrisis('Я думаю про самогубство'), isTrue);
    expect(isCrisis('Ich denke an Selbstmord'), isTrue);
    expect(isCrisis('je veux en finir'), isTrue);
    expect(isCrisis('Je veux en finir avec le sucre'), isFalse);
    expect(isCrisis('Хочу схуднути до літа'), isFalse);
  });

  test('score: tool exact, args case-insensitive substring', () {
    const q = (q: 'x', tool: 'log_health', args: {'kind': 'glucose', 'value': '140'});
    expect(score(q, (tool: 'log_health', args: {'kind': 'Glucose', 'value': '140 mg/dL'})),
        (tool: true, args: true));
    expect(score(q, (tool: 'log_health', args: {'kind': 'weight', 'value': '140'})),
        (tool: true, args: false));
    expect(score(q, (tool: 'log_meal', args: {'kind': 'glucose', 'value': '140'})),
        (tool: false, args: false));
    expect(score(q, (tool: 'log_health', args: {})), (tool: true, args: false));

    const both = (q: 'x', tool: 'log_meal+lookup_nutrition', args: {'items': 'egg'});
    expect(score(both, (tool: 'lookup_nutrition+log_meal', args: {'items': '2 eggs', 'food': 'egg'})),
        (tool: true, args: true));
    expect(score(both, (tool: 'log_meal', args: {'items': '2 eggs'})), (tool: false, args: false),
        reason: 'half a request is a miss');
    expect(score(q, (tool: 'log_health+log_meal', args: q.args)), (tool: false, args: false),
        reason: 'an extra action is a miss');
  });
}
