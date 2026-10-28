import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';

String hashPassword(String password) {
  return BCrypt.hashpw(password, BCrypt.gensalt());
}

bool verifyPassword(String password, String hash) {
  if (hash.isEmpty) return false;
  // Support legacy SHA-256 hashes for backward compatibility
  if (hash.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(hash)) {
    final legacy = sha256.convert(utf8.encode(password)).toString();
    return legacy == hash;
  }
  try {
    return BCrypt.checkpw(password, hash);
  } catch (_) {
    return false;
  }
}

bool isLegacyHash(String hash) {
  return hash.length == 64 && RegExp(r'^[a-f0-9]+$').hasMatch(hash);
}
