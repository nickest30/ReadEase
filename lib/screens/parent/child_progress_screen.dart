import 'package:flutter/material.dart';

import '../../models/quiz_result.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ChildProgressScreen extends StatefulWidget {
  const ChildProgressScreen({super.key});

  @override
  State<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends State<ChildProgressScreen> {
  List<QuizResult> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResults());
  }

  Future<void> _loadResults() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final child = args['child'] as Student;
    final results =
        await DatabaseService.instance.getResultsForStudent(child.id!);
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

  int get _badgeCount => _completedLevels;

  Map<String, QuizResult> get _bestPerLevel {
    final Map<String, QuizResult> best = {};
    for (final r in _results) {
      final key = '${r.gradeLevel}-${r.difficulty}';
      final current = best[key];
      if (current == null ||
          (r.score / r.totalQuestions) >
              (current.score / current.totalQuestions)) {
        best[key] = r;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final child = args['child'] as Student;

    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                        Text(
                          '${child.displayName}\'s Progress',
                          style: AppText.h2,
                        ),
                        Text(
                          'Grade ${child.gradeLevel}',
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

                          // Yse centered
                          Image.asset(
                            'assets/images/mascot/yse_reading.png',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: AppColors.accentPurple
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentPurple,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 80,
                                color: AppColors.accentPurple,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl),
                            child: _results.isEmpty
                                ? _buildEmptyMessage()
                                : _buildContentBody(),
                          ),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: const [
          Text(
            'No progress yet',
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Your child hasn\'t taken a quiz yet.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildContentBody() {
    final best = _bestPerLevel;
    final entries = best.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats row
        Row(
          children: [
            _StatCard(
              icon: Icons.emoji_events_rounded,
              label: 'Badges',
              value: '$_badgeCount',
              color: AppColors.accentYellow,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
              icon: Icons.verified_rounded,
              label: 'Levels',
              value: '$_completedLevels',
              color: AppColors.accentPurple,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
              icon: Icons.insights_rounded,
              label: 'Accuracy',
              value: '${(_overallAccuracy * 100).toStringAsFixed(0)}%',
              color: AppColors.accentTeal,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Overall completion
        const Text('OVERALL COMPLETION', style: AppText.caption),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: LinearProgressIndicator(
            value: _completedLevels / 18,
            minHeight: 12,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.accentPurple,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('$_completedLevels / 18 levels passed', style: AppText.caption),

        const SizedBox(height: AppSpacing.xl),

        // Best scores
        const Text('BEST SCORES', style: AppText.caption),
        const SizedBox(height: AppSpacing.sm),
        ...entries.map((entry) {
          final r = entry.value;
          final parts = entry.key.split('-');
          final grade = parts[0];
          final difficulty = parts[1];
          final capitalized = difficulty.isEmpty
              ? ''
              : difficulty[0].toUpperCase() + difficulty.substring(1);

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
                Expanded(
                  child: Text(
                    'Grade $grade — $capitalized',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${r.score}/${r.totalQuestions}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: r.isPassing
                        ? AppColors.textPurple
                        : AppColors.textCoral,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  r.isPassing
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 18,
                  color: r.isPassing
                      ? AppColors.accentPurple
                      : AppColors.accentCoral,
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: AppSpacing.xl),
      ],
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
                fontSize: 20,
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