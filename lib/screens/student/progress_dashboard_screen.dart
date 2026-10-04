import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/word.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/error_state.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _attempts = [];
  List<Word> _weakWords = [];
  int _completedLevels = 0;
  int _badgeCount = 0;
  double _accuracy = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in again to view your progress.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final attempts = await DatabaseService.instance
          .getAllQuizAttemptsWithBatch(student.id!);
      final completed =
          await DatabaseService.instance.getCompletedLevelCount(student.id!);
      final stats = await DatabaseService.instance
          .getQuizStatsForStudent(student.id!);
      final weak = await DatabaseService.instance
          .getWeakWordsFromAttempts(student.id!);
      final badges = await DatabaseService.instance
          .getBadgesForStudent(student.id!);

      if (!mounted) return;
      setState(() {
        _attempts = attempts;
        _completedLevels = completed;
        _accuracy = (stats['accuracy'] as double?) ?? 0.0;
        _weakWords = weak;
        _badgeCount = badges.length;
        _loading = false;
      });
    } catch (e) {
      debugPrint('📊 Progress load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We couldn\'t load your progress right now.';
      });
    }
  }

  /// Best attempt per batch (deduped).
  Map<int, Map<String, dynamic>> get _bestPerBatch {
    final Map<int, Map<String, dynamic>> best = {};
    for (final a in _attempts) {
      final batchId = a['batch_id'] as int;
      final accuracy =
          (a['score'] as int) / (a['total_questions'] as int);
      final current = best[batchId];
      if (current == null ||
          accuracy > (current['_accuracy'] as double)) {
        best[batchId] = {...a, '_accuracy': accuracy};
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
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
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
    );
  }

  // ── Body ─────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentTeal),
      );
    }

    if (_error != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ErrorState(
          title: 'Can\'t load progress',
          message: _error,
          onRetry: _loadData,
        ),
      );
    }

    if (_attempts.isEmpty) {
      return _buildEmpty();
    }

    return _buildContent();
  }

  // ── Empty state ──────────────────────────────────────────────────

  Widget _buildEmpty() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Image.asset(
            'assets/images/mascot/yse_thinking.png',
            width: 160,
            height: 160,
            errorBuilder: (_, _, _) => Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 80,
                color: AppColors.accentTeal,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'No progress yet',
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Complete a lesson and pass a quiz to see your stats here!',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/grade-selection');
              },
              icon: const Icon(Icons.school_rounded, size: 20),
              label: const Text(
                'Start Learning',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ──────────────────────────────────────────────────────

  Widget _buildContent() {
    final best = _bestPerBatch;
    final entries = best.entries.toList()
      ..sort((a, b) {
        final ga = a.value['grade_level'] as int;
        final gb = b.value['grade_level'] as int;
        if (ga != gb) return ga.compareTo(gb);
        return (a.value['difficulty'] as String)
            .compareTo(b.value['difficulty'] as String);
      });

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accentTeal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),

            // Stats
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
                  color: AppColors.accentTeal,
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatCard(
                  icon: Icons.insights_rounded,
                  label: 'Accuracy',
                  value: '${(_accuracy * 100).toStringAsFixed(0)}%',
                  color: AppColors.accentPurple,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

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
            Text('$_completedLevels / 18 levels passed',
                style: AppText.caption),

            const SizedBox(height: AppSpacing.xl),

            const Text('BEST SCORES', style: AppText.caption),
            const SizedBox(height: AppSpacing.sm),
            ...entries.map((entry) {
              final a = entry.value;
              final grade = a['grade_level'] as int;
              final difficulty = a['difficulty'] as String;
              final theme = (a['theme'] as String?) ?? '';
              final score = a['score'] as int;
              final total = a['total_questions'] as int;
              final isPassing = (score / total) >= 0.70;
              final diffLabel = difficulty[0].toUpperCase() +
                  difficulty.substring(1);

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grade $grade — $diffLabel',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (theme.isNotEmpty)
                            Text(
                              theme,
                              style: AppText.caption,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '$score/$total',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isPassing
                            ? AppColors.textTeal
                            : AppColors.textCoral,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      isPassing
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                      color: isPassing
                          ? AppColors.accentTeal
                          : AppColors.accentCoral,
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSpacing.xl),

            // Weak words
            if (_weakWords.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.fitness_center_rounded,
                    size: 18,
                    color: AppColors.accentOrange,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'WORDS TO PRACTICE',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'These words got missed. Try them again!',
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _weakWords.map((word) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppColors.accentOrange.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: AppColors.accentOrange
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      word.text,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOrange,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
            ] else ...[
              // Subtle "all clear" note when there are no weak words.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: AppColors.accentGreen.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.celebration_rounded,
                      size: 20,
                      color: AppColors.accentGreen,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'No tricky words yet — you\'re doing great!',
                        style: AppText.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
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