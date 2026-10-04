import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/credential_storage.dart';
import '../services/firestore_service.dart';

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
        _sessionState =
            user != null ? SessionState.online : SessionState.offline;
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

  /// Send a password reset email via Firebase Auth.
  /// Returns true if Firebase accepted the request.
  /// Note: callers should show a success message regardless of the
  /// return value to avoid leaking whether the email is registered.
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await AuthService.instance.sendPasswordResetEmail(
        email.trim().toLowerCase(),
      );
      return true;
    } catch (e) {
      debugPrint('🔑 Password reset failed: $e');
      return false;
    }
  }

  /// Attempt to restore a Firebase Auth session for a specific UID.
  /// Called during PIN entry when we know which user should be restored.
  Future<bool> tryRestoreSessionFor({required String uid}) async {
    // 1. Sign out if a DIFFERENT user is currently signed in
    if (isSignedIn && _firebaseUser?.uid != uid) {
      debugPrint(
        '🔑 tryRestoreSessionFor: wrong user signed in '
        '(${_firebaseUser?.uid}) — signing out',
      );
      await signOut();
    }

    // 2. Already correct user — done
    if (isSignedIn && _firebaseUser?.uid == uid) {
      debugPrint('🔑 tryRestoreSessionFor: already signed in as $uid');
      return true;
    }

    // 3. Look for saved credentials
    final creds = await CredentialStorage.instance.read(uid);
    if (creds == null) {
      debugPrint(
        '🔑 tryRestoreSessionFor: NO credentials for $uid '
        '(caller should prompt for password)',
      );
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
    if (isSignedIn && _firebaseUser?.uid != uid) {
      await signOut();
    }
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

  Future<void> signOutAndForget() async {
    final currentUid = uid;
    await AuthService.instance.signOut();
    if (currentUid != null) {
      await CredentialStorage.instance.clear(currentUid);
    }
    _sessionState = SessionState.offline;
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────
  // PHONE VERIFICATION (Tier 2 OTP)
  // ────────────────────────────────────────────────────────────────

  /// Send verification email to current user (Firebase handles rate-limit).
  Future<void> sendVerificationEmail() async {
    await AuthService.instance.sendEmailVerification();
  }

  /// Check if the current user's email is verified.
  Future<bool> isEmailVerified() async {
    return AuthService.instance.isEmailVerified();
  }

  Future<bool> checkEmailVerified() async {
    return AuthService.instance.isEmailVerified();
  }

  /// Start phone verification flow.
  /// Used at signup (linked to account) and login (as 2FA step).
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    await AuthService.instance.startPhoneVerification(
      phoneNumber: phoneNumber,
      onCodeSent: (_) => onCodeSent(),
      onAutoVerified: onAutoVerified,
      onError: onError,
    );
  }

  /// Confirm an OTP code. Returns true if verified.
  Future<bool> confirmPhoneCode(String smsCode) async {
    final ok = await AuthService.instance.confirmPhoneCode(smsCode);
    if (ok) {
      // Update cloud marker for current user
      final uid = AuthService.instance.currentUid;
      if (uid != null) {
        // Try both parent and teacher — one will succeed
        try {
          await FirestoreService.instance.markPhoneVerified(uid, 'parent');
        } catch (_) {}
        try {
          await FirestoreService.instance.markPhoneVerified(uid, 'teacher');
        } catch (_) {}
      }
    }
    return ok;
  }


  /// Whether the current device is trusted for this uid.
  /// If true, skip the OTP step at login.
  Future<bool> isCurrentDeviceTrusted(String uid) async {
    return CredentialStorage.instance.isDeviceTrusted(uid);
  }

  /// Mark the current device as trusted for this uid.
  Future<void> trustCurrentDevice(String uid) async {
    await CredentialStorage.instance.trustDevice(uid);
  }




  /// Get the phone number linked to the current user (if any).
  String? get currentPhoneNumber => AuthService.instance.currentPhoneNumber;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}