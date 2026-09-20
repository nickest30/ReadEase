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
}