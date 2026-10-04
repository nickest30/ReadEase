import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/parent.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';
import '../shared/forgot_password_screen.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final input = _identifierController.text.trim();
      final password = _passwordController.text;
      final isEmail = input.contains('@');

      // ── Path 1: Email entered → cloud login ──
      if (isEmail) {
        await _loginWithEmail(
          email: input.toLowerCase(),
          password: password,
          authProvider: authProvider,
          parentProvider: parentProvider,
        );
        return;
      }

      // ── Path 2: Username entered → try local first ──
      final localParent = await DatabaseService.instance
          .getParentByUsername(input.toLowerCase());

      if (localParent != null) {
        final isCorrect =
            BCrypt.checkpw(password, localParent.passwordHash);

        if (!isCorrect) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Incorrect password.';
            _isSubmitting = false;
          });
          return;
        }

        try {
          await authProvider.signIn(localParent.email, password);
        } catch (_) {
          // Offline — proceed
        }

        if (!mounted) return;
        parentProvider.setParent(localParent);
        Navigator.of(context).pushReplacementNamed('/parent-dashboard');
        return;
      }

      // Local miss — inform user to use email
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Username not found on this device.\n'
            'If this is a new device, log in with your email instead.';
        _isSubmitting = false;
      });
    } catch (e) {
      debugPrint('🔑 Parent login ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _loginWithEmail({
    required String email,
    required String password,
    required AuthProvider authProvider,
    required ParentProvider parentProvider,
  }) async {
    // 1. Firebase Auth
    final firebaseOk = await authProvider.signIn(email, password);
    if (!mounted) return;

    if (!firebaseOk) {
      setState(() {
        _errorMessage = 'Incorrect email or password.';
        _isSubmitting = false;
      });
      return;
    }

    // 2. Check if this email is already a local parent (fast path)
    Parent? localParent;
    final allParents = await DatabaseService.instance.getAllParents();
    for (final p in allParents) {
      if (p.email.toLowerCase() == email) {
        localParent = p;
        break;
      }
    }

    if (localParent != null) {
      if (!mounted) return;
      parentProvider.setParent(localParent);
      Navigator.of(context).pushReplacementNamed('/parent-dashboard');
      return;
    }

    // 3. Not local — fetch profile from Firestore by UID
    final uid = authProvider.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Session error. Try again.';
        _isSubmitting = false;
      });
      return;
    }

    final cloudDoc = await FirestoreService.instance.getParentByUid(uid);

    if (cloudDoc == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Account exists but profile is missing. Try signing up again.';
        _isSubmitting = false;
      });
      await authProvider.signOut();
      return;
    }

    // 4. Save locally so future logins work offline
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    final newLocalParent = Parent(
      username: (cloudDoc['username'] ?? '') as String,
      passwordHash: hashedPassword,
      fullName: (cloudDoc['fullName'] ?? '') as String,
      email: email,
      firebaseUid: uid,
      createdAt: DateTime.now().toIso8601String(),
    );

    final newId =
        await DatabaseService.instance.insertParent(newLocalParent);
    if (!mounted) return;

    final created =
        await DatabaseService.instance.getParentById(newId);

    if (created == null) {
      setState(() {
        _errorMessage = 'Could not save profile. Try again.';
        _isSubmitting = false;
      });
      return;
    }

    debugPrint('🔑 Parent cloud login OK — local profile created');

    await CloudSyncService.instance.downloadParentChildren(
      localParentId: created.id!,
      firebaseUid: uid,
    );

    if (!mounted) return;
    parentProvider.setParent(created);
    Navigator.of(context).pushReplacementNamed('/parent-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),

                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),

                const SizedBox(height: AppSpacing.sm),

                const Text('Welcome Back!', style: AppText.h1),
                const SizedBox(height: 2),
                const Text('Sign in to continue', style: AppText.caption),

                const SizedBox(height: AppSpacing.xl),

                const FieldLabel('Username or Email'),
                TextFormField(
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.usernameOrEmail,
                  decoration: buildInputDecoration(
                    hint: 'Enter username or email',
                    focusColor: AppColors.accentPurple,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                const FieldLabel('Password'),
                PasswordField(
                  controller: _passwordController,
                  hintText: 'Enter your password',
                  textInputAction: TextInputAction.done,
                  focusColor: AppColors.accentPurple,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please enter your password' : null,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(
                            role: ForgotPasswordRole.parent,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.accentPurple,
                      ),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.textCoral,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}