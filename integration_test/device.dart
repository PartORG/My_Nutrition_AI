import 'dart:io';

/// Resident memory of this process in MB (Linux and Android both expose it).
int rssMb() {
  final line = File('/proc/self/status')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('VmRSS:'));
  return int.parse(RegExp(r'\d+').firstMatch(line)![0]!) ~/ 1024;
}
