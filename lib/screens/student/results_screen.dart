import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz_result.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _saved = false;
  bool _isPassing = false;
  int _pointsEarned = 0;
  int _score = 0;
  int _totalQuestions = 0;
  int _gradeLevel = 1;
  String _difficulty = 'easy';
  int _starsEarned = 0;
  String _encouragementComment = '';

  // ─────────────────────────────────────────────────────────
  // Star-tier comments (4 per tier, randomly picked)
  // ─────────────────────────────────────────────────────────
  static const Map<int, List<String>> _commentsByStars = {
    1: [
      'Every detective starts somewhere!',
      "It's okay, let's try again together.",
      'Every missed word is a clue to learn.',
      'Not bad for a first attempt!',
    ],
    2: [
      'You\'re warming up! Keep going.',
      'Getting there, one more try!',
      'Nice effort! Let\'s do it again.',
      'Progress is progress. Try again!',
    ],
    3: [
      'So close! You\'ve got this.',
      'Almost there, one more shot!',
      'Great effort! Just a few more words.',
      'You\'re nearly a Word Detective!',
    ],
    4: [
      'Great job, detective!',
      'Excellent work! Keep it up.',
      'Well done! You\'re improving fast.',
      'Superb reading! Proud of you.',
    ],
    5: [
      'PERFECT! You\'re a word champion!',
      'Amazing! Every word was right!',
      'Incredible! Full marks, detective!',
      'Outstanding! You nailed it!',
    ],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_saved) {
      _saved = true;
      _saveResult();
    }
  }

  Future<void> _saveResult() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    _gradeLevel = args['gradeLevel'] as int;
    _difficulty = args['difficulty'] as String;
    _score = args['score'] as int;
    _totalQuestions = args['totalQuestions'] as int;

    final pointsEarned = _score * 5;
    final stars = _totalQuestions == 0
        ? 0
        : ((_score / _totalQuestions) * 5).round();

    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) return;

    final result = QuizResult(
      studentId: student.id!,
      gradeLevel: _gradeLevel,
      difficulty: _difficulty,
      score: _score,
      totalQuestions: _totalQuestions,
      pointsEarned: pointsEarned,
      completedAt: DateTime.now().toIso8601String(),
    );

    // Save to local DB
    await DatabaseService.instance.insertQuizResult(result);
    await DatabaseService.instance.addPoints(student.id!, pointsEarned);

    // Refresh student + update provider
    final updated = await DatabaseService.instance.getStudentById(student.id!);
    if (!mounted) return;
    if (updated != null) {
      context.read<StudentProvider>().updateStudent(updated);
    }

    // Sync to Firestore if we have a Firebase account
    if (student.firebaseUid != null && updated != null) {
      try {
        final allResults =
            await DatabaseService.instance.getResultsForStudent(student.id!);

        await FirestoreService.instance.syncStudentProgress(
          student.firebaseUid!,
          student.displayName,
          updated.totalPoints,
          allResults,
        );

        await FirestoreService.instance.updateLeaderboardEntry(
          student.firebaseUid!,
          student.displayName,
          updated.totalPoints,
          student.gradeLevel,
        );
      } catch (_) {
        // Offline — will sync on next successful quiz
      }
    }

    if (!mounted) return;

    // Pick a random comment for this star tier
    final comments = _commentsByStars[stars] ?? _commentsByStars[3]!;
    final pickedComment = comments[Random().nextInt(comments.length)];

    setState(() {
      _isPassing = result.isPassing;
      _pointsEarned = pointsEarned;
      _starsEarned = stars;
      _encouragementComment = pickedComment;
    });
  }

  // ─────────────────────────────────────────────────────────
  // Yse asset + fallback per star tier
  // ─────────────────────────────────────────────────────────
  String get _yseAsset {
    if (_starsEarned >= 5) return 'assets/images/mascot/yse_celebrate.png';
    if (_starsEarned >= 4) return 'assets/images/mascot/yse_salute.png';
    if (_starsEarned >= 3) return 'assets/images/mascot/yse_clapping.png';
    if (_starsEarned >= 2) return 'assets/images/mascot/yse_thumbsup.png';
    return 'assets/images/mascot/yse_apologetic.png';
  }

  IconData get _yseFallbackIcon {
    if (_starsEarned >= 5) return Icons.celebration_rounded;
    if (_starsEarned >= 4) return Icons.emoji_events_rounded;
    if (_starsEarned >= 3) return Icons.psychology_rounded;
    if (_starsEarned >= 2) return Icons.thumb_up_rounded;
    return Icons.favorite_rounded;
  }

  Color get _yseFallbackColor {
    if (_starsEarned >= 5) return AppColors.accentYellow;
    if (_starsEarned >= 4) return AppColors.accentTeal;
    if (_starsEarned >= 3) return AppColors.accentOrange;
    if (_starsEarned >= 2) return AppColors.accentOrange;
    return AppColors.accentCoral;
  }

  // ─────────────────────────────────────────────────────────
  // Badge popup
  // ─────────────────────────────────────────────────────────
  String get _badgeName {
    final diff = _difficulty.isEmpty
        ? ''
        : _difficulty[0].toUpperCase() + _difficulty.substring(1);
    if (_starsEarned >= 5) {
      return 'Perfect Score';
    }
    if (_difficulty == 'easy') return 'Easy Reader';
    if (_difficulty == 'medium') return 'Medium Master';
    if (_difficulty == 'hard') return 'Hard Hero';
    return 'Grade $_gradeLevel $diff';
  }

  String get _badgeDescription {
    if (_starsEarned >= 5) {
      return 'Perfect score in Grade $_gradeLevel ${_capitalize(_difficulty)}!';
    }
    return 'You passed Grade $_gradeLevel ${_capitalize(_difficulty)} with $_score out of $_totalQuestions.';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _showBadgeDialog() {
    final earnedAt = DateTime.now();
    final dateStr =
        '${earnedAt.day}/${earnedAt.month}/${earnedAt.year}';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: AppColors.accentYellow, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentYellow.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close X
              Align(
                alignment: Alignment.topRight,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.studentBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Badge icon (replaced by real PNG in M5)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentYellow,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: AppColors.accentYellow,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Badge name
              Text(
                _badgeName,
                textAlign: TextAlign.center,
                style: AppText.h1.copyWith(
                  color: AppColors.textYellow,
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // Badge description
              Text(
                _badgeDescription,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),

              const SizedBox(height: AppSpacing.md),

              // Divider
              Container(
                height: 1,
                color: AppColors.border,
              ),

              const SizedBox(height: AppSpacing.md),

              // Date + points
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(dateStr, style: AppText.caption),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: AppColors.accentYellow,
                      ),
                      const SizedBox(height: 4),
                      Text('$_pointsEarned pts', style: AppText.caption),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Yse — star-tiered pose
              Center(
                child: _YseImage(
                  assetPath: _yseAsset,
                  size: 180,
                  fallbackIcon: _yseFallbackIcon,
                  fallbackColor: _yseFallbackColor,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Random encouragement comment
              Text(
                _encouragementComment,
                textAlign: TextAlign.center,
                style: AppText.h2,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Score
              Text(
                '$_score / $_totalQuestions',
                textAlign: TextAlign.center,
                style: AppText.display.copyWith(
                  color: _isPassing
                      ? AppColors.textTeal
                      : AppColors.textOrange,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _starsEarned
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.accentYellow,
                      size: 36,
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Badge chip (if passing)
              if (_isPassing)
                Center(
                  child: InkWell(
                    onTap: _showBadgeDialog,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: AppColors.accentYellow,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: AppColors.accentYellow,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Badge Unlocked!',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textYellow,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(
                            Icons.touch_app_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.xl),

              // Points earned
              Center(
                child: Text(
                  '+$_pointsEarned points',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textYellow,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            '/difficulty-selection',
                            arguments: {'gradeLevel': _gradeLevel},
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentOrange,
                          side: const BorderSide(
                            color: AppColors.accentOrange,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/student-home',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
                          ),
                        ),
                        child: const Text(
                          'Back to Levels',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Yse image with tier-aware fallback
// ─────────────────────────────────────────────────────────

class _YseImage extends StatelessWidget {
  final String assetPath;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const _YseImage({
    required this.assetPath,
    required this.size,
    required this.fallbackIcon,
    required this.fallbackColor,
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
            color: fallbackColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: fallbackColor, width: 3),
          ),
          child: Center(
            child: Icon(
              fallbackIcon,
              size: size * 0.5,
              color: fallbackColor,
            ),
          ),
        );
      },
    );
  }
}