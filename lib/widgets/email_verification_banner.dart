import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';

/// Banner shown on parent/teacher dashboards when email isn't verified.
/// Provides a "Resend" button that re-sends the Firebase verification email.
class EmailVerificationBanner extends StatefulWidget {
  final Color accentColor;
  final String role; // 'parent' | 'teacher'

  const EmailVerificationBanner({
    super.key,
    required this.accentColor,
    required this.role,
  });

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  bool _sending = false;

  Future<void> _sendVerification() async {
    if (_sending) return;
    setState(() => _sending = true);

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.sendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent. Check your inbox.',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('📧 resend failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send email. Try again later.',
            style: TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: AppColors.accentYellow.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_rounded,
            color: AppColors.textYellow,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify your email',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textYellow,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Confirm your email to keep your account secure.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _sending ? null : _sendVerification,
            style: TextButton.styleFrom(
              foregroundColor: widget.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textYellow,
                    ),
                  )
                : const Text(
                    'Resend',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}