import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores login credentials for silent Firebase re-auth.
/// Uses Android's hardware-backed keystore via flutter_secure_storage.
class CredentialStorage {
  static final CredentialStorage instance = CredentialStorage._internal();
  CredentialStorage._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyEmail = 'auth.email';
  static const _keyPassword = 'auth.password';

  /// Save credentials after a successful full login.
  Future<void> save(String email, String password) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  /// Read stored credentials. Returns null if none saved.
  Future<Map<String, String>?> read() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email == null || password == null) return null;
    return {'email': email, 'password': password};
  }

  /// Clear stored credentials (call on logout).
  Future<void> clear() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }
}