import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final student = context.read<StudentProvider>().currentStudent;
    _displayNameController =
        TextEditingController(text: student?.displayName ?? '');
    _usernameController =
        TextEditingController(text: student?.username ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final studentProvider = context.read<StudentProvider>();
    final student = studentProvider.currentStudent;
    if (student == null) return;

    // ── PIN verification BEFORE saving ──
    final pinOk = await _showPinVerifyDialog(student.pinHash ?? '');
    if (!pinOk || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final newDisplayName = _displayNameController.text.trim();
      final newUsername = _usernameController.text.trim().toLowerCase();
      final oldUsername = student.username;

      if (newUsername != oldUsername) {
        final existing = await DatabaseService.instance
            .getStudentByUsername(newUsername);
        if (existing != null && existing.id != student.id) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'That username is already taken.';
            _isSubmitting = false;
          });
          return;
        }
      }

      if (newDisplayName != student.displayName) {
        await DatabaseService.instance
            .updateStudentDisplayName(student.id!, newDisplayName);
      }

      if (newUsername != oldUsername) {
        await DatabaseService.instance
            .updateStudentUsername(student.id!, newUsername);
      }

      if (!mounted) return;

      final refreshed =
          await DatabaseService.instance.getStudentById(student.id!);
      if (!mounted || refreshed == null) return;

      studentProvider.updateStudent(refreshed);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated!',
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
        _isSubmitting = false;
      });
    }
  }

  Future<bool> _showPinVerifyDialog(String pinHash) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PinVerifyDialog(expectedHash: pinHash),
    );
    return result ?? false;
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

                const Text('Edit Profile', style: AppText.h1),
                const Text(
                  'Update your name and username',
                  style: AppText.caption,
                ),

                // Conditional parent warning banner
                if (student.isLinked) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: AppColors.accentPurple.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.family_restroom_rounded,
                          size: 20,
                          color: AppColors.accentPurple,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Your parent can see these changes.',
                            style: AppText.caption.copyWith(
                              color: AppColors.textPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.accentTeal,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _displayNameController.text.isNotEmpty
                            ? _displayNameController.text[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                _FieldLabel('Display Name'),
                TextFormField(
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration('Your name'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length < 2) return 'Too short';
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                _FieldLabel('Username'),
                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration('Your username'),
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return 'At least 3 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                      return 'Only letters, numbers, and underscores';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Grade read-only note
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Grade ${student.gradeLevel} can\'t be changed here.',
                          style: AppText.caption,
                        ),
                      ),
                    ],
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
                    onPressed: _isSubmitting ? null : _save,
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
                        : const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Yse editing mascot
                Center(
                  child: Image.asset(
                    'assets/images/mascot/yse_editing.png',
                    width: 130,
                    height: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                            color: AppColors.border, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        size: 60,
                        color: AppColors.accentTeal,
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
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
        borderSide: const BorderSide(color: AppColors.accentTeal, width: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PIN Verify Dialog
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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
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
              'Enter your PIN to save changes',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        filled ? AppColors.accentTeal : AppColors.border,
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
              onPressed: () => Navigator.of(context).pop(false),
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
            if (key.isEmpty) return const SizedBox(width: 56, height: 48);
            return Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                width: 48,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (key == '⌫') {
                      onBackspace();
                    } else {
                      onDigit(key);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.studentBg,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: const CircleBorder(),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}