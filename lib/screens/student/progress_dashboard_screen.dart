import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz_result.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  List<QuizResult> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResults());
  }

  Future<void> _loadResults() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
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

  /// Counts UNIQUE (grade, difficulty) pairs that have been passed.
  /// Fix for earlier bug — attempts don't count multiple times.
  int get _completedLevels {
    final passed = _results.where((r) => r.isPassing);
    final Set<String> unique = {};
    for (final r in passed) {
      unique.add('${r.gradeLevel}-${r.difficulty}');
    }
    return unique.length;
  }

  /// Best score per (grade, difficulty) pair.
  /// Fix for earlier bug — retakes don't show up twice.
  Map<String, QuizResult> get _bestPerLevel {
    final Map<String, QuizResult> best = {};
    for (final r in _results) {
      final key = '${r.gradeLevel}-${r.difficulty}';
      final current = best[key];
      if (current == null ||
          (r.score / r.totalQuestions) > (current.score / current.totalQuestions)) {
        best[key] = r;
      }
    }
    return best;
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
                  const Expanded(
                    child: Text('My Progress', style: AppText.h2),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/mascot/yse_thinking.png',
            width: 140,
            height: 140,
            errorBuilder: (_, _, _) => const Icon(
              Icons.insights_rounded,
              size: 80,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'No progress yet',
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Complete a quiz to see your stats!',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final best = _bestPerLevel;
    final entries = best.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary cards
          Row(
            children: [
              _StatCard(
                label: 'Levels Done',
                value: '$_completedLevels',
                color: AppColors.accentTeal,
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatCard(
                label: 'Accuracy',
                value: '${(_overallAccuracy * 100).toStringAsFixed(0)}%',
                color: AppColors.accentPurple,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

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
                AppColors.accentTeal,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$_completedLevels / 18 levels passed',
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Per-level scores
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
                          ? AppColors.textTeal
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
                        ? AppColors.accentTeal
                        : AppColors.accentCoral,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
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
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppText.caption),
          ],
        ),
      ),
    );
  }
}