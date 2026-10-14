import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../models/content_models.dart';
import '../../models/word.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/game_sfx.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/game_score.dart';

/// Category Sort — Grade 6 Hard.
///
/// 12 words, 3 category bins, drag-and-drop. 5 pts per correct.
/// 3-strike rule auto-places a word after 3 wrong attempts (0 pts).
/// 60s hint glows one word's correct bin. 180s auto-completes.
class CategorySortScreen extends StatefulWidget {
  const CategorySortScreen({super.key});

  @override
  State<CategorySortScreen> createState() => _CategorySortScreenState();
}

class _CategorySortScreenState extends State<CategorySortScreen> {
  static const int _wordsPerRound = 12;
  static const int _categoriesPerRound = 3;
  static const int _maxStrikes = 3;
  static const int _hintAfterSeconds = 60;
  static const int _autoCompleteAfterSeconds = 180;

  /// Category → friendly display name.
  static const Map<String, String> _categoryLabels = {
    'music': 'Music',
    'visual_arts': 'Visual Arts',
    'storytelling': 'Storytelling',
    // Fallback labels in case future content adds categories
    'movement': 'Movement',
    'action': 'Action',
    'flavor': 'Flavor',
    'texture': 'Texture',
    'color': 'Color',
    'quality': 'Quality',
    'general': 'General',
  };

  /// Category → theme color.
  static const Map<String, Color> _categoryColors = {
    'music': Color(0xFF9C27B0),        // purple
    'visual_arts': Color(0xFF4A9EFF),  // blue
    'storytelling': Color(0xFFFF9800), // orange
  };

  static const Color _fallbackColor = Color(0xFF009688);

  bool _loading = true;
  String? _error;

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 6;
  String _difficulty = 'hard';

  /// All 18 loaded words (unsorted pool is derived).
  List<Word> _allWords = [];

  /// Category names in display order (3 of them).
  List<String> _categoryOrder = [];

  /// Words currently in the pool (not yet sorted).
  final Set<int> _poolWordIds = {};

  /// Words already sorted correctly. wordId → category.
  final Map<int, String> _sortedWords = {};

  /// Strike count per word (max 3).
  final Map<int, int> _strikes = {};

  /// Words that were auto-placed after 3 strikes (0 pts).
  final Set<int> _autoPlacedWordIds = {};

  /// Hint state: word id whose correct bin is glowing.
  int? _hintWordId;

  int _correctCount = 0; // words sorted correctly (5 pts each)

  Timer? _ticker;
  int _elapsedSeconds = 0;
  bool _hintFired = false;
  bool _autoCompleteFired = false;
  bool _gameOver = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<int> _wrongWordIds = [];

  // Word being dragged (for the feedback widget scale).
  int? _draggingWordId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGame());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // Load
  // ────────────────────────────────────────────────────────────

  Future<void> _loadGame() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final batchId = args['batchId'] as int;
    final gradeLevel = (args['gradeLevel'] as int?) ?? 6;
    final difficulty = (args['difficulty'] as String?) ?? 'hard';
    final student = context.read<StudentProvider>().currentStudent;

    if (student == null || student.id == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    try {
      final allWords =
          await DatabaseService.instance.getSampledWordsForBatch(batchId);

      if (allWords.length < _wordsPerRound) {
        setState(() {
          _loading = false;
          _error = 'Not enough words for Category Sort.';
        });
        return;
      }

      // Group words by category.
      final grouped = <String, List<Word>>{};
      for (final w in allWords) {
        final cat = w.category.trim();
        if (cat.isEmpty) continue;
        grouped.putIfAbsent(cat, () => []).add(w);
      }

      if (grouped.length < _categoriesPerRound) {
        setState(() {
          _loading = false;
          _error = 'Not enough categories for this round.';
        });
        return;
      }

      // Sample 4 per category, take the first 3 categories (shuffled).
      final rng = Random();
      final catNames = grouped.keys.toList()..shuffle(rng);
      final pickedCats = catNames.take(_categoriesPerRound).toList();

      final sampledWords = <Word>[];
      for (final cat in pickedCats) {
        final group = List<Word>.from(grouped[cat]!)..shuffle(rng);
        sampledWords.addAll(group.take(4));
      }
      sampledWords.shuffle(rng);

      if (!mounted) return;

      setState(() {
        _allWords = sampledWords;
        _categoryOrder = pickedCats;
        _poolWordIds
          ..clear()
          ..addAll(sampledWords.map((w) => w.id!));
        _sortedWords.clear();
        _strikes.clear();
        _autoPlacedWordIds.clear();
        _batchId = batchId;
        _studentId = student.id!;
        _gradeLevel = gradeLevel;
        _difficulty = difficulty;
        _loading = false;
      });

      _startTicker();
    } catch (e) {
      debugPrint('📦 CategorySort load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load game. Try again.';
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _gameOver) return;
      setState(() => _elapsedSeconds++);

      if (!_hintFired && _elapsedSeconds >= _hintAfterSeconds) {
        _fireHint();
      }
      if (!_autoCompleteFired &&
          _elapsedSeconds >= _autoCompleteAfterSeconds) {
        _fireAutoComplete();
      }
    });
  }

  // ────────────────────────────────────────────────────────────
  // Sorting logic
  // ────────────────────────────────────────────────────────────

  Future<void> _onWordDropped(Word word, String targetCategory) async {
    if (_gameOver) return;
    if (!_poolWordIds.contains(word.id)) return;

    final isCorrect = word.category == targetCategory;

    if (isCorrect) {
      HapticFeedback.heavyImpact();
      GameSfx.instance.playCorrect();

      setState(() {
        _poolWordIds.remove(word.id);
        _sortedWords[word.id!] = word.category;
        _correctCount++;
        _hintWordId = null;
      });

      await _playAudio(word.audioAsset);

      if (!mounted) return;

      if (_sortedWords.length >= _allWords.length) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await _finishGame();
      }
      return;
    }

    // Wrong drop.
    HapticFeedback.mediumImpact();
    GameSfx.instance.playWrong();

    final currentStrikes = _strikes[word.id] ?? 0;
    final newStrikes = currentStrikes + 1;

    setState(() {
      _strikes[word.id!] = newStrikes;
    });

    if (newStrikes >= _maxStrikes) {
      // Auto-place after 3 strikes, 0 pts.
      setState(() {
        _poolWordIds.remove(word.id);
        _sortedWords[word.id!] = word.category;
        _autoPlacedWordIds.add(word.id!);
        _hintWordId = null;
      });

      await _playAudio(word.audioAsset);

      if (!mounted) return;
      if (_sortedWords.length >= _allWords.length) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await _finishGame();
      }
    }
  }

  Future<void> _playAudio(String assetPath) async {
    if (assetPath.isEmpty) return;
    try {
      final clean = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(clean));
    } catch (e) {
      debugPrint('🔊 Word audio failed (continuing): $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Hint + auto-complete
  // ────────────────────────────────────────────────────────────

  void _fireHint() {
    _hintFired = true;
    if (_poolWordIds.isEmpty) return;
    final unsorted =
        _allWords.where((w) => _poolWordIds.contains(w.id)).toList();
    if (unsorted.isEmpty) return;
    final pick = unsorted[Random().nextInt(unsorted.length)];
    setState(() => _hintWordId = pick.id);
  }

  Future<void> _fireAutoComplete() async {
    _autoCompleteFired = true;
    final remaining =
        _allWords.where((w) => _poolWordIds.contains(w.id)).toList();
    if (remaining.isEmpty) return;

    setState(() {
      _gameOver = true;
      for (final w in remaining) {
        _poolWordIds.remove(w.id);
        _sortedWords[w.id!] = w.category;
        _autoPlacedWordIds.add(w.id!);
        _wrongWordIds.add(w.id!);
      }
      _hintWordId = null;
    });

    GameSfx.instance.playWrong();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    await _finishGame();
  }

  // ────────────────────────────────────────────────────────────
  // Finish
  // ────────────────────────────────────────────────────────────

  Future<void> _finishGame() async {
    if (_ticker?.isActive ?? false) _ticker!.cancel();
    try {
      if (!_autoCompleteFired && _sortedWords.length >= _allWords.length) {
        GameSfx.instance.playCelebration();
        await Future.delayed(const Duration(milliseconds: 1200));
      }
      if (!mounted) return;

      final totalRounds = _allWords.length;
      final wrongWordIds = List<int>.from(_wrongWordIds);

      final args = ModalRoute.of(context)!.settings.arguments as Map;
      final score = GameScore.fromArgs(
        args,
        gameCorrect: _correctCount,
        gameTotal: totalRounds,
      );

      final pointsDelta =
          await DatabaseService.instance.computePointsDeltaForBatch(
        studentId: _studentId,
        batchId: _batchId,
        newScore: score.correct,
      );

      await DatabaseService.instance.saveQuizAttempt(
        QuizAttempt(
          studentId: _studentId,
          batchId: _batchId,
          score: score.correct,
          totalQuestions: score.total,
          pointsEarned: pointsDelta,
          wrongWordIdsJson: wrongWordIds.isEmpty
              ? null
              : '[${wrongWordIds.join(',')}]',
          completedAt: DateTime.now().toIso8601String(),
        ),
      );

      for (final w in _allWords) {
        final wasCorrect = !_autoPlacedWordIds.contains(w.id) &&
            !_wrongWordIds.contains(w.id);
        await DatabaseService.instance
            .recordWordEncounter(_studentId, w.id!);
        await DatabaseService.instance.updateWordMastery(
          studentId: _studentId,
          wordId: w.id!,
          correct: wasCorrect,
        );
      }

      if (pointsDelta > 0) {
        await DatabaseService.instance.addPoints(_studentId, pointsDelta);
      }

      bool isNewBadge = false;
      final isPassing =
          totalRounds > 0 && (_correctCount / totalRounds) >= 0.70;
      if (isPassing) {
        final badgeName =
            AchievementBadge.nameFor(_gradeLevel, _difficulty);
        final badge = AchievementBadge(
          studentId: _studentId,
          gradeLevel: _gradeLevel,
          difficulty: _difficulty,
          badgeName: badgeName,
          pointsEarned: pointsDelta,
          earnedAt: DateTime.now().toIso8601String(),
        );
        isNewBadge = await DatabaseService.instance.awardBadge(badge);
      }

      final updated =
          await DatabaseService.instance.getStudentById(_studentId);
      if (!mounted) return;

      if (updated != null) {
        context.read<StudentProvider>().setStudent(updated);

        final connectivity = context.read<ConnectivityProvider>();
        final authProvider = context.read<AuthProvider>();
        unawaited(
          SyncService.instance.syncAll(
            student: updated,
            connectivity: connectivity,
            authProvider: authProvider,
          ),
        );

        if (updated.classFirestoreId != null &&
            updated.classFirestoreId!.isNotEmpty &&
            updated.firebaseUid != null) {
          try {
            final badges = await DatabaseService.instance
                .getBadgesForStudent(updated.id!);
            await FirestoreService.instance.updateEnrollmentSnapshot(
              classId: updated.classFirestoreId!,
              studentUid: updated.firebaseUid!,
              totalPoints: updated.totalPoints,
              badgeCount: badges.length,
            );
          } catch (e) {
            debugPrint('🔥 Enrollment snapshot failed: $e');
          }
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '/results',
        arguments: {
          'score': score.correct,
          'totalQuestions': score.total,
          'pointsDelta': pointsDelta,
          'gradeLevel': _gradeLevel,
          'difficulty': _difficulty,
          'isNewBadge': isNewBadge,
        },
      );
    } catch (e) {
      debugPrint('📦 CategorySort finish ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save results. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return _buildGame();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Color _gridGlowColor() {
    if (_gameOver) return AppColors.accentCoral;
    if (_elapsedSeconds < 60) return const Color(0xFF4CAF50); // green
    if (_elapsedSeconds < 120) return const Color(0xFFFF9800); // orange
    return const Color(0xFFE53935); // red
  }

  String _ysePose() {
    if (_gameOver) return 'assets/images/mascot/yse_try_again.png';
    if (_sortedWords.length >= _allWords.length && _allWords.isNotEmpty) {
      return 'assets/images/mascot/yse_you_did_it.png';
    }
    return 'assets/images/mascot/yse_thinking.png';
  }

  Widget _buildGame() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                // Yse
                Flexible(
                  flex: 2,
                  child: Image.asset(
                    _ysePose(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.category_rounded,
                      size: 80,
                      color: AppColors.accentTeal,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Time bar
                _buildBigStat(
                  icon: Icons.timer_rounded,
                  color: _gridGlowColor(),
                  label: 'TIME',
                  value: _formatTime(_elapsedSeconds),
                ),

                const SizedBox(height: 6),

                _buildBigStat(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.accentTeal,
                  label: 'SORTED',
                  value: '${_sortedWords.length} / ${_allWords.length}',
                ),

                const SizedBox(height: 8),

                // Word pool
                Flexible(
                  flex: 3,
                  child: _buildPool(),
                ),

                const SizedBox(height: 8),

                // Category bins
                Flexible(
                  flex: 4,
                  child: _buildBins(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sort the Words!', style: AppText.h2),
                SizedBox(height: 2),
                Text(
                  'Drag each word into the correct group',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPool() {
    final poolWords = _allWords
        .where((w) => _poolWordIds.contains(w.id))
        .toList();

    if (poolWords.isEmpty) {
      return const Center(
        child: Text(
          'All words sorted!',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: poolWords.map(_buildDraggableWord).toList(),
        ),
      ),
    );
  }

  Widget _buildDraggableWord(Word word) {
    final strikes = _strikes[word.id] ?? 0;
    final isHint = _hintWordId == word.id;
    final isDragging = _draggingWordId == word.id;

    final chip = _WordChip(
      word: word,
      strikes: strikes,
      isHint: isHint,
      isDragging: isDragging,
    );

    return LongPressDraggable<Word>(
      data: word,
      delay: const Duration(milliseconds: 120),
      onDragStarted: () {
        HapticFeedback.selectionClick();
        setState(() => _draggingWordId = word.id);
      },
      onDraggableCanceled: (_, _) {
        setState(() => _draggingWordId = null);
      },
      onDragEnd: (_) {
        setState(() => _draggingWordId = null);
      },
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.1,
          child: _WordChip(
            word: word,
            strikes: 0,
            isHint: false,
            isDragging: false,
            elevated: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: chip,
      ),
      child: chip,
    );
  }

  Widget _buildBins() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _categoryOrder.map((cat) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _buildBin(cat),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBin(String category) {
    final color = _categoryColors[category] ?? _fallbackColor;
    final label = _categoryLabels[category] ?? _prettifyCategory(category);
    final sortedWordsInBin = _allWords
        .where((w) =>
            _sortedWords.containsKey(w.id) && _sortedWords[w.id] == category)
        .toList();

    final isHinted = _hintWordId != null &&
        _allWords
            .any((w) => w.id == _hintWordId && w.category == category);

    return DragTarget<Word>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        _onWordDropped(details.data, category);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isHovered ? 0.22 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(
              color: isHinted
                  ? AppColors.accentYellow
                  : (isHovered ? color : color.withValues(alpha: 0.4)),
              width: isHinted ? 3 : 2,
            ),
            boxShadow: isHinted
                ? [
                    BoxShadow(
                      color: AppColors.accentYellow.withValues(alpha: 0.5),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              // Label
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Sorted word chips
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 3,
                    runSpacing: 3,
                    children: sortedWordsInBin.map((w) {
                      final auto = _autoPlacedWordIds.contains(w.id);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: auto ? 0.15 : 0.30),
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                          border: Border.all(
                            color: color.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          w.text,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _prettifyCategory(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split('_')
        .map((s) => s.isEmpty
            ? s
            : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  Widget _buildBigStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════
// Word chip widget
// ═══════════════════════════════════════════════════════════════

class _WordChip extends StatelessWidget {
  final Word word;
  final int strikes;
  final bool isHint;
  final bool isDragging;
  final bool elevated;

  const _WordChip({
    required this.word,
    required this.strikes,
    required this.isHint,
    required this.isDragging,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseBorder = isHint ? AppColors.accentYellow : AppColors.accentTeal;
    final bgColor = isHint
        ? AppColors.accentYellow.withValues(alpha: 0.15)
        : AppColors.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: baseBorder, width: isHint ? 2 : 1.5),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word.text,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          if (strikes > 0) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    i < (3 - strikes)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 10,
                    color: i < (3 - strikes)
                        ? AppColors.accentCoral
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}