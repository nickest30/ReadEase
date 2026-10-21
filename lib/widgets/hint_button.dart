import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

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
        onTap: isDisabled ? null : onTap,
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