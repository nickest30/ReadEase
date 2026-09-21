import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class BadgeCollectionScreen extends StatefulWidget {
  const BadgeCollectionScreen({super.key});

  @override
  State<BadgeCollectionScreen> createState() => _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen> {
  Set<String> _earnedBadges = {};
  bool _loading = true;

  // All possible badges (6 grades × 3 difficulties = 18)
  static const List<String> _allDifficulties = ['easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEarned());
  }

  Future<void> _loadEarned() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final results =
        await DatabaseService.instance.getResultsForStudent(student.id!);

    // A badge is earned when a (grade, difficulty) pair has been passed
    final Set<String> earned = {};
    for (final r in results) {
      if (r.isPassing) {
        earned.add('${r.gradeLevel}-${r.difficulty}');
      }
    }

    if (!mounted) return;
    setState(() {
      _earnedBadges = earned;
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
            (route) => false,
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
        child: Column(
          children: [
            // Header with count
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Badges', style: AppText.h2),
                        Text(
                          '${_earnedBadges.length} of 18 unlocked',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.sm),

                          Image.asset(
                            'assets/images/mascot/yse_gold_book.png',
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
                                Icons.menu_book_rounded,
                                size: 80,
                                color: AppColors.accentYellow,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                            child: _earnedBadges.isEmpty
                                ? _buildEmptyMessage()
                                : _buildGrid(),
                          ),

                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMessage() {
    return Column(
      children: [
        const Text(
          'No badges yet',
          style: AppText.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Pass a quiz with 70% or higher\nto earn your first badge!',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        const Text(
          'PREVIEW — WHAT YOU CAN EARN',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildGrid(),
      ],
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: 18,
      itemBuilder: (context, index) {
        final grade = (index ~/ 3) + 1;
        final difficulty = _allDifficulties[index % 3];
        final key = '$grade-$difficulty';
        final earned = _earnedBadges.contains(key);
        return _BadgeTile(
          grade: grade,
          difficulty: difficulty,
          earned: earned,
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final int grade;
  final String difficulty;
  final bool earned;

  const _BadgeTile({
    required this.grade,
    required this.difficulty,
    required this.earned,
  });

  Color get _badgeColor {
    switch (difficulty) {
      case 'easy':
        return AppColors.accentGreen;
      case 'medium':
        return AppColors.accentOrange;
      case 'hard':
        return AppColors.accentCoral;
      default:
        return AppColors.accentTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        difficulty.isEmpty ? '' : '${difficulty[0].toUpperCase()}${difficulty.substring(1)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: earned ? AppColors.surface : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: earned ? _badgeColor : AppColors.border,
          width: earned ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: earned
                  ? _badgeColor.withValues(alpha: 0.2)
                  : AppColors.border.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: earned
                  ? Icon(
                      Icons.emoji_events_rounded,
                      color: _badgeColor,
                      size: 26,
                    )
                  : const Icon(
                      Icons.lock_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'G$grade',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: earned ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: earned ? _badgeColor : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}