import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/badge.dart';
import '../../utils/app_theme.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _loaded = false;
  int _score = 0;
  int _totalQuestions = 0;
  int _pointsDelta = 0;
  int _gradeLevel = 1;
  String _difficulty = 'easy';
  bool _isNewBadge = false;
  int _starsEarned = 0;
  String _comment = '';

  static const Map<int, List<String>> _commentsByStars = {
    1: [
      'Every detective starts somewhere!',
      "It's okay — let's try again together.",
      'Every missed word is a clue to learn.',
      'Not bad for a first attempt!',
    ],
    2: [
      'You\'re warming up! Keep going.',
      'Getting there — one more try!',
      'Nice effort! Let\'s do it again.',
      'Progress is progress. Try again!',
    ],
    3: [
      'So close! You\'ve got this.',
      'Almost there — one more shot!',
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
    if (!_loaded) {
      _loaded = true;
      _loadArgs();
    }
  }

  void _loadArgs() {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    _score = args['score'] as int;
    _totalQuestions = args['totalQuestions'] as int;
    _pointsDelta = args['pointsDelta'] as int;
    _gradeLevel = args['gradeLevel'] as int;
    _difficulty = args['difficulty'] as String;
    _isNewBadge = (args['isNewBadge'] as bool?) ?? false;

    final stars = _totalQuestions == 0
        ? 0
        : ((_score / _totalQuestions) * 5).round();
    final comments = _commentsByStars[stars] ?? _commentsByStars[3]!;
    final rng = Random();
    final picked = comments[rng.nextInt(comments.length)];

    setState(() {
      _starsEarned = stars;
      _comment = picked;
    });
  }

  bool get _isPassing =>
      _totalQuestions > 0 && (_score / _totalQuestions) >= 0.70;

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

  void _showBadgeDialog() {
    final badgeName = AchievementBadge.nameFor(_gradeLevel, _difficulty);
    final imagePath =
        AchievementBadge.imagePathFor(_gradeLevel, _difficulty);

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
              SizedBox(
                width: 160,
                height: 160,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color:
                          AppColors.accentYellow.withValues(alpha: 0.15),
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
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                badgeName,
                textAlign: TextAlign.center,
                style: AppText.h1.copyWith(color: AppColors.textYellow),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Grade $_gradeLevel — ${_difficulty[0].toUpperCase()}${_difficulty.substring(1)}',
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.accentTeal,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isNewBadge ? 'Earned today!' : 'Already earned',
                    style: AppText.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.medium),
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

              // Yse — star-tiered
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Image.asset(
                    _yseAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color:
                            _yseFallbackColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _yseFallbackColor,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _yseFallbackIcon,
                          size: 90,
                          color: _yseFallbackColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Text(
                _comment,
                textAlign: TextAlign.center,
                style: AppText.h2,
              ),

              const SizedBox(height: AppSpacing.xl),

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

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _starsEarned
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.accentYellow,
                      size: 36,
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Best score chip (on non-improving retake)
              if (_pointsDelta == 0 && _score > 0) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: AppColors.accentTeal
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: AppColors.accentTeal,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Best score already counted',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

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
                        borderRadius:
                            BorderRadius.circular(AppRadius.xl),
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
                            _isNewBadge
                                ? 'NEW Badge Unlocked!'
                                : 'Badge Unlocked!',
                            style: const TextStyle(
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

              const SizedBox(height: AppSpacing.lg),

              // Points chip
              if (_pointsDelta > 0)
                Center(
                  child: Text(
                    '+$_pointsDelta points',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textYellow,
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.xl),

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
                            ModalRoute.withName('/role-selection'),
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