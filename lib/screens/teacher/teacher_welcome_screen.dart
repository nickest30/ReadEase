import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class TeacherWelcomeScreen extends StatelessWidget {
  const TeacherWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teacherBg,
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

              // Groo — centered, 200px
              Center(
                child: Image.asset(
                  'assets/images/mascot/groo_base.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.accentYellow.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentYellow,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 80,
                      color: AppColors.accentYellow,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              const Text(
                'Teacher Portal',
                textAlign: TextAlign.center,
                style: AppText.h1,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Monitor your class\'s reading progress',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/teacher-login');
                  },
                  icon: const Icon(Icons.login_rounded, size: 22),
                  label: const Text(
                    'LOGIN',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentYellow,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 4,
                    shadowColor: AppColors.accentYellow.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/teacher-signup');
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
                  label: const Text(
                    'REGISTER',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.accentTeal.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                  child: const Text(
                    'BACK',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}