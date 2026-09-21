import 'package:flutter/material.dart';

import '../../models/class_group.dart';
import '../../models/quiz_result.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ClassAnalyticsScreen extends StatefulWidget {
  const ClassAnalyticsScreen({super.key});

  @override
  State<ClassAnalyticsScreen> createState() => _ClassAnalyticsScreenState();
}

class _ClassAnalyticsScreenState extends State<ClassAnalyticsScreen> {
  List<QuizResult> _allResults = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  Future<void> _loadAnalytics() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final students = args['students'] as List<Student>;

    final List<QuizResult> allResults = [];
    for (final student in students) {
      final results = await DatabaseService.instance
          .getResultsForStudent(student.id!);
      allResults.addAll(results);
    }

    if (!mounted) return;
    setState(() {
      _allResults = allResults;
      _loading = false;
    });
  }

  double get _avgScore {
    if (_allResults.isEmpty) return 0;
    final total = _allResults.fold(
        0.0, (sum, r) => sum + (r.score / r.totalQuestions));
    return total / _allResults.length;
  }

  int get _uniquePassingStudents {
    final Set<int> unique = {};
    for (final r in _allResults) {
      if (r.isPassing) unique.add(r.studentId);
    }
    return unique.length;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final classGroup = args['classGroup'] as ClassGroup;
    final students = args['students'] as List<Student>;

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
                        const Text('Analytics', style: AppText.h2),
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.sm),

                          // Groo analytics centered
                          Image.asset(
                            'assets/images/mascot/groo_analytics.png',
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
                                Icons.bar_chart_rounded,
                                size: 72,
                                color: AppColors.accentYellow,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _StatCard(
                                      icon: Icons.people_alt_rounded,
                                      label: 'Students',
                                      value: '${students.length}',
                                      color: AppColors.accentYellow,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    _StatCard(
                                      icon: Icons.insights_rounded,
                                      label: 'Avg Score',
                                      value:
                                          '${(_avgScore * 100).toStringAsFixed(0)}%',
                                      color: AppColors.accentTeal,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    _StatCard(
                                      icon: Icons.verified_rounded,
                                      label: 'Passing',
                                      value: '$_uniquePassingStudents',
                                      color: AppColors.accentPurple,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                if (_allResults.isEmpty)
                                  Container(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.xl),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.large),
                                      border: Border.all(
                                          color: AppColors.border),
                                    ),
                                    child: const Text(
                                      'No quiz results yet.\nStudents need to complete quizzes first.',
                                      textAlign: TextAlign.center,
                                      style: AppText.caption,
                                    ),
                                  )
                                else ...[
                                  const Text(
                                    'PER STUDENT SUMMARY',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  ...students.map((student) {
                                    final sr = _allResults
                                        .where((r) =>
                                            r.studentId == student.id)
                                        .toList();
                                    final passingCount = sr
                                        .where((r) => r.isPassing)
                                        .length;
                                    return Container(
                                      margin: const EdgeInsets.only(
                                          bottom: AppSpacing.sm),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.medium),
                                        border: Border.all(
                                            color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              student.displayName,
                                              style: const TextStyle(
                                                fontFamily: 'Nunito',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color:
                                                    AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$passingCount passed · ${student.totalPoints} pts',
                                            style: AppText.caption,
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: AppText.caption),
          ],
        ),
      ),
    );
  }
}