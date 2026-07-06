import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Register a new user with Firebase Auth
  Future<String?> registerUser(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user?.uid;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase register error: ${e.code}');
      return null;
    }
  }

  // Sign in with Firebase Auth
  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase signin error: ${e.code}');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check if currently signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Get current user's Firebase UID
  String? get currentUid => _auth.currentUser?.uid;
}