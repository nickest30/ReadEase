import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../models/content_models.dart';
import '../../services/database_service.dart';
import '../../services/game_sfx.dart';
import '../../utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';

/// PassageScreen — Grade 4+.
///
/// Flow:
///   1. Illustration + title
///   2. Sentences played one at a time (active sentence highlighted, auto-scrolled)
///   3. Comprehension questions (mascot top, question middle, answers bottom)
///   4. Passage score passed to the game via route args
class PassageScreen extends StatefulWidget {
  const PassageScreen({super.key});

  @override
  State<PassageScreen> createState() => _PassageScreenState();
}

enum _PassagePhase { loading, reading, questions, done }

class _PassageScreenState extends State<PassageScreen> {
  _PassagePhase _phase = _PassagePhase.loading;
  String? _error;

  Passage? _passage;
  List<PassageSentence> _sentences = [];
  List<PassageQuestion> _questions = [];

  int _activeSentenceIndex = 0;
  bool _isPlaying = false;
  bool _hasStartedReading = false; // controls the Ready / Next Sentence button
  bool _hasCompletedBefore = false; // shows a Skip-to-Questions button

  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool _answered = false;
  int _passageCorrect = 0;

  // Cached choices per question — prevents reshuffle on rebuild.
  List<String>? _cachedChoices;
  int _cachedChoicesForIndex = -1;

  // Sentence scroll + per-sentence keys for auto-scroll.
  final ScrollController _sentenceScroll = ScrollController();
  final List<GlobalKey> _sentenceKeys = [];

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _questionAudioPlayer = AudioPlayer();
  bool _isPlayingQuestion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPassage());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _questionAudioPlayer.dispose();
    _sentenceScroll.dispose();
    super.dispose();
  }

  Future<void> _loadPassage() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final passageKey = args['passageId'] as String?;

    final studentId = context.read<StudentProvider>().currentStudent?.id;
    final batchIdArg = args['batchId'] as int?;

    if (passageKey == null || passageKey.isEmpty) {
      Navigator.of(context).pushReplacementNamed(
        '/game-intro',
        arguments: args,
      );
      return;
    }

    final passage = await DatabaseService.instance.getPassageByKey(passageKey);
    if (passage == null || passage.id == null) {
      setState(() {
        _phase = _PassagePhase.loading;
        _error = 'Passage not found.';
      });
      return;
    }

    final sentences =
        await DatabaseService.instance.getSentencesForPassage(passage.id!);
    final questions =
        await DatabaseService.instance.getQuestionsForPassage(passage.id!);

    // Did this student already finish this batch before?
    bool alreadyDone = false;
    if (studentId != null && batchIdArg != null) {
      final prior = await DatabaseService.instance
          .getQuizAttempts(studentId, batchIdArg);
      alreadyDone = prior.isNotEmpty;
    }

    if (!mounted) return;

    _sentenceKeys.clear();
    for (int i = 0; i < sentences.length; i++) {
      _sentenceKeys.add(GlobalKey());
    }

    setState(() {
      _passage = passage;
      _sentences = sentences;
      _questions = questions;
      _phase = _PassagePhase.reading;
      _activeSentenceIndex = 0;
      _hasStartedReading = false;
      _hasCompletedBefore = alreadyDone;
    });
  }

  /// Some installs still carry the old /passages/ path — retry from /words/.
  String _resolveIllustrationPath(String raw) {
    if (raw.contains('/passages/')) {
      return raw.replaceFirst('/passages/', '/words/');
    }
    return raw;
  }

  Future<void> _playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    final sentence = _sentences[index];

    setState(() {
      _activeSentenceIndex = index;
      _isPlaying = true;
      _hasStartedReading = true;
    });

    _scrollToActiveSentence();

    try {
      final clean = sentence.audio.startsWith('assets/')
          ? sentence.audio.substring('assets/'.length)
          : sentence.audio;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(clean));
      await _audioPlayer.onPlayerComplete
          .first
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('🔊 Sentence audio failed (continuing): $e');
    }

    if (!mounted) return;
    setState(() => _isPlaying = false);
  }

  void _scrollToActiveSentence() {
    if (_activeSentenceIndex >= _sentenceKeys.length) return;
    final key = _sentenceKeys[_activeSentenceIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.35,
      );
    });
  }

  Future<void> _onButtonPressed() async {
    if (_isPlaying) return;

    // First tap — "READY?" — start sentence 0.
    if (!_hasStartedReading) {
      await _playSentence(0);
      return;
    }

    // Subsequent taps — advance to next sentence, or go to questions.
    if (_activeSentenceIndex < _sentences.length - 1) {
      await _playSentence(_activeSentenceIndex + 1);
    } else {
      setState(() => _phase = _PassagePhase.questions);
      _playQuestionStem();
    }
  }

    Future<void> _playQuestionStem() async {
    if (_questions.isEmpty) return;
    final q = _questions[_currentQuestionIndex];
    final audio = q.stemAudio;
    if (audio == null || audio.isEmpty) return;
    if (_isPlayingQuestion) return;

    _isPlayingQuestion = true;
    try {
      final clean = audio.startsWith('assets/')
          ? audio.substring('assets/'.length)
          : audio;
      await _questionAudioPlayer.stop();
      await _questionAudioPlayer.play(AssetSource(clean));
      await _questionAudioPlayer.onPlayerComplete
          .first
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('🔊 Question stem audio failed (continuing): $e');
    }
    _isPlayingQuestion = false;
  }

  void _advanceToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
      _selectedAnswer = null;
      _answered = false;
      _cachedChoices = null;
      _cachedChoicesForIndex = -1;
    });
    _playQuestionStem();
  }

  List<String> _choicesForCurrentQuestion() {
    if (_cachedChoicesForIndex == _currentQuestionIndex &&
        _cachedChoices != null) {
      return _cachedChoices!;
    }
    final q = _questions[_currentQuestionIndex];
    final distractors = _parseDistractors(q.distractorsJson);
    final list = <String>[q.correctAnswer, ...distractors]..shuffle(Random());
    _cachedChoices = list;
    _cachedChoicesForIndex = _currentQuestionIndex;
    return list;
  }

    void _onSelectAnswer(String answer) {
    if (_answered) return;
    final q = _questions[_currentQuestionIndex];
    final isCorrect = answer == q.correctAnswer;

    // Immediate audio feedback on tap.
    if (isCorrect) {
      GameSfx.instance.playCorrect();
    } else {
      GameSfx.instance.playWrong();
    }

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (isCorrect) _passageCorrect++;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentQuestionIndex < _questions.length - 1) {
        _advanceToQuestion(_currentQuestionIndex + 1);
      } else {
        setState(() => _phase = _PassagePhase.done);
        _navigateToGame();
      }
    });
  }

  void _navigateToGame() {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    Navigator.of(context).pushReplacementNamed(
      '/game-intro',
      arguments: {
        'batchId': args['batchId'],
        'gradeLevel': args['gradeLevel'],
        'difficulty': args['difficulty'],
        'gameType': args['gameType'],
        'passageCorrect': _passageCorrect,
        'passageTotal': _questions.length,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _buildError();
    switch (_phase) {
      case _PassagePhase.loading:
        return const Center(child: CircularProgressIndicator());
      case _PassagePhase.reading:
        return _buildReading();
      case _PassagePhase.questions:
        return _buildQuestions();
      case _PassagePhase.done:
        return const Center(child: CircularProgressIndicator());
    }
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

  // ────────────────────────────────────────────────────────────
  // Reading phase
  // ────────────────────────────────────────────────────────────

  Widget _buildReading() {
    final p = _passage!;
    final screenH = MediaQuery.of(context).size.height;
    final illustrationHeight = (screenH * 0.38).clamp(220.0, 340.0);

    final isLastSentence =
        _hasStartedReading && _activeSentenceIndex >= _sentences.length - 1;
    final buttonLabel = !_hasStartedReading
        ? 'READY?'
        : isLastSentence
            ? 'ASK QUESTIONS'
            : 'NEXT SENTENCE';
    final buttonIcon = !_hasStartedReading
        ? Icons.play_arrow_rounded
        : isLastSentence
            ? Icons.quiz_rounded
            : Icons.arrow_forward_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),

          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Read the Passage', style: AppText.h2),
              ),
              if (_hasCompletedBefore)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _phase = _PassagePhase.questions);
                    _playQuestionStem();
                  },
                  icon: const Icon(Icons.fast_forward_rounded, size: 18),
                  label: const Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentTeal,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Big illustration — full width, cover fit
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              width: double.infinity,
              height: illustrationHeight,
              color: AppColors.surface,
              child: Image.asset(
                _resolveIllustrationPath(p.illustration),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 96,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            p.title,
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(fontSize: 18),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Sentences — auto-scrolling
          Expanded(
            child: Scrollbar(
              controller: _sentenceScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _sentenceScroll,
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  children: List.generate(_sentences.length, (i) {
                    final s = _sentences[i];
                    final isActive =
                        _hasStartedReading && i == _activeSentenceIndex;
                    final isDone =
                        _hasStartedReading && i < _activeSentenceIndex;

                    return GestureDetector(
                      onTap: isDone ? () => _playSentence(i) : null,
                      child: Container(
                        key: _sentenceKeys[i],
                        margin: const EdgeInsets.only(bottom: 8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.accentYellow
                                    .withValues(alpha: 0.25)
                                : AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.accentYellow
                                  : AppColors.border,
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            s.text,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isDone
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Ready / Next Sentence / Ask Questions
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPlaying ? null : _onButtonPressed,
              icon: Icon(buttonIcon),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Questions phase
  // ────────────────────────────────────────────────────────────

  Widget _buildQuestions() {
    final q = _questions[_currentQuestionIndex];
    final choices = _choicesForCurrentQuestion();

    return Container(
      // Slightly warmer background than the reading phase — visually refreshing.
      color: AppColors.accentYellow.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                const Expanded(
                  child: Text('Comprehension', style: AppText.h2),
                ),
                Text(
                  'Q ${_currentQuestionIndex + 1} / ${_questions.length}',
                  style: AppText.caption,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / _questions.length,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.accentTeal,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Mascot — top area
            Expanded(
              flex: 3,
              child: Center(
                child: Image.asset(
                  'assets/images/mascot/groo_teaching.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.school_rounded,
                    size: 80,
                    color: AppColors.accentPurple,
                  ),
                ),
              ),
            ),

            // Question stem — middle
                        // Question stem — middle, with a replay button
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      q.stem,
                      textAlign: TextAlign.center,
                      style: AppText.h2.copyWith(fontSize: 18),
                    ),
                  ),
                  if (q.stemAudio != null && q.stemAudio!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _playQuestionStem,
                      borderRadius:
                          BorderRadius.circular(AppRadius.medium),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.volume_up_rounded,
                          color: AppColors.accentTeal,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Answers — bottom thumb zone
            ...choices.map((choice) {
              final isCorrect = choice == q.correctAnswer;
              final isSelected = choice == _selectedAnswer;

              Color bg = AppColors.surface;
              Color border = AppColors.border;
              IconData? icon;
              Color? iconColor;

              if (_answered) {
                if (isCorrect) {
                  bg = AppColors.accentTeal.withValues(alpha: 0.15);
                  border = AppColors.accentTeal;
                  icon = Icons.check_circle_rounded;
                  iconColor = AppColors.accentTeal;
                } else if (isSelected) {
                  bg = AppColors.accentCoral.withValues(alpha: 0.15);
                  border = AppColors.accentCoral;
                  icon = Icons.cancel_rounded;
                  iconColor = AppColors.accentCoral;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: _answered ? null : () => _onSelectAnswer(choice),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            choice,
                            style: AppText.bodyBold.copyWith(fontSize: 15),
                          ),
                        ),
                        if (icon != null) Icon(icon, color: iconColor),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  List<String> _parseDistractors(String json) {
    try {
      final decoded = json.trim();
      if (!decoded.startsWith('[') || !decoded.endsWith(']')) return [];
      final inner = decoded.substring(1, decoded.length - 1);
      final matches = RegExp(r'"([^"]*)"').allMatches(inner);
      return matches.map((m) => m.group(1)!).toList();
    } catch (_) {
      return [];
    }
  }
}