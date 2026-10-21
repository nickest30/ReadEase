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
import '../../services/sync_service.dart';
import '../../utils/app_theme.dart';
import 'yse_reaction.dart';
import '../../widgets/info_button.dart';
import '../../utils/game_score.dart';

/// Bubble Pop, replaces the MCQ quiz for Grade 1 Medium.
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
  final List<int> _wrongWordIds = [];

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
      if (words.length < 4) {
        setState(() {
          _loading = false;
          _error = 'Not enough words in this lesson to play. Need at least 4.';
        });
        return;
      }

      final gameWords = words.toList();

      final questions =
          await DatabaseService.instance.getQuestionsForBatch(batchId);
      final qMap = <int, QuizQuestion>{};
      for (final q in questions) {
        qMap.putIfAbsent(q.wordId, () => q);
      }

      final rnd = Random();
      final rounds = <_RoundData>[];

      for (final correct in gameWords) {
        final pool = gameWords.where((w) => w.id != correct.id).toList();
        pool.shuffle(rnd);
        final distractors = pool.take(3).toList();

        while (distractors.length < 3) {
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

      // Play word audio for the FIRST round automatically
      _playWordAudio(_rounds[0].correctAudioPath);

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _reaction.show(YseReaction.letsGo, persistent: true);
    } catch (e) {
      debugPrint('BubblePop load ERROR: $e');
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

    // We DO NOT play the word audio here anymore. 
    // It was already played at the start of the round.
    // We just play the Correct/Wrong SFX immediately.

    final isCorrect = choice.isCorrect;

    if (isCorrect) {
      setState(() => _correctCount++);
      _currentStreak++;

      SfxService.correct();

      if (_currentStreak >= 3) {
        _reaction.show(YseReaction.hwaiting, persistent: true);
      } else {
        _reaction.show(YseReaction.nice, persistent: true);
      }
    } else {
      _currentStreak = 0;
      _wrongWordIds.add(round.correctWordId); 
      SfxService.wrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);
    }

    await Future.delayed(Duration(milliseconds: isCorrect ? 900 : 1300));
    if (!mounted) return;

    if (_currentIndex < _rounds.length - 1) {
      setState(() {
        _currentIndex++;
        _tappedChoiceWordId = null;
        _answered = false;
        _roundStart = DateTime.now();
      });
      
      // Play the word audio for the NEW round
      _playWordAudio(_rounds[_currentIndex].correctAudioPath);
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
      debugPrint('Word audio failed (continuing): $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Finish
  // ────────────────────────────────────────────────────────────

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
          wrongWordIdsJson: wrongWordIds.isEmpty ? null : '[${wrongWordIds.join(',')}]',
          completedAt: DateTime.now().toIso8601String(),
        ),
      );

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
          try {
            final badges = await DatabaseService.instance.getBadgesForStudent(updated.id!);
            await FirestoreService.instance.updateEnrollmentSnapshot(
              classId: updated.classFirestoreId!,
              studentUid: updated.firebaseUid!,
              totalPoints: updated.totalPoints,
              badgeCount: badges.length,
            );
          } catch (e) {
            debugPrint('Enrollment snapshot failed: $e');
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
      debugPrint('BubblePop finish ERROR: $e');
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
              SizedBox(
                height: 50,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    round.correctText.toUpperCase(),
                    style: AppText.display.copyWith(
                      fontSize: 40,
                      letterSpacing: 1.5,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Bubbles
        Expanded(child: _buildBubbleField(round)),

        // Yse bottom bar, reduced from 130 to 100 to give bubbles more space
        Container(
          height: 100,
          alignment: Alignment.center,
          child: YseReactionOverlay(
            controller: _reaction,
            size: 100,
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
                    const Text('Pop the Picture!', style: AppText.h2),
                    const InfoButton(
                      title: 'How to Pop',
                      description: 'Match the word to the correct picture.',
                      steps: [
                        'Read the word at the top of the screen.',
                        'Look at the 4 floating bubbles.',
                        'Tap the bubble that shows the correct picture.',
                        'If you are right, the bubble turns green!',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 20, color: AppColors.accentYellow),
                    const SizedBox(width: 6),
                    Text(
                      '${_correctCount * 5} pts',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textYellow,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    const Icon(Icons.flag_rounded,
                        size: 20, color: AppColors.accentTeal),
                    const SizedBox(width: 6),
                    Text(
                      'Round ${_currentIndex + 1} / ${_rounds.length}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTeal,
                      ),
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

  Widget _buildBubbleField(_RoundData round) {
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
          final bubbleSize = min(colW, rowH) * 0.82;

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
    final col = index % 2;
    final row = index ~/ 2;

    final verticalJitter = (index.isEven ? -8.0 : 8.0);

    final left = col * colW + (colW - bubbleSize) / 2;
    final top = row * rowH + (rowH - bubbleSize) / 2 + verticalJitter;

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
        final t = _floatController.value * 2 * pi + widget.phaseOffset;
        final dy = sin(t) * 8.0;

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
            padding: EdgeInsets.all(widget.size * 0.10),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}