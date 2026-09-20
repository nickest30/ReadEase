import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _enteredPin = '';
  int _attemptsRemaining = 5;
  bool _isLocked = false;

  void _onDigitPressed(String digit, Student student) {
    if (_isLocked) return;

    setState(() {
      if (_enteredPin.length < 4) _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin(student);
    }
  }

  void _onBackspace() {
    if (_isLocked) return;
    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  void _verifyPin(Student student) {
    final isCorrect = BCrypt.checkpw(_enteredPin, student.pinHash ?? '');

    if (isCorrect) {
      context.read<StudentProvider>().setStudent(student);
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/student-home',
        (route) => false,
      );
    } else {
      setState(() {
        _attemptsRemaining--;
        _enteredPin = '';
        if (_attemptsRemaining <= 0) {
          _isLocked = true;
        }
      });
    }
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
              // Avatar
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

                // Locked state
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: AppColors.accentCoral, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 44,
                        color: AppColors.accentCoral,
                      ),
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
                        'Too many incorrect attempts.\nFull login is required to regain access.',
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
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(
                        '/student-signin',
                      );
                    },
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
                Text(
                  '$_attemptsRemaining attempts remaining',
                  style: AppText.caption,
                ),
                const SizedBox(height: AppSpacing.lg),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _enteredPin.length;
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
                const SizedBox(height: AppSpacing.xl),

                _NumberPad(
                  onDigit: (digit) => _onDigitPressed(digit, student),
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
            if (key.isEmpty) {
              return const SizedBox(width: 72, height: 64);
            }
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