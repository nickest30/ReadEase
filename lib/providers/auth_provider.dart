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
      // Save credentials for future PIN-based silent re-auth
      await CredentialStorage.instance.save(email, password);
    }
    return ok;
  }

  /// Attempt to restore the Firebase Auth session from saved credentials.
  /// Called during PIN entry when a session might be missing.
  /// Returns true if the session was restored successfully.
  Future<bool> tryRestoreSession() async {
    if (isSignedIn) return true;

    final creds = await CredentialStorage.instance.read();
    if (creds == null) return false;

    try {
      final ok = await AuthService.instance.signIn(
        creds['email']!,
        creds['password']!,
      );
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    await CredentialStorage.instance.clear();
    _sessionState = SessionState.offline;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}