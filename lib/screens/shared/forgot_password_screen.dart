import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';

/// Roles that support password reset via email.
enum ForgotPasswordRole { parent, teacher }

extension _RoleVisuals on ForgotPasswordRole {
  Color get background => this == ForgotPasswordRole.parent
      ? AppColors.parentBg
      : AppColors.teacherBg;
  String get label => this == ForgotPasswordRole.parent ? 'Parent' : 'Teacher';
}

class ForgotPasswordScreen extends StatefulWidget {
  final ForgotPasswordRole role;

  const ForgotPasswordScreen({super.key, required this.role});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim().toLowerCase();

    // Fire and forget — we always show success to avoid leaking
    // whether the email is registered.
    await authProvider.sendPasswordResetEmail(email);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.role.background,
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

              if (_sent)
                _buildConfirmation()
              else
                _buildRequestForm(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Request state ────────────────────────────────────────────────

  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            size: 56,
            color: AppColors.accentPurple,
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            'Forgot Password?',
            style: AppText.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your ${widget.role.label.toLowerCase()} email and we\'ll '
            'send you a link to reset your password.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          const FieldLabel('Email'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            validator: Validators.email,
            decoration: buildInputDecoration(
              hint: 'name@example.com',
              focusColor: AppColors.accentPurple,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSend,
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
                      'SEND RESET LINK',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirmation state ───────────────────────────────────────────

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Icon(
          Icons.mark_email_read_rounded,
          size: 72,
          color: AppColors.accentGreen,
        ),
        const SizedBox(height: AppSpacing.lg),

        const Text(
          'Check Your Email',
          style: AppText.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'If an account exists for ${_emailController.text.trim()}, '
            'you\'ll receive a password reset link in a few minutes. '
            'Be sure to check your spam folder too.',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: const Text(
              'BACK TO LOGIN',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}