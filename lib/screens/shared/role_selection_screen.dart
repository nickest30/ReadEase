import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Exit ReadEase?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Are you sure you want to close the app?',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: Scaffold(
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

                const Center(
                  child: _YseImage(
                    assetPath: 'assets/images/mascot/yse_base.png',
                    size: 160,
                    fallbackIcon: Icons.auto_stories_rounded,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

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

                _RoleButton(
                  label: 'LEARNER',
                  icon: Icons.school_rounded,
                  color: AppColors.accentTeal,
                  onTap: () {
                    Navigator.of(context).pushNamed('/student-profile-list');
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                _RoleButton(
                  label: 'PARENT',
                  icon: Icons.family_restroom_rounded,
                  color: AppColors.accentPurple,
                  onTap: () {
                    Navigator.of(context).pushNamed('/parent-welcome');
                  },
                ),

                const SizedBox(height: AppSpacing.md),

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
      ),
    );
  }
}

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