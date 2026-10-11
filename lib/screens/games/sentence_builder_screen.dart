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
import '../../utils/game_score.dart';

/// Sentence Builder — Grade 3 Hard.
///
/// 14 rounds. Each round: big image + definition, empty sentence slots,
/// shuffled word tiles at the bottom.
///
/// Partial-feedback mechanic:
///   1. Learner places all words → auto-check fires
///   2. Correct-position tiles → green + locked
///      Wrong-position tiles  → red + tappable to return to bank
///   3. Learner removes only the wrong ones, refills, checks again
///   4. When all tiles green → sentence audio plays → +5 pts → advance
///
/// First-attempt-only scoring: a round that ever showed a red tile
/// scores 0, no matter how many retries it took to fix.
class SentenceBuilderScreen extends StatefulWidget {
  const SentenceBuilderScreen({super.key});

  @override
  State<SentenceBuilderScreen> createState() =>
      _SentenceBuilderScreenState();
}

enum _SlotState { empty, pending, correct, wrong }

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
  int _submissionsThisRound = 0;
  bool _roundResolved = false;
  bool _firstAttemptFailed = false;

  List<_Slot> _slots = [];
  List<_WordTile> _availableWords = [];

  DateTime? _roundStart;
  int? _lastResponseTimeMs;

  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;
  final List<int> _wrongWordIds = [];

  final AudioPlayer _audioPlayer = AudioPlayer();

  static const int _maxSubmissions = 3;
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
    final difficulty = (args['difficulty'] as String?) ?? 'easy';
    final student = context.read<StudentProvider>().currentStudent;

    if (student == null || student.id == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in.';
      });
      return;
    }

    try {
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

        // Split and strip punctuation for clean tile matching.
        final words_ = rawSentence
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => s.replaceAll(RegExp(r"[.,!?;:'()]"), ''))
            .where((s) => s.isNotEmpty)
            .toList();
        if (words_.length < 2) continue;

        final tiles = <_WordTile>[];
        for (int i = 0; i < words_.length; i++) {
          tiles.add(_WordTile(id: i, text: words_[i]));
        }

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
          sentenceAudioAsset: w.sampleSentenceAudio ?? '',
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
      _slots = List.generate(
        round.targetSentence.length,
        (_) => _Slot(),
      );
      _availableWords = List.from(round.scrambledTiles);
      _submissionsThisRound = 0;
      _firstAttemptFailed = false;
      _roundResolved = false;
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

  Future<void> _playSentenceAudio(String assetPath) async {
    if (assetPath.isEmpty) return;
    try {
      final clean = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(clean));
      // Wait for playback to finish, with a 6s safety timeout.
      await _audioPlayer.onPlayerComplete
          .first
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('🔊 Sentence audio failed (continuing): $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Interaction
  // ────────────────────────────────────────────────────────────

  void _onWordTap(_WordTile tile) {
    if (_roundResolved) return;
    final emptyIndex = _slots.indexWhere((s) => s.state == _SlotState.empty);
    if (emptyIndex == -1) return;

    setState(() {
      _slots[emptyIndex] = _Slot(
        tile: tile,
        state: _SlotState.pending,
      );
      _availableWords.removeWhere((t) => t.id == tile.id);
    });

    // Check only when no slots are empty.
    if (_slots.every((s) => s.state != _SlotState.empty)) {
      _checkSentence();
    }
  }

  void _onSlotTap(int index) {
    if (_roundResolved) return;
    final slot = _slots[index];

    // Correct tiles are locked.
    if (slot.state == _SlotState.correct) return;
    if (slot.tile == null) return;

    // Both `pending` and `wrong` tiles can be removed.
    setState(() {
      _availableWords.add(slot.tile!);
      _slots[index] = _Slot();
    });
  }

  void _checkSentence() {
    final round = _rounds[_currentIndex];

    bool allCorrect = true;
    int newWrongCount = 0;

    for (int i = 0; i < _slots.length; i++) {
      final slot = _slots[i];

      // Already-locked correct tiles stay put.
      if (slot.state == _SlotState.correct) continue;

      // Skip empties (shouldn't happen here, but defensive).
      if (slot.tile == null) {
        allCorrect = false;
        continue;
      }

      // Compare by text (case-insensitive).
      final placed = slot.tile!.text.toLowerCase();
      final target = round.targetSentence[i].toLowerCase();

      if (placed == target) {
        slot.state = _SlotState.correct;
      } else {
        slot.state = _SlotState.wrong;
        newWrongCount++;
        allCorrect = false;
      }
    }

    _submissionsThisRound++;

    // First submission — record if it had any wrong.
    if (_submissionsThisRound == 1 && newWrongCount > 0) {
      _firstAttemptFailed = true;
    }

    setState(() {});

    if (allCorrect) {
      _onRoundComplete();
    } else if (_submissionsThisRound >= _maxSubmissions) {
      // 3-strike reveal
      _wrongWordIds.add(round.wordId);
      setState(() => _roundResolved = true);
      _revealCorrectSentence(round);
      _reaction.show(YseReaction.tryAgain, persistent: true);
      GameSfx.instance.playWrong();
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) _advanceRound();
      });
    } else {
      // Partial feedback — learner fixes red tiles
      _currentStreak = 0;
      GameSfx.instance.playWrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);
    }
  }

  Future<void> _onRoundComplete() async {
    final round = _rounds[_currentIndex];

    _lastResponseTimeMs = _roundStart == null
        ? null
        : DateTime.now().difference(_roundStart!).inMilliseconds;

    setState(() => _roundResolved = true);

    GameSfx.instance.playCorrect();

    // First-attempt scoring
    if (!_firstAttemptFailed) {
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

    // Sequence: sparkle → short pause → sentence audio → pause → advance
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (round.sentenceAudioAsset.isNotEmpty) {
      await _playSentenceAudio(round.sentenceAudioAsset);
    } else {
      // Fallback: short delay if no sentence audio
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    _advanceRound();
  }

  void _revealCorrectSentence(_SentenceRound round) {
    final placed = <_Slot>[];
    final used = <int>{};
    for (final wordText in round.targetSentence) {
      for (final t in round.scrambledTiles) {
        if (used.contains(t.id)) continue;
        if (t.text.toLowerCase() == wordText.toLowerCase()) {
          used.add(t.id);
          placed.add(_Slot(tile: t, state: _SlotState.correct));
          break;
        }
      }
    }
    setState(() {
      _slots = placed;
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

      final args = ModalRoute.of(context)!.settings.arguments as Map;
      final score = GameScore.fromArgs(
        args,
        gameCorrect: _correctCount,
        gameTotal: _rounds.length,
      );

      final pointsDelta =
          await DatabaseService.instance.computePointsDeltaForBatch(
        studentId: _studentId,
        batchId: _batchId,
        newScore: score.correct,
      );

      final attemptId = await DatabaseService.instance.saveQuizAttempt(
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
          'score': score.correct,
          'totalQuestions': score.total,
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

  double _tileWidthFor(_SentenceRound round) {
    final longest = round.targetSentence
        .map((s) => s.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
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

                YseReactionOverlay(
                  controller: _reaction,
                  size: 150,
                ),

                const SizedBox(height: AppSpacing.sm),

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

                Text(
                  _submissionsThisRound == 0
                      ? 'Tap the words to build the sentence'
                      : 'Fix the red tiles — you can do this!',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                _buildSlots(round, tileWidth),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),

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

  Widget _buildSlots(_SentenceRound round, double tileWidth) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 8,
      children: List.generate(_slots.length, (i) {
        final slot = _slots[i];
        final hasTile = slot.tile != null;

        // Colors by state
        Color borderColor;
        Color fillColor;
        Color textColor;
        List<BoxShadow>? glow;

        switch (slot.state) {
          case _SlotState.correct:
            borderColor = AppColors.accentGreen;
            fillColor = AppColors.accentGreen.withValues(alpha: 0.14);
            textColor = AppColors.textGreen;
            glow = [
              BoxShadow(
                color: AppColors.accentGreen.withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ];
            break;
          case _SlotState.wrong:
            borderColor = AppColors.accentCoral;
            fillColor = AppColors.accentCoral.withValues(alpha: 0.14);
            textColor = AppColors.textCoral;
            glow = [
              BoxShadow(
                color: AppColors.accentCoral.withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ];
            break;
          case _SlotState.pending:
          case _SlotState.empty:
            borderColor =
                hasTile ? AppColors.accentTeal : AppColors.textMuted;
            fillColor = hasTile ? AppColors.surface : Colors.transparent;
            textColor = AppColors.textPrimary;
            glow = null;
            break;
        }

        return GestureDetector(
          onTap: () => _onSlotTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: tileWidth,
            height: _bankTileHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: borderColor, width: 2.5),
              boxShadow: glow,
            ),
            child: Center(
              child: Text(
                slot.tile?.text ?? '',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
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
  final String sentenceAudioAsset;
  final String imagePath;
  final String definition;
  final List<_WordTile> scrambledTiles;

  _SentenceRound({
    required this.wordId,
    required this.targetSentence,
    required this.correctAudioPath,
    required this.sentenceAudioAsset,
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

/// A single slot in the sentence. Holds the placed tile + validation state.
class _Slot {
  _WordTile? tile;
  _SlotState state;

  _Slot({this.tile, this.state = _SlotState.empty});
}