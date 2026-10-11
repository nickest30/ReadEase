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

/// Floor is Lava — Grade 4 Hard.
///
/// Same mechanic as Hangman (letter guessing), re-skinned as the
/// universally loved childhood game. Yse stands on a platform while
/// lava rises 1/8 per wrong guess. At 8 wrongs the lava reaches the
/// platform and the word is revealed; Yse escapes.
///
/// Kid-safe: no hanging imagery. Aligns with DepEd Child Protection
/// Policy (DO No. 40, s. 2012).
class FloorIsLavaScreen extends StatefulWidget {
  const FloorIsLavaScreen({super.key});

  @override
  State<FloorIsLavaScreen> createState() => _FloorIsLavaScreenState();
}

enum _GlowState { none, correct, wrong }

class _FloorIsLavaScreenState extends State<FloorIsLavaScreen> {
  bool _loading = true;
  String? _error;

  List<_LavaRound> _rounds = [];
  Map<int, QuizQuestion> _questionByWordId = {};

  int _batchId = 0;
  int _studentId = 0;
  int _gradeLevel = 4;
  String _difficulty = 'hard';

  int _currentIndex = 0;
  int _correctCount = 0;
  bool _roundResolved = false;
  _GlowState _glowState = _GlowState.none;

  String _currentWord = '';
  final Set<String> _correctGuesses = {};
  final Set<String> _wrongGuesses = {};
  final Set<String> _hintRevealed = {};
  int _wrongGuessCount = 0;
  bool _hintFired = false;

  DateTime? _roundStart;
  int? _lastResponseTimeMs;

  final YseReactionController _reaction = YseReactionController();
  int _currentStreak = 0;
  final List<int> _wrongWordIds = [];

  final AudioPlayer _audioPlayer = AudioPlayer();

  static const int _maxWrong = 8;
  static const int _hintThreshold = 5;
  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
    'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z',
  ];

  // Lava colors
  static const Color _lavaBright = Color(0xFFFF6B6B);
  static const Color _lavaDeep = Color(0xFFE84A4A);
  static const Color _platformStone = Color(0xFFFFF4E0);
  static const Color _platformEdge = Color(0xFFC77B4A);

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

      final rounds = <_LavaRound>[];
      for (final w in words) {
        final word = w.text.toUpperCase().trim();
        if (word.isEmpty) continue;
        if (!RegExp(r'^[A-Z]+$').hasMatch(word)) continue;

        rounds.add(_LavaRound(
          wordId: w.id!,
          word: word,
          cueAudioPath: w.lessonCueAudio ?? w.audioAsset,
          wordAudioPath: w.audioAsset,
          imagePath: w.imageAsset,
          definition: w.definition,
        ));
      }

      if (!mounted) return;

      if (rounds.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No suitable words for this game.';
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
      debugPrint('🌋 FloorIsLava load ERROR: $e');
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
      _currentWord = round.word;
      _correctGuesses.clear();
      _wrongGuesses.clear();
      _hintRevealed.clear();
      _wrongGuessCount = 0;
      _hintFired = false;
      _roundResolved = false;
      _glowState = _GlowState.none;
      _roundStart = DateTime.now();
    });
    _playAudio(round.cueAudioPath);
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
      debugPrint('🔊 Audio failed (continuing): $e');
    }
  }

  // ────────────────────────────────────────────────────────────
  // Guessing
  // ────────────────────────────────────────────────────────────

  Future<void> _onLetterTap(String letter) async {
    if (_roundResolved) return;
    if (_correctGuesses.contains(letter) || _wrongGuesses.contains(letter)) {
      return;
    }

    final isCorrect = _currentWord.contains(letter);

    setState(() {
      if (isCorrect) {
        _correctGuesses.add(letter);
      } else {
        _wrongGuesses.add(letter);
        _wrongGuessCount++;
      }
    });

    if (isCorrect) {
      GameSfx.instance.playCorrect();
      if (_isWordComplete()) {
        await _onRoundWin();
        return;
      }
    } else {
      GameSfx.instance.playWrong();

      // Fire hint at threshold (once per round)
      if (!_hintFired && _wrongGuessCount >= _hintThreshold) {
        final wonByHint = _fireHint();
        if (wonByHint) {
          await _onRoundWin();
          return;
        }
      }

      // Check loss
      if (_wrongGuessCount >= _maxWrong) {
        await _onRoundLoss();
        return;
      }
    }

    // Update Yse reaction on wrong only
    if (!isCorrect) {
      if (_wrongGuessCount >= 6) {
        _reaction.show(YseReaction.tryAgain, persistent: true);
      } else if (_wrongGuessCount >= 4) {
        _reaction.show(YseReaction.hwaiting, persistent: true);
      }
    }
  }

  bool _fireHint() {
    _hintFired = true;
    final lettersInWord = _currentWord.split('').toSet();
    final candidates = lettersInWord
        .where((c) =>
            !_correctGuesses.contains(c) && !_hintRevealed.contains(c))
        .toList();
    if (candidates.isEmpty) return false;

    final pick = candidates[Random().nextInt(candidates.length)];
    setState(() => _hintRevealed.add(pick));

    return _isWordComplete();
  }

  bool _isWordComplete() {
    for (final char in _currentWord.split('')) {
      if (!_correctGuesses.contains(char) && !_hintRevealed.contains(char)) {
        return false;
      }
    }
    return true;
  }

  // ────────────────────────────────────────────────────────────
  // Round resolution
  // ────────────────────────────────────────────────────────────

  Future<void> _onRoundWin() async {
    final round = _rounds[_currentIndex];
    _lastResponseTimeMs = _roundStart == null
        ? null
        : DateTime.now().difference(_roundStart!).inMilliseconds;

    setState(() {
      _roundResolved = true;
      _glowState = _GlowState.correct;
      _correctCount++;
    });

    _currentStreak++;
    if (_currentStreak >= 3) {
      _reaction.show(YseReaction.hwaiting, persistent: true);
    } else {
      _reaction.show(YseReaction.nice, persistent: true);
    }

    await _playAudio(round.wordAudioPath);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _advanceRound();
  }

  Future<void> _onRoundLoss() async {
    final round = _rounds[_currentIndex];
    _wrongWordIds.add(round.wordId);
    _currentStreak = 0;

    setState(() {
      _roundResolved = true;
      _glowState = _GlowState.wrong;
      _correctGuesses.addAll(_currentWord.split('').toSet());
    });

    _reaction.show(YseReaction.tryAgain, persistent: true);

    await _playAudio(round.wordAudioPath);

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    _advanceRound();
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
                wasCorrect ? 'lava_correct' : 'lava_wrong',
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
      debugPrint('🌋 FloorIsLava finish ERROR: $e');
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

  /// Three lava Yse poses.
  ///   - 0–3 wrongs: safe (cheerful)
  ///   - 4–7 wrongs: worried
  ///   - 8 wrongs (auto-reveal): escape (jumping)
  String _ysePoseFor(int wrongs) {
    if (_roundResolved && _glowState == _GlowState.wrong) {
      return 'yse_lava_escape.png';
    }
    if (wrongs >= 4) return 'yse_lava_worried.png';
    return 'yse_lava_safe.png';
  }

  Widget _buildGame() {
    final round = _rounds[_currentIndex];

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

                // Yse on platform
                _buildPlatform(),

                const SizedBox(height: AppSpacing.md),

                // Image (small, above the word for context)
                Container(
                  width: 90,
                  height: 90,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: Image.asset(
                    round.imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Word slots
                _buildWordSlots(),

                const SizedBox(height: AppSpacing.md),

                // Counter
                _buildCounter(),

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),

        // Letter bank
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.studentBg,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: _buildKeyboard(),
        ),

        // Lava meter
        _buildLavaMeter(),
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
                const Text('Escape the Lava!', style: AppText.h2),
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

  // ────────────────────────────────────────────────────────────
  // Platform + Yse
  // ────────────────────────────────────────────────────────────

  Widget _buildPlatform() {
    final pose = _ysePoseFor(_wrongGuessCount);

    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Yse
          Positioned(
            bottom: 20,
            child: Image.asset(
              'assets/images/mascot/lava/$pose',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 120,
                height: 120,
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 80,
                  color: AppColors.accentTeal,
                ),
              ),
            ),
          ),

          // Platform base
          Positioned(
            bottom: 0,
            child: Container(
              width: 180,
              height: 28,
              decoration: BoxDecoration(
                color: _platformStone,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _platformEdge, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _platformEdge.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Lava meter — rises 1/8 per wrong guess
  // ────────────────────────────────────────────────────────────

  Widget _buildLavaMeter() {
    final ratio = (_wrongGuessCount / _maxWrong).clamp(0.0, 1.0);

    return Container(
      height: 32,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Stack(
          children: [
            // Filling lava
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: 32 * ratio,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_lavaDeep, _lavaBright],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ),

            // Label
            Center(
              child: Text(
                _wrongGuessCount >= _maxWrong - 1
                    ? 'LAVA RISING!'
                    : 'Lava: $_wrongGuessCount / $_maxWrong',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ratio > 0.5
                      ? Colors.white
                      : AppColors.textPrimary,
                  shadows: ratio > 0.5
                      ? [
                          const Shadow(
                            blurRadius: 3,
                            color: Colors.black26,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Word slots
  // ────────────────────────────────────────────────────────────

  Widget _buildWordSlots() {
    final letters = _currentWord.split('');
    final size = letters.length <= 6
        ? 46.0
        : letters.length <= 8
            ? 40.0
            : 34.0;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: letters.map((char) {
        final isCorrect = _correctGuesses.contains(char);
        final isHint = _hintRevealed.contains(char);
        final revealed = isCorrect || isHint;

        Color borderColor;
        Color fillColor;
        Color textColor;

        if (_glowState == _GlowState.correct && revealed) {
          borderColor = AppColors.accentGreen;
          fillColor = AppColors.accentGreen.withValues(alpha: 0.14);
          textColor = AppColors.textGreen;
        } else if (_glowState == _GlowState.wrong && revealed) {
          borderColor = AppColors.accentCoral;
          fillColor = AppColors.accentCoral.withValues(alpha: 0.14);
          textColor = AppColors.textCoral;
        } else if (isHint) {
          borderColor = AppColors.accentYellow;
          fillColor = AppColors.accentYellow.withValues(alpha: 0.14);
          textColor = AppColors.textYellow;
        } else if (isCorrect) {
          borderColor = AppColors.accentTeal;
          fillColor = AppColors.surface;
          textColor = AppColors.textPrimary;
        } else {
          borderColor = AppColors.textMuted;
          fillColor = Colors.transparent;
          textColor = AppColors.textMuted;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: borderColor, width: 2.5),
          ),
          child: Center(
            child: Text(
              revealed ? char : '',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: size * 0.55,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCounter() {
    final Color color;
    if (_wrongGuessCount >= 6) {
      color = AppColors.textCoral;
    } else if (_wrongGuessCount >= 4) {
      color = AppColors.textOrange;
    } else {
      color = AppColors.textMuted;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Wrong: $_wrongGuessCount / $_maxWrong',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        if (_hintFired)
          const Text(
            '· hint used',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textYellow,
            ),
          ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // Keyboard
  // ────────────────────────────────────────────────────────────

  Widget _buildKeyboard() {
    const rowLengths = [5, 5, 5, 5, 5, 1];
    int cursor = 0;

    return Column(
      children: rowLengths.map((len) {
        final rowLetters = _alphabet.sublist(cursor, cursor + len);
        cursor += len;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowLetters.map((letter) {
              final isCorrect = _correctGuesses.contains(letter);
              final isWrong = _wrongGuesses.contains(letter);
              final isHintLetter = _hintRevealed.contains(letter);
              final isDisabled = isCorrect || isWrong || isHintLetter;

              Color bg;
              Color fg;
              Color border;
              if (_glowState == _GlowState.correct && isCorrect) {
                bg = AppColors.accentGreen.withValues(alpha: 0.2);
                fg = AppColors.textGreen;
                border = AppColors.accentGreen;
              } else if (_glowState == _GlowState.wrong && isWrong) {
                bg = AppColors.accentCoral.withValues(alpha: 0.2);
                fg = AppColors.textCoral;
                border = AppColors.accentCoral;
              } else if (isCorrect) {
                bg = AppColors.accentTeal.withValues(alpha: 0.2);
                fg = AppColors.textTeal;
                border = AppColors.accentTeal;
              } else if (isWrong) {
                bg = AppColors.border.withValues(alpha: 0.4);
                fg = AppColors.textMuted;
                border = AppColors.border;
              } else if (isHintLetter) {
                bg = AppColors.accentYellow.withValues(alpha: 0.2);
                fg = AppColors.textYellow;
                border = AppColors.accentYellow;
              } else {
                bg = AppColors.surface;
                fg = AppColors.textPrimary;
                border = AppColors.accentTeal;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () => _onLetterTap(letter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius:
                          BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: border, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Data model
// ═══════════════════════════════════════════════════════════════

class _LavaRound {
  final int wordId;
  final String word;
  final String cueAudioPath;
  final String wordAudioPath;
  final String imagePath;
  final String definition;

  _LavaRound({
    required this.wordId,
    required this.word,
    required this.cueAudioPath,
    required this.wordAudioPath,
    required this.imagePath,
    required this.definition,
  });
}