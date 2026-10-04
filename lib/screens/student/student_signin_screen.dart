import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';

class StudentSignInScreen extends StatefulWidget {
  const StudentSignInScreen({super.key});

  @override
  State<StudentSignInScreen> createState() => _StudentSignInScreenState();
}

class _StudentSignInScreenState extends State<StudentSignInScreen> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // ── STEP 1: Try local SQLite first ──
      Student? localStudent =
          await DatabaseService.instance.getStudentByUsername(username);

      if (localStudent != null) {
        final storedHash = localStudent.passwordHash;
        if (storedHash == null || storedHash.isEmpty) {
          if (!mounted) return;
          setState(() {
            _errorMessage =
                'This account has no password set on this device. '
                'Use your PIN or ask your parent to re-link.';
            _isSubmitting = false;
          });
          return;
        }

        final isCorrect = BCrypt.checkpw(password, storedHash);
        if (!isCorrect) {
          // ... existing wrong-password handling
        }

        if (!isCorrect) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Incorrect password.';
            _isSubmitting = false;
          });
          return;
        }

        if (localStudent.firebaseUid != null) {
          try {
            await authProvider.signIn(
              '${localStudent.username}@readease.app',
              password,
            );
          } catch (_) {
            // Offline — proceed
          }
        }

        if (!mounted) return;
        studentProvider.setStudent(localStudent);
        _navigateAfterLogin(localStudent);
        return;
      }

      // ── STEP 2: Not found locally → try cloud login ──
      debugPrint('🔑 Local miss — trying cloud for "$username"');

      final syntheticEmail = '$username@readease.app';
      final firebaseOk = await authProvider.signIn(syntheticEmail, password);

      if (!firebaseOk) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Username not found. Try again or register a new account.';
          _isSubmitting = false;
        });
        return;
      }

      final uid = authProvider.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Session error. Try again.';
          _isSubmitting = false;
        });
        return;
      }

      final cloudDoc = await FirestoreService.instance.getStudentByUid(uid);

      if (cloudDoc == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Account found but profile data is missing. Contact support.';
          _isSubmitting = false;
        });
        await authProvider.signOut();
        return;
      }

      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      final newLocalStudent = Student(
        username: username,
        passwordHash: hashedPassword,
        displayName: (cloudDoc['displayName'] ?? username) as String,
        gradeLevel: (cloudDoc['gradeLevel'] ?? 1) as int,
        totalPoints: (cloudDoc['totalPoints'] ?? 0) as int,
        firebaseUid: cloudDoc['uid'] as String,
        classFirestoreId: cloudDoc['classId'] as String?,
        className: cloudDoc['className'] as String?,
        parentId: null,
        createdAt: DateTime.now().toIso8601String(),
      );

      final newLocalId = await DatabaseService.instance
          .insertStudent(newLocalStudent);

      if (!mounted) return;

      final createdLocal =
          await DatabaseService.instance.getStudentById(newLocalId);

      if (createdLocal == null) {
        setState(() {
          _errorMessage = 'Could not save your profile. Try again.';
          _isSubmitting = false;
        });
        return;
      }

      debugPrint('🔑 Cloud login succeeded — local profile created ($newLocalId)');

      CloudSyncService.instance.downloadStudentData(
        localStudentId: createdLocal.id!,
        firebaseUid: createdLocal.firebaseUid!,
      );

      studentProvider.setStudent(createdLocal);
      _navigateAfterLogin(createdLocal);
    } catch (e) {
      debugPrint('🔑 SignIn ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  void _navigateAfterLogin(Student student) {
    if (student.pinHash == null || student.pinHash!.isEmpty) {
      Navigator.of(context).pushReplacementNamed(
        '/set-pin',
        arguments: student,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/student-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
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

                const FieldLabel('Username'),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  validator: Validators.username,
                  decoration:
                      buildInputDecoration(hint: 'Enter your username'),
                ),
                const SizedBox(height: 16),

                const FieldLabel('Password'),
                PasswordField(
                  controller: _passwordController,
                  hintText: 'Enter your password',
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please enter your password' : null,
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
      ),
    );
  }
}