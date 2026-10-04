import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/number_pad.dart';
import '../../widgets/pin_dots.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isSaving = false;
  String? _errorMessage;
  PinDotState _dotState = PinDotState.idle;

  String get _currentPin => _isConfirming ? _confirmPin : _pin;

  void _onDigitPressed(String digit) {
    if (_isSaving || _currentPin.length >= 4) return;

    if (_dotState != PinDotState.idle) {
      setState(() => _dotState = PinDotState.idle);
    }
    HapticFeedback.selectionClick();

    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        _pin += digit;
        if (_pin.length == 4) _isConfirming = true;
      } else {
        _confirmPin += digit;
        if (_confirmPin.length == 4) _verifyAndSave();
      }
    });
  }

  void _onBackspace() {
    if (_isSaving || _currentPin.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _dotState = PinDotState.idle;
      if (!_isConfirming) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin != _confirmPin) {
      HapticFeedback.mediumImpact();
      setState(() {
        _dotState = PinDotState.error;
        _errorMessage = "PINs don't match. Try again.";
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
        _errorMessage = null;
        _dotState = PinDotState.idle;
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

    final student = ModalRoute.of(context)!.settings.arguments as Student;
    final studentProvider = context.read<StudentProvider>();
    final hashedPin = BCrypt.hashpw(_pin, BCrypt.gensalt());

    await DatabaseService.instance.updatePin(student.id!, hashedPin);

    if (!mounted) return;
    final refreshed =
        await DatabaseService.instance.getStudentById(student.id!);
    if (!mounted || refreshed == null) return;

    studentProvider.setStudent(refreshed);

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/student-home',
      ModalRoute.withName('/role-selection'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: AppColors.accentTeal,
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Set Your PIN',
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Choose a 4-digit PIN for quick access',
                style: AppText.caption,
                textAlign: TextAlign.center,
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
                    ? Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.textCoral,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : _dotState == PinDotState.success
                        ? const Text(
                            'PIN set!',
                            style: TextStyle(
                              color: kPinSuccessColor,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
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
            ],
          ),
        ),
      ),
    );
  }
}