import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'data/nutri_db.dart';
import 'data/profiles.dart';

/// App-private data directory, with nutri.db installed from the bundled asset
/// when missing or unreadable by this build. Overridden in tests.
final appDirProvider = FutureProvider<Directory>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final nutri = File('${dir.path}/nutri.db');
  try {
    openNutriDb(nutri.path).close();
  } on Object {
    // ponytail: bundled dummy db; real nutri.db arrives via Asset Delivery in M7.
    final tmp = File('${dir.path}/nutri.db.download');
    final data = await rootBundle.load('assets/nutri.db');
    await tmp.writeAsBytes(data.buffer.asUint8List(), flush: true);
    installNutriDb(tmp, nutri);
  }
  return dir;
});

final profilesProvider = Provider<Profiles>((ref) {
  final profiles = Profiles.open(ref.watch(appDirProvider).requireValue);
  ref.onDispose(profiles.close);
  return profiles;
});

/// The profile currently unlocked with its PIN; null = locked.
final unlockedProvider =
    NotifierProvider<UnlockedProfile, ProfileInfo?>(UnlockedProfile.new);

class UnlockedProfile extends Notifier<ProfileInfo?> {
  @override
  ProfileInfo? build() => null;

  void unlock(ProfileInfo profile) => state = profile;
  void lock() => state = null;
}

/// Total RAM in MB from /proc/meminfo (Android); null where unavailable.
int? totalRamMb() {
  try {
    final line = File('/proc/meminfo')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('MemTotal:'));
    return int.parse(RegExp(r'\d+').firstMatch(line)![0]!) ~/ 1024;
  } on Object {
    return null;
  }
}

/// A "6 GB" phone reports ~5.4–5.7 GB after the kernel's share.
const minRamMb = 5000;
