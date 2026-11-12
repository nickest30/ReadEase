import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/backup_code.dart';

/// Modal dialog that shows a one-time backup code.
/// User must confirm they've saved it before the dialog dismisses.
class BackupCodeDialog extends StatefulWidget {
  final String code;
  final Color accentColor;

  const BackupCodeDialog({
    super.key,
    required this.code,
    required this.accentColor,
  });

  /// Show the dialog and return true if the user confirmed saving.
  static Future<bool> show(
    BuildContext context, {
    required String code,
    required Color accentColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupCodeDialog(
        code: code,
        accentColor: accentColor,
      ),
    );
    return result ?? false;
  }

  @override
  State<BackupCodeDialog> createState() => _BackupCodeDialogState();
}

class _BackupCodeDialogState extends State<BackupCodeDialog> {
  bool _confirmed = false;

  /// If the passed accent is too bright (like yellow), the interactive
  /// elements become invisible on the light dialog background. Swap
  /// to teal in those cases so the icon, checkbox, and button remain
  /// readable for every role (parent, teacher, student).
  Color get _safeAccent {
    // Luminance > 0.6 means it's a light color (yellow, cream, pale orange)
    if (widget.accentColor.computeLuminance() > 0.6) {
      return AppColors.accentTeal;
    }
    return widget.accentColor;
  }

  void _copyCode() {
    SfxService.tap();
    Clipboard.setData(ClipboardData(text: widget.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Code copied to clipboard',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon badge: safe to use original accent (it's a
                // transparent background tint, so yellow reads fine here)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.key_rounded,
                    size: 32,
                    color: _safeAccent,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Save your backup code',
                  style: AppText.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'If you lose access to your phone, this code is your way '
                  'back into your account. Write it down somewhere safe. '
                  'We\'ll only show it once.',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Code display ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.studentBg,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: _safeAccent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            BackupCode.format(widget.code),
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // ── Copy icon: always dark so it's visible
                      // regardless of the accent passed in.
                      IconButton(
                        onPressed: _copyCode,
                        icon: const Icon(Icons.copy_rounded),
                        color: AppColors.textPrimary,
                        tooltip: 'Copy code',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Checkbox row ──
                InkWell(
                  onTap: () {
                    SfxService.tap();
                    setState(() => _confirmed = !_confirmed);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _confirmed,
                            onChanged: (v) {
                              SfxService.tap();
                              setState(() => _confirmed = v ?? false);
                            },
                            activeColor: _safeAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Text(
                            'I saved my backup code',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Continue button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _confirmed
                        ? () {
                            SfxService.tap();
                            Navigator.of(context).pop(true);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _safeAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
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