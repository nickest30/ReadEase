import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:provider/provider.dart';

import '../../models/parent.dart';
import '../../services/database_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../utils/app_theme.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
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

  Future<void> _handleLogin() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final parent = await DatabaseService.instance
          .getParentByUsername(_usernameController.text.trim());

      if (!mounted) return;

      if (parent == null) {
        setState(() {
          _errorMessage = 'Username not found.';
          _isSubmitting = false;
        });
        return;
      }

      final isCorrect =
          BCrypt.checkpw(_passwordController.text, parent.passwordHash);

      if (!mounted) return;

      if (!isCorrect) {
        setState(() {
          _errorMessage = 'Incorrect password.';
          _isSubmitting = false;
        });
        return;
      }

      final firebaseOk = await authProvider.signIn(
        parent.email,
        _passwordController.text,
      );

      if (!mounted) return;

      Parent finalParent = parent;
      if (firebaseOk && parent.firebaseUid == null) {
        final uid = authProvider.uid;
        if (uid != null) {
          final updated = await DatabaseService.instance
              .updateParentFirebaseUid(parent.id!, uid);
          if (updated) {
            final refreshed =
                await DatabaseService.instance.getParentById(parent.id!);
            if (refreshed != null) finalParent = refreshed;
          }
        }
      }

      if (!mounted) return;

      parentProvider.setParent(finalParent);

      if (!firebaseOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signed in offline. Cloud features will sync later.',
              style: TextStyle(fontFamily: 'Nunito'),
            ),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      Navigator.of(context).pushReplacementNamed('/parent-dashboard');
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
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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

              // Header — text only (no Motter)
              const Text('Welcome Back!', style: AppText.h1),
              const SizedBox(height: 2),
              const Text('Sign in to continue', style: AppText.caption),

              const SizedBox(height: AppSpacing.xl),

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

              const SizedBox(height: AppSpacing.lg),

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

              // LOGIN button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPurple,
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
                          'LOGIN',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              Center(
                child: Image.asset(
                  'assets/images/mascot/motter_waving.png',
                  width: 320,
                  height: 320,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      color:
                          AppColors.accentPurple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentPurple,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: AppColors.accentPurple,
                      size: 64,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
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
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppColors.accentPurple, width: 2),
      ),
    );
  }
}