import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordService {
  const PasswordService();

  String hash(String plainText) =>
      sha256.convert(utf8.encode(plainText)).toString();

  String ensureHashed(String value) {
    if (value.isEmpty || RegExp(r'^[a-f0-9]{64}$').hasMatch(value.toLowerCase())) {
      return value;
    }
    return hash(value);
  }

  bool matches(String plainText, String stored) {
    if (stored.isEmpty) return false;
    final normalized = stored.toLowerCase();
    final isHash = RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized);
    return isHash ? hash(plainText) == normalized : plainText == stored;
  }
}