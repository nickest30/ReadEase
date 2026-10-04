import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state changes. Used by AuthProvider.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Register a new user with Firebase Auth.
  /// Returns the Firebase UID on success, null on failure.
  Future<String?> registerUser(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user?.uid;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase register error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Firebase register unknown error: $e');
      return null;
    }
  }

  /// Sign in with Firebase Auth. Returns true on success.
  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase signin error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Firebase signin unknown error: $e');
      return false;
    }
  }

  /// Sign out from Firebase Auth.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Get the current Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Get the current user's Firebase UID.
  String? get currentUid => _auth.currentUser?.uid;


  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }


  // ────────────────────────────────────────────────────────────────
  // EMAIL VERIFICATION (parent + teacher)
  // ────────────────────────────────────────────────────────────────

  /// Send a verification email to the currently signed-in user.
  /// Safe to call multiple times — Firebase rate-limits.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (user.emailVerified) return;
    try {
      await user.sendEmailVerification();
      debugPrint('📧 Verification email sent to ${user.email}');
    } catch (e) {
      debugPrint('📧 sendEmailVerification failed: $e');
    }
  }

  /// Reload the current user and return their verified state.
  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('📧 isEmailVerified check failed: $e');
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // PHONE VERIFICATION (Tier 2 OTP)
  // ────────────────────────────────────────────────────────────────

  String? _pendingVerificationId;
  int? _pendingResendToken;

  /// Initiate a phone verification flow.
  /// If a user is already signed in, the phone is LINKED to their account.
  /// If no user is signed in, it's a fresh sign-in-by-phone flow.
  ///
  /// Callbacks:
  ///  - onCodeSent: OTP was sent. Store the verificationId for later.
  ///  - onAutoVerified: Android auto-retrieved the code. Link already done.
  ///  - onError: Something failed (bad number, quota, etc.)
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android auto-retrieval — link immediately if signed in,
          // otherwise sign in with the credential.
          try {
            final user = _auth.currentUser;
            if (user != null) {
              await user.linkWithCredential(credential);
            } else {
              await _auth.signInWithCredential(credential);
            }
            onAutoVerified();
          } catch (e) {
            debugPrint('📱 Auto-verify link failed: $e');
            onError(e.toString());
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          debugPrint('📱 Phone verification failed: ${e.code} - ${e.message}');
          onError(e.message ?? 'Phone verification failed');
        },

        codeSent: (String verificationId, int? resendToken) {
          _pendingVerificationId = verificationId;
          _pendingResendToken = resendToken;
          onCodeSent(verificationId);
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _pendingVerificationId = verificationId;
        },

        forceResendingToken: _pendingResendToken,
      );
    } catch (e) {
      debugPrint('📱 startPhoneVerification error: $e');
      onError(e.toString());
    }
  }

  /// Confirm the OTP code entered by the user.
  /// On success, the phone is linked to the currently signed-in user
  /// (or a new session is created if no one was signed in).
  Future<bool> confirmPhoneCode(String smsCode) async {
    final verificationId = _pendingVerificationId;
    if (verificationId == null) {
      debugPrint('📱 No pending verification ID');
      return false;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final user = _auth.currentUser;
      if (user != null) {
        await user.linkWithCredential(credential);
        debugPrint('📱 Phone linked to ${user.uid}');
      } else {
        await _auth.signInWithCredential(credential);
        debugPrint('📱 Signed in via phone');
      }
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('📱 confirmPhoneCode failed: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('📱 confirmPhoneCode error: $e');
      return false;
    }
  }

  /// Get the phone number linked to the current user (if any).
  String? get currentPhoneNumber => _auth.currentUser?.phoneNumber;


}