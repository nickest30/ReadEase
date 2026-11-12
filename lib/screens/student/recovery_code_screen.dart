import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/hold_to_confirm_button.dart';

/// Mandatory gate shown right after solo signup.
/// Displays the freshly-generated recovery code and blocks navigation
/// until the student confirms they've saved it via hold-to-confirm.
class RecoveryCodeScreen extends StatefulWidget {
  final String code;

  const RecoveryCodeScreen({super.key, required this.code});

  static Future<bool> show(
    BuildContext context, {
    required String code,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecoveryCodeScreen(code: code),
      ),
    );
    return result ?? false;
  }

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  bool _understood = false;

  void _copyCode() {
    SfxService.tap();
    Clipboard.setData(ClipboardData(text: widget.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Recovery code copied',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onHoldComplete() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.studentBg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.horizontalPadding(context),
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Mascot ──
                      Center(
                        child: Image.asset(
                          'assets/images/mascot/yse_um_actually.png',
                          width: Responsive.imageSize(context, base: 140),
                          height: Responsive.imageSize(context, base: 140),
                          fit: BoxFit.contain,
                          cacheWidth: (Responsive.imageSize(context, base: 140) * 2).toInt(),
                          errorBuilder: (_, _, _) => Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.accentTeal.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accentTeal,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.key_rounded,
                              size: 60,
                              color: AppColors.accentTeal,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Save Your Recovery Code',
                          style: AppText.h1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'This code lets you get back into your account if '
                        'you ever forget your password.',
                        style: AppText.caption,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── Code display ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                            color: AppColors.accentTeal,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentTeal
                                  .withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'YOUR RECOVERY CODE',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.code,
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                IconButton(
                                  onPressed: _copyCode,
                                  icon: const Icon(Icons.copy_rounded),
                                  color: AppColors.accentTeal,
                                  tooltip: 'Copy code',
                                  iconSize: 28,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── Where to store it ──
                      const Text(
                        'WAYS TO STORE IT',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _StorageTip(
                        icon: Icons.menu_book_rounded,
                        text: 'Write it in a notebook or diary',
                      ),
                      const _StorageTip(
                        icon: Icons.screenshot_rounded,
                        text: 'Take a screenshot and save it',
                      ),
                      const _StorageTip(
                        icon: Icons.family_restroom_rounded,
                        text: 'Share it with a parent or guardian',
                      ),
                      const _StorageTip(
                        icon: Icons.lock_rounded,
                        text: 'Keep it somewhere private and safe',
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── Warning callout ──
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.accentCoral.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color: AppColors.accentCoral
                                .withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.accentCoral,
                              size: 22,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(
                              child: Text(
                                'We won\'t show this code again. '
                                'Without it, you can\'t recover your account.',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textCoral,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Fixed footer: checkbox + hold button ──
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.horizontalPadding(context),
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.studentBg,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Checkbox row
                    InkWell(
                      onTap: () {
                        SfxService.tap();
                        setState(() => _understood = !_understood);
                      },
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _understood,
                                onChanged: (v) {
                                  SfxService.tap();
                                  setState(
                                      () => _understood = v ?? false);
                                },
                                activeColor: AppColors.accentTeal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(
                              child: Text(
                                'I understand this is my only way to recover my account',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Hold-to-confirm button
                    HoldToConfirmButton(
                      label: 'PRESS AND HOLD TO CONTINUE',
                      holdingLabel: 'Keep holding…',
                      confirmedLabel: 'Ready!',
                      holdDuration: const Duration(seconds: 5),
                      enabled: _understood,
                      color: AppColors.accentTeal,
                      icon: Icons.lock_clock_rounded,
                      onConfirmed: _onHoldComplete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageTip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StorageTip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.accentTeal),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}