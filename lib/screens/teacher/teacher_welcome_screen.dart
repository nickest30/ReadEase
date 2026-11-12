import 'package:flutter/material.dart';

import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';

class TeacherWelcomeScreen extends StatelessWidget {
  const TeacherWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final imgSize = Responsive.imageSize(context, base: 200);
    final mainButtonHeight = Responsive.buttonHeight(context) + 8;
    final backButtonHeight = Responsive.buttonHeight(context);

    return Scaffold(
      backgroundColor: AppColors.teacherBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context),
                vertical: AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),

                  Center(
                    child: Image.asset(
                      'assets/images/mascot/groo_base.png',
                      width: imgSize,
                      height: imgSize,
                      fit: BoxFit.contain,
                      cacheWidth: (imgSize * 2).toInt(),
                      errorBuilder: (_, _, _) => Container(
                        width: imgSize,
                        height: imgSize,
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentYellow,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: imgSize * 0.4,
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
                    height: mainButtonHeight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SfxService.tap();
                        Navigator.of(context).pushNamed('/teacher-login');
                      },
                      icon: const Icon(Icons.login_rounded, size: 22),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'LOGIN',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentYellow,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 4,
                        shadowColor:
                            AppColors.accentYellow.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    height: mainButtonHeight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SfxService.tap();
                        Navigator.of(context).pushNamed('/teacher-signup');
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'REGISTER',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
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
                    height: backButtonHeight,
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
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'BACK',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
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