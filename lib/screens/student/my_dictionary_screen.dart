import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/word.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class MyDictionaryScreen extends StatefulWidget {
  const MyDictionaryScreen({super.key});

  @override
  State<MyDictionaryScreen> createState() => _MyDictionaryScreenState();
}

class _MyDictionaryScreenState extends State<MyDictionaryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Word> _allWords = [];
  Set<int> _encountered = {};
  Set<int> _mastered = {};
  Set<int> _starred = {};
  Set<int> _weak = {};
  int _highestUnlocked = 1;

  late TabController _tabController;
  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // Compute highest unlocked grade (same logic as grade selection).
      // Walks upward from the student's registered grade — each passed
      // Hard level unlocks the next grade.
      int highest = student.gradeLevel;
      for (int g = student.gradeLevel; g <= 6; g++) {
        final passedHard = await DatabaseService.instance
            .hasPassedDifficulty(student.id!, g, 'hard');
        if (passedHard && g + 1 <= 6) {
          highest = g + 1;
        } else {
          break;
        }
      }

      final words = await DatabaseService.instance.getAllWords();

      final encountered =
          (await DatabaseService.instance.getEncounteredWordIds(student.id!))
              .toSet();
      final mastered =
          await DatabaseService.instance.getMasteredWordIds(student.id!);
      final starred =
          await DatabaseService.instance.getStarredWordIds(student.id!);
      final weak =
          await DatabaseService.instance.getWeakWordIds(student.id!);

      if (!mounted) return;
      setState(() {
        _highestUnlocked = highest;
        _allWords = words
            .where((w) => w.gradeLevel <= highest)
            .toList();
        _encountered = encountered;
        _mastered = mastered;
        _starred = starred;
        _weak = weak;
        _loading = false;
      });
    } catch (e) {
      debugPrint('📖 MyDictionary load ERROR: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playWordAudio(Word word) async {
    final assetPath = word.lessonCueAudio ?? word.audioAsset;

    try {
      final cleanPath = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(cleanPath));
    } catch (e) {
      debugPrint('🔊 Dictionary cue audio failed: $e');
    }
  }

  Future<void> _toggleStar(Word word) async {
    final student = context.read<StudentProvider>().currentStudent;
    if (student?.id == null || word.id == null) return;

    if (_starred.contains(word.id)) {
      await DatabaseService.instance.unstarWord(student!.id!, word.id!);
      if (mounted) setState(() => _starred.remove(word.id));
    } else {
      await DatabaseService.instance.starWord(student!.id!, word.id!);
      if (mounted) setState(() => _starred.add(word.id!));
    }
  }

  void _showWordDetail(Word word) {
    final isEncountered = _encountered.contains(word.id);
    final isMastered = _mastered.contains(word.id);
    final isStarred = _starred.contains(word.id);
    final isWeak = _weak.contains(word.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      isScrollControlled: true,
      builder: (ctx) => _WordDetailSheet(
        word: word,
        isEncountered: isEncountered,
        isMastered: isMastered,
        isStarred: isStarred,
        isWeak: isWeak,
        onPlayAudio: () => _playWordAudio(word),
        onToggleStar: () async {
          await _toggleStar(word);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  int get _totalCount => _allWords.length;
  int get _discoveredCount => _allWords
      .where((w) => w.id != null && _encountered.contains(w.id))
      .length;

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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                          child: Text('My Dictionary', style: AppText.h2),
                        ),
                      ],
                    ),
                  ),

                  // Progress
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '$_discoveredCount of $_totalCount words discovered',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                          child: LinearProgressIndicator(
                            value: _totalCount == 0
                                ? 0
                                : _discoveredCount / _totalCount,
                            minHeight: 10,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accentTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.accentTeal,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorColor: AppColors.accentTeal,
                    labelStyle: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Favorites'),
                      Tab(text: 'Weak'),
                      Tab(text: 'Mastered'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGrid(_allWords),
                        _buildGrid(_allWords
                            .where((w) => _starred.contains(w.id))
                            .toList()),
                        _buildGrid(_allWords
                            .where((w) => _weak.contains(w.id))
                            .toList()),
                        _buildGrid(_allWords
                            .where((w) => _mastered.contains(w.id))
                            .toList()),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGrid(List<Word> words) {
    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nothing here yet',
                style: AppText.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Complete lessons to fill your dictionary!',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        final isEncountered =
            word.id != null && _encountered.contains(word.id);
        final isMastered = word.id != null && _mastered.contains(word.id);
        final isStarred = word.id != null && _starred.contains(word.id);
        final isWeak = word.id != null && _weak.contains(word.id);

        return _WordTile(
          word: word,
          isEncountered: isEncountered,
          isMastered: isMastered,
          isStarred: isStarred,
          isWeak: isWeak,
          onTap: () => _showWordDetail(word),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Word tile (Pokédex card)
// ─────────────────────────────────────────────────────────

class _WordTile extends StatelessWidget {
  final Word word;
  final bool isEncountered;
  final bool isMastered;
  final bool isStarred;
  final bool isWeak;
  final VoidCallback onTap;

  const _WordTile({
    required this.word,
    required this.isEncountered,
    required this.isMastered,
    required this.isStarred,
    required this.isWeak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isEncountered
                  ? AppColors.surface
                  : AppColors.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(
                color: isMastered
                    ? AppColors.accentYellow
                    : isEncountered
                        ? AppColors.border
                        : AppColors.border.withValues(alpha: 0.5),
                width: isMastered ? 2.5 : 1,
              ),
              boxShadow: isMastered
                  ? [
                      BoxShadow(
                        color:
                            AppColors.accentYellow.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image or "?" placeholder
                Expanded(
                  child: Center(
                    child: isEncountered
                        ? Image.asset(
                            word.imageAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: AppColors.textMuted,
                            ),
                          )
                        : Text(
                            '?',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEncountered ? word.text : '???',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isEncountered
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Star badge
          if (isStarred)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.accentYellow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),

          // Weak indicator
          if (isWeak && !isMastered)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.accentCoral,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Word detail bottom sheet
// ─────────────────────────────────────────────────────────

class _WordDetailSheet extends StatelessWidget {
  final Word word;
  final bool isEncountered;
  final bool isMastered;
  final bool isStarred;
  final bool isWeak;
  final VoidCallback onPlayAudio;
  final VoidCallback onToggleStar;

  const _WordDetailSheet({
    required this.word,
    required this.isEncountered,
    required this.isMastered,
    required this.isStarred,
    required this.isWeak,
    required this.onPlayAudio,
    required this.onToggleStar,
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

          if (!isEncountered) ...[
            const Icon(
              Icons.help_outline_rounded,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Word not yet discovered',
              style: AppText.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Complete lessons to unlock this word!',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ] else ...[
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

            // Badges
            Wrap(
              spacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                _pill('Grade ${word.gradeLevel}', AppColors.accentTeal),
                if (word.category.isNotEmpty)
                  _pill(
                    word.category.replaceAll('_', ' '),
                    AppColors.accentPurple,
                  ),
                if (isMastered)
                  _pill('Mastered', AppColors.accentYellow),
                if (isWeak && !isMastered)
                  _pill('Needs practice', AppColors.accentCoral),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Definition
            if (word.definition.isNotEmpty) ...[
              _label('MEANING'),
              const SizedBox(height: 4),
              Text(word.definition, style: AppText.body),
              const SizedBox(height: AppSpacing.md),
            ],

            // Sample sentence
            if (word.sampleSentence.isNotEmpty) ...[
              _label('SAMPLE SENTENCE'),
              const SizedBox(height: 4),
              Text(
                word.sampleSentence,
                style: AppText.body.copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onToggleStar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isStarred
                          ? AppColors.accentYellow
                          : AppColors.surface,
                      foregroundColor: isStarred
                          ? Colors.white
                          : AppColors.textYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.large),
                        side: BorderSide(
                          color: AppColors.accentYellow,
                          width: isStarred ? 0 : 2,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Icon(
                      isStarred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}