import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  // Stages: 0=enter old PIN, 1=enter new PIN, 2=confirm new PIN
  int _stage = 0;
  String _oldPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _errorMessage;
  bool _isSaving = false;

  String get _currentPin {
    if (_stage == 0) return _oldPin;
    if (_stage == 1) return _newPin;
    return _confirmPin;
  }

  String get _stageTitle {
    if (_stage == 0) return 'Enter Current PIN';
    if (_stage == 1) return 'Enter New PIN';
    return 'Confirm New PIN';
  }

  String get _stageSubtitle {
    if (_stage == 0) return 'Verify it\'s really you';
    if (_stage == 1) return 'Choose a 4-digit PIN';
    return 'Re-enter your new PIN';
  }

  void _onDigitPressed(String digit) {
    if (_isSaving) return;

    setState(() {
      _errorMessage = null;
      if (_stage == 0 && _oldPin.length < 4) _oldPin += digit;
      if (_stage == 1 && _newPin.length < 4) _newPin += digit;
      if (_stage == 2 && _confirmPin.length < 4) _confirmPin += digit;
    });

    if (_currentPin.length == 4) {
      _handleStageComplete();
    }
  }

  void _onBackspace() {
    if (_isSaving) return;
    setState(() {
      _errorMessage = null;
      if (_stage == 0 && _oldPin.isNotEmpty) {
        _oldPin = _oldPin.substring(0, _oldPin.length - 1);
      } else if (_stage == 1 && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      } else if (_stage == 2 && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _handleStageComplete() {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null) return;

    if (_stage == 0) {
      // Verify old PIN
      final isCorrect = BCrypt.checkpw(_oldPin, student.pinHash ?? '');
      if (!isCorrect) {
        setState(() {
          _errorMessage = 'Incorrect PIN. Try again.';
          _oldPin = '';
        });
        return;
      }
      setState(() => _stage = 1);
    } else if (_stage == 1) {
      // New PIN entered — check it's not trivially weak
      if (_newPin == '0000' || _newPin == '1111' || _newPin == '1234') {
        setState(() {
          _errorMessage = 'That PIN is too easy. Pick another.';
          _newPin = '';
        });
        return;
      }
      if (_newPin == _oldPin) {
        setState(() {
          _errorMessage = 'New PIN must be different from old PIN.';
          _newPin = '';
        });
        return;
      }
      setState(() => _stage = 2);
    } else {
      // Confirm
      if (_newPin != _confirmPin) {
        setState(() {
          _errorMessage = 'PINs don\'t match. Start over.';
          _newPin = '';
          _confirmPin = '';
          _stage = 1;
        });
        return;
      }
      _saveNewPin(student.id!);
    }
  }

  Future<void> _saveNewPin(int studentId) async {
    setState(() => _isSaving = true);

    try {
      final hashed = BCrypt.hashpw(_newPin, BCrypt.gensalt());
      await DatabaseService.instance.updatePin(studentId, hashed);

      if (!mounted) return;

      // Refresh student in provider
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
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Back button (top-left)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  padding: EdgeInsets.zero,
                ),
              ),

              const Spacer(),

              // Stage indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final active = index == _stage;
                  final done = index < _stage;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.accentTeal
                          : active
                              ? AppColors.accentTeal
                              : AppColors.border,
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.lg),

              const Icon(
                Icons.lock_reset_rounded,
                size: 56,
                color: AppColors.accentPurple,
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                _stageTitle,
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _stageSubtitle,
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _currentPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.accentTeal : AppColors.border,
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.textCoral,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_isSaving) ...[
                const SizedBox(height: AppSpacing.lg),
                const CircularProgressIndicator(),
              ],

              const SizedBox(height: AppSpacing.xl),

              _NumberPad(
                onDigit: _onDigitPressed,
                onBackspace: _onBackspace,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _NumberPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final layout = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: layout.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 72, height: 64);
            return Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                width: 64,
                height: 64,
                child: ElevatedButton(
                  onPressed: () {
                    if (key == '⌫') {
                      onBackspace();
                    } else {
                      onDigit(key);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 1,
                    shape: const CircleBorder(),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}