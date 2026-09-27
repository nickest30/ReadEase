import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/credential_storage.dart';

/// Session states for the app.
enum SessionState {
  /// Firebase Auth has an active user
  online,

  /// No Firebase Auth session (PIN-only, offline)
  offline,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _subscription = AuthService.instance.authStateChanges().listen(
      (user) {
        _firebaseUser = user;
        _initializing = false;
        _sessionState = user != null ? SessionState.online : SessionState.offline;
        notifyListeners();
      },
    );
  }

  StreamSubscription<User?>? _subscription;
  User? _firebaseUser;
  bool _initializing = true;
  SessionState _sessionState = SessionState.offline;

  User? get firebaseUser => _firebaseUser;
  String? get uid => _firebaseUser?.uid;
  String? get email => _firebaseUser?.email;
  bool get isSignedIn => _firebaseUser != null;
  bool get initializing => _initializing;
  SessionState get sessionState => _sessionState;
  bool get isOnline => _sessionState == SessionState.online;

  Future<String?> register(String email, String password) {
    return AuthService.instance.registerUser(email, password);
  }

  Future<bool> signIn(String email, String password) async {
    final ok = await AuthService.instance.signIn(email, password);
    if (ok) {
      // Save credentials keyed by the newly signed-in user's UID
      final uid = AuthService.instance.currentUid;
      if (uid != null) {
        await CredentialStorage.instance.save(
          uid: uid,
          email: email,
          password: password,
        );
      }
    }
    return ok;
  }

   /// Attempt to restore a Firebase Auth session for a specific UID.
  /// Called during PIN entry when we know which user should be restored.
  Future<bool> tryRestoreSessionFor({required String uid}) async {
    if (isSignedIn) {
      debugPrint('🔑 tryRestoreSessionFor: already signed in as $uid');
      return true;
    }

    final creds = await CredentialStorage.instance.read(uid);
    if (creds == null) {
      debugPrint('🔑 tryRestoreSessionFor: no credentials for $uid');
      return false;
    }

    debugPrint('🔑 tryRestoreSessionFor: restoring $uid (${creds['email']})');

    try {
      final ok = await AuthService.instance.signIn(
        creds['email']!,
        creds['password']!,
      );
      debugPrint('🔑 tryRestoreSessionFor: signIn result = $ok');
      return ok;
    } catch (e) {
      debugPrint('🔑 tryRestoreSessionFor: ERROR = $e');
      return false;
    }
  }

  /// Sign in with saved credentials for a specific UID (used after
  /// creating a child account when we need to restore the parent session).
  Future<bool> signInWithSavedCredentials(String uid) async {
    final creds = await CredentialStorage.instance.read(uid);
    if (creds == null) return false;
    return AuthService.instance.signIn(creds['email']!, creds['password']!);
  }

  /// Save credentials after a successful signup/login.
  Future<void> saveCredentials({
    required String uid,
    required String email,
    required String password,
  }) async {
    await CredentialStorage.instance.save(
      uid: uid,
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    // Note: We do NOT clear credentials here — the current user
    // may still need them. Individual clears happen via clear(uid).
    _sessionState = SessionState.offline;
    notifyListeners();
  }

  /// Full sign out — clears everything including saved credentials.
  /// Use only when the user explicitly wants to forget this device.
@override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}