import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class GradeSelectionScreen extends StatefulWidget {
  const GradeSelectionScreen({super.key});

  @override
  State<GradeSelectionScreen> createState() => _GradeSelectionScreenState();
}

class _GradeSelectionScreenState extends State<GradeSelectionScreen> {
  bool _loading = true;

  /// Highest grade the student is allowed to enter.
  /// Starts at their registered grade; increments by 1 for every grade
  /// where they've passed Hard (all 3 difficulties done).
  int _highestUnlocked = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeUnlocks());
  }

  Future<void> _computeUnlocks() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    int highest = student.gradeLevel;

    // Walk forward: unlock next grade if Hard passed at current grade.
    // Cap at 6.
    for (int g = student.gradeLevel; g <= 6; g++) {
      if (g > 6) break;
      final passedHard = await DatabaseService.instance
          .hasPassedDifficulty(student.id!, g, 'hard');
      if (passedHard && g + 1 <= 6) {
        highest = g + 1;
      } else {
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _highestUnlocked = highest;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/student-profile-list',
            ModalRoute.withName('/role-selection'),
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Grade Selection', style: AppText.h1),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Choose the grade to study',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  const _YseImage(
                    assetPath: 'assets/images/mascot/yse_point.png',
                    size: 90,
                    fallbackIcon: Icons.touch_app_rounded,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.3,
                        children: List.generate(6, (index) {
                          final grade = index + 1;
                          final isPrimary = grade == student.gradeLevel;
                          final isLocked = grade > _highestUnlocked;

                          return _GradeCard(
                            grade: grade,
                            isPrimary: isPrimary,
                            isLocked: isLocked,
                            onTap: () {
                              if (isLocked) {
                                _showLockedMessage(grade);
                                return;
                              }
                              Navigator.of(context).pushNamed(
                                '/difficulty-selection',
                                arguments: {'gradeLevel': grade},
                              );
                            },
                          );
                        }),
                      ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _showLockedMessage(int grade) {
    // Friendly hint — tells the learner what to do to unlock.
    final hint = grade == _highestUnlocked + 1
        ? 'Finish Grade $_highestUnlocked (Easy, Medium, and Hard) to unlock Grade $grade.'
        : 'Grade $grade is locked for now.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            hint,
            style: const TextStyle(fontFamily: 'Nunito'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textMuted,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────

class _GradeCard extends StatelessWidget {
  final int grade;
  final bool isPrimary;
  final bool isLocked;
  final VoidCallback onTap;

  const _GradeCard({
    required this.grade,
    required this.isPrimary,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final Color borderColor;
    final double borderWidth;

    if (isLocked) {
      bgColor = AppColors.border.withValues(alpha: 0.4);
      textColor = AppColors.textMuted;
      borderColor = AppColors.border;
      borderWidth = 1;
    } else if (isPrimary) {
      bgColor = AppColors.accentTeal;
      textColor = Colors.white;
      borderColor = AppColors.accentTeal;
      borderWidth = 2;
    } else {
      bgColor = AppColors.surface;
      textColor = AppColors.textPrimary;
      borderColor = AppColors.border;
      borderWidth = 1;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Stack(
          children: [
            if (isLocked)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$grade',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Grade $grade',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  if (isPrimary && !isLocked) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'YOUR GRADE',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
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