import 'package:flutter/material.dart';

import '../services/sfx_service.dart';
import '../utils/app_theme.dart';

/// Pill-shaped hint button shown inside game screens.
///
/// Has three visual states:
///   - Active: yellow, tappable, shows "HINT (n)" where n is remaining count
///   - On cooldown: muted, tappable is blocked, shows "Wait..."
///   - Exhausted: muted, tappable is blocked, shows "HINT (0)"
///
/// Tapping fires the caller's [onTap] callback, which is responsible
/// for applying the hint via HintService.use().
class HintButton extends StatelessWidget {
  final int hintsRemaining;
  final bool onCooldown;
  final VoidCallback? onTap;

  const HintButton({
    super.key,
    required this.hintsRemaining,
    required this.onCooldown,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = hintsRemaining == 0 || onCooldown;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled
            ? null
            : () {
                SfxService.tap();
                onTap?.call();
              },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDisabled
                ? AppColors.border.withValues(alpha: 0.8)
                : AppColors.accentYellow,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isDisabled ? null : AppShadows.medium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: isDisabled ? AppColors.textMuted : AppColors.textYellow,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                onCooldown ? 'Wait...' : 'HINT ($hintsRemaining)',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDisabled ? AppColors.textMuted : AppColors.textYellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}