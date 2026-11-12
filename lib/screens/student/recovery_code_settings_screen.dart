import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/student_recovery_code.dart';

class RecoveryCodeSettingsScreen extends StatefulWidget {
  const RecoveryCodeSettingsScreen({super.key});

  @override
  State<RecoveryCodeSettingsScreen> createState() =>
      _RecoveryCodeSettingsScreenState();
}

class _RecoveryCodeSettingsScreenState
    extends State<RecoveryCodeSettingsScreen> {
  bool _busy = false;

  Future<void> _onGenerateTapped(Student student) async {
    SfxService.tap();

    // Defensive: student must have a PIN to verify identity
    if (student.pinHash == null || student.pinHash!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please set a PIN first before generating a recovery code.',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 1. Verify PIN
    final pinOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinVerifyDialog(expectedHash: student.pinHash!),
    );

    if (pinOk != true || !mounted) return;

    // 2. Generate new code
    final raw = StudentRecoveryCode.generate();
    final normalized = StudentRecoveryCode.normalize(raw);
    final formatted = StudentRecoveryCode.format(normalized);

    // 3. Show code for user confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecoveryCodeDisplayDialog(code: formatted),
    );

    if (confirmed != true || !mounted) return;

    // 4. Save hash
    setState(() => _busy = true);
    try {
      final hash = BCrypt.hashpw(normalized, BCrypt.gensalt());
      final saved = await DatabaseService.instance
          .updateStudentRecoveryCodeHash(student.id!, hash);

      if (!mounted) return;

      if (!saved) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save recovery code. Please try again.',
              style: TextStyle(fontFamily: 'Nunito'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // 5. Refresh student in provider
      final refreshed = await DatabaseService.instance
          .getStudentById(student.id!);
      if (!mounted || refreshed == null) return;

      context.read<StudentProvider>().updateStudent(refreshed);

      setState(() => _busy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recovery code saved',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
            style: const TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    if (student == null) {
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasCode = student.recoveryCodeHash != null &&
        student.recoveryCodeHash!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button (top-left)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: IconButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                tooltip: 'Back to Settings',
              ),
            ),

            // Centered content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: (hasCode
                                  ? AppColors.accentGreen
                                  : AppColors.accentOrange)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasCode
                              ? Icons.verified_rounded
                              : Icons.key_rounded,
                          size: 48,
                          color: hasCode
                              ? AppColors.accentGreen
                              : AppColors.accentOrange,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Title
                      Text(
                        hasCode
                            ? 'Recovery Code Active'
                            : 'Set Up Recovery Code',
                        style: AppText.h1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Subtitle
                      Text(
                        hasCode
                            ? 'Your account is protected. If you forget your password, your recovery code is the only way to regain access.'
                            : 'Generate a recovery code to protect your account. If you forget your password, this code is the only way to recover it.',
                        style: AppText.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.medium),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow(
                              Icons.visibility_rounded,
                              'You will see the code only once.',
                            ),
                            const SizedBox(height: 8),
                            _infoRow(
                              Icons.copy_rounded,
                              'Copy it to a safe place.',
                            ),
                            const SizedBox(height: 8),
                            _infoRow(
                              Icons.warning_amber_rounded,
                              hasCode
                                  ? 'Regenerating will invalidate your old code.'
                                  : 'Without this code, a forgotten password cannot be recovered.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _busy
                              ? null
                              : () => _onGenerateTapped(student),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasCode
                                ? AppColors.accentOrange
                                : AppColors.accentTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.large),
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
                              : Text(
                                  hasCode
                                      ? 'REGENERATE RECOVERY CODE'
                                      : 'GENERATE RECOVERY CODE',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppText.caption),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// PIN Verification Dialog
// ─────────────────────────────────────────────────────────

class _PinVerifyDialog extends StatefulWidget {
  final String expectedHash;

  const _PinVerifyDialog({required this.expectedHash});

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  String _pin = '';
  int _attempts = 3;
  String? _error;

  void _onDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _error = null;
      });
    }
    if (_pin.length == 4) {
      _verify();
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = null;
      });
    }
  }

  void _verify() {
    final correct = BCrypt.checkpw(_pin, widget.expectedHash);
    if (correct) {
      Navigator.of(context).pop(true);
      return;
    }

    _attempts--;
    if (_attempts <= 0) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _pin = '';
      _error = 'Incorrect PIN. $_attempts attempts left.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.studentBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: AppColors.accentTeal,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Confirm with PIN',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Enter your PIN to continue',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.accentTeal : AppColors.border,
                      border: Border.all(
                        color:
                            filled ? AppColors.accentTeal : AppColors.border,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.textCoral,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _MiniPinPad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context).pop(false);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPinPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _MiniPinPad({required this.onDigit, required this.onBackspace});

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
            if (key.isEmpty) return const SizedBox(width: 56, height: 52);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SizedBox(
                width: 52,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    SfxService.tap();
                    if (key == '⌫') {
                      onBackspace();
                    } else {
                      onDigit(key);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
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

// ─────────────────────────────────────────────────────────
// Recovery Code Display Dialog
// ─────────────────────────────────────────────────────────

class _RecoveryCodeDisplayDialog extends StatefulWidget {
  final String code;

  const _RecoveryCodeDisplayDialog({required this.code});

  @override
  State<_RecoveryCodeDisplayDialog> createState() =>
      _RecoveryCodeDisplayDialogState();
}

class _RecoveryCodeDisplayDialogState
    extends State<_RecoveryCodeDisplayDialog> {
  bool _confirmed = false;

  void _copyCode() {
    SfxService.tap();
    Clipboard.setData(ClipboardData(text: widget.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Recovery code copied',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.key_rounded,
                  size: 32,
                  color: AppColors.accentTeal,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Save your recovery code',
                style: AppText.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'This is the ONLY time you will see this code. Write it down somewhere safe. If you lose it, you will not be able to recover your account.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.studentBg,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: AppColors.accentTeal.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.code,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _copyCode,
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      color: AppColors.accentTeal,
                      tooltip: 'Copy code',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                onTap: () {
                  SfxService.tap();
                  setState(() => _confirmed = !_confirmed);
                },
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _confirmed,
                          onChanged: (v) {
                            SfxService.tap();
                            setState(() => _confirmed = v ?? false);
                          },
                          activeColor: AppColors.accentTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'I saved my recovery code',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _HoldToConfirmButton(
                enabled: _confirmed,
                onConfirmed: () {
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context).pop(false);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Hold to Confirm Button
// ─────────────────────────────────────────────────────────

class _HoldToConfirmButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onConfirmed;

  const _HoldToConfirmButton({
    required this.enabled,
    required this.onConfirmed,
  });

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton> {
  static const _holdDuration = Duration(seconds: 5);

  Timer? _timer;
  double _progress = 0.0;
  bool _holding = false;
  DateTime? _holdStart;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (!widget.enabled || _holding) return;
    SfxService.tap();
    setState(() {
      _holding = true;
      _progress = 0.0;
      _holdStart = DateTime.now();
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (_holdStart == null) {
        t.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_holdStart!);
      final p = elapsed.inMilliseconds / _holdDuration.inMilliseconds;

      if (p >= 1.0) {
        t.cancel();
        setState(() {
          _progress = 1.0;
          _holding = false;
          _holdStart = null;
        });
        widget.onConfirmed();
      } else {
        setState(() => _progress = p);
      }
    });
  }

  void _cancelHold() {
    _timer?.cancel();
    if (!_holding) return;
    setState(() {
      _holding = false;
      _progress = 0.0;
      _holdStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressActive = _progress > 0.5;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: widget.enabled
                ? AppColors.accentTeal
                    .withValues(alpha: 0.15 + (_progress * 0.85))
                : AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: widget.enabled ? AppColors.accentTeal : AppColors.border,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: _progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: (_holding || progressActive)
                          ? Colors.white
                          : (widget.enabled
                              ? AppColors.accentTeal
                              : AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _holding
                          ? 'Keep holding...'
                          : (_progress >= 1.0
                              ? 'Confirmed!'
                              : 'Hold to confirm'),
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: (_holding || progressActive)
                            ? Colors.white
                            : (widget.enabled
                                ? AppColors.accentTeal
                                : AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}