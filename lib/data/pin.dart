import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 4–6 digits. A PIN this short only keeps out family members, not someone
/// with root; the lockout in Profiles is what makes guessing impractical.
bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

Uint8List newSalt() {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
}

/// PBKDF2-HMAC-SHA256, one 32-byte block.
Uint8List hashPin(String pin, List<int> salt, {int iterations = 100000}) {
  final hmac = Hmac(sha256, utf8.encode(pin));
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final out = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

/// Constant-time compare, so timing doesn't reveal how many bytes matched.
bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
