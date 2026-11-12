import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/number_pad.dart';
import '../../widgets/pin_dots.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  int _stage = 0;
  String _oldPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _errorMessage;
  bool _isSaving = false;
  PinDotState _dotState = PinDotState.idle;

  String get _currentPin {
    if (_stage == 0) return _oldPin;
    if (_stage == 1) return _newPin;
    return _confirmPin;
  }

  String get _stageTitle {
    switch (_stage) {
      case 0:
        return 'Enter Current PIN';
      case 1:
        return 'Enter New PIN';
      default:
        return 'Confirm New PIN';
    }
  }

  String get _stageSubtitle {
    switch (_stage) {
      case 0:
        return 'Verify it\'s really you';
      case 1:
        return 'Choose a 4-digit PIN';
      default:
        return 'Re-enter your new PIN';
    }
  }

  void _setCurrentPin(String value) {
    if (_stage == 0) _oldPin = value;
    if (_stage == 1) _newPin = value;
    if (_stage == 2) _confirmPin = value;
  }

  void _onDigitPressed(String digit) {
    if (_isSaving || _currentPin.length >= 4) return;

    SfxService.tap();

    if (_dotState != PinDotState.idle) {
      setState(() => _dotState = PinDotState.idle);
    }
    HapticFeedback.selectionClick();

    setState(() {
      _errorMessage = null;
      _setCurrentPin(_currentPin + digit);
    });

    if (_currentPin.length == 4) _handleStageComplete();
  }

  void _onBackspace() {
    if (_isSaving || _currentPin.isEmpty) return;

    SfxService.tap();
    HapticFeedback.lightImpact();
    
    setState(() {
      _errorMessage = null;
      _dotState = PinDotState.idle;
      _setCurrentPin(_currentPin.substring(0, _currentPin.length - 1));
    });
  }

  Future<void> _handleStageComplete() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null) return;

    if (_stage == 0) {
      await _verifyCurrentPin(student.pinHash);
    } else if (_stage == 1) {
      await _validateNewPin();
    } else {
      await _confirmNewPin(student.id!);
    }
  }

  Future<void> _verifyCurrentPin(String? storedHash) async {
    final isCorrect = BCrypt.checkpw(_oldPin, storedHash ?? '');
    if (isCorrect) {
      setState(() => _stage = 1);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _dotState = PinDotState.error;
      _errorMessage = 'Incorrect PIN. Try again.';
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _oldPin = '';
      _dotState = PinDotState.idle;
      _errorMessage = null;
    });
  }

  Future<void> _validateNewPin() async {
    if (_newPin == '0000' || _newPin == '1111' || _newPin == '1234') {
      await _rejectNewPin('That PIN is too easy. Pick another.');
      return;
    }
    if (_newPin == _oldPin) {
      await _rejectNewPin('New PIN must be different from old PIN.');
      return;
    }

    setState(() => _stage = 2);
  }

  Future<void> _rejectNewPin(String message) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _dotState = PinDotState.error;
      _errorMessage = message;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _newPin = '';
      _dotState = PinDotState.idle;
      _errorMessage = null;
    });
  }

  Future<void> _confirmNewPin(int studentId) async {
    if (_newPin != _confirmPin) {
      HapticFeedback.mediumImpact();
      setState(() {
        _dotState = PinDotState.error;
        _errorMessage = 'PINs don\'t match. Start over.';
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _newPin = '';
        _confirmPin = '';
        _stage = 1;
        _dotState = PinDotState.idle;
        _errorMessage = null;
      });
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isSaving = true;
      _dotState = PinDotState.success;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await _saveNewPin(studentId);
  }

  Future<void> _saveNewPin(int studentId) async {
    try {
      final hashed = BCrypt.hashpw(_newPin, BCrypt.gensalt());
      await DatabaseService.instance.updatePin(studentId, hashed);
      if (!mounted) return;

      final refreshed =
          await DatabaseService.instance.getStudentById(studentId);
      if (!mounted || refreshed == null) return;

      context.read<StudentProvider>().updateStudent(refreshed);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PIN updated successfully!',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSaving = false;
        _dotState = PinDotState.idle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-profile-list',
            ModalRoute.withName('/role-selection'),
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

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      SfxService.tap();
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.textPrimary),
              padding: EdgeInsets.zero,
            ),
          ),
          const Spacer(),
          _StageIndicator(current: _stage),
          const SizedBox(height: AppSpacing.lg),
          const Icon(
            Icons.lock_reset_rounded,
            size: 56,
            color: AppColors.accentPurple,
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _stageTitle,
              style: AppText.h1,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _stageSubtitle,
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PinDots(
            filledCount: _currentPin.length,
            state: _dotState,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 22,
            child: _errorMessage != null
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _errorMessage!,
                      style: AppText.caption.copyWith(
                        color: AppColors.textCoral,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _dotState == PinDotState.success
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Saving...',
                          style: AppText.caption.copyWith(
                            color: kPinSuccessColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.lg),
          NumberPad(
            enabled: !_isSaving,
            onDigit: _onDigitPressed,
            onBackspace: _onBackspace,
          ),
          const Spacer(),
        ],
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
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: content),
    );
  }
}

class _StageIndicator extends StatelessWidget {
  final int current;

  const _StageIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActiveOrDone = i <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActiveOrDone ? 12 : 10,
          height: isActiveOrDone ? 12 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActiveOrDone ? AppColors.accentTeal : AppColors.border,
          ),
        );
      }),
    );
  }
}