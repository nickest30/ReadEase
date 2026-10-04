import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../models/student.dart';
import '../../models/word.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  bool _syncAttempted = false;
  Word? _wordOfDay;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Retry any pending cloud syncs on app open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retrySyncs();
    });
  }

  Future<void> _retrySyncs() async {
    if (_syncAttempted) return;
    _syncAttempted = true;

    final student = context.read<StudentProvider>().currentStudent;
    final connectivity = context.read<ConnectivityProvider>();
    if (student == null) return;

    await SyncService.instance.retryPendingSyncs(
      student: student,
      connectivity: connectivity,
    );

    // Load Word of the Day
    await _loadWordOfDay();
  }

  Future<void> _loadWordOfDay() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) return;

    try {
      final word = await DatabaseService.instance
          .getOrPickTodaysWord(student.id!, student.gradeLevel);
      if (!mounted) return;
      setState(() => _wordOfDay = word);
    } catch (e) {
      debugPrint('📖 Word of the Day error: $e');
    }
  }

  Future<void> _playWordAudio(Word word) async {
    try {
      final cleanPath = word.audioAsset.startsWith('assets/')
          ? word.audioAsset.substring('assets/'.length)
          : word.audioAsset;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      debugPrint('🔊 Audio failed: $e');
    }
  }

  void _showWordDetail(Word word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      isScrollControlled: true,
      builder: (ctx) => _WordOfDaySheet(
        word: word,
        onPlayAudio: () => _playWordAudio(word),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final studentProvider = context.read<StudentProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Exit?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to exit?\nProgress will be saved.',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'No',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Yes',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Clear the session
    studentProvider.logout();

    // Return to profile list, preserving role-selection in the stack
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/student-profile-list',
      ModalRoute.withName('/role-selection'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    // Guard: no session → redirect to profile list
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(student: student),
                      const SizedBox(height: 20),

                      // Word of the Day
                      if (_wordOfDay != null) ...[
                        _WordOfDayCard(
                          word: _wordOfDay!,
                          onTap: () => _showWordDetail(_wordOfDay!),
                        ),
                        const SizedBox(height: 20),
                      ],

                      _HomeCard(
                        icon: Icons.menu_book_rounded,
                        label: 'Start Learning',
                        sublabel: 'Pick a grade and lesson',
                        color: AppColors.accentCoral,
                        onTap: () => Navigator.of(context).pushNamed(
                          '/grade-selection',
                        ),
                      ),
                      const SizedBox(height: 12),

                      _HomeCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'My Badges',
                        sublabel: 'See what you earned',
                        color: AppColors.accentYellow,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/badges'),
                      ),
                      const SizedBox(height: 12),

                      _HomeCard(
                        icon: Icons.bar_chart_rounded,
                        label: 'Progress',
                        sublabel: 'Track your journey',
                        color: AppColors.accentTeal,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/progress'),
                      ),
                      const SizedBox(height: 12),

                      _HomeCard(
                        icon: Icons.menu_book_rounded,
                        label: 'My Dictionary',
                        sublabel: 'Words you discovered',
                        color: AppColors.accentGreen,
                        onTap: () => Navigator.of(context)
                            .pushNamed('/my-dictionary'),
                      ),
                      const SizedBox(height: 12),

                      _HomeCard(
                        icon: Icons.leaderboard_rounded,
                        label: 'Leaderboard',
                        sublabel: 'See your ranking',
                        color: AppColors.accentPurple,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/leaderboard'),
                      ),
                      const SizedBox(height: 12),

                      _HomeCard(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        sublabel: 'Edit profile and audio',
                        color: AppColors.textMuted,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/settings'),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _confirmExit(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCoral,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Save & Exit',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Header with online/offline chip
// ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Student student;
  const _Header({required this.student});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accentTeal,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${student.displayName}!',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${student.totalPoints} points earned',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Session state chip
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.accentTeal.withValues(alpha: 0.15)
                  : AppColors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isOnline ? AppColors.accentTeal : AppColors.textMuted,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  size: 14,
                  color: isOnline
                      ? AppColors.textTeal
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online — all features' : 'Offline — practice only',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOnline
                        ? AppColors.textTeal
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Home card
// ─────────────────────────────────────────────────────────

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Word of the Day card
// ─────────────────────────────────────────────────────────

class _WordOfDayCard extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;

  const _WordOfDayCard({
    required this.word,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentYellow.withValues(alpha: 0.25),
              AppColors.accentOrange.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: AppColors.accentYellow.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Word image
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                word.imageAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.accentYellow,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: AppColors.textYellow,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'WORD OF THE DAY',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.textYellow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.text,
                    style: AppText.h1.copyWith(fontSize: 24),
                  ),
                  if (word.definition.isNotEmpty)
                    Text(
                      word.definition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textYellow,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Word of the Day bottom sheet
// ─────────────────────────────────────────────────────────

class _WordOfDaySheet extends StatelessWidget {
  final Word word;
  final VoidCallback onPlayAudio;

  const _WordOfDaySheet({
    required this.word,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Word image
          SizedBox(
            width: 140,
            height: 140,
            child: Image.asset(
              word.imageAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_outlined,
                size: 60,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Word
          Text(
            word.text,
            style: AppText.display.copyWith(fontSize: 36),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Grade pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Grade ${word.gradeLevel}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textTeal,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          if (word.definition.isNotEmpty) ...[
            _label('MEANING'),
            const SizedBox(height: 4),
            Text(
              word.definition,
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (word.sampleSentence.isNotEmpty) ...[
            _label('SAMPLE SENTENCE'),
            const SizedBox(height: 4),
            Text(
              word.sampleSentence,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Listen button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onPlayAudio,
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text(
                'LISTEN',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: AppColors.textMuted,
      ),
    );
  }
}