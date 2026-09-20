import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

/// Manages the Firebase Auth session state.
/// Screens can listen to this to know if a user is signed in.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _subscription = AuthService.instance.authStateChanges().listen(
      (user) {
        _firebaseUser = user;
        _initializing = false;
        notifyListeners();
      },
    );
  }

  StreamSubscription<User?>? _subscription;
  User? _firebaseUser;
  bool _initializing = true;

  User? get firebaseUser => _firebaseUser;
  String? get uid => _firebaseUser?.uid;
  String? get email => _firebaseUser?.email;
  bool get isSignedIn => _firebaseUser != null;
  bool get initializing => _initializing;

  Future<String?> register(String email, String password) {
    return AuthService.instance.registerUser(email, password);
  }

  Future<bool> signIn(String email, String password) {
    return AuthService.instance.signIn(email, password);
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}