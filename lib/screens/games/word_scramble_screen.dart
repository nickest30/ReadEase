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

/// Word Scramble — replaces the MCQ quiz for Grade 2 Hard.
///
/// 16 rounds. Each round: image + cue audio at start, empty target
/// slots showing word length, scrambled letter tiles below.
/// Tap a letter → places it in the next empty slot.
/// Tap a filled slot → returns the letter.
/// When all slots fill, the word is checked:
///   - Correct on first attempt: +5 pts, advance
///   - Correct after wrongs: +0 pts, advance
///   - 3 wrong attempts: reveal answer, +0 pts, advance
///
/// Same DB writes as the other games.
class WordScrambleScreen extends StatefulWidget {
  const WordScrambleScreen({super.key});

  @override
  State<WordScrambleScreen> createState() => _WordScrambleScreenState();
}

class _WordScrambleScreenState extends State<WordScrambleScreen> {
  bool _loading = true;
  String? _error;

  List<_ScrambleRound> _rounds = [];
  Map<int, QuizQuestion> _questionByWordId = {};

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 1;
  String _difficulty = 'hard';

  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongAttemptsThisRound = 0;
  bool _roundResolved = false;

  List<_LetterTile?> _placedLetters = [];
  List<_LetterTile> _availableLetters = [];

  DateTime? _roundStart;
  int? _lastResponseTimeMs;

  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;
  final List<int> _wrongWordIds = [];

  final AudioPlayer _audioPlayer = AudioPlayer();

  static const int _maxWrongAttempts = 3;

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
    final gradeLevel = (args['gradeLevel'] as int?) ?? 1;
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
      final words = await DatabaseService.instance.getWordsInBatch(batchId);
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
      final rounds = <_ScrambleRound>[];

      for (final w in words) {
        final correct = w.text.toUpperCase();
        final tiles = <_LetterTile>[];
        for (int i = 0; i < correct.length; i++) {
          tiles.add(_LetterTile(id: i, letter: correct[i]));
        }

        // Shuffle until different from correct order
        final scrambled = List<_LetterTile>.from(tiles);
        int attempts = 0;
        do {
          scrambled.shuffle(rnd);
          attempts++;
        } while (
          attempts < 10 &&
          correct.length > 1 &&
          scrambled.map((t) => t.letter).join() == correct
        );

        rounds.add(_ScrambleRound(
          wordId: w.id!,
          correctWord: correct,
          correctAudioPath: w.audioAsset,
          imagePath: w.imageAsset,
          scrambledLetters: scrambled,
        ));
      }

      if (!mounted) return;
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
      debugPrint('🔤 WordScramble load ERROR: $e');
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
      _placedLetters = List.filled(round.correctWord.length, null);
      _availableLetters = List.from(round.scrambledLetters);
      _wrongAttemptsThisRound = 0;
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

  // ────────────────────────────────────────────────────────────
  // Interaction
  // ────────────────────────────────────────────────────────────

  void _onLetterTap(_LetterTile tile) {
    if (_roundResolved) return;
    final emptyIndex = _placedLetters.indexWhere((p) => p == null);
    if (emptyIndex == -1) return;

    setState(() {
      _placedLetters[emptyIndex] = tile;
      _availableLetters.removeWhere((t) => t.id == tile.id);
    });

    // Check only when all slots are full
    if (_placedLetters.every((p) => p != null)) {
      _checkWord();
    }
  }

  void _onSlotTap(int index) {
    if (_roundResolved) return;
    final tile = _placedLetters[index];
    if (tile == null) return;

    setState(() {
      _placedLetters[index] = null;
      _availableLetters.add(tile);
    });
  }

  Future<void> _checkWord() async {
    final round = _rounds[_currentIndex];
    final placed = _placedLetters.map((t) => t?.letter ?? '').join();
    final isCorrect = placed == round.correctWord;

    if (isCorrect) {
      _lastResponseTimeMs = _roundStart == null
          ? null
          : DateTime.now().difference(_roundStart!).inMilliseconds;

      setState(() => _roundResolved = true);
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

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _advanceRound();
    } else {
      _wrongAttemptsThisRound++;
      _currentStreak = 0;
      GameSfx.instance.playWrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);

      if (_wrongAttemptsThisRound >= _maxWrongAttempts) {
        // 3 strikes — reveal the answer
        setState(() => _roundResolved = true);
        _wrongWordIds.add(round.wordId);
        _revealCorrectAnswer(round);
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        _advanceRound();
      } else {
        // Bounce letters back for retry
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() {
          for (final t in _placedLetters) {
            if (t != null) _availableLetters.add(t);
          }
          _placedLetters = List.filled(round.correctWord.length, null);
        });
      }
    }
  }

  void _revealCorrectAnswer(_ScrambleRound round) {
    final correct = round.correctWord.split('');
    final used = <int>{};
    final filled = <_LetterTile?>[];

    for (final ch in correct) {
      for (final t in round.scrambledLetters) {
        if (used.contains(t.id)) continue;
        if (t.letter == ch) {
          used.add(t.id);
          filled.add(t);
          break;
        }
      }
    }

    setState(() {
      _placedLetters = filled;
      _availableLetters = round.scrambledLetters
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
                wasCorrect ? 'scramble_correct' : 'scramble_wrong',
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
      debugPrint('🔤 WordScramble finish ERROR: $e');
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

  Widget _buildGame() {
    final round = _rounds[_currentIndex];

    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: AppSpacing.sm),

        // Image
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            width: 110,
            height: 110,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: AppColors.border),
            ),
            child: Image.asset(
              round.imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Instruction
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            _wrongAttemptsThisRound == 0
                ? 'Tap the letters to spell the word'
                : 'Try again — you can do this!',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Target slots
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _buildSlots(round),
        ),

        const Spacer(),

        // Letter pool
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _buildLetterPool(round),
        ),

        const Spacer(),

        // Yse bottom bar
        Container(
          height: 130,
          alignment: Alignment.center,
          child: YseReactionOverlay(
            controller: _reaction,
            size: 120,
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
            icon: const Icon(Icons.arrow_back,
                color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Spell the Word', style: AppText.h2),
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

  double _tileSizeFor(int wordLength) {
    if (wordLength <= 6) return 46;
    if (wordLength <= 8) return 40;
    return 34;
  }

  Widget _buildSlots(_ScrambleRound round) {
    final size = _tileSizeFor(round.correctWord.length);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 6,
      children: List.generate(_placedLetters.length, (i) {
        final tile = _placedLetters[i];
        final isFilled = tile != null;
        // Highlight during reveal
        final isRevealed = _roundResolved &&
            _wrongAttemptsThisRound >= _maxWrongAttempts;

        return GestureDetector(
          onTap: () => _onSlotTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isFilled
                  ? (isRevealed
                      ? AppColors.accentGreen.withValues(alpha: 0.15)
                      : AppColors.surface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(
                color: isFilled
                    ? (isRevealed
                        ? AppColors.accentGreen
                        : AppColors.accentTeal)
                    : AppColors.textMuted,
                width: 2,
                style: isFilled ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Text(
                tile?.letter ?? '',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w800,
                  color: isRevealed
                      ? AppColors.textGreen
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLetterPool(_ScrambleRound round) {
    final size = _tileSizeFor(round.correctWord.length);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: _availableLetters.map((tile) {
        return GestureDetector(
          onTap: () => _onLetterTap(tile),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.accentTeal, width: 2),
              boxShadow: AppShadows.soft,
            ),
            child: Center(
              child: Text(
                tile.letter,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: size * 0.5,
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

class _ScrambleRound {
  final int wordId;
  final String correctWord;
  final String correctAudioPath;
  final String imagePath;
  final List<_LetterTile> scrambledLetters;

  _ScrambleRound({
    required this.wordId,
    required this.correctWord,
    required this.correctAudioPath,
    required this.imagePath,
    required this.scrambledLetters,
  });
}

class _LetterTile {
  final int id;
  final String letter;

  _LetterTile({required this.id, required this.letter});
}