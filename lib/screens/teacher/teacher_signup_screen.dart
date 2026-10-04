import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/teacher.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';

class TeacherSignupScreen extends StatefulWidget {
  const TeacherSignupScreen({super.key});

  @override
  State<TeacherSignupScreen> createState() => _TeacherSignupScreenState();
}

class _TeacherSignupScreenState extends State<TeacherSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _schoolNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final teacherProvider = context.read<TeacherProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();

      final existing = await DatabaseService.instance
          .getTeacherByUsername(_usernameController.text.trim());
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'That username is already taken.';
          _isSubmitting = false;
        });
        return;
      }

      final firebaseUid = await authProvider.register(
        email,
        _passwordController.text,
      );
      if (!mounted) return;

      if (firebaseUid == null) {
        setState(() {
          _errorMessage =
              'Email is already registered or network failed. '
              'Try a different email.';
          _isSubmitting = false;
        });
        return;
      }

      final hashedPassword = BCrypt.hashpw(
        _passwordController.text,
        BCrypt.gensalt(),
      );

      final newTeacher = Teacher(
        username: _usernameController.text.trim(),
        passwordHash: hashedPassword,
        fullName: _fullNameController.text.trim(),
        email: email,
        schoolName: _schoolNameController.text.trim(),
        firebaseUid: firebaseUid,
        createdAt: DateTime.now().toIso8601String(),
      );

      final newId =
          await DatabaseService.instance.insertTeacher(newTeacher);
      if (!mounted) return;

      final createdTeacher =
          await DatabaseService.instance.getTeacherById(newId);
      if (!mounted || createdTeacher == null) return;

      teacherProvider.setTeacher(createdTeacher);

      // Save credentials to secure storage for silent Firebase re-auth
      await authProvider.saveCredentials(
        uid: firebaseUid,
        email: email,
        password: _passwordController.text,
      );

      try {
        await FirestoreService.instance
            .saveTeacher(createdTeacher, firebaseUid);
      } catch (_) {
        // Silent — dashboard will retry via sync on next online action
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/teacher-dashboard');
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
      backgroundColor: AppColors.teacherBg,
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

                // Header row with Groo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Account', style: AppText.h1),
                          SizedBox(height: 2),
                          Text(
                            'Set up your teacher profile',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/mascot/groo_welcoming.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color:
                              AppColors.accentYellow.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentYellow,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppColors.accentYellow,
                          size: 42,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Full Name
                const FieldLabel('Full Name'),
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.displayName,
                  decoration: buildInputDecoration(
                    hint: 'Enter your full name',
                    focusColor: AppColors.accentYellow,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Username
                const FieldLabel('Username'),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.username,
                  decoration: buildInputDecoration(
                    hint: 'Pick a username',
                    focusColor: AppColors.accentYellow,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Email
                const FieldLabel('Email'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                  decoration: buildInputDecoration(
                    hint: 'name@example.com',
                    focusColor: AppColors.accentYellow,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // School Name
                const FieldLabel('School Name'),
                TextFormField(
                  controller: _schoolNameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.schoolName,
                  decoration: buildInputDecoration(
                    hint: 'Enter your school name',
                    focusColor: AppColors.accentYellow,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Password
                const FieldLabel('Password'),
                PasswordField(
                  controller: _passwordController,
                  hintText: 'At least 6 characters',
                  textInputAction: TextInputAction.next,
                  focusColor: AppColors.accentYellow,
                  validator: (v) => Validators.password(v),
                ),

                const SizedBox(height: AppSpacing.md),

                // Confirm Password
                const FieldLabel('Confirm Password'),
                PasswordField(
                  controller: _confirmController,
                  hintText: 'Re-enter your password',
                  textInputAction: TextInputAction.done,
                  focusColor: AppColors.accentYellow,
                  validator: (v) => Validators.confirmPassword(
                    v,
                    _passwordController.text,
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
                    onPressed: _isSubmitting ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentYellow,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.textPrimary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'CREATE ACCOUNT',
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
}