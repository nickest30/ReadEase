import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/teacher.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';
import '../../widgets/terms_modal.dart';
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
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final agreed = await TermsModal.show(context);
    if (!agreed) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      return;
    }
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final teacherProvider = context.read<TeacherProvider>();

    try {
      final email = _emailController.text.trim().toLowerCase();
      final phoneRaw = _phoneController.text.trim();
      final normalizedPhone =
          phoneRaw.isNotEmpty ? _normalizePhone(phoneRaw) : null;

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

      await authProvider.saveCredentials(
        uid: firebaseUid,
        email: email,
        password: _passwordController.text,
      );

      try {
        await FirestoreService.instance
            .saveTeacher(createdTeacher, firebaseUid)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('saveTeacher failed (continuing): $e');
      }

      if (normalizedPhone != null) {
        try {
          await FirestoreService.instance
              .markPhoneNumber(firebaseUid, 'teacher', normalizedPhone)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('markPhoneNumber failed (continuing): $e');
        }
      }

      if (!mounted) return;

      unawaited(_sendEmailVerification(authProvider));

      final verified = await _showEmailVerificationGate(authProvider);
      if (!mounted) return;

      if (!verified) {
        await authProvider.signOut();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/teacher-login',
          (route) => false,
        );
        return;
      }

      try {
        await DatabaseService.instance
            .markTeacherEmailVerified(createdTeacher.id!);
      } catch (e) {
        debugPrint('markTeacherEmailVerified (local) failed: $e');
      }

      try {
        await FirestoreService.instance
            .markEmailVerified(firebaseUid, 'teacher')
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('markEmailVerified (cloud) failed: $e');
      }

      await _generateAndShowBackupCode(
        teacher: createdTeacher,
        authProvider: authProvider,
      );

      if (normalizedPhone != null) {
        unawaited(_runPhoneVerificationFlow(
          normalizedPhone: normalizedPhone,
          teacher: createdTeacher,
          authProvider: authProvider,
        ));
      }
    } catch (e) {
      debugPrint('Teacher signup ERROR: $e');
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
      debugPrint('Verification email sent');
    } catch (e) {
      debugPrint('sendVerificationEmail failed: $e');
    }
  }

  Future<bool> _showEmailVerificationGate(AuthProvider authProvider) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _HardEmailVerificationDialog(
        authProvider: authProvider,
        email: _emailController.text.trim(),
      ),
    );
    return result ?? false;
  }

  Future<void> _runPhoneVerificationFlow({
    required String normalizedPhone,
    required Teacher teacher,
    required AuthProvider authProvider,
  }) async {
    final completer = Completer<void>();
    bool codeSent = false;

    try {
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
          if (!completer.isCompleted) completer.completeError(msg);
        },
      );
    } catch (e) {
      debugPrint('Phone verification unavailable (continuing): $e');
      return;
    }

    try {
      await completer.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Phone verification error (continuing): $e');
      return;
    }

    if (!mounted || !codeSent) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: normalizedPhone,
          accentColor: AppColors.accentTeal,
          backgroundColor: AppColors.teacherBg,
          isSignup: true,
          onVerified: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (!mounted) return;

    if (teacher.firebaseUid != null) {
      try {
        await FirestoreService.instance
            .markPhoneVerified(teacher.firebaseUid!, 'teacher');
      } catch (e) {
        debugPrint('markPhoneVerified failed: $e');
      }
    }
  }

  Future<void> _generateAndShowBackupCode({
    required Teacher teacher,
    required AuthProvider authProvider,
  }) async {
    final backupCode = BackupCode.generate();
    final hashedBackup = BCrypt.hashpw(backupCode, BCrypt.gensalt());

    try {
      await DatabaseService.instance
          .updateTeacherBackupCodeHash(teacher.id!, hashedBackup);
    } catch (e) {
      debugPrint('Local backup code save failed: $e');
    }

    if (teacher.firebaseUid != null) {
      try {
        await FirestoreService.instance
            .saveBackupCodeHash(
              teacher.firebaseUid!,
              'teacher',
              hashedBackup,
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Cloud backup code sync failed (continuing): $e');
      }
    }

    if (!mounted) return;

    final saved = await BackupCodeDialog.show(
      context,
      code: backupCode,
      accentColor: AppColors.accentTeal,
    );

    if (!saved || !mounted) return;

    if (teacher.firebaseUid != null) {
      try {
        await authProvider
            .trustCurrentDevice(teacher.firebaseUid!)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('trustCurrentDevice failed (continuing): $e');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/teacher-dashboard',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 120);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            IconButton(
              onPressed: () {
                SfxService.tap();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Account', style: AppText.h1),
                      SizedBox(height: 2),
                      Text('Set up your teacher profile',
                          style: AppText.caption),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/images/mascot/groo_welcoming.png',
                  width: imgSize,
                  height: imgSize,
                  fit: BoxFit.contain,
                  cacheWidth: (imgSize * 2).toInt(),
                  errorBuilder: (_, _, _) => Container(
                    width: imgSize,
                    height: imgSize,
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.accentTeal, width: 2),
                    ),
                    child: Icon(Icons.school_rounded,
                        color: AppColors.accentTeal,
                        size: imgSize * 0.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const FieldLabel('Full Name'),
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              validator: Validators.displayName,
              decoration: buildInputDecoration(
                hint: 'Enter your full name',
                focusColor: AppColors.accentTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Username'),
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              validator: Validators.username,
              decoration: buildInputDecoration(
                hint: 'Pick a username',
                focusColor: AppColors.accentTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Email'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.email,
              decoration: buildInputDecoration(
                hint: 'name@example.com',
                focusColor: AppColors.accentTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('School Name'),
            TextFormField(
              controller: _schoolNameController,
              textInputAction: TextInputAction.next,
              validator: Validators.schoolName,
              decoration: buildInputDecoration(
                hint: 'Enter your school name',
                focusColor: AppColors.accentTeal,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Phone Number (Optional)'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (v.length != 10) {
                  return 'Enter the 10-digit number (no spaces or +63)';
                }
                return null;
              },
              decoration: buildInputDecoration(
                hint: '9123456789',
                focusColor: AppColors.accentTeal,
              ).copyWith(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  child: Text(
                    '+63',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                counterText: '',
                helperText:
                    'Optional. If SMS is unavailable, we\'ll give you '
                    'a backup code instead.',
                helperMaxLines: 2,
                helperStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Password'),
            PasswordField(
              controller: _passwordController,
              hintText: 'Enter a strong password',
              textInputAction: TextInputAction.next,
              focusColor: AppColors.accentTeal,
              validator: (v) => Validators.password(v),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'At least 8 chars: uppercase, lowercase, number, symbol',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const FieldLabel('Confirm Password'),
            PasswordField(
              controller: _confirmController,
              hintText: 'Re-enter your password',
              textInputAction: TextInputAction.done,
              focusColor: AppColors.accentTeal,
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
              height: Responsive.buttonHeight(context),
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        SfxService.tap();
                        _handleSignup();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
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
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.teacherBg,
      body: SafeArea(child: content),
    );
  }
}

class _HardEmailVerificationDialog extends StatefulWidget {
  final AuthProvider authProvider;
  final String email;

  const _HardEmailVerificationDialog({
    required this.authProvider,
    required this.email,
  });

  @override
  State<_HardEmailVerificationDialog> createState() =>
      _HardEmailVerificationDialogState();
}

class _HardEmailVerificationDialogState
    extends State<_HardEmailVerificationDialog> {
  bool _checking = false;
  bool _resending = false;
  String? _localMessage;

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _localMessage = null;
    });

    try {
      final verified = await widget.authProvider
          .checkEmailVerified()
          .timeout(const Duration(seconds: 10));

      debugPrint('HARD GATE: checkEmailVerified returned $verified');

      if (!mounted) return;

      if (verified) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _checking = false;
          _localMessage =
              'Still not verified. Check your inbox and tap again.';
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _localMessage =
            'Connection timed out. Check your internet and try again.';
      });
    } catch (e) {
      debugPrint('HARD GATE error: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _localMessage = 'Error checking status. Please try again.';
      });
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _resending = true;
      _localMessage = null;
    });

    try {
      await widget.authProvider.sendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _resending = false;
        _localMessage = 'New verification email sent!';
      });
    } catch (e) {
      debugPrint('HARD GATE resend error: $e');
      if (!mounted) return;
      setState(() {
        _resending = false;
        _localMessage = 'Could not resend. Try again in a moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Row(
          children: [
            const Icon(Icons.mark_email_unread_rounded,
                color: AppColors.accentTeal),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Verify Your Email',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _checking
                  ? null
                  : () {
                      SfxService.tap();
                      Navigator.of(context).pop(false);
                    },
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.textMuted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Close (you will need to sign in again)',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a verification link to ${widget.email}.\n\n'
              'You must verify your email to continue. Open your inbox, '
              'click the link, then tap "I Have Verified" below.',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
            ),
            if (_localMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _localMessage!,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: AppColors.textOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: _resending || _checking
                ? null
                : () {
                    SfxService.tap();
                    _resendEmail();
                  },
            child: _resending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Resend Email',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      color: AppColors.accentTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          ElevatedButton(
            onPressed: _checking ? null : _checkVerified,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(130, 40),
            ),
            child: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'I Have Verified',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}