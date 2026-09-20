import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';

class StudentSignInScreen extends StatefulWidget {
  const StudentSignInScreen({super.key});

  @override
  State<StudentSignInScreen> createState() => _StudentSignInScreenState();
}

class _StudentSignInScreenState extends State<StudentSignInScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    // ── Capture providers BEFORE any await ──
    final authProvider = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim().toLowerCase();

      final student =
          await DatabaseService.instance.getStudentByUsername(username);

      if (!mounted) return;

      if (student == null) {
        setState(() {
          _errorMessage = 'Username not found on this device.';
          _isSubmitting = false;
        });
        return;
      }

      final isCorrect = BCrypt.checkpw(
        _passwordController.text,
        student.passwordHash,
      );

      if (!mounted) return;

      if (!isCorrect) {
        setState(() {
          _errorMessage = 'Incorrect password.';
          _isSubmitting = false;
        });
        return;
      }

      // ── Firebase sign-in ──
      final syntheticEmail = '$username@readease.app';
      final firebaseOk = await authProvider.signIn(
        syntheticEmail,
        _passwordController.text,
      );

      if (!mounted) return;

      // Backfill firebase_uid if missing
      Student finalStudent = student;
      if (firebaseOk && student.firebaseUid == null) {
        final uid = authProvider.uid;
        if (uid != null) {
          final updated = await DatabaseService.instance
              .updateStudentFirebaseUid(student.id!, uid);
          if (updated) {
            final refreshed = await DatabaseService.instance
                .getStudentById(student.id!);
            if (refreshed != null) {
              finalStudent = refreshed;
            }
          }
        }
      }

      if (!mounted) return;

      studentProvider.setStudent(finalStudent);

      if (!firebaseOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signed in offline. Cloud features will sync later.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/set-pin',
        arguments: finalStudent,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              const Text('Sign In', style: AppText.h1),
              const Text(
                'Log in with your credentials',
                style: AppText.caption,
              ),
              const SizedBox(height: 28),

              const Text(
                'Username',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _usernameController,
                decoration: _inputDecoration('Enter your username'),
              ),
              const SizedBox(height: 16),

              const Text(
                'Password',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration('Enter your password'),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.textCoral,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                          'LOGIN',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentTeal, width: 2),
      ),
    );
  }
}