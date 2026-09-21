import 'package:flutter/material.dart';

import '../../models/class_group.dart';
import '../../models/student.dart';
import '../../utils/app_theme.dart';

class ClassLeaderboardScreen extends StatelessWidget {
  const ClassLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final classGroup = args['classGroup'] as ClassGroup;
    final students = List<Student>.from(args['students'] as List)
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return Scaffold(
      backgroundColor: AppColors.teacherBg,
      body: SafeArea(
        child: Column(
          children: [
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
                        const Text('Leaderboard', style: AppText.h2),
                        const SizedBox(height: 2),
                        Text(
                          classGroup.className,
                          style: AppText.caption,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    Image.asset(
                      'assets/images/mascot/groo_victory.png',
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentYellow,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          size: 72,
                          color: AppColors.accentYellow,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl),
                      child: students.isEmpty
                          ? Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.xl),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                    AppRadius.large),
                                border:
                                    Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'No students enrolled yet.',
                                textAlign: TextAlign.center,
                                style: AppText.caption,
                              ),
                            )
                          : Column(
                              children: students.asMap().entries.map((e) {
                                return _RankRow(
                                  rank: e.key + 1,
                                  student: e.value,
                                );
                              }).toList(),
                            ),
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
}

class _RankRow extends StatelessWidget {
  final int rank;
  final Student student;

  const _RankRow({required this.rank, required this.student});

  Color get _rankColor {
    if (rank == 1) return AppColors.accentYellow;
    if (rank == 2) return const Color(0xFF9E9E9E);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final initial = student.displayName.isNotEmpty
        ? student.displayName[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _rankColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.accentYellow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Grade ${student.gradeLevel}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text(
            '${student.totalPoints} pts',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textYellow,
            ),
          ),
        ],
      ),
    );
  }
}