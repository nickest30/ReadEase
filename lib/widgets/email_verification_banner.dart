import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';

/// Banner shown on parent/teacher dashboards when email isn't verified.
/// Provides a "Resend" button with a 3-minute cooldown between sends.
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
  static const int _cooldownSeconds = 180; // 3 minutes

  bool _sending = false;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownRemaining = _cooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) {
          _cooldownRemaining = 0;
          t.cancel();
        }
      });
    });
  }

  String _formatCooldown() {
    final m = _cooldownRemaining ~/ 60;
    final s = _cooldownRemaining % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  Future<void> _sendVerification() async {
    if (_sending || _cooldownRemaining > 0) return;
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
      _startCooldown();
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
    final onCooldown = _cooldownRemaining > 0;
    final buttonEnabled = !_sending && !onCooldown;

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
            onPressed: buttonEnabled ? _sendVerification : null,
            style: TextButton.styleFrom(
              foregroundColor:
                  buttonEnabled ? widget.accentColor : AppColors.textMuted,
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
                : Text(
                    onCooldown
                        ? _formatCooldown()
                        : 'Resend',
                    style: const TextStyle(
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