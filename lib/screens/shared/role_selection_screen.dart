import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.introBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Yse mascot — standing with book
              const Center(
                child: _YseImage(
                  assetPath: 'assets/images/mascot/yse_base.png',
                  size: 160,
                  fallbackIcon: Icons.auto_stories_rounded,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Welcome text
              const Text(
                'Welcome to\nReadEase!',
                textAlign: TextAlign.center,
                style: AppText.h1,
              ),
              const SizedBox(height: AppSpacing.md),

              const Text(
                'A reading companion that helps kids\nlearn words, earn badges, and\nbuild confidence.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // LEARNER button
              _RoleButton(
                label: 'LEARNER',
                icon: Icons.school_rounded,
                color: AppColors.accentTeal,
                onTap: () {
                  Navigator.of(context).pushNamed('/student-profile-list');
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // PARENT button
              _RoleButton(
                label: 'PARENT',
                icon: Icons.family_restroom_rounded,
                color: AppColors.accentPurple,
                onTap: () {
                  Navigator.of(context).pushNamed('/parent-welcome');
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // TEACHER button
              _RoleButton(
                label: 'TEACHER',
                icon: Icons.co_present_rounded,
                color: AppColors.accentYellow,
                textColor: AppColors.textPrimary,
                onTap: () {
                  Navigator.of(context).pushNamed('/teacher-welcome');
                },
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Reusable widgets (private to this file)
// ─────────────────────────────────────────────────────────

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = textColor ?? Colors.white;

    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: fgColor,
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YseImage extends StatelessWidget {
  final String assetPath;
  final double size;
  final IconData fallbackIcon;

  const _YseImage({
    required this.assetPath,
    required this.size,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Center(
            child: Icon(
              fallbackIcon,
              size: size * 0.5,
              color: AppColors.accentTeal,
            ),
          ),
        );
      },
    );
  }
}