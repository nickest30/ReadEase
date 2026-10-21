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
import '../../widgets/info_button.dart';
import 'yse_reaction.dart';
import '../../utils/game_score.dart';

class DragDropScreen extends StatefulWidget {
  const DragDropScreen({super.key});

  @override
  State<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends State<DragDropScreen> {
  bool _loading = true;
  String? _error;

  List<_RoundData> _rounds = [];
  Map<int, QuizQuestion> _questionByWordId = {};

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 1;
  String _difficulty = 'hard';

  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongAttemptsThisRound = 0;
  bool _roundResolved = false;
  int? _forcedCorrectWordId;
  DateTime? _roundStart;
  int? _lastResponseTimeMs;
  bool _showWrongFeedback = false;

  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;
  final List<int> _wrongWordIds = [];

  final AudioPlayer _audioPlayer = AudioPlayer();

  static const int _maxWrongAttempts = 3;

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
      if (words.length < 4) {
        setState(() {
          _loading = false;
          _error = 'Not enough words in this lesson to play. Need at least 4.';
        });
        return;
      }

      final gameWords = words.toList();

      final questions = await DatabaseService.instance.getQuestionsForBatch(batchId);
      final qMap = <int, QuizQuestion>{};
      for (final q in questions) {
        qMap.putIfAbsent(q.wordId, () => q);
      }

      final rnd = Random();
      final rounds = <_RoundData>[];

      for (final correct in gameWords) {
        final pool = gameWords.where((w) => w.id != correct.id).toList();

        pool.sort((a, b) {
          int score(String candidate) {
            int s = 0;
            if (candidate.length == correct.text.length) s += 2;
            if (candidate.isNotEmpty &&
                correct.text.isNotEmpty &&
                candidate[0].toLowerCase() == correct.text[0].toLowerCase()) {
              s += 1;
            }
            return s;
          }
          return score(b.text).compareTo(score(a.text));
        });

        final distractors = pool.take(3).toList();
        while (distractors.length < 3) {
          distractors.add(pool[rnd.nextInt(pool.length)]);
        }

        final choices = <_WordTile>[];
        for (final w in [correct, ...distractors]) {
          choices.add(_WordTile(
            wordId: w.id!,
            wordText: w.text,
            isCorrect: w.id == correct.id,
          ));
        }
        choices.shuffle(rnd);

        rounds.add(_RoundData(
          correctWordId: correct.id!,
          correctText: correct.text,
          correctAudioPath: correct.audioAsset,
          imagePath: correct.imageAsset,
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

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _reaction.show(YseReaction.letsGo, persistent: true);
    } catch (e) {
      debugPrint('DragDrop load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load game. Try again.';
      });
    }
  }

  Future<void> _onTileDropped(_WordTile tile) async {
    if (_roundResolved) return;
    final round = _rounds[_currentIndex];

    final responseTimeMs = _roundStart == null
        ? null
        : DateTime.now().difference(_roundStart!).inMilliseconds;

    if (tile.isCorrect) {
      _lastResponseTimeMs = responseTimeMs;
      setState(() => _roundResolved = true);

      _playWordAudio(round.correctAudioPath);
      SfxService.correct();

      final firstAttempt = _wrongAttemptsThisRound == 0;
      if (firstAttempt) {
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
      SfxService.wrong();
      _reaction.show(YseReaction.tryAgain, persistent: true);

      setState(() => _showWrongFeedback = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showWrongFeedback = false);
      });

      if (_wrongAttemptsThisRound >= _maxWrongAttempts) {
        setState(() => _roundResolved = true);
        _wrongWordIds.add(round.correctWordId);

        await Future.delayed(const Duration(milliseconds: 400));
        _playWordAudio(round.correctAudioPath);

        setState(() => _forcedCorrectWordId = round.correctWordId);
        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        _advanceRound();
      }
    }
  }

  void _advanceRound() {
    if (_currentIndex < _rounds.length - 1) {
      setState(() {
        _currentIndex++;
        _roundResolved = false;
        _wrongAttemptsThisRound = 0;
        _forcedCorrectWordId = null;
        _roundStart = DateTime.now();
      });
    } else {
      _finishGame();
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
      debugPrint('Word audio failed: $e');
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

      final args = ModalRoute.of(context)!.settings.arguments as Map;
      final score = GameScore.fromArgs(
        args,
        gameCorrect: _correctCount,
        gameTotal: _rounds.length,
      );

      final pointsDelta = await DatabaseService.instance.computePointsDeltaForBatch(
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
            selectedAnswer: wasCorrect ? 'drag_correct' : 'drag_wrong',
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
          'score': score.correct,
          'totalQuestions': score.total,
          'pointsDelta': pointsDelta,
          'gradeLevel': _gradeLevel,
          'difficulty': _difficulty,
          'isNewBadge': isNewBadge,
        },
      );
    } catch (e) {
      debugPrint('DragDrop finish ERROR: $e');
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

  Widget _buildGame() {
    final round = _rounds[_currentIndex];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.sm),

            Expanded(
              flex: 6,
              child: _buildDropZone(round),
            ),

            const SizedBox(height: AppSpacing.sm),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                _wrongAttemptsThisRound == 0
                    ? 'Drag the word onto the picture'
                    : 'Try again, which word is this?',
                style: AppText.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            _buildTileRow(round),

            const SizedBox(height: AppSpacing.sm),

            _buildBottomArea(),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Drag the Word', style: AppText.h2),
                const InfoButton(
                  title: 'How to Play',
                  description: 'Match the word to the correct picture.',
                  steps: [
                    'Look at the picture in the center.',
                    'Read the 4 word tiles below.',
                    'Drag the correct word onto the picture.',
                    'If you get it wrong, you can try again!',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropZone(_RoundData round) {
    final showCorrectHighlight = _roundResolved && _forcedCorrectWordId == round.correctWordId;
    final showSuccessGlow = _roundResolved && _wrongAttemptsThisRound == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: DragTarget<_WordTile>(
        onWillAcceptWithDetails: (details) => !_roundResolved,
        onAcceptWithDetails: (details) {
          _onTileDropped(details.data);
        },
        builder: (context, candidate, rejected) {
          final isHovering = candidate.isNotEmpty;

          Color borderColor;
          double borderWidth = 3;
          List<BoxShadow> shadows = AppShadows.soft;

          if (_showWrongFeedback) {
            borderColor = AppColors.accentCoral;
            borderWidth = 4;
            shadows = [
              BoxShadow(
                color: AppColors.accentCoral.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ];
          } else if (showCorrectHighlight || showSuccessGlow) {
            borderColor = AppColors.accentGreen;
            borderWidth = 4;
            shadows = [
              BoxShadow(
                color: AppColors.accentGreen.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ];
          } else if (isHovering) {
            borderColor = AppColors.accentTeal;
            borderWidth = 4;
            shadows = [
              BoxShadow(
                color: AppColors.accentTeal.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ];
          } else {
            borderColor = AppColors.border;
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadows,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
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
          );
        },
      ),
    );
  }

  Widget _buildTileRow(_RoundData round) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: round.choices.map((tile) {
          final isForcedCorrect = _forcedCorrectWordId == tile.wordId;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _DraggableWordTile(
                tile: tile,
                isLocked: _roundResolved,
                isForcedCorrect: isForcedCorrect,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomArea() {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          YseReactionOverlay(
            controller: _reaction,
            size: 100,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, size: 20, color: AppColors.accentYellow),
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
              const Icon(Icons.flag_rounded, size: 20, color: AppColors.accentTeal),
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
    );
  }
}

class _RoundData {
  final int correctWordId;
  final String correctText;
  final String correctAudioPath;
  final String imagePath;
  final List<_WordTile> choices;

  _RoundData({
    required this.correctWordId,
    required this.correctText,
    required this.correctAudioPath,
    required this.imagePath,
    required this.choices,
  });
}

class _WordTile {
  final int wordId;
  final String wordText;
  final bool isCorrect;

  _WordTile({
    required this.wordId,
    required this.wordText,
    required this.isCorrect,
  });
}

class _DraggableWordTile extends StatefulWidget {
  final _WordTile tile;
  final bool isLocked;
  final bool isForcedCorrect;

  const _DraggableWordTile({
    required this.tile,
    required this.isLocked,
    required this.isForcedCorrect,
  });

  @override
  State<_DraggableWordTile> createState() => _DraggableWordTileState();
}

class _DraggableWordTileState extends State<_DraggableWordTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Color _bgColor() {
    if (widget.isForcedCorrect) {
      return AppColors.accentGreen.withValues(alpha: 0.15);
    }
    return AppColors.surface;
  }

  Color _borderColor() {
    if (widget.isForcedCorrect) return AppColors.accentGreen;
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: _borderColor(), width: 2),
        boxShadow: widget.isForcedCorrect
            ? [
                BoxShadow(
                  color: AppColors.accentGreen.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : AppShadows.soft,
      ),
      child: Center(
        child: Text(
          tile.wordText.toUpperCase(),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: widget.isForcedCorrect
                ? AppColors.textGreen
                : AppColors.textPrimary,
          ),
        ),
      ),
    );

    if (widget.isLocked) {
      return AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final t = _shakeController.value;
          final dx = t == 0 ? 0.0 : (1 - t) * 6 * (t * 20 % 2 < 1 ? 1 : -1);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: card,
      );
    }

    return LongPressDraggable<_WordTile>(
      data: tile,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 90,
          child: Transform.scale(
            scale: 1.15,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: AppColors.accentTeal,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  tile.wordText.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}