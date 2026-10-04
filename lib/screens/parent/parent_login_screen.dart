import 'dart:async';
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
import '../shared/backup_code_screen.dart';
import '../shared/backup_code_entry_screen.dart';
import '../shared/forgot_password_screen.dart';
import '../shared/otp_verification_screen.dart';

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

  String _formatRemaining(Duration d) {
    if (d.inMinutes >= 1) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return s == 0 ? '$m min' : '$m min $s sec';
    }
    return '${d.inSeconds} sec';
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture providers BEFORE any await
    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();

    final identifier = _identifierController.text.trim().toLowerCase();

    // ── Rate limit gate ──
    final remaining = await DatabaseService.instance
        .loginRateLimitRemaining(identifier);
    if (remaining != null) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Too many failed attempts. Try again in ${_formatRemaining(remaining)}.';
        _isSubmitting = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final input = _identifierController.text.trim();
      final password = _passwordController.text;
      final isEmail = input.contains('@');

      if (isEmail) {
        await _loginWithEmail(
          email: input.toLowerCase(),
          password: password,
          identifier: identifier,
          authProvider: authProvider,
          parentProvider: parentProvider,
        );
        return;
      }

      // Username path (local-only)
      final localParent = await DatabaseService.instance
          .getParentByUsername(input.toLowerCase());

      if (localParent != null) {
        final isCorrect =
            BCrypt.checkpw(password, localParent.passwordHash);

        if (!isCorrect) {
          await DatabaseService.instance.recordLoginAttempt(
            identifier: identifier,
            success: false,
          );
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

        await DatabaseService.instance.clearLoginAttempts(identifier);
        if (!mounted) return;
        parentProvider.setParent(localParent);
        Navigator.of(context).pushReplacementNamed('/parent-dashboard');
        return;
      }

      await DatabaseService.instance.recordLoginAttempt(
        identifier: identifier,
        success: false,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Username not found on this device.\n'
            'If a new device, log in with your email instead.';
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
    required String identifier,
    required AuthProvider authProvider,
    required ParentProvider parentProvider,
  }) async {
    final firebaseOk = await authProvider.signIn(email, password);
    if (!mounted) return;

    if (!firebaseOk) {
      await DatabaseService.instance.recordLoginAttempt(
        identifier: identifier,
        success: false,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Incorrect email or password.';
        _isSubmitting = false;
      });
      return;
    }

    // Fast path — already local
    Parent? localParent;
    final allParents = await DatabaseService.instance.getAllParents();
    for (final p in allParents) {
      if (p.email.toLowerCase() == email) {
        localParent = p;
        break;
      }
    }

    final uid = authProvider.uid;
    if (uid == null) {
      await DatabaseService.instance.recordLoginAttempt(
        identifier: identifier,
        success: false,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Session error. Try again.';
        _isSubmitting = false;
      });
      return;
    }

    // ── Phone 2FA gate ──
    // Fetch the cloud doc to check phoneVerified state.
    // If parent is already local, use the local firebaseUid.
    final cloudDoc = await FirestoreService.instance.getParentByUidFull(uid);

    final phoneVerified = cloudDoc?['phoneVerified'] == true;
    final backupHash = cloudDoc?['backupCodeHash'] as String?;

    if (phoneVerified) {
      final trusted = await authProvider.isCurrentDeviceTrusted(uid);
      if (!trusted) {
        // Need OTP before proceeding
        final verified = await _runLoginOtpFlow(
          authProvider: authProvider,
          phoneNumber: (cloudDoc?['phoneNumber'] as String?) ?? '',
          uid: uid,
          backupHash: backupHash,
        );
        if (!verified || !mounted) {
          setState(() => _isSubmitting = false);
          return;
        }
      }
    }

    if (!mounted) return;

    // Continue with local save + dashboard
    if (localParent != null) {
      await DatabaseService.instance.clearLoginAttempts(identifier);
      // Refresh classes/children
      if (localParent.firebaseUid != null) {
        try {
          await CloudSyncService.instance.downloadParentChildren(
            localParentId: localParent.id!,
            firebaseUid: localParent.firebaseUid!,
          );
        } catch (e) {
          debugPrint('☁️ Children refresh failed: $e');
        }
      }
      if (!mounted) return;
      parentProvider.setParent(localParent);
      Navigator.of(context).pushReplacementNamed('/parent-dashboard');
      return;
    }

    // Not local — create from cloud doc
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

    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    final newLocalParent = Parent(
      username: (cloudDoc['username'] ?? '') as String,
      passwordHash: hashedPassword,
      fullName: (cloudDoc['fullName'] ?? '') as String,
      email: email,
      emailVerified: cloudDoc['emailVerified'] == true,
      phoneNumber: cloudDoc['phoneNumber'] as String?,
      phoneVerified: cloudDoc['phoneVerified'] == true,
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

    await CloudSyncService.instance.downloadParentChildren(
      localParentId: created.id!,
      firebaseUid: uid,
    );

    await DatabaseService.instance.clearLoginAttempts(identifier);

    if (!mounted) return;
    parentProvider.setParent(created);
    Navigator.of(context).pushReplacementNamed('/parent-dashboard');
  }

  /// Show OTP screen with backup-code fallback.
  /// Returns true if user successfully passed 2FA.
  Future<bool> _runLoginOtpFlow({
    required AuthProvider authProvider,
    required String phoneNumber,
    required String uid,
    required String? backupHash,
  }) async {
    // Kick off OTP send
    final completer = Completer<bool>();
    bool codeSent = false;

    await authProvider.startPhoneVerification(
      phoneNumber: phoneNumber,
      onCodeSent: () {
        codeSent = true;
        if (!completer.isCompleted) completer.complete(true);
      },
      onAutoVerified: () {
        if (!completer.isCompleted) completer.complete(true);
      },
      onError: (msg) {
        debugPrint('📱 OTP send failed: $msg');
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    final sent = await completer.future;
    if (!sent || !mounted || !codeSent) return false;

    // Show OTP screen. onVerified pops with true.
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: phoneNumber,
          accentColor: AppColors.accentPurple,
          backgroundColor: AppColors.parentBg,
          isSignup: false,
          onVerified: () => Navigator.of(context).pop(true),
          onNoPhoneFallback: () {
            // Handled inside the screen — it navigates to backup entry
          },
        ),
      ),
    );

    if (verified == true) {
      // Trust this device for 30 days
      await authProvider.trustCurrentDevice(uid);
      return true;
    }

    // If OTP was cancelled and user picked "no phone", route to backup code
    if (!mounted) return false;

    if (backupHash == null || backupHash.isEmpty) {
      setState(() {
        _errorMessage =
            'No backup code saved for this account. '
            'Use "Forgot password" to recover.';
      });
      return false;
    }

    // Backup code entry
    final newCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BackupCodeEntryScreen(
          backupCodeHash: backupHash,
          accentColor: AppColors.accentPurple,
          backgroundColor: AppColors.parentBg,
          onVerified: (code) => Navigator.of(context).pop(code),
        ),
      ),
    );

    if (newCode == null || !mounted) return false;

    // Rotate backup code — hash + save locally + push to cloud
    final newHash = BCrypt.hashpw(newCode, BCrypt.gensalt());
    await FirestoreService.instance.rotateBackupCode(uid, 'parent', newHash);

    if (!mounted) return false;

    // Show new code to user
    await BackupCodeDialog.show(
      context,
      code: newCode,
      accentColor: AppColors.accentPurple,
    );

    // Trust device
    await authProvider.trustCurrentDevice(uid);
    return true;
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
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter your password'
                      : null,
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