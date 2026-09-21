import 'package:flutter/material.dart';

import '../../models/quiz_result.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class TeacherStudentProgressScreen extends StatefulWidget {
  const TeacherStudentProgressScreen({super.key});

  @override
  State<TeacherStudentProgressScreen> createState() =>
      _TeacherStudentProgressScreenState();
}

class _TeacherStudentProgressScreenState
    extends State<TeacherStudentProgressScreen> {
  List<QuizResult> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResults());
  }

  Future<void> _loadResults() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final student = args['student'] as Student;
    final results =
        await DatabaseService.instance.getResultsForStudent(student.id!);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  double get _overallAccuracy {
    if (_results.isEmpty) return 0;
    final total = _results.fold(0, (sum, r) => sum + r.totalQuestions);
    final correct = _results.fold(0, (sum, r) => sum + r.score);
    return total == 0 ? 0 : correct / total;
  }

  int get _completedLevels {
    final passed = _results.where((r) => r.isPassing);
    final Set<String> unique = {};
    for (final r in passed) {
      unique.add('${r.gradeLevel}-${r.difficulty}');
    }
    return unique.length;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final student = args['student'] as Student;

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
                        Text(student.displayName, style: AppText.h2),
                        Text('Grade ${student.gradeLevel}',
                            style: AppText.caption),
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
                            'assets/images/mascot/groo_reading.png',
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
                                Icons.menu_book_rounded,
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
                                      icon: Icons.verified_rounded,
                                      label: 'Levels',
                                      value: '$_completedLevels',
                                      color: AppColors.accentYellow,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    _StatCard(
                                      icon: Icons.star_rounded,
                                      label: 'Points',
                                      value: '${student.totalPoints}',
                                      color: AppColors.accentTeal,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    _StatCard(
                                      icon: Icons.insights_rounded,
                                      label: 'Accuracy',
                                      value:
                                          '${(_overallAccuracy * 100).toStringAsFixed(0)}%',
                                      color: AppColors.accentPurple,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                if (_results.isEmpty)
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
                                      'This student hasn\'t taken any quizzes yet.',
                                      textAlign: TextAlign.center,
                                      style: AppText.caption,
                                    ),
                                  )
                                else ...[
                                  const Text(
                                    'QUIZ HISTORY',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  ..._results.map((r) {
                                    final diff = r.difficulty.isEmpty
                                        ? ''
                                        : r.difficulty[0].toUpperCase() +
                                            r.difficulty.substring(1);
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
                                              'Grade ${r.gradeLevel} — $diff',
                                              style: const TextStyle(
                                                fontFamily: 'Nunito',
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color:
                                                    AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${r.score}/${r.totalQuestions}',
                                            style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: r.isPassing
                                                  ? AppColors.textTeal
                                                  : AppColors.textCoral,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            r.isPassing
                                                ? Icons.check_circle_rounded
                                                : Icons.cancel_rounded,
                                            size: 16,
                                            color: r.isPassing
                                                ? AppColors.accentTeal
                                                : AppColors.accentCoral,
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