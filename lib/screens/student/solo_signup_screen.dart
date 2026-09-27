import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';

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
    if (!_formKey.currentState!.validate()) return;

    // ── Capture providers BEFORE any await ──
    final authProvider = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // 1. Check local uniqueness
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

      // 2. Hash password locally for offline login
      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      // 3. Register with Firebase Auth using synthetic email
      final syntheticEmail = '$username@readease.app';
      final firebaseUid = await authProvider.register(
        syntheticEmail,
        password,
      );

      if (!mounted) return;

      // 4. If Firebase registration failed, show friendly message
      if (firebaseUid == null) {
        setState(() {
          _errorMessage =
              'That username is already taken, or you\'re offline. '
              'Try a different username, or check your internet.';
          _isSubmitting = false;
        });
        return;
      }

      // Save credentials to secure storage
      await authProvider.saveCredentials(
        uid: firebaseUid,
        email: syntheticEmail,
        password: password,
      );

      if (!mounted) return;

      // 6. Create local Student record
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

      // 7. Sync student profile to Firestore
      //    Creates students/{firebaseUid} so teachers can see enrollments.
      await FirestoreService.instance.saveStudent(
        firebaseUid,
        createdStudent.displayName,
        createdStudent.gradeLevel,
      );

      if (!mounted) return;

      // 8. Store in session
      studentProvider.setStudent(createdStudent);

      // 9. Go to PIN setup
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
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),

                // Back button
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Header with Yse
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
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color:
                              AppColors.accentTeal.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentTeal,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: AppColors.accentTeal,
                          size: 36,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Username
                _FieldLabel('Username'),
                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration('Pick a username'),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                      return 'Only letters, numbers, and underscores';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Grade Level
                _FieldLabel('Grade Level'),
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
                    return GestureDetector(
                      onTap: () => setState(() => _selectedGrade = grade),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentTeal
                              : AppColors.surface,
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
                    );
                  }),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Password
                _FieldLabel('Password'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration('At least 6 characters'),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Confirm Password
                _FieldLabel('Confirm Password'),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: _inputDecoration('Re-enter your password'),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
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

                // Sign Up button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSignup,
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

                const SizedBox(height: AppSpacing.md),

                // Back button
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: BorderSide(color: AppColors.border),
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
// Private widgets
// ─────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
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