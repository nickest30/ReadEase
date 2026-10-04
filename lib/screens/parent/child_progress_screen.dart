import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../models/word.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class ChildProgressScreen extends StatefulWidget {
  const ChildProgressScreen({super.key});

  @override
  State<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends State<ChildProgressScreen> {
  bool _loading = true;
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
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final child = args['child'] as Student;

    if (child.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final attempts = await DatabaseService.instance
          .getAllQuizAttemptsWithBatch(child.id!);
      final completed =
          await DatabaseService.instance.getCompletedLevelCount(child.id!);
      final stats = await DatabaseService.instance
          .getQuizStatsForStudent(child.id!);
      final weak = await DatabaseService.instance
          .getWeakWordsFromAttempts(child.id!);
      final badges = await DatabaseService.instance
          .getBadgesForStudent(child.id!);

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
      debugPrint('📊 ChildProgress load ERROR: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

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
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final child = args['child'] as Student;

    return Scaffold(
      backgroundColor: AppColors.parentBg,
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
                        Text(
                          '${child.displayName}\'s Progress',
                          style: AppText.h2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Grade ${child.gradeLevel}',
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
                  : _attempts.isEmpty
                      ? _buildEmpty()
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/mascot/motter_gentle.png',
              width: 140,
              height: 140,
              errorBuilder: (_, _, _) => const Icon(
                Icons.family_restroom_rounded,
                size: 80,
                color: AppColors.accentPurple,
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
              'Your child hasn\'t completed a quiz yet.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),

          // Motter presenting
          Image.asset(
            'assets/images/mascot/motter_presenting.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
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

          const SizedBox(height: AppSpacing.sm),

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
                value: '${(_accuracy * 100).toStringAsFixed(0)}%',
                color: AppColors.accentTeal,
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
                AppColors.accentPurple,
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
                          Text(theme, style: AppText.caption),
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
                          ? AppColors.textPurple
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
                        ? AppColors.accentPurple
                        : AppColors.accentCoral,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),

          if (_weakWords.isNotEmpty) ...[
            const Text('WORDS TO PRACTICE', style: AppText.caption),
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
                    color: AppColors.accentOrange.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color:
                          AppColors.accentOrange.withValues(alpha: 0.4),
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
          ],
        ],
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