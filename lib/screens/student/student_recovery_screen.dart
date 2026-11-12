import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../services/credential_storage.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/student_recovery_code.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';

enum _RecoveryStep { username, code, password }

class StudentRecoveryScreen extends StatefulWidget {
  const StudentRecoveryScreen({super.key});

  @override
  State<StudentRecoveryScreen> createState() =>
      _StudentRecoveryScreenState();
}

class _StudentRecoveryScreenState extends State<StudentRecoveryScreen> {
  _RecoveryStep _step = _RecoveryStep.username;

  final _usernameController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  Student? _student;
  bool _busy = false;
  String? _errorMessage;

  bool _locked = false;
  Duration _lockRemaining = Duration.zero;
  Timer? _lockTimer;

  @override
  void dispose() {
    _lockTimer?.cancel();
    _usernameController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _rateKey =>
      'recovery:${_student?.username ?? _usernameController.text.trim().toLowerCase()}';

  Future<void> _verifyUsername() async {
    final username = _usernameController.text.trim().toLowerCase();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(username)) {
      setState(() =>
          _errorMessage = 'That doesn\'t look like a valid username.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final student =
          await DatabaseService.instance.getStudentByUsername(username);
      if (!mounted) return;

      if (student == null) {
        setState(() {
          _busy = false;
          _errorMessage =
              'We couldn\'t find that username on this device. '
              'Try logging in with your password, or create a new account.';
        });
        return;
      }

      if (student.isLinked) {
        setState(() {
          _busy = false;
          _errorMessage =
              'This is a parent-managed account. Ask your parent to help '
              'you recover it from their Parent Dashboard.';
        });
        return;
      }

      if (student.recoveryCodeHash == null ||
          student.recoveryCodeHash!.isEmpty) {
        setState(() {
          _busy = false;
          _errorMessage =
              'This account doesn\'t have a recovery code set up. '
              'Ask a parent or guardian for help, or create a new account.';
        });
        return;
      }

      if (student.firebaseUid == null || student.firebaseUid!.isEmpty) {
        setState(() {
          _busy = false;
          _errorMessage =
              'This account is missing cloud setup. Please contact support.';
        });
        return;
      }

      final remaining = await DatabaseService.instance
          .loginRateLimitRemaining(_rateKey);
      if (!mounted) return;

      setState(() {
        _busy = false;
        _student = student;
        _step = _RecoveryStep.code;
        _codeController.clear();
        _errorMessage = null;
        if (remaining != null && remaining.inSeconds > 0) {
          _locked = true;
          _lockRemaining = remaining;
          _startLockCountdown();
        } else {
          _locked = false;
        }
      });
    } catch (e) {
      debugPrint('Recovery username check failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _startLockCountdown() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining =
          await DatabaseService.instance.loginRateLimitRemaining(_rateKey);
      if (!mounted) return;
      if (remaining == null || remaining.inSeconds <= 0) {
        _lockTimer?.cancel();
        setState(() {
          _locked = false;
          _lockRemaining = Duration.zero;
        });
      } else {
        setState(() => _lockRemaining = remaining);
      }
    });
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyCode() async {
    if (_student == null || _locked) return;

    final raw = _codeController.text;
    if (!StudentRecoveryCode.isWellFormed(raw)) {
      setState(() => _errorMessage =
          'Enter the 8-character code (format ABCD-EFGH).');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final normalized = StudentRecoveryCode.normalize(raw);
    final formatted = StudentRecoveryCode.format(raw);
    final hash = _student!.recoveryCodeHash ?? '';
    final isCorrect = BCrypt.checkpw(normalized, hash) ||
        BCrypt.checkpw(formatted, hash);

    if (!isCorrect) {
      HapticFeedback.mediumImpact();
      await DatabaseService.instance.recordLoginAttempt(
        identifier: _rateKey,
        success: false,
      );
      final remaining = await DatabaseService.instance
          .loginRateLimitRemaining(_rateKey);
      if (!mounted) return;

      if (remaining != null && remaining.inSeconds > 0) {
        setState(() {
          _busy = false;
          _locked = true;
          _lockRemaining = remaining;
          _errorMessage = null;
        });
        _startLockCountdown();
        return;
      }

      setState(() {
        _busy = false;
        _errorMessage = 'Incorrect recovery code. Try again.';
        _codeController.clear();
      });
      return;
    }

    HapticFeedback.heavyImpact();
    await DatabaseService.instance.clearLoginAttempts(_rateKey);
    _lockTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _RecoveryStep.password;
      _errorMessage = null;
    });
  }

  Future<void> _saveNewPassword() async {
    if (_busy) return;
    if (_student == null) return;

    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final pwError = Validators.password(password);
    if (pwError != null) {
      setState(() => _errorMessage = pwError);
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords don\'t match.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    final authProvider = context.read<AuthProvider>();

    try {
      final uid = _student!.firebaseUid!;
      final creds = await CredentialStorage.instance.read(uid);

      if (creds == null || creds['password'] == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _errorMessage =
              'We can\'t reset your password on this device. Recovery '
              'works only on the device you originally signed up on.';
        });
        return;
      }

      final signedIn =
          await authProvider.signIn(creds['email']!, creds['password']!);
      if (!mounted) return;

      if (!signedIn) {
        setState(() {
          _busy = false;
          _errorMessage =
              'Could not verify your account. Try logging in with your old '
              'password instead.';
        });
        return;
      }

      try {
        final user = authProvider.firebaseUser;
        if (user == null) throw Exception('No Firebase user');
        await user.updatePassword(password);
      } catch (e) {
        debugPrint('Firebase updatePassword failed: $e');
        if (!mounted) return;
        setState(() {
          _busy = false;
          _errorMessage =
              'Could not update your password. Please try again.';
        });
        return;
      }

      await authProvider.saveCredentials(
        uid: uid,
        email: creds['email']!,
        password: password,
      );

      final newHash = BCrypt.hashpw(password, BCrypt.gensalt());
      await DatabaseService.instance
          .updateStudentPasswordHash(_student!.id!, newHash);

      await authProvider.signOut();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.accentGreen, size: 28),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Password reset!',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Your password has been updated. Log in with your new password '
            'to continue.',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                SfxService.tap();
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Go to Login',
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
      navigator.pushReplacementNamed('/student-signin');
    } catch (e) {
      debugPrint('Password recovery error: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _handleBack() {
    if (_busy) return;
    SfxService.tap();
    if (_step == _RecoveryStep.username) {
      Navigator.of(context).pop();
    } else if (_step == _RecoveryStep.code) {
      setState(() {
        _step = _RecoveryStep.username;
        _errorMessage = null;
        _codeController.clear();
      });
    } else {
      setState(() {
        _step = _RecoveryStep.code;
        _errorMessage = null;
        _passwordController.clear();
        _confirmController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _step == _RecoveryStep.username && !_busy;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        if (_step != _RecoveryStep.username) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.studentBg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.horizontalPadding(context),
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _handleBack,
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text('Account Recovery', style: AppText.h2),
                    ),
                  ],
                ),
              ),

              _StepIndicator(currentStep: _step.index),

              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.horizontalPadding(context),
                  ),
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _RecoveryStep.username:
        return _buildUsernameStep();
      case _RecoveryStep.code:
        return _buildCodeStep();
      case _RecoveryStep.password:
        return _buildPasswordStep();
    }
  }

  Widget _buildUsernameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.person_search_rounded,
            size: 56, color: AppColors.accentTeal),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Find Your Account',
          style: AppText.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Enter your username so we can check if you can recover it here.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('Username'),
        TextFormField(
          controller: _usernameController,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          decoration: buildInputDecoration(
            hint: 'Enter your username',
            focusColor: AppColors.accentTeal,
          ),
          onFieldSubmitted: (_) {
            if (!_busy) _verifyUsername();
          },
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          _buildErrorMessage(),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: Responsive.buttonHeight(context),
          child: ElevatedButton(
            onPressed: _busy
                ? null
                : () {
                    SfxService.tap();
                    _verifyUsername();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: _busy
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
                      'CONTINUE',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    if (_locked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Icon(Icons.lock_rounded,
              size: 56, color: AppColors.accentCoral),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Too Many Attempts',
            style: AppText.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try again in ${_formatRemaining(_lockRemaining)}.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: Responsive.buttonHeight(context),
            child: OutlinedButton(
              onPressed: _handleBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
              child: const Text(
                'BACK',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.key_rounded,
            size: 56, color: AppColors.accentTeal),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Enter Recovery Code',
          style: AppText.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'The 8-character code you saved for '
          '${_student?.username ?? 'your account'}.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('Recovery Code'),
        TextFormField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            color: AppColors.textPrimary,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            TextInputFormatter.withFunction((oldValue, newValue) {
              final text = newValue.text
                  .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
                  .toUpperCase();
              if (text.length > 8) return oldValue;
              if (text.length <= 4) {
                return TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
              }
              final formatted =
                  '${text.substring(0, 4)}-${text.substring(4)}';
              return TextEditingValue(
                text: formatted,
                selection:
                    TextSelection.collapsed(offset: formatted.length),
              );
            }),
          ],
          decoration: buildInputDecoration(
            hint: 'ABCD-EFGH',
            focusColor: AppColors.accentTeal,
          ),
          onFieldSubmitted: (_) {
            if (!_busy && !_locked) _verifyCode();
          },
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          _buildErrorMessage(),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: Responsive.buttonHeight(context),
          child: ElevatedButton(
            onPressed: _busy
                ? null
                : () {
                    SfxService.tap();
                    _verifyCode();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: _busy
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
                      'VERIFY CODE',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.password_rounded,
            size: 56, color: AppColors.accentTeal),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Set New Password',
          style: AppText.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Choose a strong password you\'ll remember.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('New Password'),
        PasswordField(
          controller: _passwordController,
          hintText: 'Enter your new password',
          textInputAction: TextInputAction.next,
          focusColor: AppColors.accentTeal,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Text(
            'At least 8 characters with uppercase, lowercase, number, and special character',
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
          hintText: 'Re-enter your new password',
          textInputAction: TextInputAction.done,
          focusColor: AppColors.accentTeal,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          _buildErrorMessage(),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: Responsive.buttonHeight(context),
          child: ElevatedButton(
            onPressed: _busy
                ? null
                : () {
                    SfxService.tap();
                    _saveNewPassword();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: _busy
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
                      'SAVE NEW PASSWORD',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: AppColors.accentCoral.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.accentCoral, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textCoral,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: active ? AppColors.accentTeal : AppColors.border,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}