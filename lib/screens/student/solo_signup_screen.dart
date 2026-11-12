import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/terms_modal.dart';
import '../../widgets/app_form.dart';
import '../../utils/student_recovery_code.dart';
import 'recovery_code_screen.dart';

class SoloSignupScreen extends StatefulWidget {
  const SoloSignupScreen({super.key});

  @override
  State<SoloSignupScreen> createState() => _SoloSignupScreenState();
}

class _SoloSignupScreenState extends State<SoloSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  int _selectedGrade = 1;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
    final studentProvider = context.read<StudentProvider>();

    try {
      final username = _usernameController.text.trim().toLowerCase();
      final password = _passwordController.text;

      final existing = await DatabaseService.instance
          .getStudentByUsername(username);
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _errorMessage = 'That username is already taken on this device.';
          _isSubmitting = false;
        });
        return;
      }

      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      final syntheticEmail = '$username@readease.app';
      final firebaseUid =
          await authProvider.register(syntheticEmail, password);
      if (!mounted) return;

      if (firebaseUid == null) {
        setState(() {
          _errorMessage =
              'That username is already taken, or you\'re offline. '
              'Try a different username, or check your internet.';
          _isSubmitting = false;
        });
        return;
      }

      await authProvider.saveCredentials(
        uid: firebaseUid,
        email: syntheticEmail,
        password: password,
      );
      if (!mounted) return;

      final newStudent = Student(
        username: username,
        passwordHash: hashedPassword,
        displayName: username,
        gradeLevel: _selectedGrade,
        firebaseUid: firebaseUid,
        createdAt: DateTime.now().toIso8601String(),
      );

      final newId = await DatabaseService.instance.insertStudent(newStudent);
      if (!mounted) return;

      final createdStudent =
          await DatabaseService.instance.getStudentById(newId);
      if (!mounted || createdStudent == null) return;

      unawaited(() async {
        try {
          await FirestoreService.instance.saveStudent(
            firebaseUid,
            createdStudent.displayName,
            createdStudent.gradeLevel,
          );
        } catch (e) {
          debugPrint('Initial profile cloud sync failed: $e');
        }
      }());

      studentProvider.setStudent(createdStudent);

      String? recoveryCode;
      try {
        recoveryCode = StudentRecoveryCode.generate();
        final normalized = StudentRecoveryCode.normalize(recoveryCode);
        final hashed = BCrypt.hashpw(normalized, BCrypt.gensalt());
        await DatabaseService.instance.updateStudentRecoveryCodeHash(
          createdStudent.id!,
          hashed,
        );
      } catch (e) {
        debugPrint('Recovery code setup failed: $e');
        recoveryCode = null;
      }

      if (!mounted) return;

      if (recoveryCode != null) {
        await RecoveryCodeScreen.show(context, code: recoveryCode);
        if (!mounted) return;
      }

      Navigator.of(context).pushReplacementNamed(
        '/set-pin',
        arguments: createdStudent,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 80);

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
            const SizedBox(height: AppSpacing.sm),
            IconButton(
              onPressed: () {
                SfxService.tap();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.textPrimary),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Account', style: AppText.h1),
                      SizedBox(height: 2),
                      Text(
                        'Fill in your details below',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/images/mascot/yse_base.png',
                  width: imgSize,
                  height: imgSize,
                  cacheWidth: (imgSize * 2).toInt(),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: imgSize,
                    height: imgSize,
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentTeal,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.accentTeal,
                      size: imgSize * 0.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const FieldLabel('Username'),
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              validator: Validators.username,
              decoration: buildInputDecoration(hint: 'Pick a username'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldLabel('Grade Level'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: List.generate(6, (index) {
                final grade = index + 1;
                final isSelected = _selectedGrade == grade;
                return Material(
                  color: isSelected
                      ? AppColors.accentTeal
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: InkWell(
                    onTap: () {
                      SfxService.tap();
                      setState(() => _selectedGrade = grade);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppRadius.medium),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentTeal
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Grade $grade',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldLabel('Password'),
            PasswordField(
              controller: _passwordController,
              hintText: 'Enter your password',
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.password(v),
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
            const SizedBox(height: AppSpacing.lg),
            const FieldLabel('Confirm Password'),
            PasswordField(
              controller: _confirmController,
              hintText: 'Re-enter your password',
              textInputAction: TextInputAction.done,
              validator: (v) => Validators.confirmPassword(
                v,
                _passwordController.text,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentCoral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: AppColors.accentCoral.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.accentCoral,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.textCoral,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
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
                          'SIGN UP',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: Responsive.buttonHeight(context),
              child: OutlinedButton(
                onPressed: () {
                  SfxService.tap();
                  Navigator.of(context).pop();
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
                    'BACK',
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
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: content),
    );
  }
}