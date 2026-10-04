import 'agent_queries.dart';

/// What the agent did for one query: the tool it called ('reply' for a plain
/// reply) and the args it passed.
typedef Routed = ({String tool, Map<String, dynamic> args});

/// Tool must match exactly; every expected arg value must be a
/// case-insensitive substring of the actual one.
({bool tool, bool args}) score(Q expected, Routed actual) {
  final toolOk = expected.tool == actual.tool;
  final argsOk = toolOk &&
      expected.args.entries.every((e) => '${actual.args[e.key] ?? ''}'
          .toLowerCase()
          .contains(e.value.toLowerCase()));
  return (tool: toolOk, args: argsOk);
}
