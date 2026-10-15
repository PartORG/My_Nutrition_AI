import 'agent_queries.dart';

/// What the agent did for one query: the tools it called, joined by '+' when it
/// called several ('reply' for a plain reply), and their args merged.
typedef Routed = ({String tool, Map<String, dynamic> args});

/// The same set of tools, in any order ("log_meal+lookup_nutrition"); every expected
/// arg value must be a case-insensitive substring of the actual one.
({bool tool, bool args}) score(Q expected, Routed actual) {
  final toolOk = expected.tool.split('+').toSet().containsAll(actual.tool.split('+')) &&
      actual.tool.split('+').toSet().containsAll(expected.tool.split('+'));
  final argsOk = toolOk &&
      expected.args.entries.every((e) => '${actual.args[e.key] ?? ''}'
          .toLowerCase()
          .contains(e.value.toLowerCase()));
  return (tool: toolOk, args: argsOk);
}
