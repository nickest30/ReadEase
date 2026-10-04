import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/error_state.dart';

class BadgeCollectionScreen extends StatefulWidget {
  const BadgeCollectionScreen({super.key});

  @override
  State<BadgeCollectionScreen> createState() => _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen> {
  Map<String, AchievementBadge> _earnedBadges = {};
  bool _loading = true;
  String? _error;

  static const _difficulties = ['easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBadges());
  }

  Future<void> _loadBadges() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in again to view your badges.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final badges = await DatabaseService.instance
          .getBadgesForStudent(student.id!);

      if (!mounted) return;
      setState(() {
        _earnedBadges = {for (final b in badges) b.key: b};
        _loading = false;
      });
    } catch (e) {
      debugPrint('🏅 Load badges failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We couldn\'t load your badges right now.';
      });
    }
  }

  int get _totalEarned => _earnedBadges.length;

  void _showBadgeDetail({
    required int gradeLevel,
    required String difficulty,
    required AchievementBadge? earned,
  }) {
    // ... unchanged, keep as-is ...
    final badgeName = AchievementBadge.nameFor(gradeLevel, difficulty);
    final imagePath =
        AchievementBadge.imagePathFor(gradeLevel, difficulty);
    final diffLabel = difficulty[0].toUpperCase() + difficulty.substring(1);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: earned != null
                  ? AppColors.accentYellow
                  : AppColors.border,
              width: 3,
            ),
            boxShadow: earned != null
                ? [
                    BoxShadow(
                      color:
                          AppColors.accentYellow.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ]
                : null,
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
                    decoration: const BoxDecoration(
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
                width: 180,
                height: 180,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  color: earned == null
                      ? Colors.grey.withValues(alpha: 0.4)
                      : null,
                  colorBlendMode:
                      earned == null ? BlendMode.saturation : null,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.emoji_events_rounded,
                    size: 120,
                    color: earned == null
                        ? AppColors.textMuted
                        : AppColors.accentYellow,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                badgeName,
                textAlign: TextAlign.center,
                style: AppText.h1.copyWith(
                  color: earned != null
                      ? AppColors.textYellow
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Grade $gradeLevel — $diffLabel',
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              if (earned != null) ...[
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
                      'Earned ${_formatDate(earned.earnedAt)}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Not earned yet',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Pass a quiz with 70% or higher to unlock.',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Badges', style: AppText.h2),
                Text(
                  '$_totalEarned of 18 unlocked',
                  style: AppText.caption,
                ),
              ],
            ),
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
          title: 'Can\'t load badges',
          message: _error,
          onRetry: _loadBadges,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBadges,
      color: AppColors.accentTeal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            _buildHero(),
            const SizedBox(height: AppSpacing.sm),
            _buildGrid(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Hero — Yse + encouraging line ────────────────────────────────

  Widget _buildHero() {
    // Swap the message based on badge count. Same image either way.
    final hasBadges = _totalEarned > 0;
    final message = hasBadges
        ? 'Look at your collection!'
        : 'Earn your first badge by passing a quiz!';

    return Column(
      children: [
        Image.asset(
          'assets/images/mascot/yse_gold_book.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.accentYellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentYellow,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 80,
              color: AppColors.accentYellow,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: hasBadges
                ? AppColors.textYellow
                : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ── Grid of 18 badges ────────────────────────────────────────────

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.0,
        ),
        itemCount: 18,
        itemBuilder: (context, index) {
          final grade = (index ~/ 3) + 1;
          final difficulty = _difficulties[index % 3];
          final key = '$grade-$difficulty';
          final earned = _earnedBadges[key];

          return _BadgeTile(
            gradeLevel: grade,
            difficulty: difficulty,
            earned: earned,
            onTap: () => _showBadgeDetail(
              gradeLevel: grade,
              difficulty: difficulty,
              earned: earned,
            ),
          );
        },
      ),
    );
  }
}

// _BadgeTile unchanged — keep as-is from your original.
class _BadgeTile extends StatelessWidget {
  final int gradeLevel;
  final String difficulty;
  final AchievementBadge? earned;
  final VoidCallback onTap;

  const _BadgeTile({
    required this.gradeLevel,
    required this.difficulty,
    required this.earned,
    required this.onTap,
  });

  Color get _ringColor {
    switch (difficulty) {
      case 'easy':
        return AppColors.accentGreen;
      case 'medium':
        return AppColors.accentOrange;
      case 'hard':
        return AppColors.accentCoral;
      default:
        return AppColors.accentTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEarned = earned != null;
    final imagePath =
        AchievementBadge.imagePathFor(gradeLevel, difficulty);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isEarned ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: isEarned ? _ringColor : AppColors.border,
              width: isEarned ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  color: isEarned
                      ? null
                      : Colors.grey.withValues(alpha: 0.3),
                  colorBlendMode:
                      isEarned ? null : BlendMode.saturation,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.emoji_events_rounded,
                    size: 40,
                    color: isEarned
                        ? _ringColor
                        : AppColors.textMuted,
                  ),
                ),
              ),
              Positioned(
                left: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'G$gradeLevel',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: isEarned
                          ? _ringColor
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (!isEarned)
                const Positioned(
                  right: 2,
                  top: 2,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}