import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/number_pad.dart';
import '../../widgets/pin_dots.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _enteredPin = '';
  int _attemptsRemaining = 5;
  bool _isLocked = false;
  bool _isVerifying = false;
  PinDotState _dotState = PinDotState.idle;

  void _onDigitPressed(String digit, Student student) {
    if (_isLocked || _isVerifying || _enteredPin.length >= 4) return;

    if (_dotState != PinDotState.idle) {
      setState(() => _dotState = PinDotState.idle);
    }
    HapticFeedback.selectionClick();

    setState(() => _enteredPin += digit);
    if (_enteredPin.length == 4) _verifyPin(student);
  }

  void _onBackspace() {
    if (_isLocked || _isVerifying || _enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _dotState = PinDotState.idle;
    });
  }

  Future<void> _verifyPin(Student student) async {
    setState(() => _isVerifying = true);

    final isCorrect = BCrypt.checkpw(_enteredPin, student.pinHash ?? '');
    if (!isCorrect) {
      HapticFeedback.mediumImpact();
      setState(() {
        _attemptsRemaining--;
        _dotState = PinDotState.error;
        if (_attemptsRemaining <= 0) _isLocked = true;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _enteredPin = '';
        _dotState = PinDotState.idle;
        _isVerifying = false;
      });
      return;
    }

    HapticFeedback.heavyImpact();
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
        debugPrint('🔑 Session restore failed: $e');
      }
    }

    debugPrint('🔑 auth.isSignedIn=${authProvider.isSignedIn}');
    debugPrint('🔑 auth.uid=${authProvider.uid}');
    debugPrint('🔑 student.firebaseUid=${student.firebaseUid}');

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/student-home',
      ModalRoute.withName('/role-selection'),
    );
  }

  Future<bool> _promptForPassword(Student student) async {
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
              'Hi ${student.displayName}! Please enter your password once. '
              'You won\'t need to do this again — just PIN from now on.',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Password',
                filled: true,
                fillColor: AppColors.studentBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Nunito', color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
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
      ),
    );

    if (result != true || !mounted) return false;

    final student2 = context.read<StudentProvider>().currentStudent;
    final authProvider = context.read<AuthProvider>();
    if (student2?.firebaseUid == null) return false;

    final syntheticEmail = '${student2!.username}@readease.app';

    try {
      final ok = await authProvider.signIn(
        syntheticEmail,
        passwordController.text,
      );
      if (ok) {
        debugPrint('🔑 Password verified + credentials saved');
        return true;
      }
    } catch (e) {
      debugPrint('🔑 Password verify failed: $e');
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
    final student = ModalRoute.of(context)!.settings.arguments as Student;

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.accentTeal,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.displayName.isNotEmpty
                        ? student.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(student.displayName, style: AppText.h2),

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
                      const Text(
                        'Too many incorrect attempts.\n'
                        'Full login is required to regain access.',
                        textAlign: TextAlign.center,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/student-signin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: const Text(
                      'Log In with Password',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: const Text(
                      'Back to Profiles',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}