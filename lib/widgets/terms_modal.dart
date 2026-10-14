import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Reusable Terms & Data Privacy modal — shown before account creation
/// for parent, solo student, and teacher signups.
///
/// Returns `true` if the user tapped "I Agree", `false` or `null` otherwise.
class TermsModal {
  /// Show the modal. Await the result.
  static Future<bool> show(
    BuildContext context, {
    String title = 'Terms and Data Privacy',
    String intro =
        'ReadEase keeps your data private and secure.',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.privacy_tip_rounded,
                    color: AppColors.accentTeal,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.h2.copyWith(fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Scrollable body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(intro, style: AppText.body),

                      const SizedBox(height: AppSpacing.md),
                      _section(
                        'What we collect',
                        '• Username and grade level\n'
                            '• Reading progress and scores\n'
                            '• Badges and points earned',
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      _section(
                        'Where it stays',
                        '• On this device\n'
                            '• Synced to a secure cloud server\n'
                            '  (so progress follows you across devices)',
                      ),

                      const SizedBox(height: AppSpacing.sm),
                      _section(
                        'Your consent',
                        'By tapping "I Agree", you confirm that you have '
                            'read this notice and agree to how ReadEase '
                            'stores and uses your data. If you are under '
                            '18, you confirm that a parent or guardian is '
                            'aware of and agrees to this use.',
                      ),

                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color:
                              AppColors.accentTeal.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppRadius.medium),
                        ),
                        child: const Text(
                          'ReadEase complies with the Data Privacy Act '
                          'of 2012 (Republic Act 10173).',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
                          ),
                        ),
                        child: const Text(
                          'I AGREE',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }

  static Widget _section(String heading, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(body, style: AppText.body.copyWith(fontSize: 13)),
      ],
    );
  }
}