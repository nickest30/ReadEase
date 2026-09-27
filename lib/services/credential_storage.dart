import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores login credentials for silent Firebase re-auth.
/// Supports MULTIPLE users on the same device (parent + children).
class CredentialStorage {
  static final CredentialStorage instance = CredentialStorage._internal();
  CredentialStorage._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyCredentialsMap = 'auth.credentials_map';

  /// Save credentials for a user (keyed by Firebase UID).
  Future<void> save({
    required String uid,
    required String email,
    required String password,
  }) async {
    final map = await _loadAll();
    map[uid] = jsonEncode({'email': email, 'password': password});
    await _storage.write(
      key: _keyCredentialsMap,
      value: jsonEncode(map),
    );
  }

  /// Read credentials for a specific UID.
  Future<Map<String, String>?> read(String uid) async {
    final map = await _loadAll();
    if (!map.containsKey(uid)) return null;
    try {
      final decoded = jsonDecode(map[uid]!) as Map<String, dynamic>;
      return {
        'email': decoded['email'].toString(),
        'password': decoded['password'].toString(),
      };
    } catch (_) {
      return null;
    }
  }

  /// Clear credentials for a specific UID.
  Future<void> clear(String uid) async {
    final map = await _loadAll();
    map.remove(uid);
    await _storage.write(
      key: _keyCredentialsMap,
      value: jsonEncode(map),
    );
  }

  /// Clear all saved credentials (factory reset).
  Future<void> clearAll() async {
    await _storage.delete(key: _keyCredentialsMap);
  }

  Future<Map<String, String>> _loadAll() async {
    final raw = await _storage.read(key: _keyCredentialsMap);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }
}