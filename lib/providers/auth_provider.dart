import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/credential_storage.dart';
import '../services/firestore_service.dart';

enum SessionState { online, offline }

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
      final uid = AuthService.instance.currentUid;
      if (uid != null) {
        await CredentialStorage.instance.save(
          uid: uid,
          email: email,
          password: password,
        );
        await CredentialStorage.instance.touchSession();
      }
    }
    return ok;
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await AuthService.instance.sendPasswordResetEmail(
        email.trim().toLowerCase(),
      );
      return true;
    } catch (e) {
      debugPrint('Password reset failed: $e');
      return false;
    }
  }

  Future<bool> tryRestoreSessionFor({required String uid}) async {
    if (isSignedIn && _firebaseUser?.uid != uid) {
      debugPrint('tryRestoreSessionFor: wrong user signed in '
          '(${_firebaseUser?.uid}) - signing out');
      await signOut();
    }

    if (isSignedIn && _firebaseUser?.uid == uid) {
      debugPrint('tryRestoreSessionFor: already signed in as $uid');
      return true;
    }

    final creds = await CredentialStorage.instance.read(uid);
    if (creds == null) {
      debugPrint('tryRestoreSessionFor: no credentials for $uid '
          '(caller should prompt for password)');
      return false;
    }

    debugPrint('tryRestoreSessionFor: restoring $uid (${creds['email']})');

    try {
      final ok = await AuthService.instance.signIn(
        creds['email']!,
        creds['password']!,
      );
      debugPrint('tryRestoreSessionFor: signIn result = $ok');
      if (ok) {
        await CredentialStorage.instance.touchSession();
      }
      return ok;
    } catch (e) {
      debugPrint('tryRestoreSessionFor: error = $e');
      return false;
    }
  }

  Future<bool> signInWithSavedCredentials(String uid) async {
    if (isSignedIn && _firebaseUser?.uid != uid) {
      await signOut();
    }
    final creds = await CredentialStorage.instance.read(uid);
    if (creds == null) return false;
    return AuthService.instance.signIn(creds['email']!, creds['password']!);
  }

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

  Future<bool> checkSessionExpiry() async {
    final expired = await CredentialStorage.instance.isSessionExpired();
    if (!expired) return false;

    debugPrint('Session expired, forcing sign-out');
    await AuthService.instance.signOut();
    await CredentialStorage.instance.clearSessionMarker();
    _sessionState = SessionState.offline;
    notifyListeners();
    return true;
  }

  Future<void> sendVerificationEmail() async {
    await AuthService.instance.sendEmailVerification();
  }

  /// Returns the cached emailVerified value (fast, no network).
  /// Use this for UI logic that just needs to know the current state.
  Future<bool> isEmailVerified() async {
    return AuthService.instance.isEmailVerified();
  }

  /// Checks email verification status by forcing a reload from Firebase.
  /// This is the one the "I Have Verified" button should call.
  ///
  /// Why this exists: Firebase caches the `User` object in memory. After
  /// the user clicks the verification link in their email, the SERVER
  /// knows it's verified, but the client's cached User still reports
  /// `emailVerified == false` until the app restarts or you call `reload()`.
  ///
  /// By calling `user.reload()` we force a fresh fetch from the server.
  Future<bool> checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('VERIFY: ❌ no user signed in');
      return false;
    }

    debugPrint('VERIFY: uid=${user.uid}');

    try {
      final tokenResult = await user
          .getIdTokenResult(true)
          .timeout(const Duration(seconds: 10));

      final claimVerified = tokenResult.claims?['email_verified'];
      debugPrint('VERIFY: token claim email_verified=$claimVerified');

      if (claimVerified == true) {
        debugPrint('VERIFY: ✅ verified via token claim');
        try {
          await user.reload();
        } catch (_) {}
        return true;
      }

      try {
        await user.reload().timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('VERIFY: reload failed: $e');
      }

      debugPrint('VERIFY: user.emailVerified=${user.emailVerified}');
      return user.emailVerified;
    } on TimeoutException {
      debugPrint('VERIFY: ❌ token fetch timed out');
      return false;
    } catch (e) {
      debugPrint('VERIFY: ❌ error: $e');
      return false;
    }
  }
  
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

  Future<bool> confirmPhoneCode(String smsCode) async {
    final ok = await AuthService.instance.confirmPhoneCode(smsCode);
    if (ok) {
      final uid = AuthService.instance.currentUid;
      if (uid != null) {
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

  Future<bool> isCurrentDeviceTrusted(String uid) async {
    return CredentialStorage.instance.isDeviceTrusted(uid);
  }

  Future<void> trustCurrentDevice(String uid) async {
    await CredentialStorage.instance.trustDevice(uid);
  }

  String? get currentPhoneNumber => AuthService.instance.currentPhoneNumber;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}