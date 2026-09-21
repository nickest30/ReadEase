import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class DifficultySelectionScreen extends StatefulWidget {
  const DifficultySelectionScreen({super.key});

  @override
  State<DifficultySelectionScreen> createState() =>
      _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> {
  bool _loading = true;
  bool _mediumUnlocked = false;
  bool _hardUnlocked = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _checkUnlocks();
    }
  }

  Future<void> _checkUnlocks() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final gradeLevel = args['gradeLevel'] as int;
    final student = context.read<StudentProvider>().currentStudent;

    if (student == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final passedEasy = await DatabaseService.instance
        .hasPassedDifficulty(student.id!, gradeLevel, 'easy');
    final passedMedium = await DatabaseService.instance
        .hasPassedDifficulty(student.id!, gradeLevel, 'medium');

    if (!mounted) return;
    setState(() {
      _mediumUnlocked = passedEasy;
      _hardUnlocked = passedMedium;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final gradeLevel = args['gradeLevel'] as int;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Choose Difficulty', style: AppText.h1),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Grade $gradeLevel lessons',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  const _YseImage(
                    assetPath: 'assets/images/mascot/yse_proud.png',
                    size: 90,
                    fallbackIcon: Icons.emoji_events_rounded,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _DifficultyCard(
                  emoji: '😎',
                  label: 'Easy',
                  sublabel: 'Unlocked',
                  unlocked: true,
                  color: AppColors.accentGreen,
                  onTap: () =>
                      _goToLesson(context, student, gradeLevel, 'easy'),
                ),
                const SizedBox(height: AppSpacing.md),
                _DifficultyCard(
                  emoji: '😐',
                  label: 'Medium',
                  sublabel:
                      _mediumUnlocked ? 'Unlocked' : 'Complete Easy first',
                  unlocked: _mediumUnlocked,
                  color: AppColors.accentOrange,
                  onTap: _mediumUnlocked
                      ? () => _goToLesson(context, student, gradeLevel, 'medium')
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                _DifficultyCard(
                  emoji: '😈',
                  label: 'Hard',
                  sublabel:
                      _hardUnlocked ? 'Unlocked' : 'Complete Medium first',
                  unlocked: _hardUnlocked,
                  color: AppColors.accentCoral,
                  onTap: _hardUnlocked
                      ? () => _goToLesson(context, student, gradeLevel, 'hard')
                      : null,
                ),
                const Spacer(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _goToLesson(
    BuildContext context,
    student,
    int gradeLevel,
    String difficulty,
  ) {
    Navigator.of(context).pushNamed(
      '/lesson',
      arguments: {
        'student': student,
        'gradeLevel': gradeLevel,
        'difficulty': difficulty,
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────

class _DifficultyCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final bool unlocked;
  final Color color;
  final VoidCallback? onTap;

  const _DifficultyCard({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.unlocked,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: unlocked ? color : AppColors.border,
              width: unlocked ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Emoji in colored container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),

              if (unlocked)
                Icon(Icons.chevron_right_rounded, color: color, size: 28)
              else
                const Icon(
                  Icons.lock_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
            ],
          ),
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