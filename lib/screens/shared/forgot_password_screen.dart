import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/app_form.dart';

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
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim().toLowerCase();

    // ── Step 1: Validate email exists in the correct role collection ──
    bool exists = true; // default true — if check fails, proceed anyway
    try {
      if (widget.role == ForgotPasswordRole.parent) {
        exists = await FirestoreService.instance.parentEmailExists(email);
      } else {
        exists = await FirestoreService.instance.teacherEmailExists(email);
      }
    } catch (e) {
      debugPrint('Email existence check failed (allowing): $e');
      // Fall back to sending — the user might still have an account
      exists = true;
    }

    if (!mounted) return;

    if (!exists) {
      setState(() {
        _errorMessage =
            'No ${widget.role.label.toLowerCase()} account found with '
            'this email.\n\n'
            'Double-check the address, or sign up first.';
        _isSubmitting = false;
      });
      return;
    }

    // ── Step 2: Send reset email via Firebase ──
    try {
      await authProvider.sendPasswordResetEmail(email);
    } catch (e) {
      debugPrint('Password reset email failed: $e');
      // Firebase usually doesn't throw for security. Continue to confirmation.
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final buttonHeight = Responsive.buttonHeight(context);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          IconButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_sent)
            _buildConfirmation(buttonHeight)
          else
            _buildRequestForm(buttonHeight),
        ],
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
      backgroundColor: widget.role.background,
      body: SafeArea(child: content),
    );
  }

  Widget _buildRequestForm(double buttonHeight) {
    final isTeacher = widget.role == ForgotPasswordRole.teacher;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_reset_rounded,
            size: 56,
            color: isTeacher ? AppColors.accentTeal : AppColors.accentPurple,
          ),
          const SizedBox(height: AppSpacing.md),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Forgot Password?',
              style: AppText.h1,
              textAlign: TextAlign.center,
            ),
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
              focusColor: isTeacher
                  ? AppColors.accentTeal
                  : AppColors.accentPurple,
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
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.accentCoral, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textCoral,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      SfxService.tap();
                      _handleSend();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isTeacher
                    ? AppColors.accentYellow
                    : AppColors.accentPurple,
                foregroundColor: isTeacher
                    ? const Color(0xFF2C2C2C)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: isTeacher
                            ? const Color(0xFF2C2C2C)
                            : Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'SEND RESET LINK',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(context).pop();
            },
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

  Widget _buildConfirmation(double buttonHeight) {
    final isTeacher = widget.role == ForgotPasswordRole.teacher;

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
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Check Your Email',
            style: AppText.h1,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'We sent a password reset link to ${_emailController.text.trim()}.\n\n'
            'Click the link in your email to set a new password.\n\n'
            'After resetting, log back in with your EMAIL ADDRESS '
            'and your new password.\n\n'
            'Be sure to check your spam folder too.',
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isTeacher
                  ? AppColors.accentYellow
                  : AppColors.accentPurple,
              foregroundColor: isTeacher
                  ? const Color(0xFF2C2C2C)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'BACK TO LOGIN',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}