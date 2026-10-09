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

/// Bubble Pop — replaces the MCQ quiz for Grade 1 Medium.
///
/// 7 rounds. Each round: word shown at top, 4 floating bubbles with
/// images below. Tap the bubble matching the word. Correct → +5 pts.
///
/// Writes same SQLite schema as quiz_play_screen:
///   - quiz_attempts row (score = correct rounds)
///   - quiz_question_responses rows (one per round)
///   - word mastery + encounters
///   - badge if passing (≥70%)
class BubblePopScreen extends StatefulWidget {
  const BubblePopScreen({super.key});

  @override
  State<BubblePopScreen> createState() => _BubblePopScreenState();
}

class _BubblePopScreenState extends State<BubblePopScreen> {
  // ── Loading ──
  bool _loading = true;
  String? _error;

  // ── Game data ──
  List<_RoundData> _rounds = [];
  Map<int, QuizQuestion> _questionByWordId = {};

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 1;
  String _difficulty = 'medium';

  // ── Round state ──
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _tappedChoiceWordId;       // which bubble was tapped
  bool _answered = false;         // locked for the current round
  DateTime? _roundStart;
  int? _lastResponseTimeMs;       // latest round's response time

  // ── [GAME-LAYER] Yse reactions + streak ──
  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;

  // ── Audio ──
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    final difficulty = (args['difficulty'] as String?) ?? 'medium';
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
      if (words.length < 4) {
        setState(() {
          _loading = false;
          _error =
              'Not enough words in this lesson to play. Need at least 4.';
        });
        return;
      }

      // Cap at 7 rounds (Medium quiz size)
      final gameWords = words.take(7).toList();

      final questions =
          await DatabaseService.instance.getQuestionsForBatch(batchId);
      final qMap = <int, QuizQuestion>{};
      for (final q in questions) {
        qMap.putIfAbsent(q.wordId, () => q);
      }

      // Build rounds: 1 correct + 3 distractors per round
      final rnd = Random();
      final rounds = <_RoundData>[];

      for (final correct in gameWords) {
        // Candidate distractors = other words in the batch
        final pool = gameWords.where((w) => w.id != correct.id).toList();
        pool.shuffle(rnd);
        final distractors = pool.take(3).toList();

        // Should always have 3, since we required >=4 words
        while (distractors.length < 3) {
          // Safety fallback — duplicate a distractor rather than crash
          distractors.add(pool[rnd.nextInt(pool.length)]);
        }

        final choices = <_BubbleChoice>[];
        for (final w in [correct, ...distractors]) {
          choices.add(_BubbleChoice(
            wordId: w.id!,
            wordText: w.text,
            imagePath: w.imageAsset,
            isCorrect: w.id == correct.id,
          ));
        }
        choices.shuffle(rnd);

        rounds.add(_RoundData(
          correctWordId: correct.id!,
          correctText: correct.text,
          correctAudioPath: correct.audioAsset,
          choices: choices,
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
        _roundStart = DateTime.now();
      });

      // [GAME-LAYER] LET'S GO — persistent
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _reaction.show(YseReaction.letsGo, persistent: true);
    } catch (e) {
      debugPrint('🫧 BubblePop load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load game. Try again.';
      });
    }
  }

  // ────────────────────────────────────────────────────────────
  // Bubble tap
  // ────────────────────────────────────────────────────────────

  Future<void> _onBubbleTap(_BubbleChoice choice) async {
    if (_answered) return;
    final round = _rounds[_currentIndex];

    final responseTimeMs = _roundStart == null
        ? null
        : DateTime.now().difference(_roundStart!).inMilliseconds;

    setState(() {
      _answered = true;
      _tappedChoiceWordId = choice.wordId;
      _lastResponseTimeMs = responseTimeMs;
    });

    // Play the tapped word's audio immediately for feedback
    _playWordAudio(round.correctAudioPath);

    final isCorrect = choice.isCorrect;

    if (isCorrect) {
      setState(() => _correctCount++);
      _currentStreak++;

      GameSfx.instance.playCorrect();

      if (_currentStreak >= 3) {
        _reaction.show(YseReaction.hwaiting, persistent: true);
      } else {
        _reaction.show(YseReaction.nice, persistent: true);
      }
    } else {
      _currentStreak = 0;
      _wrongWordIds.add(round.correctWordId);   // ← ADD THIS
      GameSfx.instance.playWrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);
    }

    // Hold the highlighted state briefly so the learner sees result
    await Future.delayed(Duration(milliseconds: isCorrect ? 900 : 1300));
    if (!mounted) return;

    if (_currentIndex < _rounds.length - 1) {
      setState(() {
        _currentIndex++;
        _tappedChoiceWordId = null;
        _answered = false;
        _roundStart = DateTime.now();
      });
    } else {
      await _finishGame();
    }
  }

  Future<void> _playWordAudio(String assetPath) async {
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
  // Finish — same DB writes as quiz/memory-match
  // ────────────────────────────────────────────────────────────

  Future<void> _finishGame() async {
    try {
      // [GAME-LAYER] YOU DID IT before transitioning
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

      // One response per round
      for (final round in _rounds) {
        final q = _questionByWordId[round.correctWordId];
        if (q == null) continue;
        final wasCorrect = !_wrongWordIds.contains(round.correctWordId);
        await DatabaseService.instance.saveQuestionResponse(
          QuizQuestionResponse(
            attemptId: attemptId,
            questionId: q.id ?? 0,
            selectedAnswer: wasCorrect ? 'bubble_correct' : 'bubble_wrong',
            isCorrect: wasCorrect,
            responseTimeMs: wasCorrect ? _lastResponseTimeMs : null,
          ),
        );
      }

      for (final round in _rounds) {
        final wordId = round.correctWordId;
        final wasCorrect = !_wrongWordIds.contains(wordId);
        await DatabaseService.instance.recordWordEncounter(_studentId, wordId);
        await DatabaseService.instance.updateWordMastery(
          studentId: _studentId,
          wordId: wordId,
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
      debugPrint('🫧 BubblePop finish ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save results. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Track wrong rounds during play so we can write them at the end
  final List<int> _wrongWordIds = [];

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

        // Word prompt
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              Text(
                'Pop the picture of',
                style: AppText.caption.copyWith(fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                round.correctText.toUpperCase(),
                style: AppText.display.copyWith(
                  fontSize: 40,
                  letterSpacing: 1.5,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Bubbles
        Expanded(child: _buildBubbleField(round)),

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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                const Text('Pop the Picture!', style: AppText.h2),
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

  Widget _buildBubbleField(_RoundData round) {
    // 2×2 grid with vertical offset for organic bubble feel.
    // Odd rows are indented slightly; each bubble also bobs up/down.
    final choices = round.choices;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colW = constraints.maxWidth / 2;
          final rowH = constraints.maxHeight / 2;
          final bubbleSize = min(colW, rowH) * 0.78;

          return Stack(
            children: [
              for (var i = 0; i < choices.length && i < 4; i++)
                _positionedBubble(
                  choice: choices[i],
                  index: i,
                  colW: colW,
                  rowH: rowH,
                  bubbleSize: bubbleSize,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedBubble({
    required _BubbleChoice choice,
    required int index,
    required double colW,
    required double rowH,
    required double bubbleSize,
  }) {
    // 2×2 grid positions
    final col = index % 2;
    final row = index ~/ 2;

    // Slight vertical offset per bubble for organic look
    final verticalJitter = (index.isEven ? -8.0 : 8.0);

    // Bubble center in local coords
    final left = col * colW + (colW - bubbleSize) / 2;
    final top = row * rowH + (rowH - bubbleSize) / 2 + verticalJitter;

    // Determine visual state
    final isTapped = _tappedChoiceWordId == choice.wordId;
    final showCorrect = _answered && choice.isCorrect;
    final showWrong = _answered && isTapped && !choice.isCorrect;

    return Positioned(
      left: left,
      top: top,
      width: bubbleSize,
      height: bubbleSize,
      child: _FloatingBubble(
        size: bubbleSize,
        phaseOffset: index * 0.7,
        showCorrect: showCorrect,
        showWrong: showWrong,
        dimmed: _answered && !showCorrect && !showWrong,
        onTap: () => _onBubbleTap(choice),
        child: Image.asset(
          choice.imagePath,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.image_outlined,
            size: 40,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════════════════════════

class _RoundData {
  final int correctWordId;
  final String correctText;
  final String correctAudioPath;
  final List<_BubbleChoice> choices;

  _RoundData({
    required this.correctWordId,
    required this.correctText,
    required this.correctAudioPath,
    required this.choices,
  });
}

class _BubbleChoice {
  final int wordId;
  final String wordText;
  final String imagePath;
  final bool isCorrect;

  _BubbleChoice({
    required this.wordId,
    required this.wordText,
    required this.imagePath,
    required this.isCorrect,
  });
}

// ═══════════════════════════════════════════════════════════════
// Floating bubble widget
// ═══════════════════════════════════════════════════════════════

class _FloatingBubble extends StatefulWidget {
  final double size;
  final double phaseOffset;
  final bool showCorrect;
  final bool showWrong;
  final bool dimmed;
  final VoidCallback onTap;
  final Widget child;

  const _FloatingBubble({
    required this.size,
    required this.phaseOffset,
    required this.showCorrect,
    required this.showWrong,
    required this.dimmed,
    required this.onTap,
    required this.child,
  });

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Color _borderColor() {
    if (widget.showCorrect) return AppColors.accentGreen;
    if (widget.showWrong) return AppColors.accentCoral;
    return AppColors.accentTeal;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        // Sine wave produces smooth up/down motion
        final t = _floatController.value * 2 * pi + widget.phaseOffset;
        final dy = sin(t) * 8.0; // ±8 px

        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.dimmed ? 0.4 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: _borderColor(),
                width: widget.showCorrect || widget.showWrong ? 5 : 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _borderColor().withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: EdgeInsets.all(widget.size * 0.14),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}