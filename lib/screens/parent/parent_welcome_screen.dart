import 'package:flutter/material.dart';

import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';

class ParentWelcomeScreen extends StatelessWidget {
  const ParentWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),

                  Center(
                    child: Image.asset(
                      'assets/images/mascot/motter_base.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      cacheWidth: 400,
                      errorBuilder: (_, _, _) => Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentPurple,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          size: 80,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  const Text(
                    'Parent Portal',
                    textAlign: TextAlign.center,
                    style: AppText.h1,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Monitor your child\'s reading journey',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  SizedBox(
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SfxService.tap();
                        Navigator.of(context).pushNamed('/parent-login');
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
                        backgroundColor: AppColors.accentPurple,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor:
                            AppColors.accentPurple.withValues(alpha: 0.4),
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
                        SfxService.tap();
                        Navigator.of(context).pushNamed('/parent-signup');
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
                        shadowColor:
                            AppColors.accentTeal.withValues(alpha: 0.4),
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
                      onPressed: () {
                        SfxService.tap();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.border),
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
        ),
      ),
    );
  }
}