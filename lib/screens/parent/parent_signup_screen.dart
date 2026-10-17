import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/parent.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/terms_modal.dart';
import '../../utils/backup_code.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';
import '../shared/backup_code_screen.dart';
import '../shared/otp_verification_screen.dart';

class ParentSignupScreen extends StatefulWidget {
  const ParentSignupScreen({super.key});

  @override
  State<ParentSignupScreen> createState() => _ParentSignupScreenState();
}

class _ParentSignupScreenState extends State<ParentSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Normalize PH phone to E.164. Returns null if invalid.
  /// Accepts: "9123456789" (10 digits), "+639123456789", "09123456789".
  String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('63') && digits.length == 12) return '+$digits';
    if (digits.startsWith('0') && digits.length == 11) {
      return '+63${digits.substring(1)}';
    }
    if (digits.length == 10) return '+63$digits';
    return null;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final agreed = await TermsModal.show(
      context,
      intro: 'ReadEase keeps your child\'s data private and safe.',
    );
    if (!agreed || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final phoneRaw = _phoneController.text.trim();
      final normalizedPhone =
          phoneRaw.isNotEmpty ? _normalizePhone(phoneRaw) : null;

      // Local uniqueness check
      final existing = await DatabaseService.instance
          .getParentByUsername(_usernameController.text.trim());
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'That username is already taken.';
          _isSubmitting = false;
        });
        return;
      }

      final hashedPassword = BCrypt.hashpw(
        _passwordController.text,
        BCrypt.gensalt(),
      );

      final firebaseUid = await authProvider.register(
        email,
        _passwordController.text,
      );
      if (!mounted) return;

      if (firebaseUid == null) {
        setState(() {
          _errorMessage =
              'Email is already registered or network failed. '
              'Try a different email.';
          _isSubmitting = false;
        });
        return;
      }

      final newParent = Parent(
        username: _usernameController.text.trim(),
        passwordHash: hashedPassword,
        fullName: _fullNameController.text.trim(),
        email: email,
        createdAt: DateTime.now().toIso8601String(),
        firebaseUid: firebaseUid,
      );

      final newId = await DatabaseService.instance.insertParent(newParent);
      if (!mounted) return;

      final createdParent =
          await DatabaseService.instance.getParentById(newId);
      if (!mounted || createdParent == null) return;

      parentProvider.setParent(createdParent);

      await authProvider.saveCredentials(
        uid: firebaseUid,
        email: email,
        password: _passwordController.text,
      );

      await FirestoreService.instance.saveParent(
        parentUid: firebaseUid,
        username: createdParent.username,
        fullName: createdParent.fullName,
        email: createdParent.email,
        phoneNumber: normalizedPhone,
        phoneVerified: false,
        emailVerified: false,
      );
      if (!mounted) return;

      // Send email verification in background (non-blocking)
      unawaited(_sendEmailVerification(authProvider));

      // ── Phone path or skip ──
      if (normalizedPhone != null) {
        // Phone provided — OTP flow, then backup code, then dashboard.
        await _runPhoneVerificationFlow(
          normalizedPhone: normalizedPhone,
          parent: createdParent,
          authProvider: authProvider,
        );
      } else {
        // No phone — skip OTP, but still generate a backup code so the
        // user has a second-factor option on a new device.
        await _generateAndShowBackupCode(
          parent: createdParent,
          authProvider: authProvider,
        );
      }
    } catch (e) {
      debugPrint('👨‍👩‍👧 Signup ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _sendEmailVerification(AuthProvider authProvider) async {
    try {
      await authProvider.sendVerificationEmail();
      debugPrint('📧 Verification email sent');
    } catch (e) {
      debugPrint('📧 sendVerificationEmail failed: $e');
    }
  }

  /// Start phone verification → push OTP screen → on success show backup code.
  Future<void> _runPhoneVerificationFlow({
    required String normalizedPhone,
    required Parent parent,
    required AuthProvider authProvider,
  }) async {
    // Kick off phone verification — the pending verification ID is
    // stored inside AuthService, OTP screen reads from there.
    final completer = Completer<void>();
    bool codeSent = false;

    await authProvider.startPhoneVerification(
      phoneNumber: normalizedPhone,
      onCodeSent: () {
        codeSent = true;
        if (!completer.isCompleted) completer.complete();
      },
      onAutoVerified: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (msg) {
        if (!completer.isCompleted) {
          completer.completeError(msg);
        }
      },
    );

    try {
      await completer.future;
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      final isBilling =
          raw.contains('billing_not_enabled') || raw.contains('billing');

      if (isBilling) {
        // Firebase billing isn't enabled on the project.
        // Fall through to backup-code-only signup with a friendly message.
        await _showPhoneUnavailableAndContinue(
          parent: parent,
          authProvider: authProvider,
        );
        return;
      }

      setState(() {
        _errorMessage = 'Could not send code: $e';
        _isSubmitting = false;
      });
      return;
    }

    if (!mounted || !codeSent) return;

    // Navigate to OTP screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: normalizedPhone,
          accentColor: AppColors.accentPurple,
          backgroundColor: AppColors.parentBg,
          isSignup: true,
          onVerified: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (!mounted) return;

    // Mark phone verified in Firestore (OTP was just passed)
    if (parent.firebaseUid != null) {
      await FirestoreService.instance
          .markPhoneVerified(parent.firebaseUid!, 'parent');
    }

    if (!mounted) return;

    // Generate + show backup code, trust device, go to dashboard.
    await _generateAndShowBackupCode(
      parent: parent,
      authProvider: authProvider,
    );
  }

  /// Generate, save, and display a one-time backup code.
  ///
  /// Called at the end of signup regardless of whether a phone number was
  /// provided. This ensures every parent account has a second-factor
  /// recovery path (backup code) even if they didn't link a phone.
  ///
  /// On success: saves the bcrypt-hashed code to SQLite + Firestore,
  /// shows the modal, and trusts the device for 30 days.
  Future<void> _generateAndShowBackupCode({
    required Parent parent,
    required AuthProvider authProvider,
  }) async {
    final backupCode = BackupCode.generate();
    final hashedBackup = BCrypt.hashpw(backupCode, BCrypt.gensalt());

    await DatabaseService.instance
        .updateParentBackupCodeHash(parent.id!, hashedBackup);

    // Push hash to Firestore so it works on other devices
    if (parent.firebaseUid != null) {
      await FirestoreService.instance.saveBackupCodeHash(
        parent.firebaseUid!,
        'parent',
        hashedBackup,
      );
    }

    if (!mounted) return;

    final saved = await BackupCodeDialog.show(
      context,
      code: backupCode,
      accentColor: AppColors.accentPurple,
    );

    if (!saved || !mounted) return;

    // Trust this device for 30 days
    if (parent.firebaseUid != null) {
      await authProvider.trustCurrentDevice(parent.firebaseUid!);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/parent-dashboard');
  }

  
    /// Called when phone OTP fails due to Firebase billing being disabled.
  /// Shows a friendly dialog, then continues with backup-code-only signup.
  Future<void> _showPhoneUnavailableAndContinue({
    required Parent parent,
    required AuthProvider authProvider,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.accentOrange, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Phone verification unavailable',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'We can\'t send SMS codes right now. We\'ll continue with a '
          'backup code instead — you can use it to log in on a new device. '
          'You can add a phone number later in Settings → Account & Security.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    await _generateAndShowBackupCode(
      parent: parent,
      authProvider: authProvider,
    );
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

                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Account', style: AppText.h1),
                          SizedBox(height: 2),
                          Text(
                            'Set up your parent profile',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/mascot/motter_welcoming.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color:
                              AppColors.accentPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentPurple,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          color: AppColors.accentPurple,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Full name
                const FieldLabel('Full Name'),
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.displayName,
                  decoration: buildInputDecoration(
                    hint: 'Enter your full name',
                    focusColor: AppColors.accentPurple,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Username
                const FieldLabel('Username'),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.username,
                  decoration: buildInputDecoration(
                    hint: 'Pick a username',
                    focusColor: AppColors.accentPurple,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Email
                const FieldLabel('Email'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                  decoration: buildInputDecoration(
                    hint: 'name@example.com',
                    focusColor: AppColors.accentPurple,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Phone (optional) ──
                const FieldLabel('Phone Number (optional)'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[\d\s\+\-\(\)]'),
                    ),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    // validate only if provided
                    if (_normalizePhone(v) == null) {
                      return 'Enter a valid PH number (e.g. 9123456789)';
                    }
                    return null;
                  },
                  decoration: buildInputDecoration(
                    hint: '912 345 6789',
                    focusColor: AppColors.accentPurple,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Recommended. We\'ll send a one-time code to this number '
                    'when you sign in on a new device. You can skip this and '
                    'add it later in Settings.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Password
                const FieldLabel('Password'),
                PasswordField(
                  controller: _passwordController,
                  hintText: 'At least 8 chars, mix letters/numbers',
                  textInputAction: TextInputAction.next,
                  focusColor: AppColors.accentPurple,
                  validator: (v) => Validators.password(v),
                ),

                const SizedBox(height: AppSpacing.md),

                // Confirm
                const FieldLabel('Confirm Password'),
                PasswordField(
                  controller: _confirmController,
                  hintText: 'Re-enter your password',
                  textInputAction: TextInputAction.done,
                  focusColor: AppColors.accentPurple,
                  validator: (v) => Validators.confirmPassword(
                    v,
                    _passwordController.text,
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
                    onPressed: _isSubmitting ? null : _handleSignup,
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
                            'CREATE ACCOUNT',
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