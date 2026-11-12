import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/credential_storage.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/avatar_helper.dart';
import '../../widgets/number_pad.dart';
import '../../widgets/pin_dots.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  static const int _maxAttempts = 5;
  String _enteredPin = '';
  int _attemptsRemaining = _maxAttempts;
  bool _isLocked = false;
  bool _isVerifying = false;
  PinDotState _dotState = PinDotState.idle;
  Timer? _lockTimer;
  Duration _lockRemaining = Duration.zero;

  Student? get _student {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Student) return args;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialLock());
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    final id = _student?.id;
    if (id == null) return;
    
    final remaining = await DatabaseService.instance.pinLockRemaining(id);
    if (!mounted) return;
    if (remaining != null && remaining.inSeconds > 0) {
      setState(() {
        _isLocked = true;
        _lockRemaining = remaining;
        _attemptsRemaining = 0;
      });
      _startLockCountdown();
    }
  }

  void _startLockCountdown() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final id = _student?.id;
      if (id == null || !mounted) return;
      
      final remaining = await DatabaseService.instance.pinLockRemaining(id);
      if (!mounted) return;
      if (remaining == null || remaining.inSeconds <= 0) {
        _lockTimer?.cancel();
        setState(() {
          _isLocked = false;
          _lockRemaining = Duration.zero;
          _attemptsRemaining = _maxAttempts;
        });
      } else {
        setState(() => _lockRemaining = remaining);
      }
    });
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onDigitPressed(String digit, Student student) {
    if (_isLocked || _isVerifying || _enteredPin.length >= 4) return;

    SfxService.tap();

    if (_dotState != PinDotState.idle) {
      setState(() => _dotState = PinDotState.idle);
    }
    HapticFeedback.selectionClick();

    setState(() => _enteredPin += digit);
    if (_enteredPin.length == 4) _verifyPin(student);
  }

  void _onBackspace() {
    if (_isLocked || _isVerifying || _enteredPin.isEmpty) return;
    
    SfxService.tap();
    HapticFeedback.lightImpact();
    
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _dotState = PinDotState.idle;
    });
  }

  Future<void> _verifyPin(Student student) async {
    setState(() => _isVerifying = true);

    final id = student.id;
    final isCorrect = BCrypt.checkpw(_enteredPin, student.pinHash ?? '');

    if (!isCorrect) {
      HapticFeedback.mediumImpact();
      if (id != null) {
        await DatabaseService.instance.recordPinAttempt(
          studentLocalId: id,
          success: false,
        );
      }
      if (!mounted) return;

      setState(() {
        _attemptsRemaining--;
        _dotState = PinDotState.error;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      if (id != null) {
        final remaining =
            await DatabaseService.instance.pinLockRemaining(id);
        if (!mounted) return;
        if (remaining != null && remaining.inSeconds > 0) {
          setState(() {
            _isLocked = true;
            _lockRemaining = remaining;
            _enteredPin = '';
            _dotState = PinDotState.idle;
            _isVerifying = false;
          });
          _startLockCountdown();
          return;
        }
      }

      setState(() {
        _enteredPin = '';
        _dotState = PinDotState.idle;
        _isVerifying = false;
      });
      return;
    }

    HapticFeedback.heavyImpact();
    if (id != null) {
      await DatabaseService.instance.clearPinAttempts(id);
    }

    await CredentialStorage.instance.touchSession();

    setState(() => _dotState = PinDotState.success);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    context.read<StudentProvider>().setStudent(student);

    final connectivity = context.read<ConnectivityProvider>();
    final authProvider = context.read<AuthProvider>();

    if (connectivity.isOnline && student.firebaseUid != null) {
      try {
        final restored = await authProvider.tryRestoreSessionFor(
          uid: student.firebaseUid!,
        );
        if (!restored && !authProvider.isSignedIn) {
          if (!mounted) return;
          final ok = await _promptForPassword(student);
          if (!ok || !mounted) {
            setState(() {
              _enteredPin = '';
              _dotState = PinDotState.idle;
              _isVerifying = false;
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('Session restore failed: $e');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/student-home',
      ModalRoute.withName('/role-selection'),
    );
  }

  Future<bool> _promptForPassword(Student student) async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PasswordPromptDialog(student: student),
    );

    if (password == null || password.isEmpty || !mounted) return false;

    final currentStudent = context.read<StudentProvider>().currentStudent;
    final authProvider = context.read<AuthProvider>();
    if (currentStudent?.firebaseUid == null) return false;

    final syntheticEmail = '${currentStudent!.username}@readease.app';

    try {
      final ok = await authProvider.signIn(syntheticEmail, password);
      if (ok) {
        debugPrint('Password verified + credentials saved');
        return true;
      }
    } catch (e) {
      debugPrint('Password verify failed: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incorrect password. Try again.',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final student = _student;
    
    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-profile-list',
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTablet = Responsive.isTablet(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final avatarSize = Responsive.imageSize(context, base: 72);
    final buttonHeight = Responsive.buttonHeight(context);

    Widget mainContent = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentTeal.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Image.asset(
                avatarAssetPath(student.avatarIndex),
                fit: BoxFit.cover,
                cacheWidth: (avatarSize * 2).toInt(),
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(student.displayName, style: AppText.h2),
          ),

          if (_isLocked) ...[
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: AppColors.accentCoral, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 44, color: AppColors.accentCoral),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'PROFILE LOCKED',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textCoral,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Too many incorrect attempts.\n'
                      'Try again in ${_formatRemaining(_lockRemaining)}.',
                      textAlign: TextAlign.center,
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: buttonHeight,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context)
                      .pushReplacementNamed('/student-signin');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Log In with Password',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: buttonHeight,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  SfxService.tap();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/student-profile-list',
                      (route) => false,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Back to Profiles',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppText.caption.copyWith(
                color: _attemptsRemaining <= 1
                    ? AppColors.textCoral
                    : AppColors.textMuted,
              ),
              child: Text('$_attemptsRemaining attempts remaining'),
            ),
            const SizedBox(height: AppSpacing.lg),

            PinDots(
              filledCount: _enteredPin.length,
              state: _dotState,
            ),
            const SizedBox(height: AppSpacing.sm),

            SizedBox(
              height: 22,
              child: _dotState == PinDotState.error
                  ? Text(
                      'Oops! Try again',
                      style: AppText.caption.copyWith(
                        color: AppColors.textCoral,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : _dotState == PinDotState.success
                      ? Text(
                          'Welcome back!',
                          style: AppText.caption.copyWith(
                            color: kPinSuccessColor,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.lg),

            NumberPad(
              enabled: !_isVerifying,
              onDigit: (d) => _onDigitPressed(d, student),
              onBackspace: _onBackspace,
            ),
          ],
        ],
      ),
    );

    if (isTablet) {
      mainContent = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: mainContent,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Stack(
          children: [
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: IconButton(
                onPressed: () {
                  SfxService.tap();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/student-profile-list',
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                tooltip: 'Back to Profiles',
              ),
            ),
            mainContent,
          ],
        ),
      ),
    );
  }
}

class _PasswordPromptDialog extends StatefulWidget {
  final Student student;

  const _PasswordPromptDialog({required this.student});

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    SfxService.tap();
    final text = _controller.text;
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: AppColors.surface,
      title: const Text(
        'One-Time Setup',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi ${widget.student.displayName}! Please enter your password '
            'once to connect this device to your cloud account.',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Password',
              filled: true,
              fillColor: AppColors.studentBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: IconButton(
                onPressed: () {
                  SfxService.tap();
                  setState(() => _obscure = !_obscure);
                },
                icon: Icon(
                  _obscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 20,
                ),
                color: AppColors.textMuted,
                tooltip: _obscure ? 'Show password' : 'Hide password',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide:
                    const BorderSide(color: AppColors.accentTeal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Note: Your password verifies that you own this '
              'account. It\'s used only once to reconnect this device to '
              'your cloud account, so your progress, points, and badges '
              'stay in sync. After this, you can continue using your '
              '4-digit PIN.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            SfxService.tap();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: 'Nunito', color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentTeal,
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
    );
  }
}