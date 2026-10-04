import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Reusable error card with optional retry button.
/// Use for: network failures, Firestore errors, sync issues.
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.accentCoral.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppColors.accentCoral,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.h2,
          ),

          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(fontSize: 13),
              ),
            ),
          ],

          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentCoral,
                  side: const BorderSide(
                    color: AppColors.accentCoral,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}