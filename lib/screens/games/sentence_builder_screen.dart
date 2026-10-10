import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/badge.dart';
import '../../models/content_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/game_sfx.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import 'yse_reaction.dart';

/// Sentence Builder — Grade 3 Hard.
///
/// 14 rounds. Each round: big image + definition, empty sentence slots,
/// shuffled word tiles at the bottom. Tap a word → fills next empty slot.
/// Tap a placed word → returns to bank. Green glow on correct, red on
/// wrong. 3 wrong attempts → reveal the sentence, advance with 0 pts.
///
/// Source: `sample_sentence` (verified by content team to be 5–7 words,
/// simple grammar, containing the target word).
class SentenceBuilderScreen extends StatefulWidget {
  const SentenceBuilderScreen({super.key});

  @override
  State<SentenceBuilderScreen> createState() =>
      _SentenceBuilderScreenState();
}

enum _GlowState { none, correct, wrong }

class _SentenceBuilderScreenState extends State<SentenceBuilderScreen> {
  bool _loading = true;
  String? _error;

  List<_SentenceRound> _rounds = [];
  Map<int, QuizQuestion> _questionByWordId = {};

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 3;
  String _difficulty = 'hard';

  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongAttemptsThisRound = 0;
  bool _roundResolved = false;
  _GlowState _glowState = _GlowState.none;

  List<_WordTile?> _placedWords = [];
  List<_WordTile> _availableWords = [];

  DateTime? _roundStart;
  int? _lastResponseTimeMs;

  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;
  final List<int> _wrongWordIds = [];

  final AudioPlayer _audioPlayer = AudioPlayer();

  static const int _maxWrongAttempts = 3;
  static const double _bankTileHeight = 52.0;
  static const double _minTileWidth = 56.0;
  static const double _maxTileWidth = 130.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGame());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _reaction.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // Load
  // ────────────────────────────────────────────────────────────

  Future<void> _loadGame() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final batchId = args['batchId'] as int;
    final gradeLevel = (args['gradeLevel'] as int?) ?? 3;
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
      // Use the randomizer (Grade 3 has randomized: 1)
      final words = await DatabaseService.instance
          .getSampledWordsForBatch(batchId);

      if (words.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No words found for this game.';
        });
        return;
      }

      final questions =
          await DatabaseService.instance.getQuestionsForBatch(batchId);
      final qMap = <int, QuizQuestion>{};
      for (final q in questions) {
        qMap.putIfAbsent(q.wordId, () => q);
      }

      final rnd = Random();
      final rounds = <_SentenceRound>[];

      for (final w in words) {
        final rawSentence = w.sampleSentence.trim();
        if (rawSentence.isEmpty) continue;

        // Split into words (preserve punctuation with the word)
        final words_ = rawSentence
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();
        if (words_.length < 2) continue;

        // Build tiles
        final tiles = <_WordTile>[];
        for (int i = 0; i < words_.length; i++) {
          tiles.add(_WordTile(id: i, text: words_[i]));
        }

        // Shuffle, avoiding the correct order
        final scrambled = List<_WordTile>.from(tiles);
        int attempts = 0;
        do {
          scrambled.shuffle(rnd);
          attempts++;
        } while (
          attempts < 15 &&
          words_.length > 1 &&
          scrambled.map((t) => t.text).join(' ') == words_.join(' ')
        );

        rounds.add(_SentenceRound(
          wordId: w.id!,
          targetSentence: words_,
          correctAudioPath: w.audioAsset,
          imagePath: w.imageAsset,
          definition: w.definition,
          scrambledTiles: scrambled,
        ));
      }

      if (!mounted) return;

      if (rounds.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No sentences found for this game.';
        });
        return;
      }

      setState(() {
        _rounds = rounds;
        _questionByWordId = qMap;
        _batchId = batchId;
        _studentId = student.id!;
        _gradeLevel = gradeLevel;
        _difficulty = difficulty;
        _loading = false;
      });

      _startRound();

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _reaction.show(YseReaction.letsGo, persistent: true);
    } catch (e) {
      debugPrint('📝 SentenceBuilder load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load game. Try again.';
      });
    }
  }

  void _startRound() {
    final round = _rounds[_currentIndex];
    setState(() {
      _placedWords = List.filled(round.targetSentence.length, null);
      _availableWords = List.from(round.scrambledTiles);
      _wrongAttemptsThisRound = 0;
      _roundResolved = false;
      _glowState = _GlowState.none;
      _roundStart = DateTime.now();
    });
    _playCueAudio(round.correctAudioPath);
  }

  Future<void> _playCueAudio(String audioAsset) async {
    try {
      final clean = audioAsset.startsWith('assets/')
          ? audioAsset.substring('assets/'.length)
          : audioAsset;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(clean));
    } catch (e) {
      debugPrint('🔊 Cue audio failed (continuing): $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Interaction
  // ────────────────────────────────────────────────────────────

  void _onWordTap(_WordTile tile) {
    if (_roundResolved) return;
    final emptyIndex = _placedWords.indexWhere((p) => p == null);
    if (emptyIndex == -1) return;

    setState(() {
      _placedWords[emptyIndex] = tile;
      _availableWords.removeWhere((t) => t.id == tile.id);
    });

    if (_placedWords.every((p) => p != null)) {
      _checkSentence();
    }
  }

  void _onSlotTap(int index) {
    if (_roundResolved) return;
    final tile = _placedWords[index];
    if (tile == null) return;

    setState(() {
      _placedWords[index] = null;
      _availableWords.add(tile);
    });
  }

  Future<void> _checkSentence() async {
    final round = _rounds[_currentIndex];
    final placed = _placedWords.map((t) => t?.text ?? '').join(' ');
    final target = round.targetSentence.join(' ');
    final isCorrect = placed == target;

    if (isCorrect) {
      _lastResponseTimeMs = _roundStart == null
          ? null
          : DateTime.now().difference(_roundStart!).inMilliseconds;

      setState(() {
        _roundResolved = true;
        _glowState = _GlowState.correct;
      });
      GameSfx.instance.playCorrect();

      if (_wrongAttemptsThisRound == 0) {
        setState(() => _correctCount++);
        _currentStreak++;
        if (_currentStreak >= 3) {
          _reaction.show(YseReaction.hwaiting, persistent: true);
        } else {
          _reaction.show(YseReaction.nice, persistent: true);
        }
      } else {
        _currentStreak = 0;
        _reaction.show(YseReaction.nice, persistent: true);
      }

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      _advanceRound();
    } else {
      _wrongAttemptsThisRound++;
      _currentStreak = 0;

      setState(() => _glowState = _GlowState.wrong);
      GameSfx.instance.playWrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);

      if (_wrongAttemptsThisRound >= _maxWrongAttempts) {
        // 3 strikes — reveal the sentence
        _wrongWordIds.add(round.wordId);
        setState(() {
          _roundResolved = true;
          _glowState = _GlowState.none;
        });
        _revealCorrectSentence(round);
        setState(() => _glowState = _GlowState.correct);
        await Future.delayed(const Duration(milliseconds: 1600));
        if (!mounted) return;
        _advanceRound();
      } else {
        // Return all placed words to bank for retry
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        setState(() {
          _glowState = _GlowState.none;
          for (final t in _placedWords) {
            if (t != null) _availableWords.add(t);
          }
          _placedWords =
              List.filled(round.targetSentence.length, null);
        });
      }
    }
  }

  void _revealCorrectSentence(_SentenceRound round) {
    // Build the correct order using the tile IDs from scrambledTiles
    final placed = <_WordTile?>[];
    final used = <int>{};
    for (final wordText in round.targetSentence) {
      for (final t in round.scrambledTiles) {
        if (used.contains(t.id)) continue;
        if (t.text == wordText) {
          used.add(t.id);
          placed.add(t);
          break;
        }
      }
    }
    setState(() {
      _placedWords = placed;
      _availableWords = round.scrambledTiles
          .where((t) => !used.contains(t.id))
          .toList();
    });
  }

  void _advanceRound() {
    if (_currentIndex < _rounds.length - 1) {
      setState(() => _currentIndex++);
      _startRound();
    } else {
      _finishGame();
    }
  }

  // ────────────────────────────────────────────────────────────
  // Finish
  // ────────────────────────────────────────────────────────────

  Future<void> _finishGame() async {
    try {
      _reaction.show(YseReaction.youDidIt, persistent: true);
      GameSfx.instance.playCelebration();
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      final totalRounds = _rounds.length;
      final wrongWordIds = List<int>.from(_wrongWordIds);

      final pointsDelta =
          await DatabaseService.instance.computePointsDeltaForBatch(
        studentId: _studentId,
        batchId: _batchId,
        newScore: _correctCount,
      );

      final attemptId = await DatabaseService.instance.saveQuizAttempt(
        QuizAttempt(
          studentId: _studentId,
          batchId: _batchId,
          score: _correctCount,
          totalQuestions: totalRounds,
          pointsEarned: pointsDelta,
          wrongWordIdsJson: wrongWordIds.isEmpty
              ? null
              : '[${wrongWordIds.join(',')}]',
          completedAt: DateTime.now().toIso8601String(),
        ),
      );

      for (final round in _rounds) {
        final q = _questionByWordId[round.wordId];
        if (q == null) continue;
        final wasCorrect = !_wrongWordIds.contains(round.wordId);
        await DatabaseService.instance.saveQuestionResponse(
          QuizQuestionResponse(
            attemptId: attemptId,
            questionId: q.id ?? 0,
            selectedAnswer:
                wasCorrect ? 'sentence_correct' : 'sentence_wrong',
            isCorrect: wasCorrect,
            responseTimeMs: wasCorrect ? _lastResponseTimeMs : null,
          ),
        );
      }

      for (final round in _rounds) {
        final wasCorrect = !_wrongWordIds.contains(round.wordId);
        await DatabaseService.instance
            .recordWordEncounter(_studentId, round.wordId);
        await DatabaseService.instance.updateWordMastery(
          studentId: _studentId,
          wordId: round.wordId,
          correct: wasCorrect,
        );
      }

      if (pointsDelta > 0) {
        await DatabaseService.instance.addPoints(_studentId, pointsDelta);
      }

      bool isNewBadge = false;
      final isPassing = totalRounds > 0 &&
          (_correctCount / totalRounds) >= 0.70;
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
          'score': _correctCount,
          'totalQuestions': totalRounds,
          'pointsDelta': pointsDelta,
          'gradeLevel': _gradeLevel,
          'difficulty': _difficulty,
          'isNewBadge': isNewBadge,
        },
      );
    } catch (e) {
      debugPrint('📝 SentenceBuilder finish ERROR: $e');
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError();
    }
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

  /// Uniform tile width based on the longest word in the sentence.
  /// All slots and bank tiles use the same width for visual consistency.
  double _tileWidthFor(_SentenceRound round) {
    final longest = round.targetSentence
        .map((s) => s.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    // ~11px per char + 24px padding
    final computed = (longest * 11.0) + 24.0;
    return computed.clamp(_minTileWidth, _maxTileWidth);
  }

  Widget _buildGame() {
    final round = _rounds[_currentIndex];
    final screenH = MediaQuery.of(context).size.height;
    final imageSize = (screenH * 0.24).clamp(150.0, 200.0);
    final tileWidth = _tileWidthFor(round);

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: Column(
              children: [
                const SizedBox(height: 4),

                // Yse — top
                YseReactionOverlay(
                  controller: _reaction,
                  size: 150,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Big centered image
                Center(
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppRadius.xl),
                      border:
                          Border.all(color: AppColors.border, width: 2),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Image.asset(
                      round.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.image_outlined,
                        size: 72,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Definition
                if (round.definition.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      round.definition,
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),

                const SizedBox(height: AppSpacing.md),

                // Instruction
                Text(
                  _wrongAttemptsThisRound == 0
                      ? 'Tap the words to build the sentence'
                      : 'Try again — you can do this!',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Sentence slots
                _buildSlots(round, tileWidth),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),

        // Word bank — fixed at bottom, thumb-reachable
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.studentBg,
            border: Border(
              top: BorderSide(
                color: AppColors.border,
                width: 1,
              ),
            ),
          ),
          child: _buildWordBank(round, tileWidth),
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
            icon: const Icon(Icons.arrow_back,
                color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Build a Sentence', style: AppText.h2),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppColors.accentYellow),
                    const SizedBox(width: 3),
                    Text(
                      '${_correctCount * 5} pts',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textYellow,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Icon(Icons.flag_rounded,
                        size: 14, color: AppColors.accentTeal),
                    const SizedBox(width: 3),
                    Text(
                      'Round ${_currentIndex + 1} / ${_rounds.length}',
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Color _borderColorForSlot(bool isFilled) {
    if (_glowState == _GlowState.correct && isFilled) {
      return AppColors.accentGreen;
    }
    if (_glowState == _GlowState.wrong && isFilled) {
      return AppColors.accentCoral;
    }
    return isFilled ? AppColors.accentTeal : AppColors.textMuted;
  }

  List<BoxShadow>? _glowForSlot(bool isFilled) {
    if (!isFilled) return null;
    if (_glowState == _GlowState.correct) {
      return [
        BoxShadow(
          color: AppColors.accentGreen.withValues(alpha: 0.65),
          blurRadius: 20,
          spreadRadius: 3,
        ),
      ];
    }
    if (_glowState == _GlowState.wrong) {
      return [
        BoxShadow(
          color: AppColors.accentCoral.withValues(alpha: 0.65),
          blurRadius: 20,
          spreadRadius: 3,
        ),
      ];
    }
    return null;
  }

  Widget _buildSlots(_SentenceRound round, double tileWidth) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: List.generate(_placedWords.length, (i) {
        final tile = _placedWords[i];
        final isFilled = tile != null;

        return GestureDetector(
          onTap: () => _onSlotTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: tileWidth,
            height: _bankTileHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isFilled
                  ? (_glowState == _GlowState.correct
                      ? AppColors.accentGreen.withValues(alpha: 0.12)
                      : _glowState == _GlowState.wrong
                          ? AppColors.accentCoral.withValues(alpha: 0.12)
                          : AppColors.surface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(
                color: _borderColorForSlot(isFilled),
                width: 2.5,
              ),
              boxShadow: _glowForSlot(isFilled),
            ),
            child: Center(
              child: Text(
                tile?.text ?? '',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _glowState == _GlowState.correct && isFilled
                      ? AppColors.textGreen
                      : _glowState == _GlowState.wrong && isFilled
                          ? AppColors.textCoral
                          : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWordBank(_SentenceRound round, double tileWidth) {
    if (_availableWords.isEmpty) {
      // Reserve height so layout doesn't jump when all words are placed
      return const SizedBox(height: 52);
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: _availableWords.map((tile) {
        return GestureDetector(
          onTap: () => _onWordTap(tile),
          child: Container(
            width: tileWidth,
            height: _bankTileHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.accentTeal, width: 2.5),
              boxShadow: AppShadows.soft,
            ),
            child: Center(
              child: Text(
                tile.text,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════════════════════════

class _SentenceRound {
  final int wordId;
  final List<String> targetSentence;
  final String correctAudioPath;
  final String imagePath;
  final String definition;
  final List<_WordTile> scrambledTiles;

  _SentenceRound({
    required this.wordId,
    required this.targetSentence,
    required this.correctAudioPath,
    required this.imagePath,
    required this.definition,
    required this.scrambledTiles,
  });
}

class _WordTile {
  final int id;
  final String text;

  _WordTile({required this.id, required this.text});
}