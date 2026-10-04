import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/teacher.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';
import '../shared/backup_code_screen.dart';
import '../shared/otp_verification_screen.dart';

class TeacherSignupScreen extends StatefulWidget {
  const TeacherSignupScreen({super.key});

  @override
  State<TeacherSignupScreen> createState() => _TeacherSignupScreenState();
}

class _TeacherSignupScreenState extends State<TeacherSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _schoolNameController = TextEditingController();
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
    _schoolNameController.dispose();
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

    final authProvider = context.read<AuthProvider>();
    final teacherProvider = context.read<TeacherProvider>();

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
          .getTeacherByUsername(_usernameController.text.trim());
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'That username is already taken.';
          _isSubmitting = false;
        });
        return;
      }

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

      final hashedPassword = BCrypt.hashpw(
        _passwordController.text,
        BCrypt.gensalt(),
      );

      final newTeacher = Teacher(
        username: _usernameController.text.trim(),
        passwordHash: hashedPassword,
        fullName: _fullNameController.text.trim(),
        email: email,
        schoolName: _schoolNameController.text.trim(),
        firebaseUid: firebaseUid,
        createdAt: DateTime.now().toIso8601String(),
      );

      final newId =
          await DatabaseService.instance.insertTeacher(newTeacher);
      if (!mounted) return;

      final createdTeacher =
          await DatabaseService.instance.getTeacherById(newId);
      if (!mounted || createdTeacher == null) return;

      teacherProvider.setTeacher(createdTeacher);

      // Save credentials for silent Firebase re-auth
      await authProvider.saveCredentials(
        uid: firebaseUid,
        email: email,
        password: _passwordController.text,
      );

      try {
        await FirestoreService.instance
            .saveTeacher(createdTeacher, firebaseUid);
      } catch (e) {
        debugPrint('🔥 saveTeacher failed: $e');
      }

      // Save phone number to cloud if provided (before verification)
      if (normalizedPhone != null) {
        await FirestoreService.instance.markPhoneNumber(
          firebaseUid,
          'teacher',
          normalizedPhone,
        );
      }

      if (!mounted) return;

      // Send email verification in background (non-blocking)
      unawaited(_sendEmailVerification(authProvider));

      // ── Phone path or skip ──
      if (normalizedPhone != null) {
        await _runPhoneVerificationFlow(
          normalizedPhone: normalizedPhone,
          teacher: createdTeacher,
          authProvider: authProvider,
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/teacher-dashboard');
      }
    } catch (e) {
      debugPrint('👩‍🏫 Teacher signup ERROR: $e');
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
    required Teacher teacher,
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
          accentColor: AppColors.accentYellow,
          backgroundColor: AppColors.teacherBg,
          isSignup: true,
          onVerified: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (!mounted) return;

    // OTP done → generate + show backup code
    final backupCode = BackupCode.generate();
    final hashedBackup = BCrypt.hashpw(backupCode, BCrypt.gensalt());

    await DatabaseService.instance
        .updateTeacherBackupCodeHash(teacher.id!, hashedBackup);

    // Mark phone verified in Firestore
    if (teacher.firebaseUid != null) {
      await FirestoreService.instance
          .markPhoneVerified(teacher.firebaseUid!, 'teacher');
    }

    if (!mounted) return;

    final saved = await BackupCodeDialog.show(
      context,
      code: backupCode,
      accentColor: AppColors.accentYellow,
    );

    if (!saved || !mounted) return;

    // Trust this device for 30 days
    if (teacher.firebaseUid != null) {
      await authProvider.trustCurrentDevice(teacher.firebaseUid!);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/teacher-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teacherBg,
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

                // Header row with Groo
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
                            'Set up your teacher profile',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/mascot/groo_welcoming.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color:
                              AppColors.accentYellow.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentYellow,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppColors.accentYellow,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Full Name
                const FieldLabel('Full Name'),
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.displayName,
                  decoration: buildInputDecoration(
                    hint: 'Enter your full name',
                    focusColor: AppColors.accentYellow,
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
                    focusColor: AppColors.accentYellow,
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
                    focusColor: AppColors.accentYellow,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // School Name
                const FieldLabel('School Name'),
                TextFormField(
                  controller: _schoolNameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.schoolName,
                  decoration: buildInputDecoration(
                    hint: 'Enter your school name',
                    focusColor: AppColors.accentYellow,
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
                    if (_normalizePhone(v) == null) {
                      return 'Enter a valid PH number (e.g. 9123456789)';
                    }
                    return null;
                  },
                  decoration: buildInputDecoration(
                    hint: '912 345 6789',
                    focusColor: AppColors.accentYellow,
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
                  focusColor: AppColors.accentYellow,
                  validator: (v) => Validators.password(v),
                ),

                const SizedBox(height: AppSpacing.md),

                // Confirm Password
                const FieldLabel('Confirm Password'),
                PasswordField(
                  controller: _confirmController,
                  hintText: 'Re-enter your password',
                  textInputAction: TextInputAction.done,
                  focusColor: AppColors.accentYellow,
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
                      backgroundColor: AppColors.accentYellow,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.textPrimary,
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