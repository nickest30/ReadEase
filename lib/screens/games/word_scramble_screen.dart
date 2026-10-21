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
import '../../services/sfx_service.dart';
import '../../services/bgm_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import 'yse_reaction.dart';
import '../../widgets/info_button.dart';
import '../../utils/game_score.dart';

class WordScrambleScreen extends StatefulWidget {
  const WordScrambleScreen({super.key});

  @override
  State<WordScrambleScreen> createState() => _WordScrambleScreenState();
}

enum _GlowState { none, correct, wrong }

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
  int _passageCorrect = 0;
  int _passageTotal = 0;

  List<_LetterTile?> _placedLetters = [];
  List<_LetterTile> _availableLetters = [];

  _GlowState _glowState = _GlowState.none;

  DateTime? _roundStart;
  int? _lastResponseTimeMs;

  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;
  final List<int> _wrongWordIds = [];

  final AudioPlayer _audioPlayer = AudioPlayer();

  static const int _maxWrongAttempts = 3;
  static const double _letterSize = 60.0;

  @override
  void initState() {
    super.initState();
    BgmService.playTrack(BgmTrack.game);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGame());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _reaction.dispose();
    super.dispose();
  }

  Future<void> _loadGame() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/student-home', (route) => false);
        }
      });
      return;
    }

    final batchId = args['batchId'] as int?;
    final gradeLevel = (args['gradeLevel'] as int?) ?? 1;
    final difficulty = (args['difficulty'] as String?) ?? 'easy';
    final passageCorrect = (args['passageCorrect'] as int?) ?? 0;
    final passageTotal = (args['passageTotal'] as int?) ?? 0;
    final student = context.read<StudentProvider>().currentStudent;

    if (batchId == null || student == null || student.id == null) {
      setState(() {
        _loading = false;
        _error = 'Not signed in or missing data.';
      });
      return;
    }

    try {
      final words = await DatabaseService.instance.getSampledWordsForBatch(batchId);
      if (words.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No words found for this game.';
        });
        return;
      }

      final questions = await DatabaseService.instance.getQuestionsForBatch(batchId);
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
          definition: w.definition,
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
        _passageCorrect = passageCorrect;
        _passageTotal = passageTotal;
        _loading = false;
      });

      _startRound();

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _reaction.show(YseReaction.letsGo, persistent: true);
    } catch (e) {
      debugPrint('WordScramble load ERROR: $e');
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
      debugPrint('Cue audio failed: $e');
    }
  }

  void _onLetterTap(_LetterTile tile) {
    if (_roundResolved) return;
    SfxService.tap();
    
    final emptyIndex = _placedLetters.indexWhere((p) => p == null);
    if (emptyIndex == -1) return;

    setState(() {
      _placedLetters[emptyIndex] = tile;
      _availableLetters.removeWhere((t) => t.id == tile.id);
    });

    if (_placedLetters.every((p) => p != null)) {
      _checkWord();
    }
  }

  void _onSlotTap(int index) {
    if (_roundResolved) return;
    final tile = _placedLetters[index];
    if (tile == null) return;

    SfxService.tap();
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

      setState(() {
        _roundResolved = true;
        _glowState = _GlowState.correct;
      });
      SfxService.correct();

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

      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      _advanceRound();
    } else {
      _wrongAttemptsThisRound++;
      _currentStreak = 0;

      setState(() => _glowState = _GlowState.wrong);
      SfxService.wrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);

      if (_wrongAttemptsThisRound >= _maxWrongAttempts) {
        _wrongWordIds.add(round.wordId);
        setState(() {
          _roundResolved = true;
          _glowState = _GlowState.none;
        });
        _revealCorrectAnswer(round);
        setState(() => _glowState = _GlowState.correct);
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        _advanceRound();
      } else {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;
        setState(() {
          _glowState = _GlowState.none;
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

  Future<void> _finishGame() async {
    try {
      final totalRounds = _rounds.length;
      final isPassing = totalRounds > 0 && (_correctCount / totalRounds) >= 0.70;

      if (isPassing) {
        _reaction.show(YseReaction.youDidIt, persistent: true);
        SfxService.celebration();
        await Future.delayed(const Duration(milliseconds: 1500));
      } else {
        _reaction.show(YseReaction.tryAgain, persistent: true);
        SfxService.fail();
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      
      if (!mounted) return;

      final wrongWordIds = List<int>.from(_wrongWordIds);

      final combinedScore = _passageCorrect + _correctCount;
      final combinedTotal = _passageTotal + _rounds.length;

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
          score: combinedScore,
          totalQuestions: combinedTotal,
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
      if (isPassing) {
        final badgeName = AchievementBadge.nameFor(_gradeLevel, _difficulty);
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

      final updated = await DatabaseService.instance.getStudentById(_studentId);
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
          unawaited(() async {
            try {
              final badges = await DatabaseService.instance.getBadgesForStudent(updated.id!);
              await FirestoreService.instance.updateEnrollmentSnapshot(
                classId: updated.classFirestoreId!,
                studentUid: updated.firebaseUid!,
                totalPoints: updated.totalPoints,
                badgeCount: badges.length,
                avatarIndex: updated.avatarIndex,
              );
            } catch (e) {
              debugPrint('Enrollment snapshot failed: $e');
            }
          }());
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        '/results',
        arguments: {
          'score': combinedScore,
          'totalQuestions': combinedTotal,
          'pointsDelta': pointsDelta,
          'gradeLevel': _gradeLevel,
          'difficulty': _difficulty,
          'isNewBadge': isNewBadge,
        },
      );
    } catch (e) {
      debugPrint('WordScramble finish ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save results. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.textMuted),
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

  double _slotSizeForWidth({
    required int wordLength,
    required double availableWidth,
  }) {
    const spacing = 4.0;
    const maxSize = 76.0;
    const minSize = 36.0;

    if (wordLength <= 0) return maxSize;

    final computed = (availableWidth - (wordLength - 1) * spacing) / wordLength;
    return computed.clamp(minSize, maxSize);
  }

  Widget _buildGame() {
    final round = _rounds[_currentIndex];
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final imageSize = (screenH * 0.26).clamp(170.0, 240.0);

    final slotAvailableWidth = screenW - AppSpacing.lg * 2;
    final slotSize = _slotSizeForWidth(
      wordLength: round.correctWord.length,
      availableWidth: slotAvailableWidth,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: 4),

                    YseReactionOverlay(
                      controller: _reaction,
                      size: 140,
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Center(
                      child: Container(
                        width: imageSize,
                        height: imageSize,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.border, width: 2),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Image.asset(
                          round.imagePath,
                          fit: BoxFit.contain,
                          cacheWidth: 400,
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
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text(
                          round.definition,
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.md),

                    Text(
                      _wrongAttemptsThisRound == 0
                          ? 'Tap the letters to spell the word'
                          : 'Try again, you can do this!',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    _buildSlots(round, slotSize),

                    const SizedBox(height: AppSpacing.xl),
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
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: _buildLetterPool(round),
            ),
          ],
        ),
      ),
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
            onPressed: () {
              SfxService.tap();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Spell the Word', style: AppText.h2),
                    const InfoButton(
                      title: 'How to Spell',
                      description: 'Unscramble the letters to spell the word.',
                      steps: [
                        'Look at the picture and read the definition.',
                        'Tap the letters at the bottom to fill the empty slots.',
                        'If you make a mistake, tap a filled slot to remove the letter.',
                        'When all slots are filled, it checks automatically.',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 20, color: AppColors.accentYellow),
                    const SizedBox(width: 6),
                    Text(
                      '${_correctCount * 5} pts',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textYellow),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    const Icon(Icons.flag_rounded, size: 20, color: AppColors.accentTeal),
                    const SizedBox(width: 6),
                    Text(
                      'Round ${_currentIndex + 1} / ${_rounds.length}',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTeal),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlots(_ScrambleRound round, double size) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: List.generate(_placedLetters.length, (i) {
        final tile = _placedLetters[i];
        final isFilled = tile != null;
        final isGlowingCorrect = _glowState == _GlowState.correct;
        final isGlowingWrong = _glowState == _GlowState.wrong && isFilled;

        final Color borderColor;
        final List<BoxShadow>? glow;

        if (isGlowingCorrect && isFilled) {
          borderColor = AppColors.accentGreen;
          glow = [BoxShadow(color: AppColors.accentGreen.withValues(alpha: 0.65), blurRadius: 22, spreadRadius: 3)];
        } else if (isGlowingWrong) {
          borderColor = AppColors.accentCoral;
          glow = [BoxShadow(color: AppColors.accentCoral.withValues(alpha: 0.65), blurRadius: 22, spreadRadius: 3)];
        } else if (isFilled) {
          borderColor = AppColors.accentTeal;
          glow = null;
        } else {
          borderColor = AppColors.textMuted;
          glow = null;
        }

        final Color fillColor;
        if (isGlowingCorrect && isFilled) {
          fillColor = AppColors.accentGreen.withValues(alpha: 0.12);
        } else if (isGlowingWrong) {
          fillColor = AppColors.accentCoral.withValues(alpha: 0.12);
        } else if (isFilled) {
          fillColor = AppColors.surface;
        } else {
          fillColor = Colors.transparent;
        }

        return GestureDetector(
          onTap: () => _onSlotTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: borderColor, width: 2.5),
              boxShadow: glow,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tile?.letter ?? '',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: size * 0.55,
                    fontWeight: FontWeight.w800,
                    color: isGlowingCorrect && isFilled
                        ? AppColors.textGreen
                        : isGlowingWrong
                            ? AppColors.textCoral
                            : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLetterPool(_ScrambleRound round) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: _availableLetters.map((tile) {
        return GestureDetector(
          onTap: () => _onLetterTap(tile),
          child: Container(
            width: _letterSize,
            height: _letterSize,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.accentTeal, width: 2.5),
              boxShadow: AppShadows.soft,
            ),
            child: Center(
              child: Text(
                tile.letter,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ScrambleRound {
  final int wordId;
  final String correctWord;
  final String correctAudioPath;
  final String imagePath;
  final String definition;
  final List<_LetterTile> scrambledLetters;

  _ScrambleRound({
    required this.wordId,
    required this.correctWord,
    required this.correctAudioPath,
    required this.imagePath,
    required this.definition,
    required this.scrambledLetters,
  });
}

class _LetterTile {
  final int id;
  final String letter;

  _LetterTile({required this.id, required this.letter});
}